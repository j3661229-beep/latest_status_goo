// lib/features/home/presentation/screens/discover_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/data/indian_festivals_calendar.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_ui_components.dart';
import '../providers/home_data_provider.dart';
import '../widgets/daily_suvichar_banner.dart';
import '../widgets/festival_calendar_ribbon.dart';
import '../../../templates/presentation/providers/template_list_provider.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  String? _selectedCategoryId;
  String? _selectedType; // null = All, 'IMAGE', 'VIDEO'

  TemplateFilter get _filter => TemplateFilter(categoryId: _selectedCategoryId, type: _selectedType);

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

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: Text(
          'एक्सप्लोर करें (Explore)',
          style: GoogleFonts.hind(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, size: 22),
            tooltip: 'खोजें',
            onPressed: () => context.push('/search'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refresh,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            // Infinite scroll: load the next page near the bottom.
            if (n.metrics.axis == Axis.vertical && n.metrics.extentAfter < 600) {
              ref.read(templateListProvider(_filter).notifier).loadMore();
            }
            return false;
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Daily Suvichar (time-of-day quote card) ──────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: DailySuvicharBanner(
                    onCustomizePoster: () => context.go('/home'),
                  ),
                ),
              ),

              // ── Upcoming Festivals (API, static calendar fallback) ───────────
              SliverToBoxAdapter(
                child: festivalsAsync.maybeWhen(
                  data: (festivals) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: FestivalCalendarRibbon(
                      festivals: festivals,
                      headerColor: AppColors.textPrimary,
                      onFestivalSelected: _onFestivalSelected,
                    ),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ),

              // ── Type Filter Pills ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                  child: Row(
                    children: [
                      _SegmentPill(
                        label: 'सभी',
                        isActive: _selectedType == null,
                        onTap: () => setState(() => _selectedType = null),
                      ),
                      const SizedBox(width: 8),
                      _SegmentPill(
                        label: 'फोटो स्टेटस',
                        isActive: _selectedType == 'IMAGE',
                        onTap: () => setState(() => _selectedType = 'IMAGE'),
                      ),
                      const SizedBox(width: 8),
                      _SegmentPill(
                        label: 'वीडियो स्टेटस',
                        isActive: _selectedType == 'VIDEO',
                        onTap: () => setState(() => _selectedType = 'VIDEO'),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Category Horizontal List ─────────────────────────────────────
              SliverToBoxAdapter(
                child: homeData.whenOrNull(
                      data: (data) {
                        if (data.categories.isEmpty) return const SizedBox.shrink();
                        return Container(
                          color: AppColors.surface,
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SizedBox(
                            height: 38,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                              children: [
                                _CategoryPill(
                                  label: 'सभी श्रेणियां',
                                  isActive: _selectedCategoryId == null,
                                  onTap: () => setState(() => _selectedCategoryId = null),
                                ),
                                const SizedBox(width: 6),
                                ...data.categories.map((cat) => Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: _CategoryPill(
                                        label: cat.nameHi ?? cat.nameEn ?? '',
                                        emoji: cat.emoji,
                                        isActive: _selectedCategoryId == cat.id,
                                        onTap: () => setState(() => _selectedCategoryId = cat.id),
                                      ),
                                    )),
                              ],
                            ),
                          ),
                        );
                      },
                    ) ??
                    const SizedBox.shrink(),
              ),

              const SliverToBoxAdapter(
                child: Divider(height: 1, color: AppColors.surfaceBorder),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.sm),
              ),

              // ── Template Grid ─────────────────────────────────────────────────
              templatesAsync.when(
                loading: () => SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (_, __) => Container(
                        decoration: BoxDecoration(
                          color: AppColors.shimmer,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                      ),
                      childCount: 6,
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.68,
                    ),
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_rounded, color: AppColors.textMuted, size: 44),
                          const SizedBox(height: 12),
                          Text(
                            'स्टेटस लोड नहीं हो सके',
                            style: GoogleFonts.hind(
                                color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 14),
                          const SizedBox(height: 4),
                          Text(
                            apiErrorMessage(e, fallback: ''),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.hind(color: AppColors.textMuted, fontSize: 13),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () => ref.invalidate(templateListProvider(_filter)),
                            style: ElevatedButton.styleFrom(minimumSize: const Size(140, 44)),
                            child: const Text('पुनः प्रयास करें'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                data: (paged) {
                  final templates = paged.items;
                  if (templates.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(48),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.inbox_rounded, size: 48, color: AppColors.textHint),
                              const SizedBox(height: 12),
                              Text(
                                'इस श्रेणी में कोई स्टेटस नहीं मिला',
                                style: GoogleFonts.hind(
                                    fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => AppTemplateCard(template: templates[i]),
                        childCount: templates.length,
                      ),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 14,
                        childAspectRatio: 0.68,
                      ),
                    ),
                  );
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

              const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.xl),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Segment Pill ─────────────────────────────────────────────────────────────

class _SegmentPill extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SegmentPill({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.textPrimary : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: GoogleFonts.hind(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Category Pill ────────────────────────────────────────────────────────────

class _CategoryPill extends StatelessWidget {
  final String label;
  final String? emoji;
  final bool isActive;
  final VoidCallback onTap;

  const _CategoryPill({
    required this.label,
    this.emoji,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primarySurface : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.surfaceBorder,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null && emoji!.isNotEmpty) ...[
              Text(emoji!, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.hind(
                color: isActive ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
