// lib/features/templates/presentation/screens/template_preview_screen.dart
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../core/utils/color_utils.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/branding_frame.dart';
import '../widgets/branding_frame_overlay.dart';
import '../widgets/frame_picker_sheet.dart';
import '../widgets/quote_picker_sheet.dart';
import '../../data/template_repository.dart';
import '../providers/template_list_provider.dart';
import '../../../auth/presentation/providers/current_user_provider.dart';

class TemplatePreviewScreen extends ConsumerStatefulWidget {
  final String templateId;
  const TemplatePreviewScreen({super.key, required this.templateId});

  @override
  ConsumerState<TemplatePreviewScreen> createState() => _TemplatePreviewScreenState();
}

class _TemplatePreviewScreenState extends ConsumerState<TemplatePreviewScreen> {
  String _displayName = '';
  String? _customQuote;
  BrandingFrameData? _brandingFrame;
  bool _isSaved = false;
  bool _isSharing = false;

  // Draggable Positions (percentages 0.0 to 1.0)
  bool _positionsInitialized = false;
  double _nameTop = 0.77;
  double _nameLeft = 0.5;
  double _photoTop = 0.65;
  double _photoLeft = 0.5;

  void _initBrandingFrame() {
    if (_brandingFrame != null) return;
    final user = ref.read(currentUserProvider);
    _brandingFrame = BrandingFrameData(
      name: user?.name ?? 'आपका नाम',
      photoUrl: user?.profilePhoto,
      businessName: user?.businessName,
      businessPhone: user?.phoneNumber ?? user?.businessPhone,
      businessAddress: user?.state ?? user?.businessAddress,
      businessDesignation: user?.businessDesignation,
      style: FrameStyle.fromString(user?.frameType),
    );
  }

  void _showFramePickerSheet() {
    _initBrandingFrame();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FramePickerSheet(
        initialData: _brandingFrame!,
        onApply: (updated) {
          setState(() {
            _brandingFrame = updated;
            _displayName = updated.name;
          });
        },
      ),
    );
  }

  void _showQuotePickerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuotePickerSheet(
        onSelectQuote: (quote) {
          setState(() => _customQuote = quote);
        },
      ),
    );
  }

  final GlobalKey _repaintBoundaryKey = GlobalKey();

  Future<void> _shareImage() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final pngBytes = await _captureImage();
      if (pngBytes == null) throw Exception("Cannot capture image");

      final xfile = XFile.fromData(pngBytes, mimeType: 'image/png', name: 'status_go.png');
      
      // Record Engagement
      ref.read(templateRepositoryProvider).recordShare(widget.templateId, 'NATIVE');

      await Share.shareXFiles([xfile], text: 'साझा करें (Share with Status Go! 📲)');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to share: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<Uint8List?> _captureImage() async {
    final boundary = _repaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _saveToGallery() async {
    final status = await Permission.photos.status;
    if (status.isDenied) {
      final result = await Permission.photos.request();
      if (!result.isGranted) return;
    }

    try {
      final pngBytes = await _captureImage();
      if (pngBytes == null) return;

      final result = await ImageGallerySaverPlus.saveImage(pngBytes, quality: 100, name: "status_go_${DateTime.now().millisecondsSinceEpoch}");
      
      if (mounted) {
        final success = result['isSuccess'] ?? false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '✅ Saved to Gallery!' : '❌ Failed to save'),
            backgroundColor: success ? AppColors.success : AppColors.danger,
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showEditNameSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditNameBottomSheet(
        initialName: _displayName,
        onSave: (name) {
          setState(() => _displayName = name);
          context.pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final templateAsync = ref.watch(singleTemplateProvider(widget.templateId));
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: templateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white54, size: 48),
              const SizedBox(height: 16),
              const Text('Could not load template', style: TextStyle(color: Colors.white)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => context.pop(), child: const Text('Go Back')),
            ],
          ),
        ),
        data: (template) {
          if (template == null) {
            return const Center(child: Text('Template not found', style: TextStyle(color: Colors.white)));
          }

          if (!_positionsInitialized) {
            final currentUser = ref.read(currentUserProvider);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _nameTop = template.nameZoneY ?? 0.77;
                _nameLeft = template.nameZoneX ?? 0.5;
                _photoTop = template.photoZoneY ?? 0.65;
                _photoLeft = template.photoZoneX ?? 0.5;
                if (_displayName.isEmpty && currentUser != null) {
                  _displayName = currentUser.name ?? 'आपका नाम';
                }
                _positionsInitialized = true;
              });
            });
          }

          // Parse gradient
          List<Color> gradientColors = [AppColors.primary, AppColors.secondary];
          if (template.gradient != null && template.gradient!.isNotEmpty) {
            gradientColors = ColorUtils.parseGradientString(template.gradient);
          } else if (template.category?.gradient != null) {
            gradientColors = ColorUtils.parseGradientString(template.category!.gradient);
          }

          return Stack(
            children: [
              // ── Template Frame ───────────────────────────────────────────
              Center(
                child: ZoomIn(
                  duration: const Duration(milliseconds: 600),
                  child: RepaintBoundary(
                    key: _repaintBoundaryKey,
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: gradientColors,
                          ),
                          image: template.imageUrl != null
                              ? DecorationImage(image: NetworkImage(template.imageUrl!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: Stack(
                          children: [
                            if (template.imageUrl != null)
                              Positioned.fill(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.black54, Colors.transparent, Colors.black87],
                                    ),
                                  ),
                                ),
                              ),

                            if ((_customQuote ?? template.quoteHi) != null)
                              Positioned(
                                left: 24, right: 24,
                                top: screenHeight * 0.35,
                                child: Text(
                                  _customQuote ?? template.quoteHi!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    height: 1.4,
                                    shadows: [Shadow(blurRadius: 10, color: Colors.black54)],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                            // Draggable Profile Photo Zone
                            if (template.photoZoneEnabled)
                              Positioned(
                                top: screenHeight * _photoTop,
                                left: (screenWidth * _photoLeft) - 35, // center 70px icon
                                child: GestureDetector(
                                  onPanUpdate: (details) {
                                    setState(() {
                                      _photoTop += details.delta.dy / screenHeight;
                                      _photoLeft += details.delta.dx / screenWidth;
                                    });
                                  },
                                  child: Container(
                                    width: 70, height: 70,
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      shape: template.photoZoneShape == 'rectangle' ? BoxShape.rectangle : BoxShape.circle,
                                      borderRadius: template.photoZoneShape == 'rectangle' ? BorderRadius.circular(16) : null,
                                      border: Border.all(color: Colors.white, width: 2.5),
                                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
                                      image: ref.watch(currentUserProvider)?.profilePhoto != null
                                          ? DecorationImage(
                                              image: NetworkImage(ref.watch(currentUserProvider)!.profilePhoto!),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: ref.watch(currentUserProvider)?.profilePhoto == null
                                        ? const Center(child: Icon(Icons.person_rounded, size: 36, color: Colors.white70))
                                        : null,
                                  ),
                                ),
                              ),

                            // Draggable Name Zone
                            if (template.nameZoneEnabled)
                              Positioned(
                                top: screenHeight * _nameTop,
                                left: (screenWidth * _nameLeft) - 100,
                                child: GestureDetector(
                                  onPanUpdate: (details) {
                                    setState(() {
                                      _nameTop += details.delta.dy / screenHeight;
                                      _nameLeft += details.delta.dx / screenWidth;
                                    });
                                  },
                                  onTap: _showEditNameSheet,
                                  child: Container(
                                    width: 200,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _displayName.isEmpty ? Colors.black.withOpacity(0.5) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(24),
                                      border: _displayName.isEmpty ? Border.all(color: Colors.white38) : null,
                                    ),
                                    child: Text(
                                      _displayName.isNotEmpty ? _displayName : 'अपना नाम लिखें ✏️',
                                      style: TextStyle(
                                        color: template.nameColor != null 
                                            ? ColorUtils.fromHex(template.nameColor!) 
                                            : Colors.white,
                                        fontSize: (template.nameFontSize ?? 0.04) * screenHeight, // relative sizing like Crafto
                                        fontWeight: FontWeight.w900,
                                        shadows: const [Shadow(blurRadius: 4, color: Colors.black45)],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),

                            // Branding Frame Footer Overlay (Personal, Business, Political)
                            if (_brandingFrame != null)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: BrandingFrameOverlay(data: _brandingFrame!),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Top Bar ────────────────────────────────────────────────
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              template.nameEn ?? 'Preview',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                            Text(
                              template.category?.nameEn ?? '',
                              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _isSaved = !_isSaved),
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Icon(
                            _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            color: _isSaved ? AppColors.warning : Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Bottom Action Bar ──────────────────────────────────────────
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                    ),
                  ),
                  child: FadeInUp(
                    duration: const Duration(milliseconds: 500),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Crafto Quick Tools Row
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _MiniToolButton(
                                icon: Icons.crop_portrait_rounded,
                                label: 'फ्रेम (Frame)',
                                onTap: _showFramePickerSheet,
                              ),
                              Container(width: 1, height: 20, color: Colors.white24),
                              _MiniToolButton(
                                icon: Icons.format_quote_rounded,
                                label: 'सुविचार (Quote)',
                                onTap: _showQuotePickerSheet,
                              ),
                              Container(width: 1, height: 20, color: Colors.white24),
                              _MiniToolButton(
                                icon: Icons.edit_rounded,
                                label: 'नाम (Name)',
                                onTap: _showEditNameSheet,
                              ),
                            ],
                          ),
                        ),

                        // Action Buttons (Download & WhatsApp Status Share)
                        Row(
                          children: [
                            // Download
                            _ActionButton(
                              icon: Icons.download_rounded,
                              label: 'Download',
                              color: Colors.white.withOpacity(0.15),
                              textColor: Colors.white,
                              onTap: _saveToGallery,
                            ),
                            const SizedBox(width: 12),
                            // Share to WhatsApp (Primary)
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF25D366).withValues(alpha: 0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isSharing ? null : _shareImage,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                  child: _isSharing
                                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 22),
                                          SizedBox(width: 10),
                                          Text('WhatsApp Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                                        ],
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: textColor, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _EditNameBottomSheet extends StatefulWidget {
  final String initialName;
  final Function(String) onSave;

  const _EditNameBottomSheet({required this.initialName, required this.onSave});

  @override
  State<_EditNameBottomSheet> createState() => _EditNameBottomSheetState();
}

class _EditNameBottomSheetState extends State<_EditNameBottomSheet> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24, left: 24, right: 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('✏️', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              const Text('Add Your Name', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
              const Spacer(),
              _SuggestionChip(label: 'Personal', onTap: () {}),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            decoration: InputDecoration(
              hintText: 'Enter your name...',
              filled: true,
              fillColor: AppColors.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.person_rounded, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => widget.onSave(_controller.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: const Text('Save Overlay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
    );
  }
}

class _MiniToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MiniToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFFDE047), size: 17),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
