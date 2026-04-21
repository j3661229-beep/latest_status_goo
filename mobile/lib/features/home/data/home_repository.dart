// lib/features/home/data/home_repository.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_client.dart';
import '../../templates/domain/models/template_model.dart';

part 'home_repository.g.dart';

@riverpod
HomeRepository homeRepository(HomeRepositoryRef ref) {
  return HomeRepository(apiClient);
}

class HomeRepository {
  final Dio _dio;
  HomeRepository(this._dio);

  Future<List<CategoryModel>> getCategories() async {
    try {
      final res = await _dio.get('/categories');
      if (res.statusCode == 200 && res.data['data'] != null) {
        return (res.data['data'] as List).map((e) => CategoryModel.fromJson(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<TemplateModel>> getFeatured() async {
    try {
      final res = await _dio.get('/templates/featured');
      if (res.statusCode == 200 && res.data['data'] != null) {
        return (res.data['data'] as List).map((e) => TemplateModel.fromJson(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<TemplateModel>> getTrending() async {
    try {
      final res = await _dio.get('/templates/trending');
      if (res.statusCode == 200 && res.data['data'] != null) {
        return (res.data['data'] as List).map((e) => TemplateModel.fromJson(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> getUpcomingFestivals() async {
    try {
      final res = await _dio.get('/festivals/upcoming');
      if (res.statusCode == 200 && res.data['data'] != null) {
        return res.data['data'] as List;
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
