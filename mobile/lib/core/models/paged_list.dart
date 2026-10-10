// lib/core/models/paged_list.dart

/// Immutable state for an infinite-scroll list.
class PagedList<T> {
  final List<T> items;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;
  final Object? loadMoreError;

  const PagedList({
    required this.items,
    this.page = 1,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  PagedList<T> copyWith({
    List<T>? items,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return PagedList<T>(
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError: clearLoadMoreError ? null : (loadMoreError ?? this.loadMoreError),
    );
  }
}
