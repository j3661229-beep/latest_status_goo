// lib/features/templates/presentation/widgets/template_composition.dart
//
// Shared status composition (template artwork + user's photo/name placed in the
// creator-defined zones). Used by both the Home feed and the preview screen so
// what users see in the feed matches what they export.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/models/branding_frame.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/color_utils.dart';
import '../../domain/models/template_model.dart';
import 'branding_frame_overlay.dart';

/// Export aspect ratio (matches AppConstants.frameWidth x frameHeight).
const double kStatusAspectRatio = 9 / 16;

class TemplateComposition extends StatelessWidget {
  final TemplateModel template;
  final String displayName;
  final ImageProvider? userPhoto;
  final String? customQuote;
  final BrandingFrameData? brandingFrame;

  /// Shows "add name / add photo" affordances when values are missing.
  final bool editable;
  final VoidCallback? onPhotoTap;
  final VoidCallback? onNameTap;

  /// Optional big title at the top (Home feed style).
  final String? headerTitle;
  final bool showVideoBadge;

  /// Editor toggles: hide the name / photo zones entirely.
  final bool showName;
  final bool showPhoto;
  final double borderRadius;
  final List<BoxShadow>? boxShadow;

  const TemplateComposition({
    super.key,
    required this.template,
    required this.displayName,
    this.userPhoto,
    this.customQuote,
    this.brandingFrame,
    this.editable = false,
    this.onPhotoTap,
    this.onNameTap,
    this.headerTitle,
    this.showVideoBadge = false,
    this.showName = true,
    this.showPhoto = true,
    this.borderRadius = AppRadius.lg,
    this.boxShadow,
  });

  // Sensible fallbacks when the creator didn't define zones.
  static const double _defaultPhotoX = 0.5;
  static const double _defaultPhotoY = 0.7;
  static const double _defaultPhotoSize = 0.22;
  static const double _defaultNameX = 0.5;
  static const double _defaultNameY = 0.82;

  @override
  Widget build(BuildContext context) {
    final imageUrl = template.displayImageUrl;
    final hasImage = imageUrl != null;

    List<Color> gradientColors = [AppColors.primary, AppColors.primaryLight];
    if (template.gradient != null && template.gradient!.isNotEmpty) {
      gradientColors = ColorUtils.parseGradientString(template.gradient);
    } else if (template.category?.gradient != null) {
      gradientColors = ColorUtils.parseGradientString(template.category!.gradient);
    }
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: gradientColors.length >= 2 ? gradientColors : [gradientColors.first, gradientColors.first],
    );

    final quote = customQuote ?? (!hasImage ? template.quoteHi : null);
    final title = headerTitle;

    return AspectRatio(
      aspectRatio: kStatusAspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          final pSize = (template.photoZoneSize ?? _defaultPhotoSize) * w;
          final pLeft = ((template.photoZoneX ?? _defaultPhotoX) * w) - (pSize / 2);
          final pTop = ((template.photoZoneY ?? _defaultPhotoY) * h) - (pSize / 2);
          final nLeft = (template.nameZoneX ?? _defaultNameX) * w;
          final nTop = (template.nameZoneY ?? _defaultNameY) * h;
          final isRect = template.photoZoneShape == 'rectangle';

          return Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: hasImage ? null : gradient,
              boxShadow: boxShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Artwork
                if (hasImage)
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => DecoratedBox(
                      decoration: BoxDecoration(gradient: gradient),
                      child: const Center(
                        child: CircularProgressIndicator(color: AppColors.onDarkMuted, strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) => DecoratedBox(
                      decoration: BoxDecoration(gradient: gradient),
                      child: const Icon(Icons.image_not_supported_rounded, color: AppColors.onDarkMuted, size: 48),
                    ),
                  ),

                // 2. Optional header title (with contrast vignette)
                if (title != null && title.isNotEmpty) ...[
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.ink.withValues(alpha: 0.45), AppColors.transparent],
                          stops: const [0.0, 0.25],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: h * 0.03,
                    left: 12,
                    right: 12,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.hind(
                        color: AppColors.saffron,
                        fontSize: (w * 0.085).clamp(18.0, 32.0),
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(color: AppColors.ink.withValues(alpha: 0.8), offset: const Offset(1, 2), blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                ],

                // 3. Quote (only without artwork, or when the user picked one)
                if (quote != null && quote.isNotEmpty)
                  Positioned(
                    left: 20,
                    right: 20,
                    top: h * 0.28,
                    child: Text(
                      quote,
                      style: GoogleFonts.hind(
                        color: AppColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                        shadows: const [Shadow(blurRadius: 8, color: AppColors.ink)],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // 4. Creator-defined photo zone
                if (showPhoto && template.photoZoneEnabled && (userPhoto != null || editable))
                  Positioned(
                    top: pTop,
                    left: pLeft,
                    width: pSize,
                    height: pSize,
                    child: GestureDetector(
                      onTap: onPhotoTap,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.scrim,
                          shape: isRect ? BoxShape.rectangle : BoxShape.circle,
                          borderRadius: isRect ? BorderRadius.circular(AppRadius.md) : null,
                          border: Border.all(color: AppColors.white, width: 2),
                          boxShadow: const [BoxShadow(color: AppColors.scrim, blurRadius: 6)],
                          image: userPhoto != null
                              ? DecorationImage(image: userPhoto!, fit: BoxFit.cover, onError: (_, __) {})
                              : null,
                        ),
                        child: userPhoto == null
                            ? const Center(child: Icon(Icons.add_a_photo_rounded, size: 24, color: AppColors.white))
                            : null,
                      ),
                    ),
                  ),

                // 5. Creator-defined name zone
                if (showName && template.nameZoneEnabled && (displayName.isNotEmpty || editable))
                  Positioned(
                    top: nTop,
                    left: nLeft,
                    child: FractionalTranslation(
                      translation: const Offset(-0.5, 0),
                      child: GestureDetector(
                        onTap: onNameTap,
                        child: Container(
                          constraints: BoxConstraints(maxWidth: w * 0.9),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: displayName.isEmpty ? AppColors.scrim : AppColors.transparent,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: displayName.isEmpty ? Border.all(color: AppColors.onDarkMuted) : null,
                          ),
                          child: Text(
                            displayName.isNotEmpty ? displayName : 'नाम जोड़ें ✏️',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.hind(
                              color: template.nameColor != null ? ColorUtils.fromHex(template.nameColor!) : AppColors.white,
                              fontSize: (template.nameFontSize?.toDouble() ?? 16.0).clamp(12.0, 24.0),
                              fontWeight: FontWeight.w700,
                              shadows: const [Shadow(blurRadius: 6, color: AppColors.ink)],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),

                // 6. Video badge
                if (showVideoBadge && template.isVideo)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.ink.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.white, width: 2),
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: AppColors.white, size: 36),
                    ),
                  ),

                // 7. Branding frame
                if (brandingFrame != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: BrandingFrameOverlay(data: brandingFrame!),
                  ),

                // 8. Locked premium template
                if (template.isLocked) const TemplateLockOverlay(),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Dark scrim + lock badge for premium templates the user can't use.
class TemplateLockOverlay extends StatelessWidget {
  final bool compact;
  const TemplateLockOverlay({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'प्रीमियम स्टेटस — अनलॉक करने के लिए प्रीमियम लें',
      child: Container(
        color: AppColors.scrim,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(compact ? 8 : 14),
              decoration: const BoxDecoration(
                gradient: AppColors.premiumGradient,
                shape: BoxShape.circle,
                boxShadow: AppShadows.premiumGlow,
              ),
              child: Icon(Icons.lock_rounded, color: AppColors.ink, size: compact ? 18 : 30),
            ),
            if (!compact) ...[
              const SizedBox(height: 10),
              Text(
                'प्रीमियम स्टेटस',
                style: AppText.body(color: AppColors.white, size: 16, weight: FontWeight.w800),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
