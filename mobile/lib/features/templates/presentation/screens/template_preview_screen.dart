// lib/features/templates/presentation/screens/template_preview_screen.dart
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/template_repository.dart';
import '../providers/template_list_provider.dart';

class TemplatePreviewScreen extends ConsumerStatefulWidget {
  final String templateId;
  const TemplatePreviewScreen({super.key, required this.templateId});

  @override
  ConsumerState<TemplatePreviewScreen> createState() => _TemplatePreviewScreenState();
}

class _TemplatePreviewScreenState extends ConsumerState<TemplatePreviewScreen> {
  String _displayName = '';
  bool _showNameInput = false;
  bool _isSaved = false;
  bool _isSharing = false;

  // Draggable Name Position (percentages 0.0 to 1.0)
  double _nameTop = 0.77;
  double _nameLeft = 0.5;

  final GlobalKey _repaintBoundaryKey = GlobalKey();

  Future<void> _shareImage() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final boundary = _repaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception("Cannot capture image");

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final xfile = XFile.fromData(pngBytes, mimeType: 'image/png', name: 'status_go.png');
      
      // Record Engagement (fire and forget)
      ref.read(templateRepositoryProvider).recordShare(widget.templateId, 'NATIVE');

      await Share.shareXFiles([xfile], text: 'Made with Status Go! 📲');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to share: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
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

          // Parse gradient
          List<Color> gradientColors = [AppColors.primary, AppColors.secondary];
          if (template.gradient != null && template.gradient!.isNotEmpty) {
            gradientColors = ColorUtils.parseGradientString(template.gradient);
          } else if (template.category?.gradient != null) {
            gradientColors = ColorUtils.parseGradientString(template.category!.gradient);
          }

          return Stack(
            children: [
              // ── Template Frame (the part that gets exported as image) ──
              Center(
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
                          // Overlay darken to ensure text readability if there's an image
                          if (template.imageUrl != null)
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black54, Colors.transparent, Colors.black87]),
                              ),
                            ),

                          // Pre-defined Quote fallback if image doesn't have text
                          if (template.imageUrl == null && template.quoteHi != null)
                            Positioned(
                              left: 24, right: 24,
                              top: screenHeight * 0.4,
                              child: Text(
                                template.quoteHi!,
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

                          // Draggable Name Zone
                          if (template.nameZoneEnabled)
                            Positioned(
                              top: screenHeight * _nameTop,
                              left: (screenWidth * _nameLeft) - 100, // Center roughly
                              child: GestureDetector(
                                onPanUpdate: (details) {
                                  setState(() {
                                    _nameTop += details.delta.dy / screenHeight;
                                    _nameLeft += details.delta.dx / screenWidth;
                                    // Clamp within boundaries
                                    if (_nameTop < 0.1) _nameTop = 0.1;
                                    if (_nameTop > 0.9) _nameTop = 0.9;
                                    if (_nameLeft < 0.1) _nameLeft = 0.1;
                                    if (_nameLeft > 0.9) _nameLeft = 0.9;
                                  });
                                },
                                onTap: () => setState(() => _showNameInput = !_showNameInput),
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
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      shadows: [Shadow(blurRadius: 4, color: Colors.black38)],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Top Bar ─────────────────────────────────────
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
                          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                      const Spacer(),
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

              // ── Name Input Bottom Sheet ──────────────────────
              if (_showNameInput)
                Positioned(
                  left: 16, right: 16,
                  bottom: 120, // above action bar
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 10))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.edit_document, size: 18, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text('Add Your Name', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          autofocus: true,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          onChanged: (v) => setState(() => _displayName = v),
                          decoration: InputDecoration(
                            hintText: 'e.g. Ramesh Gupta',
                            filled: true,
                            fillColor: AppColors.bg,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => setState(() => _showNameInput = false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text('Save Overlay', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Bottom Action Bar ────────────────────────────
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
                  child: Row(
                    children: [
                      // Share Button
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isSharing ? null : _shareImage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 8,
                            shadowColor: AppColors.primary.withOpacity(0.5),
                          ),
                          child: _isSharing
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.share_rounded, size: 20, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text('Share Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                                ],
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Edit Name Button Toggle (replaces standard save button for more intuitive UX)
                      Expanded(
                        flex: 1,
                        child: ElevatedButton(
                          onPressed: () => setState(() => _showNameInput = !_showNameInput),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.textPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Icon(Icons.text_fields_rounded, size: 22),
                        ),
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
