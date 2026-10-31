// src/lib/content/youtube.ts
// Utility functions for parsing, validating, and generating YouTube URLs and IDs.

const YT_REGEX = /(?:youtu\.be\/|youtube\.com\/(?:watch\?(?:.*&)?v=|embed\/|shorts\/|v\/|live\/))([a-zA-Z0-9_-]{11})/;
const EXACT_ID_REGEX = /^[a-zA-Z0-9_-]{11}$/;

/**
 * Extracts the 11-character YouTube video ID from various YouTube URL formats or directly.
 */
export function extractYoutubeId(input: string | null | undefined): string | null {
  if (!input) return null;
  const trimmed = input.trim();
  if (EXACT_ID_REGEX.test(trimmed)) {
    return trimmed;
  }
  const match = trimmed.match(YT_REGEX);
  return match ? match[1] : null;
}

/**
 * Returns standard YouTube watch URL.
 */
export function getYoutubeWatchUrl(id: string): string {
  return `https://www.youtube.com/watch?v=${id}`;
}

/**
 * Returns standard YouTube embed URL.
 */
export function getYoutubeEmbedUrl(id: string): string {
  return `https://www.youtube.com/embed/${id}`;
}

/**
 * Returns standard high-quality YouTube thumbnail URL.
 */
export function getYoutubeThumbnailUrl(id: string): string {
  return `https://img.youtube.com/vi/${id}/hqdefault.jpg`;
}
