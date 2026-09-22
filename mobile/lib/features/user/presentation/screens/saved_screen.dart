// lib/features/user/presentation/screens/saved_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../templates/domain/models/template_model.dart';

final savedTemplatesProvider = FutureProvider.autoDispose<List<TemplateModel>>((ref) async {
  try {
    final res = await apiClient.get('/user/saved');
    if (res.statusCode == 200 && res.data['data'] != null) {
      return (res.data['data'] as List).map((e) => TemplateModel.fromJson(e)).toList();
    }
    return [];
  } catch (e) {
    return [];
  }
});

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedTemplatesProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          'सहेजे गए स्टेटस (Saved)',
          style: GoogleFonts.hind(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 24),
            tooltip: 'रिफ्रेश करें',
            onPressed: () => ref.refresh(savedTemplatesProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.refresh(savedTemplatesProvider),
        child: savedAsync.when(
          loading: () => GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: 4,
            itemBuilder: (_, __) => Container(
              decoration: BoxDecoration(
                color: AppColors.shimmer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
            ),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'स्टेटस लोड करने में समस्या आई',
                    style: GoogleFonts.hind(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => ref.refresh(savedTemplatesProvider),
                    child: Text('पुनः प्रयास करें', style: GoogleFonts.hind(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
          data: (templates) {
            if (templates.isEmpty) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: const BoxDecoration(
                              color: AppColors.primarySurface,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.bookmark_border_rounded,
                              size: 56,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'कोई स्टेटस सेव नहीं किया गया',
                            style: GoogleFonts.hind(
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'अपनी पसंद के किसी भी स्टेटस को बाद में इस्तेमाल करने के लिए सेव बटन दबाएं।',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.hind(
                              fontSize: 15,
                              color: AppColors.textMuted,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.explore, size: 20),
                            label: Text(
                              'स्टेटस देखें (Explore)',
                              style: GoogleFonts.hind(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(200, 48),
                            ),
                            onPressed: () => context.go('/discover'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final t = templates[index];
                return _SavedTemplateCard(
                  template: t,
                  onRemove: () async {
                    try {
                      await apiClient.delete('/user/saved/${t.id}');
                      ref.invalidate(savedTemplatesProvider);
                    } catch (_) {}
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SavedTemplateCard extends StatelessWidget {
  final TemplateModel template;
  final VoidCallback onRemove;

  const _SavedTemplateCard({required this.template, required this.onRemove});

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

              // Bottom gradient
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

              // Delete / Remove Bookmark Button
              Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: Colors.black.withOpacity(0.6),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onRemove,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.bookmark_remove, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),

              // Title
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
