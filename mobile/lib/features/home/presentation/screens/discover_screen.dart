// lib/features/home/presentation/screens/discover_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/theme/app_theme.dart';
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
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          'सभी स्टेटस (Explore)',
          style: GoogleFonts.hind(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, size: 26),
            tooltip: 'खोजें (Search)',
            onPressed: () => context.push('/search'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // ── Type Filter Pills ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _TypeFilterButton(
                    label: 'सभी (All)',
                    icon: Icons.grid_view_rounded,
                    isActive: _selectedType == null,
                    onTap: () => setState(() => _selectedType = null),
                  ),
                  const SizedBox(width: 10),
                  _TypeFilterButton(
                    label: 'फोटो (Photos)',
                    icon: Icons.image_rounded,
                    isActive: _selectedType == 'IMAGE',
                    onTap: () => setState(() => _selectedType = 'IMAGE'),
                  ),
                  const SizedBox(width: 10),
                  _TypeFilterButton(
                    label: 'वीडियो (Videos)',
                    icon: Icons.play_circle_fill_rounded,
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
                if (data.categories.isEmpty) return const SizedBox();
                return Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _CategoryPill(
                          label: 'सभी श्रेणियां (All)',
                          emoji: '✨',
                          isActive: _selectedCategoryId == null,
                          onTap: () => setState(() => _selectedCategoryId = null),
                        ),
                        const SizedBox(width: 8),
                        ...data.categories.map((cat) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _CategoryPill(
                            label: cat.nameHi ?? cat.nameEn ?? '',
                            emoji: cat.emoji ?? '📁',
                            isActive: _selectedCategoryId == cat.id,
                            onTap: () => setState(() => _selectedCategoryId = cat.id),
                          ),
                        )),
                      ],
                    ),
                  ),
                );
              },
            ) ?? const SizedBox(),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // ── Template Grid ─────────────────────────────────────────────────
          templatesAsync.when(
            loading: () => SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (_, __) => Container(
                    decoration: BoxDecoration(
                      color: AppColors.shimmer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                  ),
                  childCount: 6,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.72,
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
                      const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'स्टेटस लोड नहीं हो सके',
                        style: GoogleFonts.hind(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => ref.refresh(discoverTemplatesProvider(
                          categoryId: _selectedCategoryId,
                          type: _selectedType,
                        )),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(140, 44),
                        ),
                        child: Text(
                          'पुनः प्रयास करें (Retry)',
                          style: GoogleFonts.hind(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            data: (templates) {
              if (templates.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off_rounded, size: 56, color: AppColors.textHint),
                        const SizedBox(height: 16),
                        Text(
                          'कोई स्टेटस नहीं मिला',
                          style: GoogleFonts.hind(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'कृपया अन्य श्रेणी या फिल्टर का चयन करें',
                          style: GoogleFonts.hind(color: AppColors.textMuted, fontSize: 15),
                        ),
                      ],
                    ),
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
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 90)),
        ],
      ),
    );
  }
}

class _TypeFilterButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _TypeFilterButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: isActive ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive ? AppColors.primary : AppColors.surfaceBorder,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isActive ? Colors.white : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.hind(
                    color: isActive ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final String label;
  final String emoji;
  final bool isActive;
  final VoidCallback onTap;

  const _CategoryPill({
    required this.label,
    required this.emoji,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? AppColors.primarySurface : AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? AppColors.primary : AppColors.surfaceBorder,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.hind(
                  color: isActive ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
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
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        onTap: () => context.push('/template/${template.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              if (template.imageThumbUrl != null && template.imageThumbUrl!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: template.imageThumbUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: AppColors.shimmer),
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.primarySurface,
                    child: Center(
                      child: Text(template.category?.emoji ?? '✨', style: const TextStyle(fontSize: 36)),
                    ),
                  ),
                )
              else
                Container(
                  color: AppColors.primarySurface,
                  child: Center(
                    child: Text(template.category?.emoji ?? '✨', style: const TextStyle(fontSize: 36)),
                  ),
                ),

              // Gradient Overlay at bottom for readable text
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 70,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
              ),

              // Video Badge
              if (template.type == 'VIDEO')
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow, color: Colors.white, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          'VIDEO',
                          style: GoogleFonts.hind(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),

              // Premium Crown Badge
              if (template.isPremium == true)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.workspace_premium, color: Colors.white, size: 13),
                        const SizedBox(width: 2),
                        Text(
                          'PRO',
                          style: GoogleFonts.hind(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),

              // Template Title
              Positioned(
                bottom: 8,
                left: 10,
                right: 10,
                child: Text(
                  template.nameHi ?? template.nameEn ?? 'स्टेटस पोस्टर',
                  style: GoogleFonts.hind(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
