// lib/features/search/presentation/providers/search_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/models/paged_list.dart';
import '../../../templates/data/template_repository.dart';
import '../../../templates/domain/models/template_model.dart';

part 'search_provider.g.dart';

/// Backend returns at most this many results per search page.
const int kSearchPageSize = 30;

@riverpod
Future<List<String>> trendingTerms(TrendingTermsRef ref) async {
  // Errors propagate (AsyncError) — the UI decides how to present them.
  final res = await apiClient.get('/search/trending');
  final terms = res.data is Map ? res.data['terms'] : null;
  if (terms is! List) return [];
  return terms.map((e) => e.toString()).toList();
}

@riverpod
class SearchTemplates extends _$SearchTemplates {
  @override
  Future<PagedList<TemplateModel>> build(String query) async {
    if (query.length < 2) return const PagedList(items: [], hasMore: false);
    final items = await _fetch(1);
    return PagedList(items: items, page: 1, hasMore: items.length >= kSearchPageSize);
  }

  Future<List<TemplateModel>> _fetch(int page) async {
    final res = await apiClient.get('/search', queryParameters: {'q': query, 'page': page});
    return parseTemplateList(res.data);
  }

  /// Loads the next page. After a failure, automatic calls are ignored until
  /// the user retries ([force] = true).
  Future<void> loadMore({bool force = false}) async {
    final current = state.valueOrNull;
    if (current != null && current.loadMoreError != null && !force) return;
    if (current == null || state.isLoading || current.isLoadingMore || !current.hasMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true, clearLoadMoreError: true));
    final nextPage = current.page + 1;
    try {
      final newItems = await _fetch(nextPage);
      final latest = state.valueOrNull ?? current;
      final seen = latest.items.map((t) => t.id).toSet();
      final unique = newItems.where((t) => seen.add(t.id)).toList();
      state = AsyncData(latest.copyWith(
        items: [...latest.items, ...unique],
        page: nextPage,
        // Stop when a page is short or brings nothing new.
        hasMore: newItems.length >= kSearchPageSize && unique.isNotEmpty,
        isLoadingMore: false,
      ));
    } catch (e) {
      final latest = state.valueOrNull ?? current;
      state = AsyncData(latest.copyWith(isLoadingMore: false, loadMoreError: e));
    }
  }
}
