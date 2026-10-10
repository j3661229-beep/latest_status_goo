// lib/core/theme/app_ui_components.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme.dart';
import '../../features/templates/domain/models/template_model.dart';
import '../../features/templates/presentation/widgets/template_composition.dart' show TemplateLockOverlay;

// ─── Section Header ───────────────────────────────────────────────────────────

class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;
  final String seeAllText;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onSeeAll,
    this.seeAllText = 'सभी देखें',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.hind(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: GoogleFonts.hind(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onSeeAll != null)
            InkWell(
              onTap: onSeeAll,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      seeAllText,
                      style: GoogleFonts.hind(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AppColors.primary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Visual-First Template Card ───────────────────────────────────────────────

class AppTemplateCard extends StatelessWidget {
  final TemplateModel template;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  final Widget? actionOverlay;

  const AppTemplateCard({
    super.key,
    required this.template,
    this.width,
    this.height,
    this.onTap,
    this.actionOverlay,
  });

  @override
  Widget build(BuildContext context) {
    final imgUrl = template.imageThumbUrl ?? template.imageUrl ?? template.videoThumbUrl;
    final name = template.nameHi ?? template.nameEn ?? '';
    final isPremium = template.isPremium == true;
    final isLocked = template.isLocked;

    return GestureDetector(
      // Locked premium templates lead to the upgrade screen.
      onTap: onTap ?? () => context.push(isLocked ? '/premium' : '/template/${template.id}'),
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Artwork Container (Image is Hero)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.surfaceBorder, width: 0.8),
                  boxShadow: AppShadows.subtle,
                  color: AppColors.surfaceMuted,
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imgUrl != null && imgUrl.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: imgUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: AppColors.shimmer),
                        errorWidget: (_, __, ___) => _FallbackGradient(template),
                      )
                    else
                      _FallbackGradient(template),

                    // Subtle Dark Scrim on Bottom of image for contrast
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 40,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Color(0x3D000000), Colors.transparent],
                          ),
                        ),
                      ),
                    ),

                    // Subtle Premium Indicator
                    if (isPremium)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 12, color: Color(0xFFFBBF24)),
                              const SizedBox(width: 3),
                              Text(
                                'प्रीमियम',
                                style: GoogleFonts.hind(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (isLocked) const TemplateLockOverlay(compact: true),

                    // Top Right Action Overlay (e.g. remove bookmark)
                    if (actionOverlay != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: actionOverlay!,
                      ),
                  ],
                ),
              ),
            ),

            // Minimal Metadata (Clean, compact caption)
            if (name.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.hind(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FallbackGradient extends StatelessWidget {
  final TemplateModel template;
  const _FallbackGradient(this.template);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.parseGradient(template.gradient);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors ?? [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        template.nameHi?.isNotEmpty == true ? template.nameHi!.substring(0, 1) : '🙏',
        style: const TextStyle(fontSize: 32),
      ),
    );
  }
}

// ─── Search Bar Trigger (Home Header) ─────────────────────────────────────────

class AppSearchBarTrigger extends StatelessWidget {
  final VoidCallback onTap;
  final String hintText;

  const AppSearchBarTrigger({
    super.key,
    required this.onTap,
    this.hintText = 'सुप्रभात, महाकाल, त्योहार स्टेटस खोजें...',
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.surfaceBorder, width: 0.8),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hintText,
                style: GoogleFonts.hind(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textHint,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── WhatsApp Action Button ───────────────────────────────────────────────────

class AppWhatsAppButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  const AppWhatsAppButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.label = 'व्हाट्सएप स्टेटस लगाएं',
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.whatsapp,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.share_rounded, size: 20, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.hind(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
    );
  }
}

// ─── Infinite Scroll Footer ───────────────────────────────────────────────────

class PagingFooter extends StatelessWidget {
  final bool isLoading;
  final bool hasError;
  final VoidCallback onRetry;

  const PagingFooter({
    super.key,
    required this.isLoading,
    required this.hasError,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
          ),
        ),
      );
    }
    if (hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              'और स्टेटस लोड नहीं हो सके — पुनः प्रयास करें',
              style: GoogleFonts.hind(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );
    }
    return const SizedBox(height: AppSpacing.lg);
  }
}
