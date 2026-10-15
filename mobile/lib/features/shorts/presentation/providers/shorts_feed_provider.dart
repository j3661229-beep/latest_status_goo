// lib/features/shorts/presentation/providers/shorts_feed_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/short_models.dart';
import '../../data/shorts_repository.dart';

class ShortsQuery {
  final ShortsFeed feed;
  final String? category;
  const ShortsQuery(this.feed, [this.category]);

  @override
  bool operator ==(Object other) => other is ShortsQuery && other.feed == feed && other.category == category;
  @override
  int get hashCode => Object.hash(feed, category);
}

class ShortsFeedState {
  final List<ShortItem> items;
  final int page;
  final bool hasMore;
  final bool loading; // first page
  final bool loadingMore;
  final Object? error; // first-page error
  final Object? loadMoreError;

  const ShortsFeedState({
    this.items = const [],
    this.page = 0,
    this.hasMore = true,
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.loadMoreError,
  });

  ShortsFeedState copyWith({
    List<ShortItem>? items,
    int? page,
    bool? hasMore,
    bool? loading,
    bool? loadingMore,
    Object? error,
    Object? loadMoreError,
    bool clearError = false,
    bool clearLoadMoreError = false,
  }) =>
      ShortsFeedState(
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: clearError ? null : (error ?? this.error),
        loadMoreError: clearLoadMoreError ? null : (loadMoreError ?? this.loadMoreError),
      );
}

class ShortsFeedNotifier extends StateNotifier<ShortsFeedState> {
  ShortsFeedNotifier(this._repo, this.query) : super(const ShortsFeedState()) {
    refresh();
  }

  final ShortsRepository _repo;
  final ShortsQuery query;
  int _generation = 0; // invalidates in-flight requests after refresh/dispose

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> refresh() async {
    final gen = ++_generation;
    // Keep old items visible during a refresh so the pager doesn't collapse.
    state = state.copyWith(loading: state.items.isEmpty, clearError: true, clearLoadMoreError: true, loadingMore: false);
    try {
      final p = await _repo.list(feed: query.feed, category: query.category, page: 1);
      if (gen != _generation) return;
      state = ShortsFeedState(items: p.items, page: 1, hasMore: p.hasMore, loading: false);
    } catch (e) {
      if (gen != _generation) return;
      state = state.copyWith(loading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore || state.error != null) return;
    final gen = _generation;
    state = state.copyWith(loadingMore: true, clearLoadMoreError: true);
    try {
      final p = await _repo.list(feed: query.feed, category: query.category, page: state.page + 1);
      if (gen != _generation) return;
      final known = state.items.map((e) => e.id).toSet();
      state = state.copyWith(
        items: [...state.items, ...p.items.where((e) => !known.contains(e.id))],
        page: state.page + 1,
        hasMore: p.hasMore,
        loadingMore: false,
      );
    } catch (e) {
      if (gen != _generation) return;
      state = state.copyWith(loadingMore: false, loadMoreError: e);
    }
  }

  /// Optimistic bookmark; rolls back and rethrows on failure.
  Future<void> toggleSaved(String id) async {
    final idx = state.items.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final target = !state.items[idx].isSaved;
    _setSaved(id, target);
    try {
      await _repo.setSaved(id, target);
    } catch (_) {
      _setSaved(id, !target);
      rethrow;
    }
  }

  void _setSaved(String id, bool saved) {
    state = state.copyWith(items: [for (final e in state.items) e.id == id ? e.copyWith(isSaved: saved) : e]);
  }
}

final shortsFeedProvider =
    StateNotifierProvider.autoDispose.family<ShortsFeedNotifier, ShortsFeedState, ShortsQuery>(
  (ref, q) => ShortsFeedNotifier(ref.watch(shortsRepositoryProvider), q),
);

final shortDetailProvider = FutureProvider.autoDispose.family<ShortDetail, String>(
  (ref, id) => ref.watch(shortsRepositoryProvider).detail(id),
);
