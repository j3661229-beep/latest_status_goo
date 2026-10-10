// src/modules/subscriptions/sub.route.ts
import { FastifyInstance } from 'fastify';
import { Plan } from '@prisma/client';
import { z } from 'zod';
import { RazorpayService, PLAN_AMOUNTS } from '../../lib/payment/razorpay.service';
import { invalidateUserCaches } from '../../lib/auth/auth-state';
import { sendValidationError } from '../../lib/http/validation';
import { env } from '../../config/env';
import { OneSignalService, NOTIF_TEMPLATES } from '../../lib/notification/onesignal.service';

const DAY_MS = 24 * 60 * 60 * 1000;
const PLAN_DAYS: Record<'PREMIUM' | 'ANNUAL', number> = { PREMIUM: 30, ANNUAL: 365 };

const VerifySchema = z.object({
  razorpayOrderId: z.string().min(1).max(100),
  razorpayPaymentId: z.string().min(1).max(100),
  razorpaySignature: z.string().min(1).max(200),
});

export async function subscriptionRoutes(fastify: FastifyInstance) {
  /**
   * Activate a PENDING subscription exactly once (safe under concurrent verify +
   * webhook). The new period starts at max(now, current planExpiresAt) so early
   * renewals don't lose remaining days. Returns null if the subscription is not
   * PENDING/ACTIVE.
   */
  async function activateSubscription(
    subscriptionId: string,
    razorpayPaymentId: string,
    razorpaySignature: string | null,
    razorpayMethod: string | null = null,
  ): Promise<{ plan: Plan; expiresAt: Date; activatedNow: boolean } | null> {
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
      // Keep the higher tier label while an annual plan is still running
      const plan: Plan = hasActivePlan && user?.plan === 'ANNUAL' ? 'ANNUAL' : sub.plan;

      // Conditional update: only one concurrent caller flips PENDING -> ACTIVE
      const flipped = await tx.subscription.updateMany({
        where: { id: sub.id, status: 'PENDING' },
        data: {
          status: 'ACTIVE',
          razorpayPaymentId,
          ...(razorpaySignature && { razorpaySignature }),
          ...(razorpayMethod && { razorpayMethod }),
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

      await tx.user.update({
        where: { id: sub.userId },
        data: { plan, planExpiresAt: expiresAt },
      });
      return { plan, expiresAt, activatedNow: true, userId: sub.userId };
    });

    if (!result) return null;
    if (result.activatedNow) {
      await invalidateUserCaches(fastify.redis, result.userId);
    }
    return { plan: result.plan, expiresAt: result.expiresAt, activatedNow: result.activatedNow };
  }

  // GET /plans
  fastify.get('/plans', async (_req, reply) => {
    return reply.send({
      plans: [
        {
          id: 'FREE',
          name: 'Free',
          amount: 0,
          currency: 'INR',
          period: null,
          features: [
            '10 image downloads/day',
            '3 video downloads/day',
            'Basic categories',
            'No watermark',
          ],
        },
        {
          id: 'PREMIUM',
          name: 'Premium Monthly',
          amount: 9900,
          currency: 'INR',
          period: 'monthly',
          features: [
            'Unlimited image + video downloads',
            'All categories including festival packs',
            'Priority support',
            'No ads',
          ],
        },
        {
          id: 'ANNUAL',
          name: 'Premium Annual',
          amount: 79900,
          currency: 'INR',
          period: 'annual',
          savings: 'Save ₹389 vs monthly',
          features: [
            'Everything in Premium Monthly',
            'Best value — ₹66.58/month',
          ],
        },
      ],
    });
  });

  // POST /subscribe/create
  fastify.post('/create', {
    preHandler: [fastify.authenticate],
    config: { rateLimit: { max: 5, timeWindow: '1 minute' } },
  }, async (req, reply) => {
    const { userId } = req.user as any;
    const { plan } = ((req.body as any) ?? {}) as { plan?: 'PREMIUM' | 'ANNUAL' };

    if (plan !== 'PREMIUM' && plan !== 'ANNUAL') {
      return reply.status(400).send({ error: 'Invalid plan' });
    }

    const order = await RazorpayService.createOrder(userId, plan);

    await fastify.prisma.subscription.create({
      data: {
        userId,
        plan,
        amount: PLAN_AMOUNTS[plan],
        currency: 'INR',
        status: 'PENDING',
        razorpayOrderId: order.id,
        startsAt: new Date(),
        expiresAt: new Date(Date.now() + PLAN_DAYS[plan] * DAY_MS),
      },
    });

    return reply.send({
      orderId: order.id,
      amount: order.amount,
      currency: order.currency,
      keyId: env.RAZORPAY_KEY_ID,
    });
  });

  // POST /subscribe/verify — client-side confirmation after Razorpay checkout.
  // Idempotent: verifying an already-activated order returns the same result.
  fastify.post('/verify', {
    preHandler: [fastify.authenticate],
    config: { rateLimit: { max: 5, timeWindow: '1 minute' } },
  }, async (req, reply) => {
    const { userId } = req.user as any;
    const parsed = VerifySchema.safeParse(req.body ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error, 'Invalid payment details');
    const { razorpayOrderId, razorpayPaymentId, razorpaySignature } = parsed.data;

    const valid = RazorpayService.verifyPaymentSignature(
      razorpayOrderId, razorpayPaymentId, razorpaySignature
    );

    if (!valid) {
      return reply.status(400).send({ error: 'Payment verification failed' });
    }

    // The order must belong to the requesting user
    const sub = await fastify.prisma.subscription.findUnique({ where: { razorpayOrderId } });
    if (!sub || sub.userId !== userId) {
      return reply.status(404).send({ error: 'Subscription not found' });
    }
    if (sub.status !== 'PENDING' && sub.status !== 'ACTIVE') {
      return reply.status(409).send({ error: `Subscription is ${sub.status.toLowerCase()}` });
    }

    const result = await activateSubscription(sub.id, razorpayPaymentId, razorpaySignature);
    if (!result) return reply.status(409).send({ error: 'Subscription could not be activated' });

    if (result.activatedNow) {
      // Send welcome push
      const user = await fastify.prisma.user.findUnique({
        where: { id: userId },
        select: { oneSignalPlayerId: true },
      });
      if (user?.oneSignalPlayerId) {
        OneSignalService.send({
          ...NOTIF_TEMPLATES.welcome,
          playerIds: [user.oneSignalPlayerId],
        }).catch(() => {});
      }
    }

    return reply.send({
      success: true,
      plan: result.plan,
      expiresAt: result.expiresAt,
    });
  });

  // POST /subscribe/webhook — Razorpay server-to-server events.
  // Registered in its own encapsulated context so the raw-body JSON parser
  // only applies here (the signature is computed over the exact raw bytes).
  await fastify.register(async (webhook) => {
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
      try {
        event = JSON.parse(raw.toString('utf8'));
      } catch {
        return reply.status(400).send({ error: 'Invalid JSON' });
      }

      // Razorpay retries deliveries — skip events we've already processed
      const eventId = req.headers['x-razorpay-event-id'];
      if (typeof eventId === 'string' && eventId) {
        const fresh = await fastify.redis.set(`rzp:evt:${eventId}`, '1', 'EX', 86400, 'NX').catch(() => 'OK');
        if (fresh === null) return reply.send({ status: 'duplicate' });
      }

      const payment = event?.payload?.payment?.entity;
      const orderId: string | undefined = event?.payload?.order?.entity?.id ?? payment?.order_id;

      if ((event?.event === 'payment.captured' || event?.event === 'order.paid') && orderId && payment?.id) {
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
      } else if (event?.event === 'payment.failed' && orderId) {
        await fastify.prisma.subscription.updateMany({
          where: { razorpayOrderId: orderId, status: 'PENDING' },
          data: {
            status: 'FAILED',
            failureReason: String(payment?.error_description ?? 'payment.failed').slice(0, 500),
          },
        });
      }

      return reply.send({ status: 'ok' });
    });
  });

  // GET /subscribe/status
  fastify.get('/status', { preHandler: [fastify.authenticate] }, async (req, reply) => {
    const { userId } = req.user as any;

    const user = await fastify.prisma.user.findUnique({
      where: { id: userId },
      select: { plan: true, planExpiresAt: true },
    });

    const daysRemaining = user?.planExpiresAt
      ? Math.ceil((user.planExpiresAt.getTime() - Date.now()) / (1000 * 60 * 60 * 24))
      : null;

    return reply.send({
      plan: user?.plan ?? 'FREE',
      expiresAt: user?.planExpiresAt ?? null,
      daysRemaining,
      features: {
        unlimitedImages: user?.plan !== 'FREE',
        unlimitedVideos: user?.plan !== 'FREE',
        festivalPacks: user?.plan !== 'FREE',
      },
    });
  });
}
