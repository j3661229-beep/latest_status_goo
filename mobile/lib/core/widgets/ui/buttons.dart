// lib/core/widgets/ui/buttons.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import 'motion.dart';

enum GradientButtonVariant { primary, whatsapp, premium, festival }

/// Big pill CTA with gradient, glow, loading state and haptics.
///
/// ```dart
/// GradientButton(label: 'आगे बढ़ें', onPressed: _next)
/// GradientButton(label: 'WhatsApp पर शेयर', icon: Icons.share_rounded,
///     variant: GradientButtonVariant.whatsapp, onPressed: _share)
/// ```
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final GradientButtonVariant variant;
  final bool isLoading;
  final bool expand;
  final bool haptic;
  final double height;

  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = GradientButtonVariant.primary,
    this.isLoading = false,
    this.expand = true,
    this.haptic = true,
    this.height = 56,
  });

  LinearGradient get _gradient {
    switch (variant) {
      case GradientButtonVariant.primary:
        return AppColors.brandGradient;
      case GradientButtonVariant.whatsapp:
        return AppColors.whatsappGradient;
      case GradientButtonVariant.premium:
        return AppColors.premiumGradient;
      case GradientButtonVariant.festival:
        return AppColors.festivalGradient;
    }
  }

  List<BoxShadow> get _glow {
    switch (variant) {
      case GradientButtonVariant.primary:
        return AppShadows.primaryGlow;
      case GradientButtonVariant.whatsapp:
        return AppShadows.whatsappGlow;
      case GradientButtonVariant.premium:
        return AppShadows.premiumGlow;
      case GradientButtonVariant.festival:
        return AppShadows.festivalGlow;
    }
  }

  Color get _fg => variant == GradientButtonVariant.premium ? AppColors.ink : AppColors.white;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final p = context.palette;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.6, color: _fg),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: 22, color: enabled ? _fg : p.textHint),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(
                size: 17,
                weight: FontWeight.w700,
                color: enabled ? _fg : p.textHint,
                height: 1.2,
              ),
            ),
          ),
        ],
      ],
    );

    return PressableScale(
      onTap: enabled
          ? () {
              if (haptic) HapticFeedback.lightImpact();
              onPressed!();
            }
          : null,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        constraints: BoxConstraints(minHeight: height, minWidth: expand ? double.infinity : 0),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        decoration: BoxDecoration(
          gradient: enabled || isLoading ? _gradient : null,
          color: enabled || isLoading ? null : p.surfaceMuted,
          borderRadius: AppRadius.pillAll,
          boxShadow: enabled ? _glow : null,
        ),
        alignment: Alignment.center,
        child: content,
      ),
    );
  }
}

/// Outlined / tonal secondary pill button.
///
/// ```dart
/// SecondaryButton(label: 'बाद में', onPressed: () {})
/// SecondaryButton(label: 'हटाएं', destructive: true, icon: Icons.delete_outline, onPressed: ...)
/// ```
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool isLoading;
  final bool destructive;
  final bool tonal;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.isLoading = false,
    this.destructive = false,
    this.tonal = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = destructive ? AppColors.danger : (tonal ? p.primary : p.textPrimary);
    final enabled = onPressed != null && !isLoading;
    return PressableScale(
      onTap: enabled ? onPressed : null,
      semanticLabel: label,
      child: Container(
        constraints: BoxConstraints(minHeight: 54, minWidth: expand ? double.infinity : 0),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: tonal ? (destructive ? AppColors.dangerSurface : p.primarySurface) : AppColors.transparent,
          borderRadius: AppRadius.pillAll,
          border: tonal ? null : Border.all(color: destructive ? AppColors.danger : p.border, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: color))
            else ...[
              if (icon != null) ...[Icon(icon, size: 21, color: color), const SizedBox(width: 8)],
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(
                    size: 16.5,
                    weight: FontWeight.w700,
                    color: enabled ? color : p.textHint,
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

/// Round icon button with a guaranteed 48dp target and a mandatory semantics label.
///
/// ```dart
/// AppIconButton(icon: Icons.close_rounded, semanticLabel: 'बंद करें', onPressed: ...)
/// AppIconButton(icon: Icons.favorite, semanticLabel: 'Save', glass: true, onPressed: ...)
/// ```
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final bool glass; // translucent white (use over imagery / dark surfaces)
  final bool filled; // muted background circle
  final Color? color;
  final double size;
  final double iconSize;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.glass = false,
    this.filled = false,
    this.color,
    this.size = 48,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = color ?? (glass ? AppColors.white : p.textPrimary);
    final box = size < AppSpacing.minTouch ? AppSpacing.minTouch : size;
    return PressableScale(
      semanticLabel: semanticLabel,
      onTap: onPressed,
      scale: 0.9,
      child: SizedBox(
        width: box,
        height: box,
        child: Center(
          child: Container(
            width: size - 4,
            height: size - 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: glass ? AppColors.glassStrong : (filled ? p.surfaceMuted : null),
              border: glass ? Border.all(color: AppColors.glassBorder) : null,
            ),
            child: Icon(icon, size: iconSize, color: onPressed == null ? p.textHint : fg),
          ),
        ),
      ),
    );
  }
}
