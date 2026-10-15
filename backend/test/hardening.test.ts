// Production-hardening regression tests: Redis fail-closed, cache degradation, payment secrets,
// webhook idempotency, graceful shutdown wiring.
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { createHmac } from 'crypto';
import Fastify from 'fastify';

// ── mutable env stand-in (modules read fields at call time) ─────────────────
const envMock = vi.hoisted(() => ({
  NODE_ENV: 'production',
  REDIS_URL: 'redis://x',
  REDIS_ALLOW_MEMORY_FALLBACK: false,
  RAZORPAY_KEY_ID: 'rzp_live_real',
  RAZORPAY_KEY_SECRET: 'real_secret_value',
  RAZORPAY_WEBHOOK_SECRET: 'whsec_real',
  RZP_MONTHLY_PLAN_ID: undefined as string | undefined,
  GOOGLE_CLIENT_ID: 'x', ONESIGNAL_APP_ID: undefined, ONESIGNAL_REST_KEY: undefined,
}));
vi.mock('../src/config/env', () => ({ env: envMock }));

// ── fake ioredis ────────────────────────────────────────────────────────────
const redisState = vi.hoisted(() => ({ connectError: null as Error | null, instances: [] as any[] }));
vi.mock('ioredis', () => ({
  default: class FakeRedis {
    handlers: Record<string, Function> = {};
    quit = vi.fn().mockResolvedValue('OK');
    disconnect = vi.fn();
    opts: any;
    constructor(_url: string, opts: any) { this.opts = opts; redisState.instances.push(this); }
    on(ev: string, fn: Function) { this.handlers[ev] = fn; return this; }
    async connect() { if (redisState.connectError) throw redisState.connectError; }
    async get() { return 'real-redis'; }
  },
}));

import redisPlugin from '../src/plugins/redis.plugin';
import { CacheService } from '../src/lib/cache/cache.service';
import { RazorpayService } from '../src/lib/payment/razorpay.service';
import { subscriptionRoutes } from '../src/modules/subscriptions/sub.route';

beforeEach(() => {
  Object.assign(envMock, {
    NODE_ENV: 'production', REDIS_ALLOW_MEMORY_FALLBACK: false,
    RAZORPAY_KEY_ID: 'rzp_live_real', RAZORPAY_KEY_SECRET: 'real_secret_value', RAZORPAY_WEBHOOK_SECRET: 'whsec_real',
  });
  redisState.connectError = null;
  redisState.instances.length = 0;
});

describe('Redis plugin: fails closed in production', () => {
  it('refuses to boot when Redis is unreachable', async () => {
    redisState.connectError = new Error('ECONNREFUSED');
    const app = Fastify();
    app.register(redisPlugin);
    await expect(app.ready()).rejects.toThrow(/Redis is required in production but unreachable/);
  });

  it('uses the REAL client (no memory proxy) and fails fast instead of queueing offline', async () => {
    const app = Fastify();
    await app.register(redisPlugin);
    await app.ready();
    expect(await app.redis.get('k')).toBe('real-redis'); // would be null from MemoryRedis
    const opts = redisState.instances[0].opts;
    expect(opts.enableOfflineQueue).toBe(false);
    expect(opts.maxRetriesPerRequest).toBe(1);
    expect(opts.retryStrategy(50)).toBe(5000); // keeps reconnecting forever, capped
    await app.close();
    expect(redisState.instances[0].quit).toHaveBeenCalled();
  });

  it('the in-memory fallback is only available outside production or by explicit opt-in', async () => {
    redisState.connectError = new Error('down');
    envMock.NODE_ENV = 'development';
    let app = Fastify();
    await app.register(redisPlugin);
    await app.ready();
    await app.redis.set('a', '1');
    expect(await app.redis.get('a')).toBe('1'); // served by MemoryRedis, no throw
    await app.close();

    envMock.NODE_ENV = 'production';
    envMock.REDIS_ALLOW_MEMORY_FALLBACK = true;
    app = Fastify();
    await app.register(redisPlugin);
    await app.ready();
    await app.redis.set('b', '2');
    expect(await app.redis.get('b')).toBe('2');
    await app.close();
  });
});

describe('CacheService degrades instead of failing', () => {
  const broken = () => {
    const fail = vi.fn().mockRejectedValue(new Error('Redis down'));
    return { get: fail, setex: fail, del: fail, scan: fail } as any;
  };
  beforeEach(() => { vi.spyOn(console, 'warn').mockImplementation(() => undefined); });

  it('every operation survives a Redis outage', async () => {
    const c = new CacheService(broken());
    expect(await c.get('k')).toBeNull();
    await expect(c.set('k', { a: 1 }, 10)).resolves.toBeUndefined();
    await expect(c.del('k')).resolves.toBeUndefined();
    await expect(c.delMany(['a', 'b'])).resolves.toBeUndefined();
    expect(await c.invalidatePattern('tpl:*')).toBe(0);
    await expect(c.invalidateTemplateCache('t1')).resolves.toBeUndefined();
  });
  it('still works normally when Redis is healthy', async () => {
    const store = new Map<string, string>();
    const c = new CacheService({
      get: async (k: string) => store.get(k) ?? null,
      setex: async (k: string, _t: number, v: string) => { store.set(k, v); },
    } as any);
    await c.set('x', { n: 1 }, 5);
    expect(await c.get('x')).toEqual({ n: 1 });
    expect(await c.get('missing')).toBeNull();
  });
});

describe('Razorpay: placeholder credentials are never trusted', () => {
  const sig = (secret: string, body: string) => createHmac('sha256', secret).update(body).digest('hex');

  it('placeholder secret ⇒ not configured, and payment signatures are rejected even if "correctly" signed', () => {
    envMock.RAZORPAY_KEY_SECRET = 'placeholder';
    envMock.RAZORPAY_KEY_ID = 'rzp_test_placeholder';
    expect(RazorpayService.isConfigured()).toBe(false);
    const forged = sig('placeholder', 'order_1|pay_1'); // anyone can compute this
    expect(RazorpayService.verifyPaymentSignature('order_1', 'pay_1', forged)).toBe(false);
    expect(RazorpayService.verifySubscriptionPaymentSignature('sub_1', 'pay_1', sig('placeholder', 'pay_1|sub_1'))).toBe(false);
  });
  it('real secret ⇒ valid signatures pass, tampered ones fail', () => {
    expect(RazorpayService.isConfigured()).toBe(true);
    expect(RazorpayService.verifyPaymentSignature('o1', 'p1', sig('real_secret_value', 'o1|p1'))).toBe(true);
    expect(RazorpayService.verifyPaymentSignature('o1', 'p2', sig('real_secret_value', 'o1|p1'))).toBe(false);
    expect(RazorpayService.verifyPaymentSignature('o1', 'p1', 'zz')).toBe(false);
    expect(RazorpayService.verifySubscriptionPaymentSignature('s1', 'p1', sig('real_secret_value', 'p1|s1'))).toBe(true);
  });
  it('webhook secret placeholder ⇒ webhook verification always fails', () => {
    envMock.RAZORPAY_WEBHOOK_SECRET = 'placeholder';
    const body = Buffer.from('{}');
    expect(RazorpayService.verifyWebhookSignature(body, sig('placeholder', '{}'))).toBe(false);
  });
});

describe('subscription routes', () => {
  async function build(redis: any, prisma: any = {}) {
    const app = Fastify();
    app.decorate('prisma', prisma);
    app.decorate('redis', redis);
    app.decorate('authenticate', async (req: any) => { req.user = { userId: 'u1', role: 'USER' }; });
    app.decorate('optionalAuthenticate', async () => undefined);
    app.decorate('requireRole', () => async () => undefined);
    await app.register(subscriptionRoutes, { prefix: '/subscribe' });
    return app;
  }
  const webhook = (app: any, body: object, secret = 'whsec_real', eventId = 'evt_1') => {
    const raw = JSON.stringify(body);
    return app.inject({
      method: 'POST', url: '/subscribe/webhook', payload: raw,
      headers: { 'content-type': 'application/json', 'x-razorpay-signature': sig(secret, raw), 'x-razorpay-event-id': eventId },
    });
  };
  const sig = (secret: string, body: string) => createHmac('sha256', secret).update(body).digest('hex');
  const prismaSpy = () => ({ subscription: { findUnique: vi.fn().mockResolvedValue(null), updateMany: vi.fn(), update: vi.fn() }, user: { update: vi.fn() } });

  it('webhook: Redis failure ⇒ 503 and the event is NOT processed (so Razorpay retries)', async () => {
    const prisma = prismaSpy();
    const app = await build({ set: vi.fn().mockRejectedValue(new Error('Redis down')) }, prisma);
    const r = await webhook(app, { event: 'subscription.cancelled', payload: { subscription: { entity: { id: 'sub_1' } } } });
    expect(r.statusCode).toBe(503);
    expect(prisma.subscription.findUnique).not.toHaveBeenCalled();
    expect(prisma.subscription.updateMany).not.toHaveBeenCalled();
  });
  it('webhook: a replayed event id is acknowledged without being processed again', async () => {
    const prisma = prismaSpy();
    const app = await build({ set: vi.fn().mockResolvedValue(null) }, prisma); // NX failed ⇒ already seen
    const r = await webhook(app, { event: 'subscription.completed', payload: { subscription: { entity: { id: 'sub_1' } } } });
    expect(r.json()).toEqual({ status: 'duplicate' });
    expect(prisma.subscription.updateMany).not.toHaveBeenCalled();
  });
  it('webhook: a first-seen event is processed', async () => {
    const prisma = prismaSpy();
    const app = await build({ set: vi.fn().mockResolvedValue('OK') }, prisma);
    const r = await webhook(app, { event: 'subscription.completed', payload: { subscription: { entity: { id: 'sub_9' } } } });
    expect(r.statusCode).toBe(200);
    expect(prisma.subscription.updateMany).toHaveBeenCalledWith({ where: { razorpaySubId: 'sub_9' }, data: { status: 'EXPIRED' } });
  });
  it('webhook: bad signature ⇒ 400 and Redis is never consulted', async () => {
    const redis = { set: vi.fn() };
    const app = await build(redis);
    const r = await webhook(app, { event: 'x' }, 'wrong_secret');
    expect(r.statusCode).toBe(400);
    expect(redis.set).not.toHaveBeenCalled();
  });
  it('production + placeholder credentials ⇒ payment-creating POSTs are refused with 503; reads still work', async () => {
    envMock.RAZORPAY_KEY_SECRET = 'placeholder';
    envMock.RAZORPAY_KEY_ID = 'rzp_test_placeholder';
    const app = await build({});
    const create = await app.inject({ method: 'POST', url: '/subscribe/create', payload: { plan: 'PREMIUM' } });
    expect(create.statusCode).toBe(503);
    expect(create.json().error).toMatch(/not configured/);
    // Reads are not blocked by the payments guard (whatever they return, it is not the 503 guard).
    const plans = await app.inject({ method: 'GET', url: '/subscribe/plans' });
    expect(plans.json().error ?? '').not.toMatch(/not configured/);
  });
  it('non-production keeps working with placeholder credentials (local development)', async () => {
    envMock.NODE_ENV = 'development';
    envMock.RAZORPAY_KEY_SECRET = 'placeholder';
    const app = await build({});
    const r = await app.inject({ method: 'POST', url: '/subscribe/create', payload: { plan: 'PREMIUM' } });
    expect(r.statusCode).not.toBe(503);
  });
});
