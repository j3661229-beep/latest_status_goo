// lib/features/home/presentation/screens/discover_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/color_utils.dart';
import '../providers/home_data_provider.dart';
import '../../../templates/data/template_repository.dart';
import '../../../templates/domain/models/template_model.dart';

part 'discover_screen.g.dart';

// Provider to fetch filtered templates
@riverpod
Future<List<TemplateModel>> discoverTemplates(
  DiscoverTemplatesRef ref, {
  String? categoryId,
  String? type,
}) async {
  return ref.read(templateRepositoryProvider).getTemplates(
    categoryId: categoryId,
    type: type,
    limit: 40,
  );
}

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  String? _selectedCategoryId;
  String? _selectedType; // null = All, 'IMAGE', 'VIDEO'

  @override
  Widget build(BuildContext context) {
    final homeData = ref.watch(homeDataProvider);
    final templatesAsync = ref.watch(discoverTemplatesProvider(
      categoryId: _selectedCategoryId,
      type: _selectedType,
    ));

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            title: const Text(
              'Discover',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 22),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search_rounded, color: AppColors.textPrimary),
                onPressed: () => context.push('/search'),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: AppColors.surfaceBorder),
            ),
          ),

          // ── Type Filter Pills ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  _TypePill(label: 'All', icon: Icons.apps_rounded, isActive: _selectedType == null,
                      onTap: () => setState(() => _selectedType = null)),
                  const SizedBox(width: 8),
                  _TypePill(label: 'Images', icon: Icons.image_rounded, isActive: _selectedType == 'IMAGE',
                      onTap: () => setState(() => _selectedType = 'IMAGE')),
                  const SizedBox(width: 8),
                  _TypePill(label: 'Videos', icon: Icons.play_circle_outline_rounded, isActive: _selectedType == 'VIDEO',
                      onTap: () => setState(() => _selectedType = 'VIDEO')),
                ],
              ),
            ),
          ),

          // ── Category Chips ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: homeData.whenOrNull(
              data: (data) {
                if (data.categories.isEmpty) return const SizedBox();
                return SizedBox(
                  height: 50,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    children: [
                      // "All Categories" chip
                      _CategoryChip(
                        label: 'All',
                        emoji: '✨',
                        isActive: _selectedCategoryId == null,
                        onTap: () => setState(() => _selectedCategoryId = null),
                      ),
                      const SizedBox(width: 8),
                      ...data.categories.map((cat) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _CategoryChip(
                          label: cat.nameEn ?? cat.nameHi ?? '',
                          emoji: cat.emoji ?? '📁',
                          isActive: _selectedCategoryId == cat.id,
                          gradient: ColorUtils.parseGradientString(cat.gradient),
                          onTap: () => setState(() => _selectedCategoryId = cat.id),
                        ),
                      )),
                    ],
                  ),
                );
              },
            ) ?? const SizedBox(),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Template Grid ─────────────────────────────────────────────────
          templatesAsync.when(
            loading: () => SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (_, __) => Container(
                  decoration: BoxDecoration(color: AppColors.shimmer, borderRadius: BorderRadius.circular(20)),
                ),
                childCount: 6,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.72,
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, color: AppColors.textMuted, size: 48),
                    const SizedBox(height: 12),
                    const Text('Could not load templates', style: TextStyle(color: AppColors.textMuted)),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => ref.refresh(discoverTemplatesProvider(categoryId: _selectedCategoryId, type: _selectedType)),
                      child: const Text('Try Again'),
                    ),
                  ]),
                ),
              ),
            ),
            data: (templates) {
              if (templates.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(60),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('🔍', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 16),
                      const Text('No templates found', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      const Text('Try a different category or type', style: TextStyle(color: AppColors.textMuted)),
                    ]),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _TemplateGridCard(template: templates[index]),
                    childCount: templates.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.72,
                  ),
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  const _TypePill({required this.label, required this.icon, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isActive ? AppColors.brandGradient : null,
          color: isActive ? null : AppColors.bg,
          borderRadius: BorderRadius.circular(20),
          border: isActive ? null : Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isActive ? Colors.white : AppColors.textMuted),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: isActive ? Colors.white : AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool isActive;
  final List<Color>? gradient;
  final VoidCallback onTap;
  const _CategoryChip({required this.label, required this.emoji, required this.isActive, this.gradient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: isActive && gradient != null
              ? LinearGradient(colors: gradient!, begin: Alignment.topLeft, end: Alignment.bottomRight)
              : isActive ? AppColors.brandGradient : null,
          color: isActive ? null : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isActive ? null : Border.all(color: AppColors.surfaceBorder),
          boxShadow: isActive ? [BoxShadow(color: (gradient?.first ?? AppColors.primary).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: isActive ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _TemplateGridCard extends StatelessWidget {
  final TemplateModel template;
  const _TemplateGridCard({required this.template});

  @override
  Widget build(BuildContext context) {
    final colors = ColorUtils.parseGradientString(template.gradient ?? template.category?.gradient);

    return GestureDetector(
      onTap: () => context.push('/template/${template.id}'),
      child: Container(
        decoration: BoxDecoration(
          gradient: template.imageThumbUrl == null
              ? LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight)
              : null,
          color: AppColors.shimmer,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.cardShadow,
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            if (template.imageThumbUrl != null)
              Positioned.fill(child: Image.network(template.imageThumbUrl!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: BoxDecoration(gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
                    child: Center(child: Text(template.category?.emoji ?? '✨', style: const TextStyle(fontSize: 40))),
                  ))),
            if (template.imageThumbUrl == null)
              Center(child: Text(template.category?.emoji ?? '✨', style: const TextStyle(fontSize: 44))),

            // Dark overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.72)],
                    stops: const [0.45, 1.0],
                  ),
                ),
              ),
            ),

            // VIDEO badge
            if (template.type == 'VIDEO')
              Positioned(
                top: 10, left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.play_arrow_rounded, color: Colors.white, size: 10),
                    SizedBox(width: 2),
                    Text('VIDEO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),

            // Premium badge
            if (template.isPremium == true)
              Positioned(
                top: 10, right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(8)),
                  child: const Text('⭐', style: TextStyle(fontSize: 10)),
                ),
              ),

            // Template name
            Positioned(
              bottom: 10, left: 10, right: 10,
              child: Text(
                template.nameHi ?? template.nameEn ?? 'Status',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12,
                    shadows: [Shadow(color: Colors.black, blurRadius: 6)]),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
