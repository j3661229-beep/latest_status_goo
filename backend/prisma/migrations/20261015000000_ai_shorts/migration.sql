-- CreateEnum
CREATE TYPE "ContentKind" AS ENUM ('SCHEME', 'NEWS');

-- CreateEnum
CREATE TYPE "ContentStatus" AS ENUM ('DRAFT', 'SOURCE_VERIFIED', 'SCRIPT_READY', 'GENERATING', 'GENERATED', 'NEEDS_REVIEW', 'APPROVED', 'PUBLISHED', 'FAILED', 'REJECTED', 'EXPIRED', 'CORRECTION_REQUIRED', 'UNPUBLISHED');

-- CreateEnum
CREATE TYPE "ContentJobType" AS ENUM ('SOURCE_REFRESH', 'NEWS_INGEST', 'SOURCE_VALIDATE', 'DEDUPE', 'SCRIPT', 'NARRATION', 'VISUALS', 'RENDER', 'THUMBNAIL', 'UPLOAD', 'REVIEW_REMINDER', 'CORRECTION');

-- CreateEnum
CREATE TYPE "ContentJobState" AS ENUM ('QUEUED', 'RUNNING', 'SUCCEEDED', 'FAILED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "CorrectionStatus" AS ENUM ('NONE', 'CORRECTED', 'WITHDRAWN');

-- CreateEnum
CREATE TYPE "ContentReportReason" AS ENUM ('INCORRECT', 'OUTDATED', 'MISLEADING', 'OFFENSIVE', 'OTHER');

-- CreateEnum
CREATE TYPE "ContentReportStatus" AS ENUM ('OPEN', 'RESOLVED', 'DISMISSED');

-- CreateEnum
CREATE TYPE "ContentEventType" AS ENUM ('VIEW', 'COMPLETE', 'SHARE', 'OPEN_LINK');

-- CreateTable
CREATE TABLE "Scheme" (
    "id" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "officialName" TEXT NOT NULL,
    "nameHi" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "scope" TEXT NOT NULL DEFAULT 'CENTRAL',
    "stateCode" TEXT,
    "department" TEXT,
    "language" "Language" NOT NULL DEFAULT 'HINDI',
    "benefits" TEXT[],
    "eligibility" TEXT[],
    "documents" TEXT[],
    "applicationSteps" TEXT[],
    "applicationMode" TEXT,
    "applicationUrl" TEXT,
    "sourceUrls" TEXT[],
    "sourceUpdatedAt" TIMESTAMP(3),
    "lastCheckedAt" TIMESTAMP(3),
    "lastVerifiedAt" TIMESTAMP(3),
    "reviewStatus" "ContentStatus" NOT NULL DEFAULT 'DRAFT',
    "nextReviewAt" TIMESTAMP(3),
    "expiresAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Scheme_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "NewsStory" (
    "id" TEXT NOT NULL,
    "originalHeadline" TEXT NOT NULL,
    "publisher" TEXT NOT NULL,
    "canonicalUrl" TEXT NOT NULL,
    "dedupeKey" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "language" "Language" NOT NULL DEFAULT 'HINDI',
    "publishedAt" TIMESTAMP(3) NOT NULL,
    "retrievedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lastVerifiedAt" TIMESTAMP(3),
    "relatedSources" JSONB NOT NULL DEFAULT '[]',
    "summary" TEXT,
    "isDeveloping" BOOLEAN NOT NULL DEFAULT false,
    "correctionStatus" "CorrectionStatus" NOT NULL DEFAULT 'NONE',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "NewsStory_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ShortVideo" (
    "id" TEXT NOT NULL,
    "kind" "ContentKind" NOT NULL,
    "schemeId" TEXT,
    "newsStoryId" TEXT,
    "language" "Language" NOT NULL DEFAULT 'HINDI',
    "category" TEXT NOT NULL,
    "region" TEXT,
    "title" TEXT NOT NULL,
    "hook" TEXT,
    "description" TEXT,
    "status" "ContentStatus" NOT NULL DEFAULT 'DRAFT',
    "scriptVersion" INTEGER NOT NULL DEFAULT 1,
    "script" JSONB,
    "captions" JSONB,
    "claims" JSONB,
    "warnings" JSONB,
    "attribution" TEXT,
    "durationSec" DOUBLE PRECISION,
    "videoKey" TEXT,
    "thumbnailKey" TEXT,
    "audioKey" TEXT,
    "aiMeta" JSONB,
    "costMicroUsd" INTEGER NOT NULL DEFAULT 0,
    "correctionNote" TEXT,
    "scheduledAt" TIMESTAMP(3),
    "publishedAt" TIMESTAMP(3),
    "expiresAt" TIMESTAMP(3),
    "approvedById" TEXT,
    "publishedById" TEXT,
    "viewCount" INTEGER NOT NULL DEFAULT 0,
    "shareCount" INTEGER NOT NULL DEFAULT 0,
    "bookmarkCount" INTEGER NOT NULL DEFAULT 0,
    "reportCount" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ShortVideo_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ContentJob" (
    "id" TEXT NOT NULL,
    "type" "ContentJobType" NOT NULL,
    "state" "ContentJobState" NOT NULL DEFAULT 'QUEUED',
    "shortVideoId" TEXT,
    "idempotencyKey" TEXT NOT NULL,
    "payload" JSONB,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "maxAttempts" INTEGER NOT NULL DEFAULT 3,
    "failureReason" TEXT,
    "costMicroUsd" INTEGER NOT NULL DEFAULT 0,
    "queuedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "startedAt" TIMESTAMP(3),
    "finishedAt" TIMESTAMP(3),

    CONSTRAINT "ContentJob_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ContentReview" (
    "id" TEXT NOT NULL,
    "shortVideoId" TEXT NOT NULL,
    "actorId" TEXT NOT NULL,
    "action" TEXT NOT NULL,
    "reason" TEXT,
    "before" JSONB,
    "after" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ContentReview_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ContentReport" (
    "id" TEXT NOT NULL,
    "shortVideoId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "reason" "ContentReportReason" NOT NULL,
    "note" TEXT,
    "status" "ContentReportStatus" NOT NULL DEFAULT 'OPEN',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ContentReport_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ContentEvent" (
    "id" TEXT NOT NULL,
    "shortVideoId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "type" "ContentEventType" NOT NULL,
    "dayKey" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ContentEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ContentBookmark" (
    "id" TEXT NOT NULL,
    "shortVideoId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ContentBookmark_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Scheme_slug_key" ON "Scheme"("slug");

-- CreateIndex
CREATE INDEX "Scheme_category_idx" ON "Scheme"("category");

-- CreateIndex
CREATE INDEX "Scheme_scope_stateCode_idx" ON "Scheme"("scope", "stateCode");

-- CreateIndex
CREATE INDEX "Scheme_nextReviewAt_idx" ON "Scheme"("nextReviewAt");

-- CreateIndex
CREATE UNIQUE INDEX "NewsStory_canonicalUrl_key" ON "NewsStory"("canonicalUrl");

-- CreateIndex
CREATE INDEX "NewsStory_dedupeKey_idx" ON "NewsStory"("dedupeKey");

-- CreateIndex
CREATE INDEX "NewsStory_category_publishedAt_idx" ON "NewsStory"("category", "publishedAt");

-- CreateIndex
CREATE INDEX "NewsStory_publishedAt_idx" ON "NewsStory"("publishedAt");

-- CreateIndex
CREATE INDEX "ShortVideo_status_kind_publishedAt_idx" ON "ShortVideo"("status", "kind", "publishedAt");

-- CreateIndex
CREATE INDEX "ShortVideo_kind_category_status_idx" ON "ShortVideo"("kind", "category", "status");

-- CreateIndex
CREATE INDEX "ShortVideo_schemeId_idx" ON "ShortVideo"("schemeId");

-- CreateIndex
CREATE INDEX "ShortVideo_newsStoryId_idx" ON "ShortVideo"("newsStoryId");

-- CreateIndex
CREATE INDEX "ShortVideo_status_scheduledAt_idx" ON "ShortVideo"("status", "scheduledAt");

-- CreateIndex
CREATE UNIQUE INDEX "ContentJob_idempotencyKey_key" ON "ContentJob"("idempotencyKey");

-- CreateIndex
CREATE INDEX "ContentJob_state_type_queuedAt_idx" ON "ContentJob"("state", "type", "queuedAt");

-- CreateIndex
CREATE INDEX "ContentJob_shortVideoId_idx" ON "ContentJob"("shortVideoId");

-- CreateIndex
CREATE INDEX "ContentReview_shortVideoId_createdAt_idx" ON "ContentReview"("shortVideoId", "createdAt");

-- CreateIndex
CREATE INDEX "ContentReport_status_createdAt_idx" ON "ContentReport"("status", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "ContentReport_shortVideoId_userId_key" ON "ContentReport"("shortVideoId", "userId");

-- CreateIndex
CREATE UNIQUE INDEX "ContentEvent_shortVideoId_userId_type_dayKey_key" ON "ContentEvent"("shortVideoId", "userId", "type", "dayKey");

-- CreateIndex
CREATE INDEX "ContentBookmark_userId_createdAt_idx" ON "ContentBookmark"("userId", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "ContentBookmark_userId_shortVideoId_key" ON "ContentBookmark"("userId", "shortVideoId");

-- AddForeignKey
ALTER TABLE "ShortVideo" ADD CONSTRAINT "ShortVideo_schemeId_fkey" FOREIGN KEY ("schemeId") REFERENCES "Scheme"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ShortVideo" ADD CONSTRAINT "ShortVideo_newsStoryId_fkey" FOREIGN KEY ("newsStoryId") REFERENCES "NewsStory"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ContentJob" ADD CONSTRAINT "ContentJob_shortVideoId_fkey" FOREIGN KEY ("shortVideoId") REFERENCES "ShortVideo"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ContentReview" ADD CONSTRAINT "ContentReview_shortVideoId_fkey" FOREIGN KEY ("shortVideoId") REFERENCES "ShortVideo"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ContentReport" ADD CONSTRAINT "ContentReport_shortVideoId_fkey" FOREIGN KEY ("shortVideoId") REFERENCES "ShortVideo"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ContentEvent" ADD CONSTRAINT "ContentEvent_shortVideoId_fkey" FOREIGN KEY ("shortVideoId") REFERENCES "ShortVideo"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ContentBookmark" ADD CONSTRAINT "ContentBookmark_shortVideoId_fkey" FOREIGN KEY ("shortVideoId") REFERENCES "ShortVideo"("id") ON DELETE CASCADE ON UPDATE CASCADE;

