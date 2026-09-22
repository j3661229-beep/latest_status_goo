// lib/features/templates/presentation/screens/template_preview_screen.dart
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/api/api_client.dart';
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

  // Positions (percentages 0.0 to 1.0)
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

      await Share.shareXFiles([xfile], text: 'Status Go ऐप से साझा किया गया 📲');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('शेयर करने में त्रुटि: $e', style: GoogleFonts.hind()),
            backgroundColor: AppColors.danger,
          ),
        );
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

      final result = await ImageGallerySaverPlus.saveImage(
        pngBytes,
        quality: 100,
        name: "status_go_${DateTime.now().millisecondsSinceEpoch}",
      );
      
      if (mounted) {
        final success = result['isSuccess'] ?? false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? '✅ फोटो गैलरी में सेव हो गई!' : '❌ सेव नहीं हो सकी',
              style: GoogleFonts.hind(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            backgroundColor: success ? AppColors.success : AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('त्रुटि: $e', style: GoogleFonts.hind()),
            backgroundColor: AppColors.danger,
          ),
        );
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
      backgroundColor: const Color(0xFF1E293B), // Soft Slate background for previewing canvas
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'स्टेटस तैयार करें',
          style: GoogleFonts.hind(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 19),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: _isSaved ? AppColors.accent : Colors.white,
              size: 26,
            ),
            tooltip: 'सेव करें',
            onPressed: () async {
              final newSaved = !_isSaved;
              setState(() => _isSaved = newSaved);
              final messenger = ScaffoldMessenger.of(context);
              try {
                if (newSaved) {
                  await apiClient.post('/user/saved/${widget.templateId}');
                } else {
                  await apiClient.delete('/user/saved/${widget.templateId}');
                }
              } catch (_) {}
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    newSaved ? 'स्टेटस सेव हो गया' : 'स्टेटस सेव से हटा दिया गया',
                    style: GoogleFonts.hind(),
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: templateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white70, size: 48),
              const SizedBox(height: 16),
              Text(
                'स्टेटस लोड नहीं हो सका',
                style: GoogleFonts.hind(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: Text('वापस जाएं (Back)', style: GoogleFonts.hind(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        data: (template) {
          if (template == null) {
            return Center(
              child: Text('स्टेटस नहीं मिला', style: GoogleFonts.hind(color: Colors.white, fontSize: 16)),
            );
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

          List<Color> gradientColors = [AppColors.primary, AppColors.primaryLight];
          if (template.gradient != null && template.gradient!.isNotEmpty) {
            gradientColors = ColorUtils.parseGradientString(template.gradient);
          } else if (template.category?.gradient != null) {
            gradientColors = ColorUtils.parseGradientString(template.category!.gradient);
          }

          return Column(
            children: [
              // ── Preview Canvas Area ───────────────────────────────────────
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: RepaintBoundary(
                      key: _repaintBoundaryKey,
                      child: AspectRatio(
                        aspectRatio: 9 / 16,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: gradientColors,
                            ),
                            image: template.imageUrl != null
                                ? DecorationImage(image: NetworkImage(template.imageUrl!), fit: BoxFit.cover)
                                : null,
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black45,
                                blurRadius: 16,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.hardEdge,
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
                                  left: 20,
                                  right: 20,
                                  top: screenHeight * 0.28,
                                  child: Text(
                                    _customQuote ?? template.quoteHi!,
                                    style: GoogleFonts.hind(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      height: 1.35,
                                      shadows: const [Shadow(blurRadius: 8, color: Colors.black87)],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),

                              // Draggable Profile Photo Zone
                              if (template.photoZoneEnabled)
                                Positioned(
                                  top: screenHeight * _photoTop,
                                  left: (screenWidth * _photoLeft) - 35,
                                  child: GestureDetector(
                                    onPanUpdate: (details) {
                                      setState(() {
                                        _photoTop += details.delta.dy / screenHeight;
                                        _photoLeft += details.delta.dx / screenWidth;
                                      });
                                    },
                                    child: Container(
                                      width: 70,
                                      height: 70,
                                      decoration: BoxDecoration(
                                        color: Colors.black26,
                                        shape: template.photoZoneShape == 'rectangle'
                                            ? BoxShape.rectangle
                                            : BoxShape.circle,
                                        borderRadius: template.photoZoneShape == 'rectangle'
                                            ? BorderRadius.circular(14)
                                            : null,
                                        border: Border.all(color: Colors.white, width: 2.5),
                                        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
                                        image: ref.watch(currentUserProvider)?.profilePhoto != null
                                            ? DecorationImage(
                                                image: NetworkImage(ref.watch(currentUserProvider)!.profilePhoto!),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: ref.watch(currentUserProvider)?.profilePhoto == null
                                          ? const Center(child: Icon(Icons.person, size: 36, color: Colors.white70))
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
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _displayName.isEmpty ? Colors.black54 : Colors.transparent,
                                        borderRadius: BorderRadius.circular(20),
                                        border: _displayName.isEmpty ? Border.all(color: Colors.white54) : null,
                                      ),
                                      child: Text(
                                        _displayName.isNotEmpty ? _displayName : 'अपना नाम जोड़ें ✏️',
                                        style: GoogleFonts.hind(
                                          color: template.nameColor != null
                                              ? ColorUtils.fromHex(template.nameColor!)
                                              : Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),

                              // Branding Frame Footer Overlay
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
              ),

              // ── Bottom Controls Sheet (White, Clean, High Contrast) ───────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 12,
                      offset: Offset(0, -3),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Customize Tools Row
                      Row(
                        children: [
                          Expanded(
                            child: _CustomToolTile(
                              icon: Icons.portrait,
                              label: 'फ्रेम बदलें',
                              subLabel: 'Frame',
                              onTap: _showFramePickerSheet,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _CustomToolTile(
                              icon: Icons.format_quote,
                              label: 'सुविचार',
                              subLabel: 'Quotes',
                              onTap: _showQuotePickerSheet,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _CustomToolTile(
                              icon: Icons.edit,
                              label: 'नाम बदलें',
                              subLabel: 'Edit Name',
                              onTap: _showEditNameSheet,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Action Buttons (Gallery Download + WhatsApp Status Share)
                      Row(
                        children: [
                          // Gallery Download Button
                          Expanded(
                            flex: 2,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                side: const BorderSide(color: AppColors.surfaceBorder, width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _saveToGallery,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.download, color: AppColors.textPrimary, size: 22),
                                  const SizedBox(width: 6),
                                  Text(
                                    'गैलरी में सेव',
                                    style: GoogleFonts.hind(fontWeight: FontWeight.w700, fontSize: 15),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // WhatsApp Share Button (Prominent Green)
                          Expanded(
                            flex: 3,
                            child: ElevatedButton(
                              onPressed: _isSharing ? null : _shareImage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                elevation: 1,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: _isSharing
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.chat_bubble, color: Colors.white, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          'व्हाट्सएप स्टेटस',
                                          style: GoogleFonts.hind(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _CustomToolTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subLabel;
  final VoidCallback onTap;

  const _CustomToolTile({
    required this.icon,
    required this.label,
    required this.subLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primarySurface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.hind(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
              ),
              Text(
                subLabel,
                style: GoogleFonts.hind(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
              ),
            ],
          ),
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
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                'अपना नाम लिखें (Add Name)',
                style: GoogleFonts.hind(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            style: GoogleFonts.hind(fontWeight: FontWeight.w600, fontSize: 17),
            decoration: InputDecoration(
              hintText: 'उदा. राजेश शर्मा',
              filled: true,
              fillColor: AppColors.bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.surfaceBorder),
              ),
              prefixIcon: const Icon(Icons.person, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => widget.onSave(_controller.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'सेव करें (Save)',
                style: GoogleFonts.hind(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
