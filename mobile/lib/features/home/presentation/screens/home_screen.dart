// lib/features/home/presentation/screens/home_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../core/utils/color_utils.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/home_data_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final homeDataAsync = ref.watch(homeDataProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: () => ref.read(homeDataProvider.notifier).refresh(),
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            // ── Immersive Gradient Header ─────────────────────────────────────
            SliverAppBar(
              expandedHeight: 140,
              pinned: true,
              backgroundColor: AppColors.primary,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Container(
                  decoration: const BoxDecoration(gradient: AppColors.brandGradient),
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Logo pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('📲', style: TextStyle(fontSize: 16)),
                                SizedBox(width: 6),
                                Text(
                                  'Status Go',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          // Streak badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                            ),
                            child: const Row(
                              children: [
                                Text('🔥', style: TextStyle(fontSize: 13)),
                                SizedBox(width: 4),
                                Text('5 Days', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Search button
                          GestureDetector(
                            onTap: () => context.push('/search'),
                            child: Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.search_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Main Content ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: homeDataAsync.when(
                data: (data) => _buildContent(data),
                loading: () => _buildLoadingSkeleton(),
                error: (err, stack) => _buildErrorState(err),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(HomeState data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),

        // ── Festival Banner ─────────────────────────────────────────
        if (data.festivals.isNotEmpty)
          FadeInDown(
            duration: const Duration(milliseconds: 500),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _FestivalBanner(festival: data.festivals.first),
            ),
          ),

        if (data.festivals.isNotEmpty) const SizedBox(height: 28),

        // ── Featured Templates ────────────────────────────────────
        if (data.featured.isNotEmpty) ...[
          _SectionHeader(
            emoji: '⭐',
            title: 'Featured Status',
            onSeeAll: () => context.go('/discover'),
          ),
          const SizedBox(height: 14),
          FadeIn(
            duration: const Duration(milliseconds: 600),
            child: SizedBox(
              height: 250,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: data.featured.length,
                itemBuilder: (ctx, i) => Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: _FeaturedCard(template: data.featured[i]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],

        // ── Categories ────────────────────────────────────────────
        if (data.categories.isNotEmpty) ...[
          _SectionHeader(
            emoji: '📂',
            title: 'Browse by Category',
            onSeeAll: () => context.go('/discover'),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: data.categories.length,
              itemBuilder: (ctx, i) => Padding(
                padding: const EdgeInsets.only(right: 14),
                child: _CategoryTile(category: data.categories[i]),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],

        // ── Trending ─────────────────────────────────────────────
        if (data.trending.isNotEmpty) ...[
          _SectionHeader(
            emoji: '🔥',
            title: 'Trending Now',
            onSeeAll: () => context.go('/discover'),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.72,
              ),
              itemCount: data.trending.length,
              itemBuilder: (ctx, i) => _TrendingCard(template: data.trending[i]),
            ),
          ),
        ],

        // Bottom nav padding
        const SizedBox(height: 110),
      ],
    );
  }

  // ── Skeleton Loading ────────────────────────────────────────────────────────
  Widget _buildLoadingSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _Shimmer(height: 80, radius: 20),
          const SizedBox(height: 28),
          _Shimmer(width: 140, height: 20, radius: 10),
          const SizedBox(height: 14),
          Row(children: [
            _Shimmer(width: 160, height: 250, radius: 24),
            const SizedBox(width: 14),
            _Shimmer(width: 160, height: 250, radius: 24),
          ]),
          const SizedBox(height: 28),
          _Shimmer(width: 160, height: 20, radius: 10),
          const SizedBox(height: 14),
          Row(children: [
            _Shimmer(width: 75, height: 100, radius: 20),
            const SizedBox(width: 14),
            _Shimmer(width: 75, height: 100, radius: 20),
            const SizedBox(width: 14),
            _Shimmer(width: 75, height: 100, radius: 20),
          ]),
          const SizedBox(height: 28),
          _Shimmer(width: 120, height: 20, radius: 10),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.72,
            ),
            itemCount: 4,
            itemBuilder: (_, __) => _Shimmer(radius: 20),
          ),
        ],
      ),
    );
  }

  Widget _Shimmer({double? width, double? height, double radius = 12}) {
    return Container(
      width: width,
      height: height ?? 80,
      decoration: BoxDecoration(
        color: AppColors.shimmer,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  // ── Error State ──────────────────────────────────────────────────────────────
  Widget _buildErrorState(Object err) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.danger),
          ),
          const SizedBox(height: 20),
          const Text(
            'Could not load content',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Check your internet connection and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => ref.read(homeDataProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}

// ── Section Header ─────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String emoji;
  final String title;
  final VoidCallback? onSeeAll;
  const _SectionHeader({required this.emoji, required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -0.3),
          ),
          const Spacer(),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'See all',
                  style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Festival Banner ─────────────────────────────────────────────────────────────
class _FestivalBanner extends StatelessWidget {
  final Map<String, dynamic> festival;
  const _FestivalBanner({required this.festival});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B9D), Color(0xFFFFB347)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.cardShadowFor(const Color(0xFFFF6B9D)),
      ),
      child: Row(
        children: [
          Text(festival['emoji'] ?? '🎉', style: const TextStyle(fontSize: 36)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${festival['nameHi'] ?? ''} आ रहा है!',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 2),
                const Text(
                  'खास स्टेटस से शुभकामनाएं दें',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.go('/discover'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: const Text('देखें', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFFFF6B9D))),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Featured Template Card ──────────────────────────────────────────────────────
class _FeaturedCard extends StatelessWidget {
  final dynamic template;
  const _FeaturedCard({required this.template});

  @override
  Widget build(BuildContext context) {
    final colors = ColorUtils.parseGradientString(
      template.gradient ?? template.category?.gradient,
    );
    final isNew = template.createdAt != null &&
        DateTime.now().difference(template.createdAt!).inDays <= 7;

    return GestureDetector(
      onTap: () => context.push('/template/${template.id}'),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppColors.cardShadowFor(colors.first),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // Thumbnail
            if (template.imageThumbUrl != null)
              Positioned.fill(
                child: Image.network(
                  template.imageThumbUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),

            // Bottom gradient for readability
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
              ),
            ),

            // NEW badge
            if (isNew)
              Positioned(
                top: 10, left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                ),
              ),

            // Category emoji
            if (template.imageThumbUrl == null)
              Center(
                child: Text(template.category?.emoji ?? '✨', style: const TextStyle(fontSize: 48)),
              ),

            // Title
            Positioned(
              bottom: 12, left: 12, right: 12,
              child: Text(
                template.nameHi ?? template.nameEn ?? 'Status',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                ),
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category Tile ───────────────────────────────────────────────────────────────
class _CategoryTile extends StatelessWidget {
  final dynamic category;
  const _CategoryTile({required this.category});

  @override
  Widget build(BuildContext context) {
    final colors = ColorUtils.parseGradientString(category.gradient);

    return GestureDetector(
      onTap: () => context.go('/discover?cat=${category.id}'),
      child: Column(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(color: colors.first.withOpacity(0.28), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Center(child: Text(category.emoji, style: const TextStyle(fontSize: 32))),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 72,
            child: Text(
              category.nameEn,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Trending Card ───────────────────────────────────────────────────────────────
class _TrendingCard extends StatelessWidget {
  final dynamic template;
  const _TrendingCard({required this.template});

  @override
  Widget build(BuildContext context) {
    final colors = ColorUtils.parseGradientString(
      template.gradient ?? template.category?.gradient,
    );

    return GestureDetector(
      onTap: () => context.push('/template/${template.id}'),
      child: Container(
        decoration: BoxDecoration(
          gradient: template.imageThumbUrl == null
              ? LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight)
              : null,
          color: template.imageThumbUrl != null ? null : null,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.cardShadow,
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // Background image
            if (template.imageThumbUrl != null)
              Positioned.fill(
                child: Image.network(template.imageThumbUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                      ),
                    )),
              ),

            // Emoji if no image
            if (template.imageThumbUrl == null)
              Center(child: Text(template.category?.emoji ?? '✨', style: const TextStyle(fontSize: 40))),

            // Gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                  ),
                ),
              ),
            ),

            // Uses badge
            Positioned(
              top: 10, right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.trending_up_rounded, color: Colors.white, size: 10),
                    const SizedBox(width: 3),
                    Text(
                      _formatCount(template.useCount ?? 0),
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),

            // Type badge (VIDEO)
            if (template.type == 'VIDEO')
              Positioned(
                top: 10, left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 10),
                      SizedBox(width: 3),
                      Text('VIDEO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),

            // Title
            Positioned(
              bottom: 10, left: 10, right: 10,
              child: Text(
                template.nameHi ?? template.nameEn ?? 'Status',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }
}
