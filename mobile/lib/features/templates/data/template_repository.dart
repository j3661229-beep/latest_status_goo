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

  Future<TemplateModel?> getTemplateById(String id) async {
    try {
      final res = await _dio.get('/templates/$id');
      if (res.statusCode == 200) {
        return TemplateModel.fromJson(res.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<TemplateModel>> getTemplates({
    String? categoryId,
    String? type,
    int page = 1,
    int limit = 20,
    String? lang,
  }) async {
    try {
      final res = await _dio.get('/templates', queryParameters: {
        if (categoryId != null) 'cat': categoryId,
        if (type != null) 'type': type,
        if (lang != null) 'lang': lang,
        'page': page,
        'limit': limit,
      });
      if (res.statusCode == 200 && res.data['data'] != null) {
        return (res.data['data'] as List).map((e) => TemplateModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

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
