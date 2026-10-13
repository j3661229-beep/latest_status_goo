// lib/features/home/presentation/screens/discover_screen.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/data/indian_festivals_calendar.dart';
import '../../../../core/theme/app_ui_components.dart' show PagingFooter;
import '../../../../core/widgets/app_ui.dart';
import '../../../templates/domain/models/template_model.dart';
import '../../../templates/presentation/providers/template_list_provider.dart';
import '../../data/home_repository.dart' show HomeFeedData;
import '../providers/home_data_provider.dart';
import '../widgets/daily_suvichar_banner.dart';
import '../widgets/discover_widgets.dart';
import '../widgets/festival_calendar_ribbon.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  static const double _headerHeight = 76;

  final ScrollController _scroll = ScrollController();
  final ValueNotifier<bool> _scrolled = ValueNotifier<bool>(false);

  String? _selectedCategoryId;
  String? _selectedType; // null = All, 'IMAGE', 'VIDEO'

  TemplateFilter get _filter => TemplateFilter(categoryId: _selectedCategoryId, type: _selectedType);
  bool get _isFiltered => _selectedCategoryId != null || _selectedType != null;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      final s = _scroll.offset > 8;
      if (s != _scrolled.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && s != _scrolled.value) _scrolled.value = s;
        });
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _scrolled.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(upcomingFestivalsProvider);
    final listFuture = ref.refresh(templateListProvider(_filter).future);
    await ref.read(homeDataProvider.notifier).refresh();
    try {
      await listFuture;
    } catch (_) {
      // Error UI (with retry) is rendered from the provider state.
    }
  }

  /// Festival tap → matching category if we know it, otherwise a search.
  void _onFestivalSelected(IndianFestivalItem festival) {
    final categories = ref.read(homeDataProvider).valueOrNull?.categories ?? const [];
    String? categoryId = festival.categoryId;
    if (categoryId == null && festival.categorySlug.isNotEmpty) {
      for (final c in categories) {
        if (c.slug == festival.categorySlug) {
          categoryId = c.id;
          break;
        }
      }
    }
    if (categoryId != null && categories.any((c) => c.id == categoryId)) {
      setState(() => _selectedCategoryId = categoryId);
    } else {
      context.push('/search?q=${Uri.encodeQueryComponent(festival.nameHi)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeData = ref.watch(homeDataProvider);
    final templatesAsync = ref.watch(templateListProvider(_filter));
    final festivalsAsync = ref.watch(upcomingFestivalsProvider);
    final p = context.palette;
    final topPad = MediaQuery.of(context).padding.top;

    final feed = homeData.valueOrNull;
    final trending = feed?.trending ?? const <TemplateModel>[];
    final fresh = _freshTemplates(feed);
    final categories = feed?.categories ?? const <CategoryModel>[];

    return Scaffold(
      backgroundColor: p.bg,
      body: RefreshIndicator(
        color: p.primary,
        edgeOffset: topPad + _headerHeight,
        onRefresh: _refresh,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            // Infinite scroll: load the next page near the bottom.
            if (n.metrics.axis == Axis.vertical && n.metrics.extentAfter < 600) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  ref.read(templateListProvider(_filter).notifier).loadMore();
                }
              });
            }
            return false;
          },
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Sticky blurred header with search entry ──────────────────────
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickySearchHeader(
                  extent: topPad + _headerHeight,
                  topPadding: topPad,
                  scrolled: _scrolled,
                  onSearch: () => context.push('/search'),
                  onBell: () => context.push('/notifications'),
                ),
              ),

              // ── Daily Suvichar ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  index: 0,
                  child: DailySuvicharBanner(onCustomizePoster: () => context.go('/home')),
                ),
              ),

              // ── Categories ───────────────────────────────────────────────────
              if (categories.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: FilterPillRow(
                      labels: ['सभी', ...categories.map((c) => c.nameHi ?? c.nameEn ?? '')],
                      emojis: ['✨', ...categories.map((c) => c.emoji)],
                      selectedIndex: _selectedCategoryId == null
                          ? 0
                          : (categories.indexWhere((c) => c.id == _selectedCategoryId) + 1)
                              .clamp(0, categories.length),
                      onSelected: (i) => setState(
                        () => _selectedCategoryId = i == 0 ? null : categories[i - 1].id,
                      ),
                    ),
                  ),
                ),

              // ── Type filter ──────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: TemplateTypeSegment(
                    value: _selectedType,
                    onChanged: (v) => setState(() => _selectedType = v),
                  ),
                ),
              ),

              // ── Curated sections (only on the unfiltered view) ───────────────
              if (!_isFiltered) ...[
                SliverToBoxAdapter(
                  child: TemplateCarouselSection(
                    title: 'ट्रेंडिंग',
                    subtitle: 'आज सबसे ज़्यादा इस्तेमाल हो रहे',
                    templates: trending,
                    staggerIndex: 1,
                  ),
                ),
                SliverToBoxAdapter(
                  child: TemplateCarouselSection(
                    title: 'नए',
                    subtitle: 'ताज़ा जुड़े हुए स्टेटस',
                    templates: fresh,
                    staggerIndex: 2,
                  ),
                ),
                SliverToBoxAdapter(
                  child: festivalsAsync.maybeWhen(
                    data: (festivals) => FadeSlideIn(
                      index: 3,
                      child: FestivalCalendarRibbon(
                        festivals: festivals,
                        onFestivalSelected: _onFestivalSelected,
                      ),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ),
              ],

              SliverToBoxAdapter(
                child: SectionHeader(
                  title: _isFiltered ? 'चुने हुए स्टेटस' : 'सभी स्टेटस',
                  subtitle: _isFiltered ? 'फ़िल्टर के अनुसार' : 'आपके लिए चुने गए',
                ),
              ),

              // ── Template grid ────────────────────────────────────────────────
              templatesAsync.when(
                loading: () => const SliverToBoxAdapter(child: ShimmerGrid(itemCount: 6)),
                error: (e, _) => SliverToBoxAdapter(
                  child: SizedBox(
                    height: 380,
                    child: ErrorState(
                      title: 'स्टेटस लोड नहीं हो सके',
                      message: apiErrorMessage(e, fallback: 'कृपया इंटरनेट जांचें और दोबारा कोशिश करें।'),
                      onRetry: () => ref.invalidate(templateListProvider(_filter)),
                    ),
                  ),
                ),
                data: (paged) {
                  if (paged.items.isEmpty) {
                    return SliverToBoxAdapter(
                      child: SizedBox(
                        height: 380,
                        child: EmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'इस श्रेणी में कोई स्टेटस नहीं मिला',
                          message: 'दूसरी श्रेणी या फ़िल्टर चुनकर देखें।',
                          actionLabel: _isFiltered ? 'फ़िल्टर हटाएं' : null,
                          onAction: _isFiltered
                              ? () => setState(() {
                                    _selectedCategoryId = null;
                                    _selectedType = null;
                                  })
                              : null,
                          compact: true,
                        ),
                      ),
                    );
                  }
                  return SliverTemplateGrid(templates: paged.items);
                },
              ),

              SliverToBoxAdapter(
                child: templatesAsync.maybeWhen(
                  data: (paged) => paged.items.isEmpty
                      ? const SizedBox.shrink()
                      : PagingFooter(
                          isLoading: paged.isLoadingMore,
                          hasError: paged.loadMoreError != null,
                          onRetry: () => ref.read(templateListProvider(_filter).notifier).loadMore(force: true),
                        ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
            ],
          ),
        ),
      ),
    );
  }

  /// "नए" section: freshly added templates from the home feed.
  List<TemplateModel> _freshTemplates(HomeFeedData? feed) {
    if (feed == null) return const [];
    final seen = <String>{};
    final all = <TemplateModel>[
      ...feed.featured,
      ...feed.coordinatorPicks,
    ].where((t) => seen.add(t.id)).toList();
    final onlyNew = all.where((t) => t.isNew == true).toList();
    return onlyNew.isNotEmpty ? onlyNew : all;
  }
}

/// Pinned header: title row + search entry; gains a blur + tint once scrolled.
class _StickySearchHeader extends SliverPersistentHeaderDelegate {
  final double extent;
  final double topPadding;
  final ValueNotifier<bool> scrolled;
  final VoidCallback onSearch;
  final VoidCallback onBell;

  _StickySearchHeader({
    required this.extent,
    required this.topPadding,
    required this.scrolled,
    required this.onSearch,
    required this.onBell,
  });

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final p = context.palette;
    final content = Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.page, topPadding + AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: DiscoverSearchBar(onTap: onSearch)),
          const SizedBox(width: AppSpacing.xxs),
          AppIconButton(
            icon: Icons.notifications_none_rounded,
            semanticLabel: 'सूचनाएं',
            onPressed: onBell,
          ),
        ],
      ),
    );
    return ValueListenableBuilder<bool>(
      valueListenable: scrolled,
      builder: (context, isScrolled, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: isScrolled ? p.bg.withValues(alpha: 0.96) : p.bg,
            border: Border(bottom: BorderSide(color: isScrolled ? p.divider : Colors.transparent)),
          ),
          child: content,
        );
      },
    );
  }

  @override
  bool shouldRebuild(covariant _StickySearchHeader old) =>
      old.extent != extent || old.topPadding != topPadding;
}
