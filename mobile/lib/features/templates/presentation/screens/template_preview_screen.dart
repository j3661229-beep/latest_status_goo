// lib/features/templates/presentation/screens/template_preview_screen.dart
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/auth/session_store.dart';
import '../../../../core/services/status_export_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_ui_components.dart';
import '../../../../core/models/branding_frame.dart';
import '../../../../core/widgets/profile_photo.dart';
import '../widgets/frame_picker_sheet.dart';
import '../widgets/quote_picker_sheet.dart';
import '../widgets/template_composition.dart';
import '../../data/template_repository.dart';
import '../../domain/models/template_model.dart';
import '../providers/template_list_provider.dart';
import '../../../auth/presentation/providers/current_user_provider.dart';
import '../../../user/data/saved_templates.dart';

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
  bool _isTogglingSave = false;
  bool _isSharing = false;
  bool _isSavingGallery = false;

  /// While true, edit affordances (placeholders) are hidden so they don't end
  /// up in the exported image.
  bool _exporting = false;

  final GlobalKey _repaintBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Engagement tracking — fire-and-forget, errors ignored.
    ref.read(templateRepositoryProvider).recordView(widget.templateId);
    // Initial bookmark state: cached id set now, server copy in background.
    ref.read(savedIdsProvider.notifier).ensureSynced();
  }

  void _initBrandingFrame() {
    if (_brandingFrame != null) return;
    final user = ref.read(currentUserProvider);
    _brandingFrame = BrandingFrameData(
      name: user?.name ?? 'आपका नाम',
      // Local file or remote URL — the overlay renders either.
      photoUrl: SessionStore.instance.effectivePhoto ?? user?.profilePhoto,
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

  Future<Uint8List?> _captureClean() async {
    setState(() => _exporting = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      return await StatusExportService.capture(_repaintBoundaryKey);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _shareImage() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final pngBytes = await _captureClean();
      if (pngBytes == null) throw const ApiException('इमेज कैप्चर नहीं हो सकी');

      final platform = await StatusExportService.sharePng(pngBytes, text: 'Status Go ऐप से साझा किया गया 📲');
      if (platform != null) {
        final repo = ref.read(templateRepositoryProvider);
        repo.recordShare(widget.templateId, platform);
        repo.recordUse(widget.templateId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('शेयर करने में समस्या: ${apiErrorMessage(e)}', style: GoogleFonts.hind()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _saveToGallery() async {
    if (_isSavingGallery) return;
    setState(() => _isSavingGallery = true);

    try {
      final pngBytes = await _captureClean();
      final result =
          pngBytes == null ? GallerySaveResult.failed : await StatusExportService.saveToGallery(pngBytes);
      if (result == GallerySaveResult.saved) {
        ref.read(templateRepositoryProvider).recordUse(widget.templateId);
      }
      if (mounted) StatusExportService.showSaveResult(context, result);
    } finally {
      if (mounted) setState(() => _isSavingGallery = false);
    }
  }

  Future<void> _toggleSaved() async {
    if (_isTogglingSave) return;
    setState(() => _isTogglingSave = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Optimistic update with rollback inside the notifier.
      final nowSaved = await ref.read(savedIdsProvider.notifier).toggle(widget.templateId);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            nowSaved ? 'स्टेटस सेव हो गया' : 'स्टेटस सेव से हटा दिया गया',
            style: GoogleFonts.hind(),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(e, fallback: 'सेव नहीं हो सका। कृपया दोबारा कोशिश करें।'),
            style: GoogleFonts.hind(),
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isTogglingSave = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final templateAsync = ref.watch(singleTemplateProvider(widget.templateId));
    final currentUser = ref.watch(currentUserProvider);
    final isSaved = ref.watch(savedIdsProvider).contains(widget.templateId);
    final userPhoto = currentUserPhotoProvider(serverPhoto: currentUser?.profilePhoto);

    if (_displayName.isEmpty) {
      _displayName = SessionStore.instance.displayName ?? currentUser?.name ?? '';
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate backdrop for artwork presentation
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'स्टेटस तैयार करें',
          style: GoogleFonts.hind(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: isSaved ? AppColors.accent : Colors.white,
              size: 24,
            ),
            tooltip: isSaved ? 'सेव से हटाएं' : 'सेव करें',
            onPressed: _isTogglingSave ? null : _toggleSaved,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: templateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white70, size: 48),
              const SizedBox(height: 14),
              Text(
                'स्टेटस लोड नहीं हो सका',
                style: GoogleFonts.hind(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  apiErrorMessage(err, fallback: ''),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.hind(color: Colors.white70, fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: () => context.pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                    ),
                    child: Text('वापस जाएं (Back)', style: GoogleFonts.hind(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(singleTemplateProvider(widget.templateId)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    child: Text('पुनः प्रयास करें', style: GoogleFonts.hind(fontWeight: FontWeight.w700)),
                  ),
                ],
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

          if (template.isLocked) {
            return _LockedTemplateView(template: template);
          }

          return Column(
            children: [
              // ── 1. Hero Artwork Preview (shared composition) ────────────────
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: RepaintBoundary(
                      key: _repaintBoundaryKey,
                      child: TemplateComposition(
                        template: template,
                        displayName: _displayName,
                        userPhoto: userPhoto,
                        customQuote: _customQuote,
                        brandingFrame: _brandingFrame,
                        editable: !_exporting,
                        onPhotoTap: _showFramePickerSheet,
                        onNameTap: _showEditNameSheet,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── 2. Clean Personalization & Action Dock ─────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, 14, AppSpacing.md, AppSpacing.lg),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.xl),
                    topRight: Radius.circular(AppRadius.xl),
                  ),
                  boxShadow: AppShadows.bottomDock,
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Quick Personalize Tool Pills
                      Row(
                        children: [
                          Expanded(
                            child: _QuickToolPill(
                              icon: Icons.account_box_outlined,
                              label: 'फ़ोटो व फ़्रेम',
                              onTap: _showFramePickerSheet,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _QuickToolPill(
                              icon: Icons.edit_outlined,
                              label: 'नाम बदलें',
                              onTap: _showEditNameSheet,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _QuickToolPill(
                              icon: Icons.format_quote_outlined,
                              label: 'सुविचार बदलें',
                              onTap: _showQuotePickerSheet,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Primary Actions: WhatsApp Share + Gallery Save
                      Row(
                        children: [
                          // Gallery Save
                          Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.surfaceBorder),
                            ),
                            child: IconButton(
                              icon: _isSavingGallery
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.download_rounded, color: AppColors.textPrimary, size: 22),
                              tooltip: 'गैलरी में डाउनलोड करें',
                              onPressed: _isSavingGallery ? null : _saveToGallery,
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Primary WhatsApp Status Button (Clear Hero CTA)
                          Expanded(
                            child: AppWhatsAppButton(
                              onPressed: _isSharing ? null : _shareImage,
                              isLoading: _isSharing,
                              label: 'व्हाट्सएप पर स्टेटस लगाएं',
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

// ─── Locked Premium Template ──────────────────────────────────────────────────

class _LockedTemplateView extends StatelessWidget {
  final TemplateModel template;
  const _LockedTemplateView({required this.template});

  @override
  Widget build(BuildContext context) {
    final thumb = template.displayImageUrl;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: kStatusAspectRatio,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (thumb != null)
                        CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover)
                      else
                        const ColoredBox(color: Color(0xFF1E293B)),
                      const TemplateLockOverlay(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'यह प्रीमियम स्टेटस है। इसे इस्तेमाल करने के लिए प्रीमियम सदस्यता लें।',
            textAlign: TextAlign.center,
            style: GoogleFonts.hind(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/premium'),
              icon: const Icon(Icons.workspace_premium_rounded),
              label: Text('प्रीमियम अनलॉक करें', style: GoogleFonts.hind(fontSize: 16, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Quick Personalize Pill ───────────────────────────────────────────────────

class _QuickToolPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickToolPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.surfaceBorder, width: 0.8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.hind(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
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

// ─── Edit Name Bottom Sheet ───────────────────────────────────────────────────

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
          topLeft: Radius.circular(AppRadius.xl),
          topRight: Radius.circular(AppRadius.xl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_outlined, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                'स्टेटस पर दिखने वाला नाम',
                style: GoogleFonts.hind(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            style: GoogleFonts.hind(fontWeight: FontWeight.w600, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'उदा. राजेश शर्मा',
              filled: true,
              fillColor: AppColors.surfaceMuted,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 20),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => widget.onSave(_controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              child: Text(
                'सेव करें',
                style: GoogleFonts.hind(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
