-- Baseline: schema as it existed before the AI Shorts migration (generated with
--   prisma migrate diff --from-empty --to-schema-datamodel <schema @ 5c976f0> --script)
-- so a FRESH database can be built with `prisma migrate deploy`. Existing databases that were created
-- with `prisma db push` must NOT run this: mark it applied with `prisma migrate resolve --applied`.

-- Required extension: search uses pg_trgm similarity().
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- CreateEnum
CREATE TYPE "UserRole" AS ENUM ('USER', 'CREATOR', 'MANAGER', 'SUPER_ADMIN');

-- CreateEnum
CREATE TYPE "Language" AS ENUM ('HINDI', 'MARATHI', 'ENGLISH', 'GUJARATI', 'PUNJABI', 'TAMIL', 'TELUGU');

-- CreateEnum
CREATE TYPE "Plan" AS ENUM ('FREE', 'PREMIUM', 'ANNUAL');

-- CreateEnum
CREATE TYPE "TemplateType" AS ENUM ('IMAGE', 'VIDEO');

-- CreateEnum
CREATE TYPE "TemplateStatus" AS ENUM ('DRAFT', 'PENDING', 'APPROVED', 'REJECTED', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "SubStatus" AS ENUM ('ACTIVE', 'EXPIRED', 'CANCELLED', 'PENDING', 'FAILED');

-- CreateEnum
CREATE TYPE "NotifType" AS ENUM ('DAILY_STATUS', 'FESTIVAL_ALERT', 'NEW_CONTENT', 'PREMIUM_OFFER', 'STREAK_REMINDER', 'WELCOME', 'TEMPLATE_APPROVED', 'TEMPLATE_REJECTED', 'ADMIN_PENDING_REVIEW');

-- CreateEnum
CREATE TYPE "SharePlatform" AS ENUM ('WHATSAPP_STATUS', 'WHATSAPP_CHAT', 'FACEBOOK', 'INSTAGRAM_STORIES', 'INSTAGRAM_FEED', 'DOWNLOAD', 'OTHER');

-- CreateEnum
CREATE TYPE "JobStatus" AS ENUM ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED');

-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "googleId" TEXT,
    "email" TEXT,
    "phoneNumber" TEXT,
    "name" TEXT,
    "profilePhoto" TEXT,
    "password" TEXT,
    "displayName" TEXT,
    "customPhotoUrl" TEXT,
    "language" "Language" NOT NULL DEFAULT 'HINDI',
    "plan" "Plan" NOT NULL DEFAULT 'FREE',
    "planExpiresAt" TIMESTAMP(3),
    "role" "UserRole" NOT NULL DEFAULT 'USER',
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "oneSignalPlayerId" TEXT,
    "timezone" TEXT NOT NULL DEFAULT 'Asia/Kolkata',
    "state" VARCHAR(100),
    "region" VARCHAR(100),
    "onboardingCompleted" BOOLEAN NOT NULL DEFAULT false,
    "businessName" VARCHAR(150),
    "businessPhone" VARCHAR(20),
    "businessAddress" VARCHAR(255),
    "businessDesignation" VARCHAR(100),
    "businessLogo" TEXT,
    "frameType" TEXT DEFAULT 'PERSONAL',
    "streakCount" INTEGER NOT NULL DEFAULT 0,
    "lastStreakDate" TIMESTAMP(3),
    "lastActiveAt" TIMESTAMP(3),
    "totalShares" INTEGER NOT NULL DEFAULT 0,
    "totalSaves" INTEGER NOT NULL DEFAULT 0,
    "appVersion" TEXT,
    "deviceModel" TEXT,
    "introOfferClaimedAt" TIMESTAMP(3),
    "activeRzpSubId" VARCHAR(100),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CreatorProfile" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "displayName" TEXT NOT NULL,
    "bio" VARCHAR(500),
    "portfolioUrl" TEXT,
    "specialization" TEXT[],
    "totalUploads" INTEGER NOT NULL DEFAULT 0,
    "approvedCount" INTEGER NOT NULL DEFAULT 0,
    "rejectedCount" INTEGER NOT NULL DEFAULT 0,
    "pendingCount" INTEGER NOT NULL DEFAULT 0,
    "totalAppUses" INTEGER NOT NULL DEFAULT 0,
    "totalEarnings" INTEGER NOT NULL DEFAULT 0,
    "approvalRate" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "isVerified" BOOLEAN NOT NULL DEFAULT false,
    "verifiedAt" TIMESTAMP(3),
    "isSuspended" BOOLEAN NOT NULL DEFAULT false,
    "suspendedReason" TEXT,
    "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CreatorProfile_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Category" (
    "id" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "nameEn" TEXT NOT NULL,
    "nameHi" TEXT NOT NULL,
    "nameMr" TEXT NOT NULL,
    "nameGu" TEXT,
    "namePa" TEXT,
    "emoji" TEXT NOT NULL,
    "gradient" TEXT NOT NULL,
    "coverImage" TEXT,
    "description" TEXT,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "templateCount" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Category_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Template" (
    "id" TEXT NOT NULL,
    "type" "TemplateType" NOT NULL,
    "status" "TemplateStatus" NOT NULL DEFAULT 'DRAFT',
    "categoryId" TEXT NOT NULL,
    "creatorId" TEXT NOT NULL,
    "reviewerId" TEXT,
    "reviewNote" TEXT,
    "submittedAt" TIMESTAMP(3),
    "reviewedAt" TIMESTAMP(3),
    "nameHi" VARCHAR(100),
    "nameMr" VARCHAR(100),
    "nameEn" VARCHAR(100),
    "nameGu" VARCHAR(100),
    "namePa" VARCHAR(100),
    "quoteHi" TEXT,
    "quoteMr" TEXT,
    "quoteEn" TEXT,
    "quoteGu" TEXT,
    "quotePa" TEXT,
    "photoZoneEnabled" BOOLEAN NOT NULL DEFAULT false,
    "photoZoneX" DOUBLE PRECISION,
    "photoZoneY" DOUBLE PRECISION,
    "photoZoneSize" DOUBLE PRECISION,
    "photoZoneShape" TEXT,
    "fitMode" TEXT NOT NULL DEFAULT 'contain',
    "nameZoneEnabled" BOOLEAN NOT NULL DEFAULT false,
    "nameZoneX" DOUBLE PRECISION,
    "nameZoneY" DOUBLE PRECISION,
    "nameFontSize" DOUBLE PRECISION DEFAULT 0.04,
    "nameColor" TEXT DEFAULT '#FFFFFF',
    "nameFont" TEXT DEFAULT 'Nunito',
    "imageUrl" TEXT,
    "imageThumbUrl" TEXT,
    "imageWidth" INTEGER,
    "imageHeight" INTEGER,
    "videoUrl" TEXT,
    "videoThumbUrl" TEXT,
    "videoDuration" INTEGER,
    "videoStreamId" TEXT,
    "videoFileSize" INTEGER,
    "gradient" TEXT,
    "tags" TEXT[],
    "festivalId" TEXT,
    "isFeatured" BOOLEAN NOT NULL DEFAULT false,
    "isTrending" BOOLEAN NOT NULL DEFAULT false,
    "isPremium" BOOLEAN NOT NULL DEFAULT false,
    "isNew" BOOLEAN NOT NULL DEFAULT true,
    "isCoordinatorPick" BOOLEAN NOT NULL DEFAULT false,
    "coordinatorNote" VARCHAR(300),
    "coordinatorState" VARCHAR(100),
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "primaryLanguage" "Language" NOT NULL DEFAULT 'HINDI',
    "useCount" INTEGER NOT NULL DEFAULT 0,
    "shareCount" INTEGER NOT NULL DEFAULT 0,
    "saveCount" INTEGER NOT NULL DEFAULT 0,
    "viewCount" INTEGER NOT NULL DEFAULT 0,
    "downloadCount" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Template_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SavedStatus" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "templateId" TEXT NOT NULL,
    "savedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SavedStatus_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ShareHistory" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "templateId" TEXT NOT NULL,
    "platform" "SharePlatform" NOT NULL,
    "sharedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ShareHistory_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Subscription" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "plan" "Plan" NOT NULL,
    "amount" INTEGER NOT NULL,
    "currency" TEXT NOT NULL DEFAULT 'INR',
    "status" "SubStatus" NOT NULL,
    "razorpayOrderId" TEXT,
    "razorpayPaymentId" TEXT,
    "razorpaySignature" TEXT,
    "razorpayMethod" TEXT,
    "razorpaySubId" TEXT,
    "isRecurring" BOOLEAN NOT NULL DEFAULT false,
    "invoiceUrl" TEXT,
    "startsAt" TIMESTAMP(3) NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "cancelledAt" TIMESTAMP(3),
    "failureReason" TEXT,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Subscription_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Festival" (
    "id" TEXT NOT NULL,
    "nameHi" TEXT NOT NULL,
    "nameMr" TEXT NOT NULL,
    "nameEn" TEXT NOT NULL,
    "nameGu" TEXT,
    "namePa" TEXT,
    "date" TIMESTAMP(3) NOT NULL,
    "isRecurring" BOOLEAN NOT NULL DEFAULT true,
    "notifyDaysBefore" INTEGER NOT NULL DEFAULT 2,
    "emoji" TEXT NOT NULL,
    "categoryId" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "region" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Festival_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "NotificationLog" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "type" "NotifType" NOT NULL,
    "data" JSONB,
    "isRead" BOOLEAN NOT NULL DEFAULT false,
    "oneSignalId" TEXT,
    "deliveredAt" TIMESTAMP(3),
    "readAt" TIMESTAMP(3),
    "sentAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "NotificationLog_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PushCampaign" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "imageUrl" TEXT,
    "deepLink" TEXT,
    "targetSegment" TEXT NOT NULL,
    "scheduledAt" TIMESTAMP(3),
    "sentAt" TIMESTAMP(3),
    "status" TEXT NOT NULL DEFAULT 'draft',
    "oneSignalId" TEXT,
    "deliveredCount" INTEGER NOT NULL DEFAULT 0,
    "openedCount" INTEGER NOT NULL DEFAULT 0,
    "createdBy" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PushCampaign_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AnalyticsEvent" (
    "id" TEXT NOT NULL,
    "event" TEXT NOT NULL,
    "userId" TEXT,
    "templateId" TEXT,
    "sessionId" TEXT,
    "metadata" JSONB,
    "platform" TEXT DEFAULT 'android',
    "appVersion" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AnalyticsEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AppConfig" (
    "id" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "value" TEXT NOT NULL,
    "type" TEXT NOT NULL DEFAULT 'string',
    "description" TEXT,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "updatedBy" TEXT,

    CONSTRAINT "AppConfig_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AuditLog" (
    "id" TEXT NOT NULL,
    "adminId" TEXT NOT NULL,
    "action" TEXT NOT NULL,
    "entityType" TEXT NOT NULL,
    "entityId" TEXT NOT NULL,
    "before" JSONB,
    "after" JSONB,
    "ip" TEXT,
    "userAgent" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AuditLog_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_googleId_key" ON "User"("googleId");

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE UNIQUE INDEX "User_phoneNumber_key" ON "User"("phoneNumber");

-- CreateIndex
CREATE INDEX "User_email_idx" ON "User"("email");

-- CreateIndex
CREATE INDEX "User_googleId_idx" ON "User"("googleId");

-- CreateIndex
CREATE INDEX "User_role_idx" ON "User"("role");

-- CreateIndex
CREATE INDEX "User_plan_planExpiresAt_idx" ON "User"("plan", "planExpiresAt");

-- CreateIndex
CREATE INDEX "User_language_idx" ON "User"("language");

-- CreateIndex
CREATE INDEX "User_lastActiveAt_idx" ON "User"("lastActiveAt");

-- CreateIndex
CREATE INDEX "User_createdAt_idx" ON "User"("createdAt" DESC);

-- CreateIndex
CREATE INDEX "User_isActive_role_idx" ON "User"("isActive", "role");

-- CreateIndex
CREATE INDEX "User_state_region_idx" ON "User"("state", "region");

-- CreateIndex
CREATE UNIQUE INDEX "CreatorProfile_userId_key" ON "CreatorProfile"("userId");

-- CreateIndex
CREATE INDEX "CreatorProfile_userId_idx" ON "CreatorProfile"("userId");

-- CreateIndex
CREATE INDEX "CreatorProfile_isVerified_idx" ON "CreatorProfile"("isVerified");

-- CreateIndex
CREATE INDEX "CreatorProfile_approvalRate_idx" ON "CreatorProfile"("approvalRate" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "Category_slug_key" ON "Category"("slug");

-- CreateIndex
CREATE INDEX "Category_slug_idx" ON "Category"("slug");

-- CreateIndex
CREATE INDEX "Category_isActive_sortOrder_idx" ON "Category"("isActive", "sortOrder");

-- CreateIndex
CREATE INDEX "Template_type_status_idx" ON "Template"("type", "status");

-- CreateIndex
CREATE INDEX "Template_categoryId_status_sortOrder_idx" ON "Template"("categoryId", "status", "sortOrder");

-- CreateIndex
CREATE INDEX "Template_creatorId_status_idx" ON "Template"("creatorId", "status");

-- CreateIndex
CREATE INDEX "Template_status_isFeatured_idx" ON "Template"("status", "isFeatured");

-- CreateIndex
CREATE INDEX "Template_status_isTrending_idx" ON "Template"("status", "isTrending");

-- CreateIndex
CREATE INDEX "Template_status_isPremium_idx" ON "Template"("status", "isPremium");

-- CreateIndex
CREATE INDEX "Template_status_isNew_idx" ON "Template"("status", "isNew");

-- CreateIndex
CREATE INDEX "Template_useCount_idx" ON "Template"("useCount" DESC);

-- CreateIndex
CREATE INDEX "Template_shareCount_idx" ON "Template"("shareCount" DESC);

-- CreateIndex
CREATE INDEX "Template_createdAt_idx" ON "Template"("createdAt" DESC);

-- CreateIndex
CREATE INDEX "Template_primaryLanguage_status_idx" ON "Template"("primaryLanguage", "status");

-- CreateIndex
CREATE INDEX "Template_tags_idx" ON "Template"("tags");

-- CreateIndex
CREATE INDEX "SavedStatus_userId_savedAt_idx" ON "SavedStatus"("userId", "savedAt" DESC);

-- CreateIndex
CREATE INDEX "SavedStatus_templateId_idx" ON "SavedStatus"("templateId");

-- CreateIndex
CREATE UNIQUE INDEX "SavedStatus_userId_templateId_key" ON "SavedStatus"("userId", "templateId");

-- CreateIndex
CREATE INDEX "ShareHistory_userId_sharedAt_idx" ON "ShareHistory"("userId", "sharedAt" DESC);

-- CreateIndex
CREATE INDEX "ShareHistory_templateId_sharedAt_idx" ON "ShareHistory"("templateId", "sharedAt");

-- CreateIndex
CREATE INDEX "ShareHistory_platform_sharedAt_idx" ON "ShareHistory"("platform", "sharedAt");

-- CreateIndex
CREATE INDEX "ShareHistory_sharedAt_idx" ON "ShareHistory"("sharedAt");

-- CreateIndex
CREATE UNIQUE INDEX "Subscription_razorpayOrderId_key" ON "Subscription"("razorpayOrderId");

-- CreateIndex
CREATE UNIQUE INDEX "Subscription_razorpayPaymentId_key" ON "Subscription"("razorpayPaymentId");

-- CreateIndex
CREATE UNIQUE INDEX "Subscription_razorpaySubId_key" ON "Subscription"("razorpaySubId");

-- CreateIndex
CREATE INDEX "Subscription_userId_status_idx" ON "Subscription"("userId", "status");

-- CreateIndex
CREATE INDEX "Subscription_expiresAt_idx" ON "Subscription"("expiresAt");

-- CreateIndex
CREATE INDEX "Subscription_status_createdAt_idx" ON "Subscription"("status", "createdAt");

-- CreateIndex
CREATE INDEX "Subscription_razorpayOrderId_idx" ON "Subscription"("razorpayOrderId");

-- CreateIndex
CREATE INDEX "Subscription_razorpaySubId_idx" ON "Subscription"("razorpaySubId");

-- CreateIndex
CREATE INDEX "Festival_date_idx" ON "Festival"("date");

-- CreateIndex
CREATE INDEX "Festival_isActive_date_idx" ON "Festival"("isActive", "date");

-- CreateIndex
CREATE INDEX "NotificationLog_userId_isRead_sentAt_idx" ON "NotificationLog"("userId", "isRead", "sentAt" DESC);

-- CreateIndex
CREATE INDEX "NotificationLog_sentAt_idx" ON "NotificationLog"("sentAt");

-- CreateIndex
CREATE INDEX "NotificationLog_type_sentAt_idx" ON "NotificationLog"("type", "sentAt");

-- CreateIndex
CREATE INDEX "AnalyticsEvent_event_createdAt_idx" ON "AnalyticsEvent"("event", "createdAt");

-- CreateIndex
CREATE INDEX "AnalyticsEvent_userId_createdAt_idx" ON "AnalyticsEvent"("userId", "createdAt");

-- CreateIndex
CREATE INDEX "AnalyticsEvent_createdAt_idx" ON "AnalyticsEvent"("createdAt");

-- CreateIndex
CREATE INDEX "AnalyticsEvent_templateId_event_idx" ON "AnalyticsEvent"("templateId", "event");

-- CreateIndex
CREATE UNIQUE INDEX "AppConfig_key_key" ON "AppConfig"("key");

-- CreateIndex
CREATE INDEX "AuditLog_adminId_createdAt_idx" ON "AuditLog"("adminId", "createdAt");

-- CreateIndex
CREATE INDEX "AuditLog_entityType_entityId_idx" ON "AuditLog"("entityType", "entityId");

-- CreateIndex
CREATE INDEX "AuditLog_createdAt_idx" ON "AuditLog"("createdAt");

-- AddForeignKey
ALTER TABLE "CreatorProfile" ADD CONSTRAINT "CreatorProfile_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Template" ADD CONSTRAINT "Template_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "Category"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Template" ADD CONSTRAINT "Template_creatorId_fkey" FOREIGN KEY ("creatorId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Template" ADD CONSTRAINT "Template_reviewerId_fkey" FOREIGN KEY ("reviewerId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SavedStatus" ADD CONSTRAINT "SavedStatus_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SavedStatus" ADD CONSTRAINT "SavedStatus_templateId_fkey" FOREIGN KEY ("templateId") REFERENCES "Template"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ShareHistory" ADD CONSTRAINT "ShareHistory_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ShareHistory" ADD CONSTRAINT "ShareHistory_templateId_fkey" FOREIGN KEY ("templateId") REFERENCES "Template"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Subscription" ADD CONSTRAINT "Subscription_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Festival" ADD CONSTRAINT "Festival_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "Category"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NotificationLog" ADD CONSTRAINT "NotificationLog_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AnalyticsEvent" ADD CONSTRAINT "AnalyticsEvent_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

