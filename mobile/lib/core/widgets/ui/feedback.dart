// lib/core/widgets/ui/feedback.dart
//
// Snackbars, dialogs, empty / error states, shimmer skeletons, offline banner.
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../theme/app_theme.dart';
import 'buttons.dart';

/// Floating, rounded snackbars.
///
/// ```dart
/// AppSnack.success(context, 'सेव हो गया');
/// AppSnack.error(context, apiErrorMessage(e));
/// ```
class AppSnack {
  AppSnack._();

  static void success(BuildContext context, String message) =>
      _show(context, message, Icons.check_circle_rounded, AppColors.success);

  static void error(BuildContext context, String message) =>
      _show(context, message, Icons.error_rounded, AppColors.danger);

  static void info(BuildContext context, String message) =>
      _show(context, message, Icons.info_rounded, AppColors.primaryLight);

  static void _show(BuildContext context, String message, IconData icon, Color iconColor) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}

/// Confirmation dialog. Resolves to `true` only when confirmed.
///
/// ```dart
/// final ok = await ConfirmDialog.show(context,
///     title: 'लॉग आउट?', message: 'क्या आप लॉग आउट करना चाहते हैं?',
///     confirmLabel: 'लॉग आउट', destructive: true, icon: Icons.logout_rounded);
/// ```
class ConfirmDialog {
  ConfirmDialog._();

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'ठीक है',
    String cancelLabel = 'रद्द करें',
    bool destructive = false,
    IconData? icon,
    Widget? extra,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final p = ctx.palette;
        final tone = destructive ? AppColors.danger : p.primary;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (icon != null)
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: destructive ? AppColors.dangerSurface : p.primarySurface,
                      ),
                      child: Icon(icon, color: tone, size: 32),
                    ),
                  ),
                Text(title, textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 10),
                Text(message, textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.bodyMedium),
                if (extra != null) ...[const SizedBox(height: 12), extra],
                const SizedBox(height: 24),
                destructive
                    ? SecondaryButton(
                        label: confirmLabel,
                        destructive: true,
                        tonal: true,
                        onPressed: () => Navigator.of(ctx).pop(true),
                      )
                    : GradientButton(label: confirmLabel, onPressed: () => Navigator.of(ctx).pop(true)),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(cancelLabel),
                ),
              ],
            ),
          ),
        );
      },
    );
    return result == true;
  }
}

/// Illustrated empty state (icon on layered gradient discs) with optional CTA.
///
/// ```dart
/// EmptyState(
///   icon: Icons.bookmark_border_rounded,
///   title: 'अभी कुछ सेव नहीं है',
///   message: 'पसंदीदा स्टेटस सेव करें',
///   actionLabel: 'स्टेटस देखें',
///   onAction: () => context.go('/home'),
/// )
/// ```
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Gradient? gradient;
  final bool compact;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.gradient,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final size = compact ? 96.0 : 132.0;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size + 28,
              height: size + 28,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: size + 28,
                    height: size + 28,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: p.primarySurface),
                  ),
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: gradient ?? AppColors.brandGradient,
                      boxShadow: AppShadows.primaryGlow,
                    ),
                    child: Icon(icon, size: size * 0.46, color: AppColors.white),
                  ),
                  Positioned(
                    top: 6,
                    right: 10,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.gold),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 4,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.accent),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              GradientButton(label: actionLabel!, onPressed: onAction, expand: false),
            ],
          ],
        ),
      ),
    );
  }
}

/// Friendly error state with a retry button.
///
/// ```dart
/// ErrorState(message: apiErrorMessage(e), onRetry: () => ref.invalidate(xProvider))
/// ```
class ErrorState extends StatelessWidget {
  final String? title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;

  const ErrorState({
    super.key,
    this.title,
    this.message = 'कुछ गलत हो गया। कृपया इंटरनेट जांचें और दोबारा कोशिश करें।',
    this.onRetry,
    this.retryLabel = 'फिर से कोशिश करें',
    this.icon = Icons.wifi_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.dangerSurface),
              child: Icon(icon, size: 44, color: AppColors.danger),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title ?? 'ओह! कनेक्शन में समस्या',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              GradientButton(label: retryLabel, icon: Icons.refresh_rounded, onPressed: onRetry, expand: false),
            ],
          ],
        ),
      ),
    );
  }
}

/// Slim banner for "no internet" style notices with an optional retry.
///
/// ```dart
/// OfflineBanner(onRetry: _load)
/// ```
class OfflineBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const OfflineBanner({
    super.key,
    this.message = 'इंटरनेट नहीं है। कनेक्शन जांचें।',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: AppRadius.mdAll),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.warning, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppText.body(size: 14.5, weight: FontWeight.w600, color: AppColors.ink, height: 1.3),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: AppColors.warning),
              child: const Text('दोबारा'),
            ),
        ],
      ),
    );
  }
}

// ── Shimmer skeletons ─────────────────────────────────────────────────────────

/// Shimmering rounded rectangle.
///
/// ```dart
/// ShimmerBox(height: 120, radius: AppRadius.lg)
/// ```
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;

  const ShimmerBox({super.key, this.width, this.height, this.radius = AppRadius.md});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Shimmer.fromColors(
      baseColor: p.shimmerBase,
      highlightColor: p.shimmerHighlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: p.shimmerBase, borderRadius: BorderRadius.circular(radius)),
      ),
    );
  }
}

/// Skeleton for a 2-column template grid (non-scrolling; put inside a scroll view).
///
/// ```dart
/// const ShimmerGrid(itemCount: 6)
/// ```
class ShimmerGrid extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;
  final double aspectRatio;
  final EdgeInsetsGeometry padding;

  const ShimmerGrid({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 2,
    this.aspectRatio = 0.72,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.page),
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      itemCount: itemCount,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: aspectRatio,
      ),
      itemBuilder: (_, __) => const ShimmerBox(radius: AppRadius.lg),
    );
  }
}

/// Skeleton for a vertical list of rows.
///
/// ```dart
/// const ShimmerList(itemCount: 5)
/// ```
class ShimmerList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsetsGeometry padding;

  const ShimmerList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 76,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.page),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, __) => ShimmerBox(height: itemHeight, radius: AppRadius.md),
    );
  }
}
