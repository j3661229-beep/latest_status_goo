// lib/features/home/presentation/widgets/daily_suvichar_banner.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/data/daily_suvichar_data.dart';
import '../../../auth/presentation/providers/current_user_provider.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              'सुविचार कॉपी हो गया!',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A2E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final slot = DailySuvicharData.getCurrentSlot();
    final quotes = DailySuvicharData.getForCurrentTime();
    final suvichar = quotes[_currentIndex % quotes.length];
    final title = DailySuvicharData.getSlotTitle(slot);
    final gradient = suvichar.gradientColors;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background subtle pattern watermark
          Positioned(
            right: -15,
            bottom: -20,
            child: Text(
              suvichar.emoji,
              style: TextStyle(
                fontSize: 100,
                color: Colors.white.withOpacity(0.12),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Slot Header + Shuffle Button ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(suvichar.emoji, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            title,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Next / Shuffle quote
                    InkWell(
                      onTap: () => _nextQuote(quotes.length),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.refresh_rounded, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'अगला (${(_currentIndex % quotes.length) + 1}/${quotes.length})',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ── Suvichar Quote Text ──
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _showEn && suvichar.textEn != null
                        ? '"${suvichar.textEn}"'
                        : '"${suvichar.textHi}"',
                    key: ValueKey('${suvichar.id}_$_showEn'),
                    style: GoogleFonts.rozhaOne(
                      fontSize: 18,
                      color: Colors.white,
                      height: 1.45,
                      letterSpacing: 0.2,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.4),
                          offset: const Offset(0, 1),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Author & Lang Toggle
                Row(
                  children: [
                    Text(
                      '— ${suvichar.author}',
                      style: GoogleFonts.outfit(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (suvichar.textEn != null)
                      GestureDetector(
                        onTap: () => setState(() => _showEn = !_showEn),
                        child: Text(
                          _showEn ? '🇮🇳 हिंदी में पढ़ें' : '🌐 Read in English',
                          style: GoogleFonts.outfit(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Action Buttons Row ──
                Row(
                  children: [
                    // 1-Tap WhatsApp Share
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: () => _shareOnWhatsApp(suvichar, user?.name ?? user?.displayName),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 3,
                        ),
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: Text(
                          'WhatsApp शेयर',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Copy Button
                    IconButton(
                      onPressed: () => _copyToClipboard(suvichar),
                      tooltip: 'कॉपी करें',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        padding: const EdgeInsets.all(10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 19),
                    ),

                    const SizedBox(width: 8),

                    // Create Status Poster Button
                    Expanded(
                      flex: 3,
                      child: OutlinedButton.icon(
                        onPressed: widget.onCustomizePoster,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white, width: 1.5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.palette_rounded, size: 17),
                        label: Text(
                          'पोस्टर बनाएं',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
