// src/modules/subscriptions/sub.route.ts
import { FastifyInstance } from 'fastify';
import { RazorpayService, PLAN_AMOUNTS } from '../../lib/payment/razorpay.service';
import { CacheService } from '../../lib/cache/cache.service';
import { CK } from '../../lib/cache/keys';
import { OneSignalService, NOTIF_TEMPLATES } from '../../lib/notification/onesignal.service';

export async function subscriptionRoutes(fastify: FastifyInstance) {
  const cache = new CacheService(fastify.redis);

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
    const { plan } = req.body as { plan: 'PREMIUM' | 'ANNUAL' };

    if (!['PREMIUM', 'ANNUAL'].includes(plan)) {
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
        expiresAt: new Date(Date.now() + (plan === 'ANNUAL' ? 365 : 30) * 24 * 60 * 60 * 1000),
      },
    });

    return reply.send({
      orderId: order.id,
      amount: order.amount,
      currency: order.currency,
      keyId: process.env.RAZORPAY_KEY_ID,
    });
  });

  // POST /subscribe/verify
  fastify.post('/verify', { 
    preHandler: [fastify.authenticate],
    config: { rateLimit: { max: 5, timeWindow: '1 minute' } },
  }, async (req, reply) => {
    const { userId } = req.user as any;
    const { razorpayOrderId, razorpayPaymentId, razorpaySignature } = req.body as any;

    const valid = RazorpayService.verifyPaymentSignature(
      razorpayOrderId, razorpayPaymentId, razorpaySignature
    );

    if (!valid) {
      return reply.status(400).send({ error: 'Payment verification failed' });
    }

    // Get the pending subscription
    const sub = await fastify.prisma.subscription.findFirst({
      where: { userId, razorpayOrderId, status: 'PENDING' },
    });

    if (!sub) return reply.status(404).send({ error: 'Subscription not found' });

    const planDays = sub.plan === 'ANNUAL' ? 365 : 30;
    const expiresAt = new Date(Date.now() + planDays * 24 * 60 * 60 * 1000);

    // Atomic update: subscription + user plan
    await fastify.prisma.$transaction([
      fastify.prisma.subscription.update({
        where: { id: sub.id },
        data: {
          status: 'ACTIVE',
          razorpayPaymentId,
          razorpaySignature,
          expiresAt,
          startsAt: new Date(),
        },
      }),
      fastify.prisma.user.update({
        where: { id: userId },
        data: { plan: sub.plan, planExpiresAt: expiresAt },
      }),
    ]);

    // Invalidate user cache
    await cache.del(CK.userProfile(userId));
    await cache.del(CK.userPlan(userId));

    // Send welcome push
    const user = await fastify.prisma.user.findUnique({ where: { id: userId } });
    if (user?.oneSignalPlayerId) {
      OneSignalService.send({
        ...NOTIF_TEMPLATES.welcome,
        playerIds: [user.oneSignalPlayerId],
      }).catch(() => {});
    }

    return reply.send({
      success: true,
      plan: sub.plan,
      expiresAt,
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
