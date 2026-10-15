// src/modules/subscriptions/sub.route.ts
import { FastifyInstance } from 'fastify';
import { Plan } from '@prisma/client';
import { z } from 'zod';
import { RazorpayService, PLAN_AMOUNTS, RZP_PLAN_INTERVALS } from '../../lib/payment/razorpay.service';
import { invalidateUserCaches } from '../../lib/auth/auth-state';
import { sendValidationError } from '../../lib/http/validation';
import { env } from '../../config/env';
import { OneSignalService, NOTIF_TEMPLATES } from '../../lib/notification/onesignal.service';

const DAY_MS = 24 * 60 * 60 * 1000;
const PLAN_DAYS: Record<'PREMIUM' | 'ANNUAL', number> = { PREMIUM: 30, ANNUAL: 365 };
const INTRO_OFFER_DAYS = 30;

// ─── Zod Schemas ───────────────────────────────────────────────────────────────

const VerifySchema = z.object({
  razorpayOrderId:    z.string().min(1).max(100),
  razorpayPaymentId:  z.string().min(1).max(100),
  razorpaySignature:  z.string().min(1).max(500),
});

const IntroVerifySchema = z.object({
  razorpaySubscriptionId: z.string().min(1).max(100),
  razorpayPaymentId:      z.string().min(1).max(100),
  razorpaySignature:      z.string().min(1).max(500),
});

const CancelSchema = z.object({
  cancelAtCycleEnd: z.boolean().default(true),
});

// ─── Route Handler ─────────────────────────────────────────────────────────────

export async function subscriptionRoutes(fastify: FastifyInstance) {

  // In production, refuse to start any payment flow while Razorpay still has its placeholder credentials.
  // (The webhook scope already returns 503 on its own when its secret is a placeholder.)
  fastify.addHook('onRequest', async (req, reply) => {
    if (env.NODE_ENV === 'production' && req.method === 'POST' && !req.url.includes('/webhook') && !RazorpayService.isConfigured()) {
      return reply.status(503).send({ error: 'Payments are not configured' });
    }
  });

  // ── Helper: resolve the monthly plan ID ──────────────────────────────────────
  async function getMonthlyPlanId(): Promise<string | null> {
    if (env.RZP_MONTHLY_PLAN_ID) return env.RZP_MONTHLY_PLAN_ID;
    const row = await fastify.prisma.appConfig.findUnique({ where: { key: 'rzp_plan_id_monthly' } });
    return row?.value ?? null;
  }

  // ── Helper: send premium welcome push ─────────────────────────────────────────
  async function sendWelcomePush(userId: string) {
    const user = await fastify.prisma.user.findUnique({
      where: { id: userId },
      select: { oneSignalPlayerId: true },
    });
    if (user?.oneSignalPlayerId) {
      OneSignalService.send({ ...NOTIF_TEMPLATES.welcome, playerIds: [user.oneSignalPlayerId] }).catch(() => {});
    }
  }

  // ── Helper: activate a ONE-TIME order subscription ───────────────────────────
  async function activateSubscription(
    subscriptionId: string,
    razorpayPaymentId: string,
    razorpaySignature: string | null,
    razorpayMethod: string | null = null,
  ): Promise<{ plan: Plan; expiresAt: Date; activatedNow: boolean; userId: string } | null> {
    const result = await fastify.prisma.$transaction(async (tx) => {
      const sub = await tx.subscription.findUnique({ where: { id: subscriptionId } });
      if (!sub) return null;
      if (sub.status === 'ACTIVE') {
        return { plan: sub.plan, expiresAt: sub.expiresAt, activatedNow: false, userId: sub.userId };
      }
      if (sub.status !== 'PENDING') return null;

      const user = await tx.user.findUnique({
        where: { id: sub.userId },
        select: { plan: true, planExpiresAt: true },
      });
      const now = new Date();
      const currentExpiry = user && user.plan !== 'FREE' ? user.planExpiresAt : null;
      const hasActivePlan = !!currentExpiry && currentExpiry > now;
      const base = hasActivePlan && currentExpiry ? currentExpiry : now;
      const days = PLAN_DAYS[sub.plan as 'PREMIUM' | 'ANNUAL'] ?? 30;
      const expiresAt = new Date(base.getTime() + days * DAY_MS);
      const plan: Plan = hasActivePlan && user?.plan === 'ANNUAL' ? 'ANNUAL' : sub.plan;

      const flipped = await tx.subscription.updateMany({
        where: { id: sub.id, status: 'PENDING' },
        data: {
          status: 'ACTIVE',
          razorpayPaymentId,
          ...(razorpaySignature && { razorpaySignature }),
          ...(razorpayMethod    && { razorpayMethod }),
          startsAt: now,
          expiresAt,
        },
      });
      if (flipped.count === 0) {
        const current = await tx.subscription.findUnique({ where: { id: sub.id } });
        return current?.status === 'ACTIVE'
          ? { plan: current.plan, expiresAt: current.expiresAt, activatedNow: false, userId: current.userId }
          : null;
      }
      await tx.user.update({ where: { id: sub.userId }, data: { plan, planExpiresAt: expiresAt } });
      return { plan, expiresAt, activatedNow: true, userId: sub.userId };
    });

    if (!result) return null;
    if (result.activatedNow) await invalidateUserCaches(fastify.redis, result.userId);
    return result;
  }

  // ── Helper: activate INTRO subscription after ₹1 authentication ───────────────
  async function activateIntroSubscription(
    dbSubId: string,
    razorpayPaymentId: string,
    razorpaySignature: string | null,
  ): Promise<{ expiresAt: Date; activatedNow: boolean; userId: string } | null> {
    const result = await fastify.prisma.$transaction(async (tx) => {
      const sub = await tx.subscription.findUnique({ where: { id: dbSubId } });
      if (!sub || !sub.isRecurring) return null;
      if (sub.status === 'ACTIVE') {
        return { expiresAt: sub.expiresAt, activatedNow: false, userId: sub.userId };
      }
      if (sub.status !== 'PENDING') return null;

      const now = new Date();
      const expiresAt = new Date(now.getTime() + INTRO_OFFER_DAYS * DAY_MS);

      const flipped = await tx.subscription.updateMany({
        where: { id: sub.id, status: 'PENDING' },
        data: {
          status: 'ACTIVE',
          razorpayPaymentId,
          ...(razorpaySignature && { razorpaySignature }),
          startsAt: now,
          expiresAt,
        },
      });
      if (flipped.count === 0) {
        const current = await tx.subscription.findUnique({ where: { id: sub.id } });
        return current?.status === 'ACTIVE'
          ? { expiresAt: current.expiresAt, activatedNow: false, userId: current.userId }
          : null;
      }

      await tx.user.update({
        where: { id: sub.userId },
        data: {
          plan: 'PREMIUM',
          planExpiresAt: expiresAt,
          introOfferClaimedAt: now,
          activeRzpSubId: sub.razorpaySubId,
        },
      });
      return { expiresAt, activatedNow: true, userId: sub.userId };
    });

    if (!result) return null;
    if (result.activatedNow) await invalidateUserCaches(fastify.redis, result.userId);
    return result;
  }

  // ── Helper: extend plan on successful recurring charge ───────────────────────
  async function handleRecurringRenewal(
    rzpSubId: string,
    razorpayPaymentId: string,
    method: string | null,
  ): Promise<void> {
    const sub = await fastify.prisma.subscription.findUnique({ where: { razorpaySubId: rzpSubId } });
    if (!sub) { fastify.log.warn({ rzpSubId }, 'subscription.charged: no DB record'); return; }

    await fastify.prisma.$transaction(async (tx) => {
      const user = await tx.user.findUnique({
        where: { id: sub.userId },
        select: { planExpiresAt: true },
      });
      const now = new Date();
      const base = user?.planExpiresAt && user.planExpiresAt > now ? user.planExpiresAt : now;
      const newExpiry = new Date(base.getTime() + 30 * DAY_MS);

      await tx.subscription.update({
        where: { id: sub.id },
        data: {
          status: 'ACTIVE',
          razorpayPaymentId,
          ...(method && { razorpayMethod: method }),
          expiresAt: newExpiry,
          failureReason: null,
        },
      });
      await tx.user.update({
        where: { id: sub.userId },
        data: { plan: 'PREMIUM', planExpiresAt: newExpiry },
      });
    });

    await invalidateUserCaches(fastify.redis, sub.userId);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  GET /subscribe/plans
  // ═══════════════════════════════════════════════════════════════════════════

  fastify.get('/plans', async (_req, reply) => {
    const planId = await getMonthlyPlanId();
    return reply.send({
      introOffer: {
        available: !!planId,
        upfrontAmount: 100,
        upfrontAmountDisplay: '₹1',
        recurringAmount: 9900,
        recurringAmountDisplay: '₹99',
        recurringPeriod: 'monthly',
        trialDays: INTRO_OFFER_DAYS,
        description: 'पहले 30 दिन सिर्फ ₹1 — फिर ₹99/माह AutoPay से',
      },
      plans: [
        {
          id: 'FREE', name: 'Free', amount: 0, currency: 'INR', period: null,
          features: ['10 image downloads/day', '3 video downloads/day', 'Basic categories', 'No watermark'],
        },
        {
          id: 'PREMIUM', name: 'Premium Monthly', amount: 9900, currency: 'INR', period: 'monthly',
          features: ['Unlimited image + video downloads', 'All categories including festival packs', 'Priority support', 'No ads'],
        },
        {
          id: 'ANNUAL', name: 'Premium Annual', amount: 79900, currency: 'INR', period: 'annual',
          savings: 'Save ₹389 vs monthly',
          features: ['Everything in Premium Monthly', 'Best value — ₹66.58/month'],
        },
      ],
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  ONE-TIME ORDER FLOW (existing — unchanged)
  // ═══════════════════════════════════════════════════════════════════════════

  fastify.post('/create', {
    preHandler: [fastify.authenticate],
    config: { rateLimit: { max: 5, timeWindow: '1 minute' } },
  }, async (req, reply) => {
    const { userId } = req.user as any;
    const { plan } = ((req.body as any) ?? {}) as { plan?: 'PREMIUM' | 'ANNUAL' };
    if (plan !== 'PREMIUM' && plan !== 'ANNUAL') return reply.status(400).send({ error: 'Invalid plan' });

    const order = await RazorpayService.createOrder(userId, plan);
    await fastify.prisma.subscription.create({
      data: {
        userId, plan, amount: PLAN_AMOUNTS[plan], currency: 'INR', status: 'PENDING',
        razorpayOrderId: order.id,
        startsAt: new Date(),
        expiresAt: new Date(Date.now() + PLAN_DAYS[plan] * DAY_MS),
      },
    });

    return reply.send({ orderId: order.id, amount: order.amount, currency: order.currency, keyId: env.RAZORPAY_KEY_ID });
  });

  fastify.post('/verify', {
    preHandler: [fastify.authenticate],
    config: { rateLimit: { max: 5, timeWindow: '1 minute' } },
  }, async (req, reply) => {
    const { userId } = req.user as any;
    const parsed = VerifySchema.safeParse(req.body ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error, 'Invalid payment details');
    const { razorpayOrderId, razorpayPaymentId, razorpaySignature } = parsed.data;

    if (!RazorpayService.verifyPaymentSignature(razorpayOrderId, razorpayPaymentId, razorpaySignature)) {
      return reply.status(400).send({ error: 'Payment verification failed' });
    }

    const sub = await fastify.prisma.subscription.findUnique({ where: { razorpayOrderId } });
    if (!sub || sub.userId !== userId) return reply.status(404).send({ error: 'Subscription not found' });
    if (sub.status !== 'PENDING' && sub.status !== 'ACTIVE') {
      return reply.status(409).send({ error: `Subscription is ${sub.status.toLowerCase()}` });
    }

    const result = await activateSubscription(sub.id, razorpayPaymentId, razorpaySignature);
    if (!result) return reply.status(409).send({ error: 'Subscription could not be activated' });
    if (result.activatedNow) await sendWelcomePush(userId);

    return reply.send({ success: true, plan: result.plan, expiresAt: result.expiresAt });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  INTRO OFFER FLOW (new)
  // ═══════════════════════════════════════════════════════════════════════════

  // POST /subscribe/intro/setup-plan — SUPER_ADMIN only, called ONCE to create
  // plan_XXXX in Razorpay and persist its ID in AppConfig. Idempotent.
  fastify.post('/intro/setup-plan', {
    preHandler: [fastify.authenticate],
    config: { rateLimit: { max: 3, timeWindow: '1 minute' } },
  }, async (req, reply) => {
    const { role } = (req.user as any);
    if (role !== 'SUPER_ADMIN') return reply.status(403).send({ error: 'Forbidden' });

    const existing = await fastify.prisma.appConfig.findUnique({ where: { key: 'rzp_plan_id_monthly' } });
    if (existing?.value) return reply.send({ planId: existing.value, created: false });

    const plan = await RazorpayService.createPlan('PREMIUM');
    await fastify.prisma.appConfig.upsert({
      where:  { key: 'rzp_plan_id_monthly' },
      create: { key: 'rzp_plan_id_monthly', value: plan.id, type: 'string', description: 'Razorpay plan_XXXX for ₹99/month recurring subscription' },
      update: { value: plan.id },
    });

    fastify.log.info({ planId: plan.id }, 'Razorpay monthly plan created');
    return reply.send({ planId: plan.id, created: true });
  });

  // POST /subscribe/intro/create — eligibility check + create Razorpay sub
  fastify.post('/intro/create', {
    preHandler: [fastify.authenticate],
    config: { rateLimit: { max: 3, timeWindow: '1 day' } },
  }, async (req, reply) => {
    const { userId } = req.user as any;

    const planId = await getMonthlyPlanId();
    if (!planId) return reply.status(503).send({ error: 'Intro offer not configured' });

    const user = await fastify.prisma.user.findUnique({
      where: { id: userId },
      select: { introOfferClaimedAt: true, plan: true },
    });
    if (!user) return reply.status(404).send({ error: 'User not found' });

    if (user.introOfferClaimedAt) {
      return reply.status(409).send({
        error: 'intro_already_claimed',
        message: 'यह ऑफर केवल एक बार उपलब्ध है। आप पहले ही इसका उपयोग कर चुके हैं।',
      });
    }
    if (user.plan !== 'FREE') {
      return reply.status(409).send({ error: 'already_premium', message: 'आप पहले से प्रीमियम सदस्य हैं।' });
    }

    // Resume an existing PENDING intro subscription rather than creating a duplicate
    const existingSub = await fastify.prisma.subscription.findFirst({
      where: { userId, isRecurring: true, status: 'PENDING' },
    });
    if (existingSub?.razorpaySubId) {
      const now = new Date();
      return reply.send({
        subscriptionId: existingSub.razorpaySubId,
        upfrontAmount: 100,
        upfrontAmountDisplay: '₹1',
        firstRenewalAt: new Date(now.getTime() + INTRO_OFFER_DAYS * DAY_MS),
        recurringAmount: 9900,
        recurringAmountDisplay: '₹99/माह',
        keyId: env.RAZORPAY_KEY_ID,
        resumed: true,
      });
    }

    const rzpSub = await RazorpayService.createIntroSubscription(planId, userId);

    const now = new Date();
    const firstRenewalAt = new Date(now.getTime() + INTRO_OFFER_DAYS * DAY_MS);
    await fastify.prisma.subscription.create({
      data: {
        userId,
        plan: 'PREMIUM',
        amount: 100,
        currency: 'INR',
        status: 'PENDING',
        razorpaySubId: rzpSub.id,
        isRecurring: true,
        startsAt: now,
        expiresAt: firstRenewalAt,
        metadata: { offer: 'intro_30d_1rs', planId },
      },
    });

    return reply.send({
      subscriptionId: rzpSub.id,
      upfrontAmount: 100,
      upfrontAmountDisplay: '₹1',
      firstRenewalAt,
      recurringAmount: 9900,
      recurringAmountDisplay: '₹99/माह',
      keyId: env.RAZORPAY_KEY_ID,
      shortUrl: rzpSub.short_url,
    });
  });

  // POST /subscribe/intro/verify — Flutter calls this after Razorpay checkout success
  fastify.post('/intro/verify', {
    preHandler: [fastify.authenticate],
    config: { rateLimit: { max: 5, timeWindow: '1 minute' } },
  }, async (req, reply) => {
    const { userId } = req.user as any;
    const parsed = IntroVerifySchema.safeParse(req.body ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error, 'Invalid payment details');
    const { razorpaySubscriptionId, razorpayPaymentId, razorpaySignature } = parsed.data;

    // HMAC-SHA256(paymentId|subscriptionId, key_secret)
    if (!RazorpayService.verifySubscriptionPaymentSignature(razorpaySubscriptionId, razorpayPaymentId, razorpaySignature)) {
      return reply.status(400).send({ error: 'Payment verification failed' });
    }

    const sub = await fastify.prisma.subscription.findUnique({ where: { razorpaySubId: razorpaySubscriptionId } });
    if (!sub || sub.userId !== userId) return reply.status(404).send({ error: 'Subscription not found' });

    if (sub.status === 'ACTIVE') {
      return reply.send({ success: true, plan: 'PREMIUM', expiresAt: sub.expiresAt, alreadyActive: true });
    }
    if (sub.status !== 'PENDING') {
      return reply.status(409).send({ error: `Subscription is ${sub.status.toLowerCase()}` });
    }

    const result = await activateIntroSubscription(sub.id, razorpayPaymentId, razorpaySignature);
    if (!result) return reply.status(409).send({ error: 'Subscription could not be activated' });
    if (result.activatedNow) await sendWelcomePush(userId);

    return reply.send({
      success: true,
      plan: 'PREMIUM',
      expiresAt: result.expiresAt,
      nextBillingAt: result.expiresAt,
      recurringAmount: 9900,
    });
  });

  // POST /subscribe/cancel — cancel recurring sub at end of current cycle
  fastify.post('/cancel', {
    preHandler: [fastify.authenticate],
    config: { rateLimit: { max: 3, timeWindow: '1 minute' } },
  }, async (req, reply) => {
    const { userId } = req.user as any;
    const parsed = CancelSchema.safeParse(req.body ?? {});
    const cancelAtCycleEnd = parsed.success ? parsed.data.cancelAtCycleEnd : true;

    const user = await fastify.prisma.user.findUnique({
      where: { id: userId },
      select: { activeRzpSubId: true },
    });
    if (!user?.activeRzpSubId) {
      return reply.status(404).send({ error: 'No active recurring subscription found' });
    }

    await RazorpayService.cancelSubscription(user.activeRzpSubId, cancelAtCycleEnd);

    await fastify.prisma.subscription.updateMany({
      where: { userId, razorpaySubId: user.activeRzpSubId, status: 'ACTIVE' },
      data: { status: 'CANCELLED', cancelledAt: new Date() },
    });
    await fastify.prisma.user.update({ where: { id: userId }, data: { activeRzpSubId: null } });
    await invalidateUserCaches(fastify.redis, userId);

    return reply.send({
      success: true,
      message: cancelAtCycleEnd
        ? 'आपका प्रीमियम वर्तमान cycle के अंत तक सक्रिय रहेगा।'
        : 'Subscription तुरंत रद्द कर दिया गया।',
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  WEBHOOK — handles order events (existing) + subscription lifecycle (new)
  // ═══════════════════════════════════════════════════════════════════════════

  await fastify.register(async (webhook) => {
    if (webhook.hasContentTypeParser('application/json')) {
      webhook.removeContentTypeParser('application/json');
    }
    webhook.addContentTypeParser('application/json', { parseAs: 'buffer' }, (_req, body, done) => {
      done(null, body);
    });

    webhook.post('/webhook', async (req, reply) => {
      if (!RazorpayService.isWebhookConfigured()) {
        return reply.status(503).send({ error: 'Webhook not configured' });
      }

      const raw = req.body as Buffer;
      const signature = req.headers['x-razorpay-signature'];
      if (!Buffer.isBuffer(raw) || typeof signature !== 'string'
        || !RazorpayService.verifyWebhookSignature(raw, signature)) {
        return reply.status(400).send({ error: 'Invalid signature' });
      }

      let event: any;
      try { event = JSON.parse(raw.toString('utf8')); }
      catch { return reply.status(400).send({ error: 'Invalid JSON' }); }

      // Idempotency — Razorpay retries on non-2xx; skip duplicates
      const eventId = req.headers['x-razorpay-event-id'];
      if (typeof eventId === 'string' && eventId) {
        let fresh: string | null;
        try {
          fresh = await fastify.redis.set(`rzp:evt:${eventId}`, '1', 'EX', 86400, 'NX');
        } catch (err) {
          // Cannot prove this event is new → do NOT process it (a replay could grant premium twice).
          // 503 makes Razorpay retry later, when Redis is back.
          req.log.error({ err, eventId }, 'webhook idempotency store unavailable');
          return reply.status(503).send({ error: 'Temporarily unavailable, retry later' });
        }
        if (fresh === null) return reply.send({ status: 'duplicate' });
      }

      const eventType: string = event?.event ?? '';
      const payment   = event?.payload?.payment?.entity;
      const subEntity = event?.payload?.subscription?.entity;

      fastify.log.info({ eventType, rzpSubId: subEntity?.id, paymentId: payment?.id }, 'Razorpay webhook received');

      // ── Subscription lifecycle events ──────────────────────────────────

      if (eventType === 'subscription.authenticated' && subEntity?.id && payment?.id) {
        // ₹1 charged successfully; mandate set up. Grant 30-day access.
        const sub = await fastify.prisma.subscription.findUnique({ where: { razorpaySubId: subEntity.id } });
        if (sub && sub.status === 'PENDING') {
          const result = await activateIntroSubscription(sub.id, payment.id, null);
          if (result?.activatedNow) await sendWelcomePush(sub.userId);
        }

      } else if (eventType === 'subscription.charged' && subEntity?.id && payment?.id) {
        // Recurring renewal charge succeeded — extend plan 30 more days
        await handleRecurringRenewal(subEntity.id, payment.id, payment.method ?? null);

      } else if (eventType === 'subscription.halted' && subEntity?.id) {
        // All Razorpay retries exhausted; subscription paused. Do NOT downgrade immediately —
        // the hourly plan_expiry worker handles expiry when planExpiresAt passes.
        const sub = await fastify.prisma.subscription.findUnique({ where: { razorpaySubId: subEntity.id } });
        if (sub) {
          await fastify.prisma.subscription.update({
            where: { id: sub.id },
            data: { status: 'FAILED', failureReason: 'AutoPay failed after retries — subscription halted by Razorpay' },
          });
          fastify.log.warn({ rzpSubId: subEntity.id, userId: sub.userId }, 'Subscription halted');
        }

      } else if (eventType === 'subscription.cancelled' && subEntity?.id) {
        // Cancellation confirmed — may be triggered by our API or directly from user's UPI app
        const sub = await fastify.prisma.subscription.findUnique({ where: { razorpaySubId: subEntity.id } });
        if (sub && sub.status !== 'CANCELLED') {
          await fastify.prisma.subscription.update({
            where: { id: sub.id },
            data: { status: 'CANCELLED', cancelledAt: new Date() },
          });
          await fastify.prisma.user.update({ where: { id: sub.userId }, data: { activeRzpSubId: null } });
          await invalidateUserCaches(fastify.redis, sub.userId);
        }

      } else if (eventType === 'subscription.completed' && subEntity?.id) {
        // All total_count cycles exhausted
        await fastify.prisma.subscription.updateMany({
          where: { razorpaySubId: subEntity.id },
          data: { status: 'EXPIRED' },
        });

      // ── One-time order events (existing — preserved) ──────────────────

      } else if ((eventType === 'payment.captured' || eventType === 'order.paid') && payment?.id) {
        const orderId: string | undefined = event?.payload?.order?.entity?.id ?? payment?.order_id;
        if (orderId) {
          const sub = await fastify.prisma.subscription.findUnique({ where: { razorpayOrderId: orderId } });
          if (sub && (sub.status === 'PENDING' || sub.status === 'FAILED')) {
            if (sub.status === 'FAILED') {
              await fastify.prisma.subscription.updateMany({
                where: { id: sub.id, status: 'FAILED' },
                data: { status: 'PENDING', failureReason: null },
              });
            }
            await activateSubscription(sub.id, payment.id, null, payment.method ?? null);
          }
        }

      } else if (eventType === 'payment.failed') {
        const orderId: string | undefined = event?.payload?.order?.entity?.id ?? payment?.order_id;
        if (orderId) {
          await fastify.prisma.subscription.updateMany({
            where: { razorpayOrderId: orderId, status: 'PENDING' },
            data: {
              status: 'FAILED',
              failureReason: String(payment?.error_description ?? 'payment.failed').slice(0, 500),
            },
          });
        }
      }

      return reply.send({ status: 'ok' });
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  GET /subscribe/status — extended with recurring info + intro eligibility
  // ═══════════════════════════════════════════════════════════════════════════

  fastify.get('/status', { preHandler: [fastify.authenticate] }, async (req, reply) => {
    const { userId } = req.user as any;

    const user = await fastify.prisma.user.findUnique({
      where: { id: userId },
      select: { plan: true, planExpiresAt: true, introOfferClaimedAt: true, activeRzpSubId: true },
    });

    const daysRemaining = user?.planExpiresAt
      ? Math.ceil((user.planExpiresAt.getTime() - Date.now()) / (1000 * 60 * 60 * 24))
      : null;

    const activeSub = user?.activeRzpSubId
      ? await fastify.prisma.subscription.findUnique({
          where: { razorpaySubId: user.activeRzpSubId },
          select: { expiresAt: true, isRecurring: true, status: true },
        })
      : null;

    return reply.send({
      plan: user?.plan ?? 'FREE',
      expiresAt: user?.planExpiresAt ?? null,
      daysRemaining,
      isRecurring: !!activeSub?.isRecurring && activeSub?.status === 'ACTIVE',
      nextBillingAt: activeSub?.isRecurring && activeSub?.status === 'ACTIVE' ? activeSub.expiresAt : null,
      recurringAmount: 9900,
      rzpSubId: user?.activeRzpSubId ?? null,
      introEligible: !user?.introOfferClaimedAt && user?.plan === 'FREE',
      features: {
        unlimitedImages: user?.plan !== 'FREE',
        unlimitedVideos: user?.plan !== 'FREE',
        festivalPacks:   user?.plan !== 'FREE',
      },
    });
  });
}

