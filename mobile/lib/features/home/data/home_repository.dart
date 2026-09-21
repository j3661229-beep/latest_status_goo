// lib/features/home/data/home_repository.dart
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../templates/domain/models/template_model.dart';

part 'home_repository.g.dart';

@riverpod
HomeRepository homeRepository(HomeRepositoryRef ref) {
  return HomeRepository(apiClient);
}

class HomeRepository {
  final Dio _dio;
  HomeRepository(this._dio);

  // ─── Single-call home feed (backend caches it in Redis) ──────────────────

  Future<HomeFeedData> getHomeFeed() async {
    final box = Hive.box(AppConstants.hiveBoxSettings);
    final state = box.get(AppConstants.keyState, defaultValue: 'all') as String;
    final lang = box.get(AppConstants.keyLanguage, defaultValue: 'HINDI') as String;

    try {
      final res = await _dio.get(
        '/templates/home',
        queryParameters: {'state': state, 'lang': lang},
      );

      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        return HomeFeedData.fromJson(data);
      }
      return HomeFeedData.empty();
    } catch (_) {
      return HomeFeedData.empty();
    }
  }

  // ─── Legacy individual endpoints (kept for backward compat) ───────────────

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

// ─── Data Models ──────────────────────────────────────────────────────────────

class HomeFeedData {
  final List<TemplateModel> featured;
  final List<TemplateModel> trending;
  final List<TemplateModel> coordinatorPicks;
  final Map<String, dynamic>? festivalToday;
  final List<CategoryModel> categories;

  const HomeFeedData({
    required this.featured,
    required this.trending,
    required this.coordinatorPicks,
    this.festivalToday,
    required this.categories,
  });

  factory HomeFeedData.fromJson(Map<String, dynamic> json) {
    List<TemplateModel> parseTemplates(dynamic raw) {
      if (raw == null) return [];
      return (raw as List).map((e) => TemplateModel.fromJson(e as Map<String, dynamic>)).toList();
    }

    List<CategoryModel> parseCategories(dynamic raw) {
      if (raw == null) return [];
      return (raw as List).map((e) => CategoryModel.fromJson(e as Map<String, dynamic>)).toList();
    }

    return HomeFeedData(
      featured: parseTemplates(json['featured']),
      trending: parseTemplates(json['trending']),
      coordinatorPicks: parseTemplates(json['coordinatorPicks']),
      festivalToday: json['festivalToday'] as Map<String, dynamic>?,
      categories: parseCategories(json['categories']),
    );
  }

  factory HomeFeedData.empty() => const HomeFeedData(
        featured: [],
        trending: [],
        coordinatorPicks: [],
        categories: [],
      );
}
