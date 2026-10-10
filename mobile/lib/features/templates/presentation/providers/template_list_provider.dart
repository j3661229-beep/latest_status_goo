// lib/features/templates/presentation/providers/template_list_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/models/paged_list.dart';
import '../../data/template_repository.dart';
import '../../domain/models/template_model.dart';

part 'template_list_provider.g.dart';

class TemplateFilter {
  final String? categoryId;
  final String? type;
  final String? lang;

  const TemplateFilter({this.categoryId, this.type, this.lang});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TemplateFilter &&
        other.categoryId == categoryId &&
        other.type == type &&
        other.lang == lang;
  }

  @override
  int get hashCode => Object.hash(categoryId, type, lang);
}

const int kTemplatePageSize = 20;

/// Paginated template list. The first page is the provider's AsyncValue (so
/// loading / error UIs work as usual); further pages are appended by
/// [loadMore] while the previous data stays visible.
@riverpod
class TemplateList extends _$TemplateList {
  @override
  Future<PagedList<TemplateModel>> build(TemplateFilter filter) async {
    final items = await _fetchPage(1);
    return PagedList(items: items, page: 1, hasMore: items.length >= kTemplatePageSize);
  }

  Future<List<TemplateModel>> _fetchPage(int page) {
    return ref.read(templateRepositoryProvider).getTemplates(
          categoryId: filter.categoryId,
          type: filter.type,
          lang: filter.lang,
          page: page,
          limit: kTemplatePageSize,
        );
  }

  /// Loads the next page. After a failure, automatic calls are ignored until
  /// the user retries ([force] = true).
  Future<void> loadMore({bool force = false}) async {
    final current = state.valueOrNull;
    if (current != null && current.loadMoreError != null && !force) return;
    // Guard: nothing loaded yet, already loading, or no more pages.
    if (current == null || state.isLoading || current.isLoadingMore || !current.hasMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true, clearLoadMoreError: true));
    final nextPage = current.page + 1;
    try {
      final newItems = await _fetchPage(nextPage);
      final latest = state.valueOrNull ?? current;
      final seen = latest.items.map((t) => t.id).toSet();
      final unique = newItems.where((t) => seen.add(t.id)).toList();
      state = AsyncData(latest.copyWith(
        items: [...latest.items, ...unique],
        page: nextPage,
        hasMore: newItems.length >= kTemplatePageSize && unique.isNotEmpty,
        isLoadingMore: false,
      ));
    } catch (e) {
      final latest = state.valueOrNull ?? current;
      state = AsyncData(latest.copyWith(isLoadingMore: false, loadMoreError: e));
    }
  }
}

@riverpod
Future<TemplateModel?> singleTemplate(SingleTemplateRef ref, String id) {
  final repo = ref.read(templateRepositoryProvider);
  return repo.getTemplateById(id);
}
