// lib/features/home/presentation/screens/home_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../templates/domain/models/template_model.dart';
import '../../data/home_repository.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────

final homeFeedProvider = FutureProvider.autoDispose<HomeFeedData>((ref) async {
  final repo = ref.read(homeRepositoryProvider);
  return repo.getHomeFeed();
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedCategory = 'all';

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(homeFeedProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Status Go'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'खोजें',
            onPressed: () => context.push('/search'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: feed.when(
        loading: () => _buildSkeleton(),
        error: (e, _) => _buildError(() => ref.invalidate(homeFeedProvider)),
        data: (data) => _buildBody(data),
      ),
    );
  }

  Widget _buildBody(HomeFeedData data) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => ref.invalidate(homeFeedProvider),
      child: CustomScrollView(
        slivers: [
          // Festival banner
          if (data.festivalToday != null)
            SliverToBoxAdapter(
              child: _FestivalBanner(festival: data.festivalToday!),
            ),

          // Category chips
          if (data.categories.isNotEmpty)
            SliverToBoxAdapter(
              child: _CategoryBar(
                categories: data.categories,
                selected: _selectedCategory,
                onSelect: (slug) => setState(() => _selectedCategory = slug),
              ),
            ),

          // Featured section
          if (data.featured.isNotEmpty) ...[
            _SectionHeader(title: 'आज के विशेष स्टेटस', onSeeAll: () {}),
            SliverToBoxAdapter(
              child: _HorizontalList(templates: data.featured),
            ),
          ],

          // Trending
          if (data.trending.isNotEmpty) ...[
            _SectionHeader(title: 'लोकप्रिय स्टेटस', onSeeAll: () {}),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: _TemplateGrid(
                templates: _filterByCategory(data.trending),
              ),
            ),
          ],

          // Coordinator picks
          if (data.coordinatorPicks.isNotEmpty) ...[
            _SectionHeader(title: '⭐ चुने हुए स्टेटस', onSeeAll: () {}),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: _TemplateGrid(
                templates: data.coordinatorPicks,
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  List<TemplateModel> _filterByCategory(List<TemplateModel> templates) {
    if (_selectedCategory == 'all') return templates;
    return templates
        .where((t) => t.category?.slug == _selectedCategory)
        .toList();
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(
        4,
        (_) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 180,
          decoration: BoxDecoration(
            color: AppColors.shimmer,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildError(VoidCallback retry) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            'कनेक्शन में समस्या है',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'इंटरनेट जाँचें और दोबारा कोशिश करें',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('दोबारा कोशिश करें'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(200, 48)),
          ),
        ],
      ),
    );
  }
}

// ─── Festival Banner ──────────────────────────────────────────────────────────

class _FestivalBanner extends StatelessWidget {
  final Map<String, dynamic> festival;
  const _FestivalBanner({required this.festival});

  @override
  Widget build(BuildContext context) {
    final name = festival['nameHi'] ?? festival['nameEn'] ?? 'Festival';
    final emoji = festival['emoji'] ?? '🎉';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'आज का त्यौहार',
                  style: GoogleFonts.hind(
                      fontSize: 13,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  name,
                  style: GoogleFonts.hind(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              minimumSize: const Size(80, 38),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: GoogleFonts.hind(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            child: const Text('देखें'),
          ),
        ],
      ),
    );
  }
}

// ─── Category Bar ─────────────────────────────────────────────────────────────

class _CategoryBar extends StatelessWidget {
  final List<CategoryModel> categories;
  final String selected;
  final ValueChanged<String> onSelect;
  const _CategoryBar(
      {required this.categories,
      required this.selected,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final all = [
      const CategoryModel(id: 'all', slug: 'all', nameHi: 'सभी', emoji: '🏠')
    ] + categories;

    return SizedBox(
      height: 56,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: all.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final cat = all[i];
          final isSelected = cat.slug == selected;
          return GestureDetector(
            onTap: () => onSelect(cat.slug),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.surfaceBorder),
              ),
              child: Text(
                '${cat.emoji ?? ''} ${cat.nameHi ?? cat.nameEn ?? cat.slug}',
                style: GoogleFonts.hind(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends SliverToBoxAdapter {
  _SectionHeader({required String title, required VoidCallback onSeeAll})
      : super(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.hind(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('सभी देखें'),
                ),
              ],
            ),
          ),
        );
}

// ─── Horizontal Template List ─────────────────────────────────────────────────

class _HorizontalList extends StatelessWidget {
  final List<TemplateModel> templates;
  const _HorizontalList({required this.templates});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: templates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) => _TemplateCard(
          template: templates[i],
          width: 160,
        ),
      ),
    );
  }
}

// ─── Template Grid ────────────────────────────────────────────────────────────

class _TemplateGrid extends StatelessWidget {
  final List<TemplateModel> templates;
  const _TemplateGrid({required this.templates});

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      delegate: SliverChildBuilderDelegate(
        (ctx, i) => _TemplateCard(template: templates[i]),
        childCount: templates.length,
      ),
    );
  }
}

// ─── Template Card ────────────────────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  final TemplateModel template;
  final double? width;
  const _TemplateCard({required this.template, this.width});

  @override
  Widget build(BuildContext context) {
    final imgUrl = template.imageThumbUrl ?? template.imageUrl;
    final name = template.nameHi ?? template.nameEn ?? '';

    return GestureDetector(
      onTap: () => context.push('/template/${template.id}'),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceBorder),
          boxShadow: AppColors.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image
            Expanded(
              child: imgUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imgUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: AppColors.shimmer),
                      errorWidget: (_, __, ___) => _GradientPlaceholder(template),
                    )
                  : _GradientPlaceholder(template),
            ),
            // Name + badges
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (name.isNotEmpty)
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.hind(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                  if (template.isPremium == true) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '⭐ Premium',
                        style: GoogleFonts.hind(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientPlaceholder extends StatelessWidget {
  final TemplateModel template;
  const _GradientPlaceholder(this.template);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.parseGradient(template.gradient);
    return Container(
      decoration: BoxDecoration(
        gradient: colors != null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              )
            : const LinearGradient(
                colors: [AppColors.primarySurface, AppColors.primaryLight],
              ),
      ),
      child: Center(
        child: Text(
          template.nameHi?.substring(0, 1) ?? '🙏',
          style: const TextStyle(fontSize: 36),
        ),
      ),
    );
  }
}
