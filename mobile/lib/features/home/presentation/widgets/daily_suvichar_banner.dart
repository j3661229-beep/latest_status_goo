// lib/features/home/presentation/widgets/daily_suvichar_banner.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/data/daily_suvichar_data.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../auth/presentation/providers/current_user_provider.dart';

/// "आज का सुविचार" gradient card with next / language / share / copy actions.
class DailySuvicharBanner extends ConsumerStatefulWidget {
  final VoidCallback? onCustomizePoster;

  const DailySuvicharBanner({
    super.key,
    this.onCustomizePoster,
  });

  @override
  ConsumerState<DailySuvicharBanner> createState() => _DailySuvicharBannerState();
}

class _DailySuvicharBannerState extends ConsumerState<DailySuvicharBanner> {
  int _currentIndex = 0;
  bool _showEn = false;

  void _nextQuote(int total) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentIndex = (_currentIndex + 1) % total;
    });
  }

  Future<void> _shareOnWhatsApp(DailySuvichar suvichar, String? userName) async {
    final signature = userName != null && userName.isNotEmpty
        ? '\n\n— सादर प्रेषक: $userName\nडाउनलोड स्टेटस गो (Status Go) 📲'
        : '\n\nडाउनलोड स्टेटस गो (Status Go) 📲';

    final shareText = '${suvichar.emoji} ${suvichar.textHi}$signature';

    final whatsappUrl = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(shareText)}');
    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl);
        return;
      }
    } catch (_) {}

    // Fallback to native share sheet
    await Share.share(shareText);
  }

  void _copyToClipboard(DailySuvichar suvichar) {
    Clipboard.setData(ClipboardData(text: '${suvichar.emoji} ${suvichar.textHi}'));
    if (!mounted) return;
    AppSnack.success(context, 'सुविचार कॉपी हो गया!');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final slot = DailySuvicharData.getCurrentSlot();
    final quotes = DailySuvicharData.getForCurrentTime();
    final suvichar = quotes[_currentIndex % quotes.length];
    final title = DailySuvicharData.getSlotTitle(slot);
    final showEn = _showEn && suvichar.textEn != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: AppRadius.xlAll,
        boxShadow: AppShadows.primaryGlow,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.xlAll,
        child: Stack(
          children: [
            Positioned(
              right: -14,
              bottom: -22,
              child: ExcludeSemantics(
                child: Text(
                  suvichar.emoji,
                  style: TextStyle(fontSize: 120, color: AppColors.white.withValues(alpha: 0.14)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.glassStrong,
                            borderRadius: AppRadius.pillAll,
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(suvichar.emoji, style: const TextStyle(fontSize: 15)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'आज का सुविचार',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.body(
                                      size: 13.5, weight: FontWeight.w800, color: AppColors.white, height: 1.2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Semantics(
                        button: true,
                        label: 'अगला सुविचार',
                        child: InkWell(
                          onTap: () => _nextQuote(quotes.length),
                          borderRadius: AppRadius.pillAll,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: AppSpacing.minTouch, minWidth: 48),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.refresh_rounded, color: AppColors.white, size: 20),
                                const SizedBox(width: 4),
                                Text(
                                  '${(_currentIndex % quotes.length) + 1}/${quotes.length}',
                                  style: AppText.body(
                                      size: 13.5, weight: FontWeight.w700, color: AppColors.white, height: 1.2),
                                ),
                                const SizedBox(width: 4),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 2),
                    child: Text(
                      title,
                      style: AppText.body(
                          size: 13, weight: FontWeight.w600, color: AppColors.white.withValues(alpha: 0.85)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AnimatedSwitcher(
                    duration: AppMotion.normal,
                    child: Text(
                      showEn ? '"${suvichar.textEn}"' : '"${suvichar.textHi}"',
                      key: ValueKey('${suvichar.id}_$_showEn'),
                      style: AppText.heading(size: 19, weight: FontWeight.w600, color: AppColors.white, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '— ${suvichar.author}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(
                              size: 13.5,
                              weight: FontWeight.w600,
                              color: AppColors.white.withValues(alpha: 0.9),
                              height: 1.3),
                        ),
                      ),
                      if (suvichar.textEn != null)
                        Flexible(
                          child: Semantics(
                          button: true,
                          label: _showEn ? 'हिंदी में पढ़ें' : 'Read in English',
                          child: InkWell(
                            onTap: () => setState(() => _showEn = !_showEn),
                            borderRadius: AppRadius.pillAll,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
                              child: Center(
                                widthFactor: 1,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    _showEn ? 'हिंदी में पढ़ें' : 'Read in English',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.body(
                                      size: 13,
                                      weight: FontWeight.w700,
                                      color: AppColors.white,
                                      height: 1.2,
                                    ).copyWith(decoration: TextDecoration.underline),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: GradientButton(
                          label: 'WhatsApp शेयर',
                          icon: Icons.share_rounded,
                          variant: GradientButtonVariant.whatsapp,
                          height: 50,
                          onPressed: () => _shareOnWhatsApp(suvichar, user?.name ?? user?.displayName),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      AppIconButton(
                        icon: Icons.copy_rounded,
                        semanticLabel: 'सुविचार कॉपी करें',
                        glass: true,
                        onPressed: () => _copyToClipboard(suvichar),
                      ),
                      if (widget.onCustomizePoster != null)
                        AppIconButton(
                          icon: Icons.palette_rounded,
                          semanticLabel: 'पोस्टर बनाएं',
                          glass: true,
                          onPressed: widget.onCustomizePoster,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
