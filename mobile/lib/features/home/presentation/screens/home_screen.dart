// lib/features/home/presentation/screens/home_screen.dart
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/home_repository.dart';
import '../providers/home_data_provider.dart';
import '../../../templates/domain/models/template_model.dart';
import '../widgets/daily_suvichar_banner.dart';
import '../widgets/festival_calendar_ribbon.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollController = ScrollController();
  String _selectedCategory = 'All';

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final homeDataAsync = ref.watch(homeDataProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: homeDataAsync.when(
        loading: _buildSkeleton,
        error: (err, _) => _buildError(err),
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.read(homeDataProvider.notifier).refresh(),
          color: AppColors.primary,
          backgroundColor: const Color(0xFF1A1A2E),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // ── Floating Header ────────────────────────────────────────
              _buildSliverHeader(data),

              // ── Daily Time-Aware Suvichar Banner ───────────────────────
              SliverToBoxAdapter(
                child: DailySuvicharBanner(
                  onCustomizePoster: () {
                    final targetTemplate = data.coordinatorPicks.isNotEmpty
                        ? data.coordinatorPicks.first
                        : (data.featured.isNotEmpty ? data.featured.first : null);
                    if (targetTemplate != null) {
                      context.push('/template/${targetTemplate.id}', extra: targetTemplate);
                    }
                  },
                ),
              ),

              // ── Upcoming Festival Calendar Ribbon ──────────────────────
              SliverToBoxAdapter(
                child: FestivalCalendarRibbon(
                  onFestivalSelected: (item) {
                    context.go('/search?q=${Uri.encodeComponent(item.nameHi)}');
                  },
                ),
              ),

              // ── Coordinator Picks (if any) ─────────────────────────────
              if (data.coordinatorPicks.isNotEmpty)
                _buildCoordinatorPicks(data.coordinatorPicks),

              // ── Festival Banner ────────────────────────────────────────
              if (data.festivalToday != null)
                _buildFestivalBanner(data.festivalToday!),

              // ── Category Pills ─────────────────────────────────────────
              if (data.categories.isNotEmpty)
                _buildCategoryPills(data.categories),

              // ── Featured Section ───────────────────────────────────────
              if (data.featured.isNotEmpty)
                _buildSectionHeader('✨ Featured'),
              if (data.featured.isNotEmpty)
                _buildMasonryGrid(data.featured),

              // ── Trending Section ───────────────────────────────────────
              if (data.trending.isNotEmpty)
                _buildSectionHeader('🔥 Trending Now'),
              if (data.trending.isNotEmpty)
                _buildHorizontalReel(data.trending),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  SliverToBoxAdapter _buildSliverHeader(HomeFeedData data) {
    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 16,
          left: 20,
          right: 20,
          bottom: 20,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0A0A1A),
              const Color(0xFF0A0A1A).withOpacity(0.0),
            ],
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good ${_getTimeGreeting()} 👋',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Status Go',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),

            // Search button
            _GlassIconButton(
              icon: Icons.search_rounded,
              onTap: () => context.go('/search'),
            ),
            const SizedBox(width: 10),
            // Notification button
            const _GlassIconButton(icon: Icons.notifications_none_rounded),
          ],
        ),
      ),
    );
  }

  // ── Coordinator Picks ────────────────────────────────────────────────────────

  SliverToBoxAdapter _buildCoordinatorPicks(List<TemplateModel> picks) {
    return SliverToBoxAdapter(
      child: FadeInLeft(
        duration: const Duration(milliseconds: 600),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          const Color(0xFFFFD700).withOpacity(0.8),
                          const Color(0xFFFF8C00).withOpacity(0.8),
                        ]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Coordinator Picks',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: picks.length,
                  itemBuilder: (context, i) {
                    return _CoordinatorPickCard(template: picks[i]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Festival Banner ───────────────────────────────────────────────────────────

  SliverToBoxAdapter _buildFestivalBanner(Map<String, dynamic> festival) {
    return SliverToBoxAdapter(
      child: FadeInUp(
        duration: const Duration(milliseconds: 500),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF6B35).withOpacity(0.8),
                    const Color(0xFFE83E8C).withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B35).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 36)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          festival['nameHi']?.toString() ?? festival['nameEn']?.toString() ?? 'Festival Today',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Tap for status templates',
                          style: GoogleFonts.outfit(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'View All',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Category Pills ────────────────────────────────────────────────────────────

  SliverToBoxAdapter _buildCategoryPills(List<CategoryModel> categories) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: categories.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return _CategoryPill(
                  label: 'All',
                  isSelected: _selectedCategory == 'All',
                  onTap: () => setState(() => _selectedCategory = 'All'),
                );
              }
              final cat = categories[i - 1];
              final label = cat.nameHi ?? cat.nameEn ?? cat.slug;
              return _CategoryPill(
                label: '${cat.emoji ?? ''} $label',
                isSelected: _selectedCategory == cat.slug,
                onTap: () => setState(() => _selectedCategory = cat.slug),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────────────

  SliverToBoxAdapter _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Text(
          title,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.3,
          ),
        ),
      ),
    );
  }

  // ── Masonry Grid ──────────────────────────────────────────────────────────────

  SliverPadding _buildMasonryGrid(List<TemplateModel> templates) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return _TemplateCard(template: templates[index]);
          },
          childCount: templates.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
      ),
    );
  }

  // ── Horizontal reel ───────────────────────────────────────────────────────────

  SliverToBoxAdapter _buildHorizontalReel(List<TemplateModel> templates) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 220,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: templates.length,
          itemBuilder: (context, i) => _TrendingCard(template: templates[i]),
        ),
      ),
    );
  }

  // ── Skeleton ──────────────────────────────────────────────────────────────────

  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1A2E),
      highlightColor: const Color(0xFF2A2A3E),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 80),
              _ShimmerBox(width: 120, height: 20, radius: 8),
              const SizedBox(height: 8),
              _ShimmerBox(width: 200, height: 32, radius: 10),
              const SizedBox(height: 24),
              _ShimmerBox(width: double.infinity, height: 200, radius: 20),
              const SizedBox(height: 24),
              Row(children: [
                for (var i = 0; i < 4; i++) ...[
                  _ShimmerBox(width: 80, height: 36, radius: 18),
                  const SizedBox(width: 8),
                ],
              ]),
              const SizedBox(height: 24),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: 6,
                itemBuilder: (_, __) => _ShimmerBox(width: double.infinity, height: double.infinity, radius: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(Object err) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, color: Colors.white38, size: 64),
          const SizedBox(height: 16),
          Text('Could not load content', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 16)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => ref.read(homeDataProvider.notifier).refresh(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Retry', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _GlassIconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      );
}

class _CategoryPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _CategoryPill({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.brandGradient : null,
          color: isSelected ? null : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.12),
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))]
              : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _CoordinatorPickCard extends StatelessWidget {
  final TemplateModel template;
  const _CoordinatorPickCard({required this.template});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/template/${template.id}'),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (template.imageUrl != null)
                CachedNetworkImage(
                  imageUrl: template.imageThumbUrl ?? template.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppColors.parseGradient(template.gradient) ??
                            [AppColors.primary, AppColors.secondary],
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppColors.parseGradient(template.gradient) ??
                            [AppColors.primary, AppColors.secondary],
                      ),
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: AppColors.parseGradient(template.gradient) ??
                          [AppColors.primary, AppColors.secondary],
                    ),
                  ),
                ),

              // Coordinator badge
              Positioned(
                top: 10, right: 10,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.5), blurRadius: 8)],
                  ),
                  child: const Icon(Icons.star_rounded, color: Colors.white, size: 12),
                ),
              ),

              // Bottom gradient
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                    ),
                  ),
                ),
              ),

              Positioned(
                bottom: 10, left: 10, right: 10,
                child: Text(
                  template.nameHi ?? template.nameEn ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final TemplateModel template;
  const _TemplateCard({required this.template});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/template/${template.id}'),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (template.imageUrl != null)
                CachedNetworkImage(
                  imageUrl: template.imageThumbUrl ?? template.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _GradientPlaceholder(gradient: template.gradient),
                  errorWidget: (_, __, ___) => _GradientPlaceholder(gradient: template.gradient),
                )
              else
                _GradientPlaceholder(gradient: template.gradient),

              // Premium badge
              if (template.isPremium == true)
                Positioned(
                  top: 10, left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('PRO', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
                  ),
                ),

              // Bottom gradient + title
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.5, 1.0],
                      colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                    ),
                  ),
                ),
              ),

              Positioned(
                bottom: 10, left: 10, right: 10,
                child: Text(
                  template.nameHi ?? template.nameEn ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    shadows: [const Shadow(blurRadius: 4, color: Colors.black54)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendingCard extends StatelessWidget {
  final TemplateModel template;
  const _TrendingCard({required this.template});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/template/${template.id}'),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (template.imageUrl != null)
                CachedNetworkImage(
                  imageUrl: template.imageThumbUrl ?? template.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _GradientPlaceholder(gradient: template.gradient),
                  errorWidget: (_, __, ___) => _GradientPlaceholder(gradient: template.gradient),
                )
              else
                _GradientPlaceholder(gradient: template.gradient),

              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.55, 1.0],
                      colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                    ),
                  ),
                ),
              ),

              Positioned(
                top: 10, left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF6B35), size: 12),
                      const SizedBox(width: 3),
                      Text(
                        '${template.useCount ?? 0}',
                        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),

              Positioned(
                bottom: 10, left: 10, right: 10,
                child: Text(
                  template.nameHi ?? template.nameEn ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientPlaceholder extends StatelessWidget {
  final String? gradient;
  const _GradientPlaceholder({this.gradient});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.parseGradient(gradient) ?? [AppColors.primary, AppColors.secondary],
          ),
        ),
      );
}

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  const _ShimmerBox({required this.width, required this.height, required this.radius});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}
