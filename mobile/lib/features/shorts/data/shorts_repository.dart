// lib/features/shorts/data/shorts_repository.dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import 'short_models.dart';

final shortsRepositoryProvider = Provider<ShortsRepository>((ref) => ShortsRepository(apiClient));

/// Which list the feed shows. `saved` ignores category.
enum ShortsFeed { news, scheme, saved }

class ShortsRepository {
  final Dio _dio;
  ShortsRepository(this._dio);

  static const pageSize = 10;

  Future<ShortPage> list({required ShortsFeed feed, String? category, int page = 1}) async {
    final res = feed == ShortsFeed.saved
        ? await _dio.get('/shorts/bookmarks/list', queryParameters: {'page': page, 'limit': pageSize})
        : await _dio.get(
            feed == ShortsFeed.news ? '/news' : '/schemes',
            queryParameters: {'page': page, 'limit': pageSize, if (category != null) 'category': category},
          );
    final body = res.data;
    if (body is! Map || body['data'] is! List) throw const FormatException('Invalid shorts response');
    final items = <ShortItem>[];
    for (final raw in body['data'] as List) {
      if (raw is! Map) continue;
      try {
        items.add(ShortItem.fromJson(Map<String, dynamic>.from(raw)));
      } catch (_) {
        // Skip one malformed item rather than failing the whole page.
      }
    }
    final meta = body['meta'];
    final hasMore = meta is Map ? meta['hasMore'] == true : items.length >= pageSize;
    return ShortPage(items, hasMore);
  }

  Future<ShortDetail> detail(String id) async {
    final res = await _dio.get('/shorts/$id');
    final body = res.data;
    if (body is! Map || body['data'] is! Map) throw const FormatException('Invalid detail response');
    final related = <ShortItem>[];
    if (body['related'] is List) {
      for (final r in body['related'] as List) {
        if (r is Map) {
          try {
            related.add(ShortItem.fromJson(Map<String, dynamic>.from(r)));
          } catch (_) {}
        }
      }
    }
    return ShortDetail(ShortItem.fromJson(Map<String, dynamic>.from(body['data'] as Map)), related);
  }

  Future<void> setSaved(String id, bool saved) async {
    if (saved) {
      await _dio.post('/shorts/$id/bookmark');
    } else {
      await _dio.delete('/shorts/$id/bookmark');
    }
  }

  Future<void> report(String id, String reason, {String? note}) async {
    await _dio.post('/shorts/$id/report', data: {
      'reason': reason,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  /// Best-effort analytics; the backend de-duplicates per user/type/day.
  Future<void> event(String id, String type) async {
    try {
      await _dio.post('/shorts/$id/events', data: {'type': type});
    } catch (_) {}
  }
}
