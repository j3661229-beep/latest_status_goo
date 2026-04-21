// src/lib/notification/onesignal.service.ts
import axios from 'axios';
import { env } from '../../config/env';

const ONESIGNAL_API = 'https://onesignal.com/api/v1';

export type NotifSegment =
  | 'All'
  | 'Active Users'
  | 'Inactive Users - 3 Days'
  | 'Inactive Users - 7 Days';

export interface OneSignalFilter {
  field?: string;
  key?: string;
  relation?: string;
  value?: string;
  hours_ago?: string;
  operator?: string;
}

export interface SendNotifParams {
  heading: string;
  content: string;
  imageUrl?: string;
  data?: Record<string, string>;
  segment?: NotifSegment;
  playerIds?: string[];
  scheduledAt?: Date;
  filters?: OneSignalFilter[];
}

// Notification copy templates (Hindi + Marathi)
export const NOTIF_TEMPLATES = {
  daily_hi: {
    heading: '🙏 आज का स्टेटस तैयार है!',
    content: 'नए devotional और motivational status देखें। अभी share करें!',
    data: { screen: 'home' },
  },
  daily_mr: {
    heading: '🙏 आजचा स्टेटस तयार आहे!',
    content: 'नवे devotional आणि motivational status पहा. आत्ता share करा!',
    data: { screen: 'home' },
  },
  festival_hi: (festivalName: string) => ({
    heading: `🎉 ${festivalName} कल है!`,
    content: `Special ${festivalName} status के साथ wishes share करें`,
    data: { screen: 'discover', query: festivalName },
  }),
  festival_mr: (festivalName: string) => ({
    heading: `🎉 ${festivalName} उद्या आहे!`,
    content: `Special ${festivalName} status सह wishes share करा`,
    data: { screen: 'discover', query: festivalName },
  }),
  premium_nudge: {
    heading: '⭐ Unlimited Status चाहिए?',
    content: 'Premium में unlimited image + video status। Try करें ₹99/month में।',
    data: { screen: 'premium' },
  },
  template_approved: (templateName: string) => ({
    heading: '✅ Template Approved!',
    content: `"${templateName}" को admin ने approve किया। अब यह app में live है!`,
    data: { screen: 'creator_templates' },
  }),
  template_rejected: (templateName: string, reason: string) => ({
    heading: '❌ Template Needs Changes',
    content: `"${templateName}" rejected: ${reason.slice(0, 80)}`,
    data: { screen: 'creator_templates' },
  }),
  welcome: {
    heading: '🎉 Status Go में आपका स्वागत है!',
    content: 'अभी browse करें और पहला status share करें। यह बिल्कुल free है!',
    data: { screen: 'home' },
  },
} as const;

export class OneSignalService {
  static async send(params: SendNotifParams): Promise<string | null> {
    if (!env.ONESIGNAL_APP_ID || !env.ONESIGNAL_REST_KEY) {
      console.warn('OneSignal not configured — skipping push notification');
      return null;
    }

    const body: Record<string, unknown> = {
      app_id: env.ONESIGNAL_APP_ID,
      headings: { en: params.heading, hi: params.heading, mr: params.heading },
      contents: { en: params.content, hi: params.content, mr: params.content },
      small_icon: 'ic_notification',
      android_accent_color: 'FF7C5CFC',
      android_channel_id: 'status_go_default',
    };

    if (params.playerIds?.length) {
      body.include_player_ids = params.playerIds;
    } else if (params.filters?.length) {
      body.filters = params.filters;
    } else {
      body.included_segments = [params.segment ?? 'All'];
    }

    if (params.imageUrl) body.big_picture = params.imageUrl;
    if (params.data) body.data = params.data;
    if (params.scheduledAt) body.send_after = params.scheduledAt.toISOString();

    try {
      const res = await axios.post(`${ONESIGNAL_API}/notifications`, body, {
        headers: {
          Authorization: `Basic ${env.ONESIGNAL_REST_KEY}`,
          'Content-Type': 'application/json',
        },
        timeout: 10_000,
      });
      return res.data.id as string;
    } catch (err: any) {
      console.error('OneSignal send failed:', err?.response?.data ?? err.message);
      return null;
    }
  }

  // Build OneSignal tag filters from target segment
  static buildFilters(target: string): OneSignalFilter[] {
    switch (target) {
      case 'hindi':
        return [{ field: 'tag', key: 'language', relation: '=', value: 'HINDI' }];
      case 'marathi':
        return [{ field: 'tag', key: 'language', relation: '=', value: 'MARATHI' }];
      case 'hindi_free':
        return [
          { field: 'tag', key: 'language', relation: '=', value: 'HINDI' },
          { operator: 'AND' },
          { field: 'tag', key: 'plan', relation: '=', value: 'FREE' },
        ];
      case 'free':
        return [{ field: 'tag', key: 'plan', relation: '=', value: 'FREE' }];
      case 'premium':
        return [{ field: 'tag', key: 'plan', relation: '=', value: 'PREMIUM' }];
      case 'inactive_7d':
        return [{ field: 'last_session', relation: '>', hours_ago: String(7 * 24) }];
      case 'premium_expiring':
        return [
          { field: 'tag', key: 'plan', relation: '=', value: 'PREMIUM' },
          { operator: 'AND' },
          { field: 'tag', key: 'plan_expiry_days', relation: '<', value: '3' },
        ];
      default:
        return []; // 'all' — no filters = all users
    }
  }
}
