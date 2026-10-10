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

export const PLAN_AMOUNTS = {
  PREMIUM: 9900,   // ₹99 in paise
  ANNUAL:  79900,  // ₹799 in paise
} as const;

export interface RazorpayOrder {
  id: string;
  amount: number;
  currency: string;
  receipt: string;
}

export class RazorpayService {
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
    const body = `${orderId}|${paymentId}`;
    const expectedSignature = createHmac('sha256', env.RAZORPAY_KEY_SECRET)
      .update(body)
      .digest('hex');

    try {
      // Constant-time comparison to prevent timing attacks
      return timingSafeEqual(
        Buffer.from(expectedSignature, 'hex'),
        Buffer.from(signature, 'hex')
      );
    } catch {
      return false;
    }
  }

  /** True when a real webhook secret is configured (not the placeholder default). */
  static isWebhookConfigured(): boolean {
    const secret = env.RAZORPAY_WEBHOOK_SECRET;
    return !!secret && secret !== 'placeholder' && secret !== 'XXXXX';
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
}
