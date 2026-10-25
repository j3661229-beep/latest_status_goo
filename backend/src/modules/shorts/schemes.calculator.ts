// src/modules/shorts/schemes.calculator.ts
// Intelligent Yojana Eligibility Calculator for Indian Citizens & CSC operators.
import { PrismaClient } from '@prisma/client';
import { z } from 'zod';
import { publicWhere } from './shorts.route';
import { shortInclude, serializeShort } from './shorts.serializer';

export const EligibilityInputSchema = z.object({
  age: z.coerce.number().int().min(1).max(120).optional(),
  gender: z.enum(['ALL', 'MALE', 'FEMALE']).default('ALL'),
  socialCategory: z.enum(['ALL', 'GENERAL', 'OBC', 'SC', 'ST', 'MINORITY']).default('ALL'),
  occupation: z.enum([
    'ALL',
    'FARMER',
    'STUDENT',
    'WOMEN',
    'SELF_EMPLOYED',
    'UNEMPLOYED',
    'SENIOR_CITIZEN',
    'LABOUR',
  ]).default('ALL'),
  annualIncome: z.coerce.number().min(0).optional(),
  stateCode: z.string().trim().max(10).optional(),
});

export type EligibilityInput = z.infer<typeof EligibilityInputSchema>;

export interface SchemeMatchResult {
  id: string;
  slug: string;
  nameHi: string;
  officialName: string;
  category: string;
  scope: string;
  stateCode: string | null;
  matchPercentage: number;
  matchReasons: string[];
  benefits: string[];
  documents: string[];
  eligibility: string[];
  applicationSteps: string[];
  applicationMode: string | null;
  applicationUrl: string | null;
  video: ReturnType<typeof serializeShort> | null;
}

export async function checkSchemeEligibility(
  prisma: PrismaClient,
  input: EligibilityInput,
): Promise<{ matches: SchemeMatchResult[]; totalEligible: number }> {
  // Fetch active schemes with their published videos
  const schemes = await prisma.scheme.findMany({
    where: {
      reviewStatus: { in: ['PUBLISHED', 'SOURCE_VERIFIED', 'NEEDS_REVIEW'] },
    },
    include: {
      videos: {
        where: publicWhere(),
        include: shortInclude,
        take: 1,
        orderBy: { publishedAt: 'desc' },
      },
    },
    orderBy: { updatedAt: 'desc' },
  });

  const results: SchemeMatchResult[] = [];

  for (const s of schemes) {
    let score = 50; // base score for active welfare schemes
    const reasons: string[] = [];

    // 1. State / Scope filter
    if (s.scope === 'STATE' && s.stateCode) {
      if (input.stateCode && input.stateCode.toUpperCase() !== s.stateCode.toUpperCase()) {
        continue; // strictly skip state-specific schemes for other states
      } else if (input.stateCode) {
        score += 15;
        reasons.push(`${input.stateCode.toUpperCase()} राज्य की विशेष योजना`);
      }
    } else {
      score += 10;
      reasons.push('केंद्रीय योजना (पूरे भारत में मान्य)');
    }

    const catUpper = s.category.toUpperCase();
    const eligText = (s.eligibility || []).join(' ').toLowerCase();
    const nameText = `${s.nameHi} ${s.officialName}`.toLowerCase();

    // 2. Occupation matching
    if (input.occupation === 'FARMER') {
      if (catUpper.includes('AGRI') || eligText.includes('किसान') || nameText.includes('kisan') || nameText.includes('किसान')) {
        score += 30;
        reasons.push('किसानों और कृषि परिवारों के लिए विशेष पात्रता');
      }
    } else if (input.occupation === 'STUDENT') {
      if (catUpper.includes('EDU') || eligText.includes('छात्र') || eligText.includes('विद्यार्थी') || nameText.includes('scholarship')) {
        score += 30;
        reasons.push('विद्यार्थियों और उच्च शिक्षा हेतु विशेष छात्रवृत्ति');
      }
    } else if (input.occupation === 'WOMEN' || input.gender === 'FEMALE') {
      if (catUpper.includes('WOMEN') || eligText.includes('महिला') || eligText.includes('बेटी') || nameText.includes('ladli') || nameText.includes('kanya')) {
        score += 30;
        reasons.push('महिला सशक्तिकरण व बालिकाओं हेतु समर्पित योजना');
      }
    } else if (input.occupation === 'SENIOR_CITIZEN' || (input.age && input.age >= 60)) {
      if (catUpper.includes('PENSION') || eligText.includes('वृद्धा') || eligText.includes('पेंशन') || eligText.includes('वरिष्ठ')) {
        score += 30;
        reasons.push('वरिष्ठ नागरिकों हेतु मासिक पेंशन सहायता');
      }
    } else if (input.occupation === 'LABOUR' || input.occupation === 'UNEMPLOYED') {
      if (catUpper.includes('EMPLOY') || catUpper.includes('LABOUR') || eligText.includes('श्रमिक') || eligText.includes('रोजगार') || eligText.includes('मजदूर')) {
        score += 25;
        reasons.push('श्रमिकों और स्वरोजगार शुरू करने हेतु आर्थिक मदद');
      }
    }

    // 3. Social category matching (SC / ST / OBC)
    if (['SC', 'ST', 'OBC'].includes(input.socialCategory)) {
      if (eligText.includes(input.socialCategory.toLowerCase()) || eligText.includes('आरक्षण') || eligText.includes('विशेष छूट')) {
        score += 10;
        reasons.push(`${input.socialCategory} वर्ग हेतु विशेष प्राथमिकता`);
      }
    }

    // 4. Income matching
    if (input.annualIncome !== undefined) {
      if (input.annualIncome <= 250000) {
        if (catUpper.includes('HOUSING') || catUpper.includes('HEALTH') || eligText.includes('bpl') || eligText.includes('गरीब') || eligText.includes('कम आय')) {
          score += 15;
          reasons.push('कम आय वर्ग / बीपीएल परिवारों के लिए पूर्ण सहायता');
        }
      }
    }

    // Cap score at 98%
    const finalScore = Math.min(score, 98);
    const video = s.videos[0] ? serializeShort(s.videos[0]) : null;

    results.push({
      id: s.id,
      slug: s.slug,
      nameHi: s.nameHi,
      officialName: s.officialName,
      category: s.category,
      scope: s.scope,
      stateCode: s.stateCode,
      matchPercentage: finalScore,
      matchReasons: reasons.length ? reasons : ['सामान्य पात्रता शर्तों के अधीन'],
      benefits: s.benefits || [],
      documents: s.documents || [],
      eligibility: s.eligibility || [],
      applicationSteps: s.applicationSteps || [],
      applicationMode: s.applicationMode || 'ONLINE',
      applicationUrl: s.applicationUrl,
      video,
    });
  }

  // Sort by highest match score first
  results.sort((a, b) => b.matchPercentage - a.matchPercentage);

  return {
    matches: results,
    totalEligible: results.length,
  };
}
