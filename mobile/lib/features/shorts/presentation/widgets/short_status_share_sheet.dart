// lib/features/shorts/presentation/widgets/short_status_share_sheet.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/auth/session_store.dart';
import '../../../../core/models/branding_frame.dart';
import '../../../../core/services/status_export_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../auth/presentation/providers/current_user_provider.dart';
import '../../../templates/presentation/widgets/branding_frame_overlay.dart';
import '../../../templates/presentation/widgets/frame_picker_sheet.dart';
import '../../data/short_models.dart';

/// Shows the Branded WhatsApp Status creation sheet for any Scheme or News Short.
Future<void> showShortStatusShareSheet(BuildContext context, ShortItem item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ShortStatusShareSheet(item: item),
  );
}

class ShortStatusShareSheet extends ConsumerStatefulWidget {
  final ShortItem item;

  const ShortStatusShareSheet({super.key, required this.item});

  @override
  ConsumerState<ShortStatusShareSheet> createState() => _ShortStatusShareSheetState();
}

class _ShortStatusShareSheetState extends ConsumerState<ShortStatusShareSheet> {
  final GlobalKey _cardKey = GlobalKey();
  BrandingFrameData? _brandingFrame;
  bool _includeBranding = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initBranding();
  }

  void _initBranding() {
    final user = ref.read(currentUserProvider);
    _brandingFrame = BrandingFrameData(
      name: user?.name ?? 'आपका नाम',
      photoUrl: SessionStore.instance.effectivePhoto ?? user?.profilePhoto,
      businessName: user?.businessName,
      businessPhone: user?.phoneNumber ?? user?.businessPhone,
      businessAddress: user?.state ?? user?.businessAddress,
      businessDesignation: user?.businessDesignation,
      style: FrameStyle.fromString(user?.frameType),
    );
  }

  void _openFrameEditor() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FramePickerSheet(
        initialData: _brandingFrame!,
        onApply: (updated) {
          setState(() => _brandingFrame = updated);
        },
      ),
    );
  }

  Future<void> _shareToWhatsApp() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final bytes = await StatusExportService.capture(_cardKey);
      if (bytes == null) {
        if (mounted) AppSnack.error(context, 'स्टेटस कार्ड तैयार नहीं हो सका।');
        return;
      }

      final item = widget.item;
      final caption = [
        '📌 ${item.title}',
        if (item.summary != null) '\n${item.summary}',
        if (item.primaryLink != null) '\n🔗 आधिकारिक जानकारी: ${item.primaryLink}',
        if (_includeBranding && _brandingFrame?.businessName != null)
          '\n🏢 संपर्क: ${_brandingFrame!.businessName} (${_brandingFrame!.businessPhone ?? ''})',
        '\n✨ Status Go ऍप से बनाया गया',
      ].join('\n');

      final xfile = XFile.fromData(
        bytes,
        name: 'status_go_${item.id}.png',
        mimeType: 'image/png',
      );

      await Share.shareXFiles([xfile], text: caption, subject: item.title);
    } catch (e) {
      if (mounted) AppSnack.error(context, 'शेयर नहीं हो सका: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveToGallery() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final bytes = await StatusExportService.capture(_cardKey);
      if (bytes == null) {
        if (mounted) AppSnack.error(context, 'कार्ड कैप्चर नहीं हो सका।');
        return;
      }
      final res = await StatusExportService.saveToGallery(bytes);
      if (mounted) StatusExportService.showSaveResult(context, res);
    } catch (e) {
      if (mounted) AppSnack.error(context, 'सेव नहीं हो सका: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isScheme = item.kind == ShortKind.scheme;
    final mediaH = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: mediaH * 0.92),
      decoration: const BoxDecoration(
        color: Color(0xFF12141A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.share_rounded, color: Color(0xFF25D366), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isScheme ? 'व्हाट्सएप योजना स्टेटस बनाएं' : 'व्हाट्सएप समाचार स्टेटस बनाएं',
                          style: AppText.heading(size: 16, weight: FontWeight.w700, color: Colors.white),
                        ),
                        Text(
                          'आपके नाम व फोटो के साथ ब्रांडेड कार्ड',
                          style: AppText.body(size: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 1),

            // Card Preview Area (Scrollable)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: _buildStatusCard(item),
                  ),
                ),
              ),
            ),

            // Bottom Controls Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1D24),
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Frame Style & Toggle row
                  Row(
                    children: [
                      FilterChip(
                        selected: _includeBranding,
                        label: Text(_includeBranding ? 'ब्रांडिंग चालू' : 'बिना ब्रांडिंग'),
                        onSelected: (v) => setState(() => _includeBranding = v),
                        avatar: Icon(
                          _includeBranding ? Icons.check_circle_rounded : Icons.person_outline_rounded,
                          size: 18,
                          color: _includeBranding ? Colors.white : Colors.white60,
                        ),
                        selectedColor: AppColors.primary,
                        backgroundColor: Colors.white10,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _includeBranding ? Colors.white : Colors.white70,
                        ),
                        side: BorderSide.none,
                      ),
                      const SizedBox(width: 8),
                      if (_includeBranding)
                        OutlinedButton.icon(
                          onPressed: _openFrameEditor,
                          icon: const Icon(Icons.edit_note_rounded, size: 16),
                          label: const Text('फ़्रेम / जानकारी बदलें'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            visualDensity: VisualDensity.compact,
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Actions row
                  Row(
                    children: [
                      // Save to gallery
                      IconButton.filledTonal(
                        tooltip: 'गैलरी में सहेजें',
                        onPressed: _isProcessing ? null : _saveToGallery,
                        icon: const Icon(Icons.download_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white12,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(48, 48),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // WhatsApp Share CTA
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing ? null : _shareToWhatsApp,
                            icon: _isProcessing
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.share_rounded, size: 22, color: Colors.white),
                            label: Text(
                              _isProcessing ? 'तैयार हो रहा है...' : 'व्हाट्सएप स्टेटस लगाएं',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
      ),
    );
  }

  /// 9:16 vertical WhatsApp Status card (1080x1920 layout ratio)
  Widget _buildStatusCard(ShortItem item) {
    const cardWidth = 320.0;
    const cardHeight = cardWidth * (16 / 9); // ~568px

    final isScheme = item.kind == ShortKind.scheme;
    final sourceText = isScheme
        ? (item.scheme?.officialName ?? item.attribution ?? 'आधिकारिक सरकारी योजना')
        : (item.news?.publisher ?? item.attribution ?? 'ताज़ा मुख्य समाचार');

    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Top/Main Poster Image with Gradient
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: cardHeight * 0.42,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (item.thumbnailUrl != null)
                        CachedNetworkImage(
                          imageUrl: item.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(color: const Color(0xFF1B263B)),
                        )
                      else
                        Container(color: const Color(0xFF1B263B)),

                      // Gradient fade downwards
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.3),
                              const Color(0xFF0D1B2A),
                            ],
                            stops: const [0.4, 1.0],
                          ),
                        ),
                      ),

                      // Top Badges
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isScheme ? const Color(0xFFE65100) : const Color(0xFF0D47A1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isScheme ? '⚡ सरकारी योजना' : '📢 मुख्य समाचार',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified_rounded, color: Color(0xFF00E5FF), size: 12),
                                  SizedBox(width: 4),
                                  Text(
                                    'स्टेटस गो सत्यापित',
                                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Middle Text & Fact Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Headline
                        Text(
                          item.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Summary / Hook
                        if (item.summary != null || item.hook != null)
                          Text(
                            item.summary ?? item.hook!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),

                        const Spacer(),

                        // Official Source Line
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.source_outlined, color: Colors.white70, size: 13),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'स्रोत: $sourceText',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),

                // Bottom Branding Overlay
                if (_includeBranding && _brandingFrame != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: BrandingFrameOverlay(data: _brandingFrame!),
                  )
                else
                  const SizedBox(height: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
