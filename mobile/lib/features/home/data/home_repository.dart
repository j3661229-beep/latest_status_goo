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
    final state = (box.get(AppConstants.keyState) as String?) ?? 'all';
    final lang = (box.get(AppConstants.keyLanguage) as String?) ?? 'HINDI';

    // Errors propagate so providers expose AsyncError (error UI with retry).
    final res = await _dio.get(
      '/templates/home',
      queryParameters: {'state': state, 'lang': lang},
    );
    final data = res.data;
    if (data is! Map) throw const FormatException('Invalid /templates/home response');
    return HomeFeedData.fromJson(Map<String, dynamic>.from(data));
  }

  /// GET /festivals/upcoming → raw festival maps. Throws on failure.
  Future<List<Map<String, dynamic>>> getUpcomingFestivals({int days = 90}) async {
    final res = await _dio.get('/festivals/upcoming', queryParameters: {'days': days});
    final raw = res.data is Map ? res.data['data'] : null;
    if (raw is! List) return [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
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
      festivalToday: json['festivalToday'] is Map ? Map<String, dynamic>.from(json['festivalToday'] as Map) : null,
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
