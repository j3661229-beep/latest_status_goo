// lib/features/search/presentation/providers/search_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/api/api_client.dart';
import '../../../templates/domain/models/template_model.dart';
import 'dart:async';

part 'search_provider.g.dart';

@riverpod
Future<List<String>> trendingTerms(TrendingTermsRef ref) async {
  try {
    final res = await apiClient.get('/search/trending');
    if (res.statusCode == 200 && res.data['terms'] != null) {
      return List<String>.from(res.data['terms']);
    }
    return [];
  } catch (e) {
    return [];
  }
}

@riverpod
class SearchTemplates extends _$SearchTemplates {
  @override
  FutureOr<List<TemplateModel>> build(String query) async {
    if (query.length < 2) return [];

    try {
      final res = await apiClient.get('/search', queryParameters: {
        'q': query,
        'page': 1,
        'limit': 20,
      });

      if (res.statusCode == 200 && res.data['data'] != null) {
        return (res.data['data'] as List).map((e) => TemplateModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
