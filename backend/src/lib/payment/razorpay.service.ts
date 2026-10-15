// src/lib/payment/razorpay.service.ts
import Razorpay from 'razorpay';
import { createHmac, timingSafeEqual } from 'crypto';
import { env } from '../../config/env';

let razorpayInstance: Razorpay | null = null;

function getRazorpay(): Razorpay {
  if (!razorpayInstance) {
    razorpayInstance = new Razorpay({
      key_id: env.RAZORPAY_KEY_ID,
      key_secret: env.RAZORPAY_KEY_SECRET,
    });
  }
  return razorpayInstance;
}

// Plan amounts for one-time orders (fallback / legacy)
export const PLAN_AMOUNTS = {
  PREMIUM: 9900,   // ₹99 in paise
  ANNUAL:  79900,  // ₹799 in paise
} as const;

// Razorpay Subscription plan IDs (created once via /subscribe/rzp-plan/sync or the dashboard)
// These are stored in AppConfig rows: key = "rzp_plan_id_monthly" / "rzp_plan_id_annual"
export const RZP_PLAN_INTERVALS: Record<'PREMIUM' | 'ANNUAL', { period: string; interval: number; amount: number; name: string }> = {
  PREMIUM: { period: 'monthly', interval: 1, amount: 9900,  name: 'Status Go Premium Monthly' },
  ANNUAL:  { period: 'yearly',  interval: 1, amount: 79900, name: 'Status Go Premium Annual'  },
};

export interface RazorpayOrder {
  id: string;
  amount: number;
  currency: string;
  receipt: string;
}

export interface RazorpaySubscription {
  id: string;           // sub_XXXX
  plan_id: string;
  status: string;
  short_url: string;
  total_count: number;
  quantity: number;
}

export interface RazorpayPlan {
  id: string;           // plan_XXXX
  entity: string;
  interval: number;
  period: string;
  item: { amount: number; currency: string; name: string };
}

const PLACEHOLDER_SECRETS = new Set(['', 'placeholder', 'XXXXX']);

export class RazorpayService {
  /** True when real API credentials are configured (not the boot-time placeholder defaults). */
  static isConfigured(): boolean {
    return !PLACEHOLDER_SECRETS.has(env.RAZORPAY_KEY_SECRET) && !env.RAZORPAY_KEY_ID.endsWith('_placeholder');
  }

  // ─── One-time Order (legacy / fallback) ───────────────────────────────────

  static async createOrder(userId: string, plan: 'PREMIUM' | 'ANNUAL'): Promise<RazorpayOrder> {
    const amount = PLAN_AMOUNTS[plan];
    const receipt = `sg_${userId.slice(-8)}_${Date.now()}`;

    const order = await getRazorpay().orders.create({
      amount,
      currency: 'INR',
      receipt,
    });

    return {
      id: order.id,
      amount: order.amount as number,
      currency: order.currency,
      receipt: order.receipt as string,
    };
  }

  static verifyPaymentSignature(
    orderId: string,
    paymentId: string,
    signature: string
  ): boolean {
    // With the placeholder secret the HMAC key is public knowledge: anyone could forge a "valid" payment.
    if (!this.isConfigured()) return false;
    const body = `${orderId}|${paymentId}`;
    const expectedSignature = createHmac('sha256', env.RAZORPAY_KEY_SECRET)
      .update(body)
      .digest('hex');
    try {
      return timingSafeEqual(
        Buffer.from(expectedSignature, 'hex'),
        Buffer.from(signature, 'hex')
      );
    } catch {
      return false;
    }
  }

  // ─── Razorpay Subscription Plans ──────────────────────────────────────────

  /**
   * Create a Razorpay plan object (called once; ID stored in AppConfig).
   * Idempotent: pass an existing plan_id to fetch instead of creating.
   */
  static async createPlan(planKey: 'PREMIUM' | 'ANNUAL'): Promise<RazorpayPlan> {
    const cfg = RZP_PLAN_INTERVALS[planKey];
    const plan = await (getRazorpay() as any).plans.create({
      period: cfg.period,
      interval: cfg.interval,
      item: {
        name: cfg.name,
        amount: cfg.amount,
        currency: 'INR',
        description: cfg.name,
      },
    });
    return plan as RazorpayPlan;
  }

  static async fetchPlan(planId: string): Promise<RazorpayPlan> {
    return (await (getRazorpay() as any).plans.fetch(planId)) as RazorpayPlan;
  }

  // ─── Razorpay Subscriptions ───────────────────────────────────────────────

  /**
   * Create a standard Razorpay Subscription for auto-renewal.
   *  - total_count: how many billing cycles (120 ≈ 10 years)
   *  - expire_by: unix timestamp after which the link expires if not authenticated
   */
  static async createSubscription(
    planId: string,
    options: {
      totalCount?: number;
      expireBy?: number;
      notes?: Record<string, string>;
    } = {}
  ): Promise<RazorpaySubscription> {
    const expireBy = options.expireBy ?? Math.floor(Date.now() / 1000) + 3600;
    const sub = await (getRazorpay() as any).subscriptions.create({
      plan_id: planId,
      total_count: options.totalCount ?? 120,
      quantity: 1,
      expire_by: expireBy,
      customer_notify: 1,
      notes: options.notes ?? {},
    });
    return sub as RazorpaySubscription;
  }

  /**
   * Create the introductory subscription:
   *   - upfront_amount = 100 paise (₹1) — charged immediately at mandate setup
   *   - start_at = now + 30 days — first ₹99 recurring charge on day 31
   *   - total_count = 120 (~10 years perpetual)
   *
   * The customer goes through a single Razorpay checkout that both:
   *   (a) collects ₹1 upfront, AND
   *   (b) sets up the UPI / e-mandate for future ₹99 charges.
   *
   * Payment method note: UPI AutoPay and e-mandate cards support this flow.
   * Net banking and wallets are automatically hidden by Razorpay when subscription_id is used.
   */
  static async createIntroSubscription(
    planId: string,
    userId: string,
  ): Promise<RazorpaySubscription> {
    const THIRTY_DAYS_S = 30 * 24 * 60 * 60;
    const startAt = Math.floor(Date.now() / 1000) + THIRTY_DAYS_S;
    // Link expires in 1 hour if user doesn't complete checkout
    const expireBy = Math.floor(Date.now() / 1000) + 3600;

    const sub = await (getRazorpay() as any).subscriptions.create({
      plan_id: planId,
      total_count: 120,
      quantity: 1,
      upfront_amount: 100,    // ₹1 in paise — charged at mandate authentication
      start_at: startAt,      // first ₹99 charge on day 31
      expire_by: expireBy,
      customer_notify: 1,
      notes: {
        userId,
        offer: 'intro_30d_1rs',
      },
    });
    return sub as RazorpaySubscription;
  }

  static async fetchSubscription(subId: string): Promise<RazorpaySubscription> {
    return (await (getRazorpay() as any).subscriptions.fetch(subId)) as RazorpaySubscription;
  }

  /**
   * Cancel a Razorpay subscription.
   * cancelAtCycleEnd=true → customer keeps access until the current cycle ends (recommended).
   * cancelAtCycleEnd=false → cancelled immediately (use for refund scenarios).
   */
  static async cancelSubscription(subId: string, cancelAtCycleEnd = true): Promise<RazorpaySubscription> {
    return (await (getRazorpay() as any).subscriptions.cancel(subId, { cancel_at_cycle_end: cancelAtCycleEnd ? 1 : 0 })) as RazorpaySubscription;
  }


  // ─── Webhook signature verification ───────────────────────────────────────

  /** True when a real webhook secret is configured (not the placeholder default). */
  static isWebhookConfigured(): boolean {
    const secret = env.RAZORPAY_WEBHOOK_SECRET;
    return !!secret && !PLACEHOLDER_SECRETS.has(secret);
  }

  /**
   * Verify `x-razorpay-signature`: hex HMAC-SHA256 of the *raw* request body
   * keyed with RAZORPAY_WEBHOOK_SECRET.
   */
  static verifyWebhookSignature(rawBody: Buffer, signature: string | undefined): boolean {
    if (!signature || !this.isWebhookConfigured()) return false;
    const expected = createHmac('sha256', env.RAZORPAY_WEBHOOK_SECRET).update(rawBody).digest('hex');
    try {
      return timingSafeEqual(Buffer.from(expected, 'hex'), Buffer.from(signature, 'hex'));
    } catch {
      return false;
    }
  }

  /**
   * Verify signature for subscription-authenticated events (subscription.authenticated).
   * Format: razorpay_subscription_id|razorpay_payment_id
   */
  static verifySubscriptionPaymentSignature(
    subscriptionId: string,
    paymentId: string,
    signature: string
  ): boolean {
    if (!this.isConfigured()) return false;
    const body = `${paymentId}|${subscriptionId}`;
    const expected = createHmac('sha256', env.RAZORPAY_KEY_SECRET).update(body).digest('hex');
    try {
      return timingSafeEqual(Buffer.from(expected, 'hex'), Buffer.from(signature, 'hex'));
    } catch {
      return false;
    }
  }
}
