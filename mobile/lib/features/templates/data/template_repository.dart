// lib/features/templates/data/template_repository.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_client.dart';
import '../domain/models/template_model.dart';

part 'template_repository.g.dart';

@riverpod
TemplateRepository templateRepository(TemplateRepositoryRef ref) {
  return TemplateRepository(apiClient);
}

class TemplateRepository {
  final Dio _dio;
  TemplateRepository(this._dio);

  /// Throws on network/server errors; returns null only for 404.
  Future<TemplateModel?> getTemplateById(String id) async {
    try {
      final res = await _dio.get('/templates/$id');
      return TemplateModel.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Throws on network/server errors (empty list means "no results").
  Future<List<TemplateModel>> getTemplates({
    String? categoryId,
    String? type,
    int page = 1,
    int limit = 20,
    String? lang,
  }) async {
    final res = await _dio.get('/templates', queryParameters: {
      if (categoryId != null) 'cat': categoryId,
      if (type != null) 'type': type,
      if (lang != null) 'lang': lang,
      'page': page,
      'limit': limit,
    });
    return parseTemplateList(res.data);
  }

  // ─── Engagement tracking (fire-and-forget; errors ignored) ────────────────

  Future<void> recordView(String id) async {
    try {
      await _dio.post('/templates/$id/view');
    } catch (_) {}
  }

  Future<void> recordUse(String id) async {
    try {
      await _dio.post('/templates/$id/use');
    } catch (_) {}
  }

  Future<void> recordShare(String id, String platform) async {
    try {
      await _dio.post('/templates/$id/share', data: {'platform': platform});
    } catch (_) {}
  }
}

/// Parses `{ data: [...] }` template list responses.
List<TemplateModel> parseTemplateList(dynamic body) {
  final raw = body is Map ? body['data'] : null;
  if (raw is! List) return [];
  return raw.whereType<Map>().map((e) => TemplateModel.fromJson(Map<String, dynamic>.from(e))).toList();
}
