// test/schemes-and-daily.test.ts
import { describe, it, expect, vi } from 'vitest';
import { getTodayContent } from '../src/modules/daily-content/daily-content.service';
import { checkSchemeEligibility, EligibilityInputSchema } from '../src/modules/shorts/schemes.calculator';

describe('Daily Content & Panchang Service', () => {
  it('generates valid Indian Panchang and Hindi Suvichar for today', () => {
    const content = getTodayContent(new Date('2026-10-25T12:00:00Z'));
    expect(content).toBeDefined();
    expect(content.greetingHi).toContain('शुभ प्रभात');
    expect(content.panchang.vikramSamvat).toBeGreaterThanOrEqual(2080);
    expect(content.panchang.dayOfWeekHi).toBeTruthy();
    expect(content.panchang.tithiHi).toBeTruthy();
    expect(content.panchang.shubhMuhurat).toContain('अभिजित');
    expect(content.suvichar.quoteHi.length).toBeGreaterThan(15);
    expect(content.suvichar.authorHi.length).toBeGreaterThan(2);
  });
});

describe('Yojana Eligibility Calculator', () => {
  it('validates citizen input correctly with Zod', () => {
    const valid = EligibilityInputSchema.safeParse({
      age: 32,
      gender: 'FEMALE',
      socialCategory: 'OBC',
      occupation: 'FARMER',
      annualIncome: 120000,
      stateCode: 'UP',
    });
    expect(valid.success).toBe(true);
  });

  it('calculates eligibility matches with correct scoring', async () => {
    const mockPrisma: any = {
      scheme: {
        findMany: vi.fn().mockResolvedValue([
          {
            id: 'scheme_kisan_1',
            slug: 'pm-kisan',
            nameHi: 'प्रधानमंत्री किसान सम्मान निधि',
            officialName: 'PM-Kisan Samman Nidhi',
            category: 'AGRICULTURE',
            scope: 'CENTRAL',
            stateCode: null,
            benefits: ['₹6,000 प्रति वर्ष तीन किस्तों में'],
            documents: ['आधार कार्ड', 'खतौनी / जमीन के कागजात', 'बैंक पासबुक'],
            eligibility: ['भूमिधारक किसान परिवार', 'पात्र छोटे व सीमांत किसान'],
            applicationSteps: ['pmkisan.gov.in पर ई-केवाईसी करें'],
            applicationMode: 'ONLINE',
            applicationUrl: 'https://pmkisan.gov.in',
            videos: [],
          },
          {
            id: 'scheme_ladli_1',
            slug: 'ladli-behna',
            nameHi: 'मुख्यमंत्री लाडली बहना योजना',
            officialName: 'Mukhyamantri Ladli Behna Yojana',
            category: 'WOMEN',
            scope: 'STATE',
            stateCode: 'MP',
            benefits: ['₹1,250 प्रतिमाह सीधे बैंक खाते में'],
            documents: ['समग्र आईडी', 'आधार कार्ड'],
            eligibility: ['मध्य प्रदेश की मूल निवासी महिला', 'विवाहित महिला'],
            applicationSteps: ['ग्राम पंचायत में आवेदन करें'],
            applicationMode: 'OFFLINE',
            applicationUrl: 'https://cmladlibahna.mp.gov.in',
            videos: [],
          },
        ]),
      },
    };

    // Farmer in UP
    const res = await checkSchemeEligibility(mockPrisma, {
      age: 40,
      gender: 'MALE',
      socialCategory: 'OBC',
      occupation: 'FARMER',
      stateCode: 'UP',
    });

    expect(res.totalEligible).toBe(1); // MP-specific scheme is filtered out
    expect(res.matches[0].id).toBe('scheme_kisan_1');
    expect(res.matches[0].matchPercentage).toBeGreaterThanOrEqual(80);
    expect(res.matches[0].matchReasons.length).toBeGreaterThan(0);
    expect(res.matches[0].documents).toContain('आधार कार्ड');
  });
});
