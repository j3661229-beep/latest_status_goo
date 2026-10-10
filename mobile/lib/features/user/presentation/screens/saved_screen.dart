// lib/features/user/presentation/screens/saved_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_ui_components.dart';
import '../../data/saved_templates.dart';

export '../../data/saved_templates.dart' show savedTemplatesProvider, savedIdsProvider;

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedTemplatesProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'सहेजे गए स्टेटस',
          style: GoogleFonts.hind(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.surfaceBorder, height: 1),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22, color: AppColors.textSecondary),
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
            physics: const AlwaysScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 14,
              childAspectRatio: 0.68,
            ),
            itemCount: 4,
            itemBuilder: (_, __) => Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.lg),
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
                  const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 44),
                  const SizedBox(height: 12),
                  Text(
                    'स्टेटस लोड करने में समस्या आई',
                    style: GoogleFonts.hind(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () => ref.refresh(savedTemplatesProvider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                    ),
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
                            width: 72,
                            height: 72,
                            decoration: const BoxDecoration(
                              color: AppColors.primarySurface,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.bookmark_border_rounded,
                              size: 36,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'कोई स्टेटस सहेजा नहीं है',
                            style: GoogleFonts.hind(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'अपनी पसंद के किसी भी स्टेटस को बाद में इस्तेमाल करने के लिए सेव बटन दबाएं।',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.hind(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.explore_rounded, size: 18),
                            label: Text(
                              'स्टेटस खोजें (Explore)',
                              style: GoogleFonts.hind(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
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
              physics: const AlwaysScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 14,
                childAspectRatio: 0.68,
              ),
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final t = templates[index];
                return AppTemplateCard(
                  template: t,
                  actionOverlay: Material(
                    color: Colors.black.withOpacity(0.55),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await ref.read(savedIdsProvider.notifier).toggle(t.id);
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                apiErrorMessage(e, fallback: 'हटाया नहीं जा सका। कृपया दोबारा कोशिश करें।'),
                                style: GoogleFonts.hind(),
                              ),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(5),
                        child: Icon(Icons.close_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
