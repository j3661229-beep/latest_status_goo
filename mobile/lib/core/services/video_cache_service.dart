// lib/core/services/video_cache_service.dart
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Disk caching and prefetching for video templates.
///
/// Prevents redownloading videos every time a user scrolls past or replays them.
/// First playback uses streaming chunks (networkUrl); subsequent playbacks use
/// the cached file directly from disk.
class VideoCacheService {
  VideoCacheService._();
  static final VideoCacheService instance = VideoCacheService._();

  final BaseCacheManager _manager = DefaultCacheManager();

  /// Check if the video is already downloaded and cached locally on disk.
  Future<io.File?> getCachedVideoFile(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return null;
    try {
      final fileInfo = await _manager.getFileFromCache(cleanUrl);
      if (fileInfo != null) {
        final localFile = io.File(fileInfo.file.path);
        if (await localFile.exists()) {
          return localFile;
        }
      }
    } catch (e) {
      debugPrint('VideoCacheService getCachedVideoFile error: $e');
    }
    return null;
  }

  /// Downloads and caches the video file in the background (non-blocking).
  void prefetchVideo(String url) {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return;
    _manager.getFileFromCache(cleanUrl).then((info) {
      if (info == null) {
        _manager.downloadFile(cleanUrl).catchError((e) {
          debugPrint('Video prefetch failed for $cleanUrl: $e');
          return null as dynamic;
        });
      }
    }).catchError((_) {});
  }
}
