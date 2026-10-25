-- Admin-controlled content format (additive; no drops, no truncation).
CREATE TYPE "ContentFormat" AS ENUM ('CARD_ONLY', 'CARD_WITH_VIDEO');
CREATE TYPE "VideoState" AS ENUM ('NOT_REQUESTED', 'QUEUED', 'GENERATING', 'READY', 'FAILED');

ALTER TABLE "ShortVideo"
  ADD COLUMN "format" "ContentFormat" NOT NULL DEFAULT 'CARD_ONLY',
  ADD COLUMN "videoState" "VideoState" NOT NULL DEFAULT 'NOT_REQUESTED',
  ADD COLUMN "videoRequestedAt" TIMESTAMP(3),
  ADD COLUMN "videoRequestedById" TEXT,
  ADD COLUMN "videoApprovedAt" TIMESTAMP(3),
  ADD COLUMN "videoApprovedById" TEXT,
  ADD COLUMN "videoFailureReason" TEXT;

-- Backfill: videos that already exist keep working. Published ones stay playable (treated as approved).
UPDATE "ShortVideo"
SET "format" = 'CARD_WITH_VIDEO',
    "videoState" = 'READY',
    "videoApprovedAt" = CASE WHEN "status" = 'PUBLISHED' THEN COALESCE("publishedAt", "updatedAt") ELSE NULL END,
    "videoApprovedById" = CASE WHEN "status" = 'PUBLISHED' THEN "publishedById" ELSE NULL END
WHERE "videoKey" IS NOT NULL;

-- Legacy in-flight render states no longer exist as card statuses (the card lifecycle is now separate from the video).
-- Nothing here was ever public: finished-but-unreviewed renders go to the review queue (video READY, not approved);
-- scripted/rendering items return to DRAFT and keep Card + Video so an admin can request the video again.
UPDATE "ShortVideo" SET "status" = 'NEEDS_REVIEW' WHERE "status" = 'GENERATED';
UPDATE "ShortVideo" SET "status" = 'DRAFT', "format" = 'CARD_WITH_VIDEO' WHERE "status" IN ('SCRIPT_READY', 'GENERATING');
