// lib/features/templates/presentation/screens/template_preview_screen.dart
//
// Immersive status editor (/template/:id): large rounded canvas over a dark
// gradient, a control dock (name / photo / frame / quotes) and a sticky
// WhatsApp-share CTA row.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/auth/session_store.dart';
import '../../../../core/models/branding_frame.dart';
import '../../../../core/services/status_export_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/profile_photo.dart';
import '../../../auth/presentation/providers/current_user_provider.dart';
import '../../../user/data/saved_templates.dart';
import '../../data/template_repository.dart';
import '../../domain/models/template_model.dart';
import '../providers/template_list_provider.dart';
import '../widgets/editor_sheet_frame.dart';
import '../widgets/frame_picker_sheet.dart';
import '../widgets/quote_picker_sheet.dart';
import '../widgets/template_composition.dart';

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
  bool _showName = true;
  bool _showPhoto = true;

  /// Photo picked inside the editor (this session only; the profile photo is
  /// left untouched).
  ImageProvider? _photoOverride;

  bool _isTogglingSave = false;
  bool _isSharing = false;
  bool _isSavingGallery = false;

  /// While true, edit affordances (placeholders), rounded corners and the drop
  /// shadow are hidden so they don't end up in the exported image.
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

  // ─── Sheets ────────────────────────────────────────────────────────────────

  Future<void> _showSheet(WidgetBuilder builder) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: builder,
    );
  }

  void _showFramePickerSheet() {
    _initBrandingFrame();
    _showSheet(
      (context) => FramePickerSheet(
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
    _showSheet(
      (context) => QuotePickerSheet(
        selectedQuote: _customQuote,
        onClear: () => setState(() => _customQuote = null),
        onSelectQuote: (quote) => setState(() => _customQuote = quote),
      ),
    );
  }

  void _showEditNameSheet() {
    _showSheet(
      (context) => _EditNameSheet(
        initialName: _displayName,
        initialShow: _showName,
        onSave: (name, show) {
          setState(() {
            _displayName = name;
            _showName = show;
          });
        },
      ),
    );
  }

  void _showPhotoSheet() {
    _showSheet(
      (context) => _PhotoSheet(
        initialShow: _showPhoto,
        initialPhoto: _photoOverride,
        profilePhoto: currentUserPhotoProvider(serverPhoto: ref.read(currentUserProvider)?.profilePhoto),
        onChanged: (show, photo) {
          setState(() {
            _showPhoto = show;
            _photoOverride = photo;
          });
        },
      ),
    );
  }

  // ─── Export ────────────────────────────────────────────────────────────────

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
    HapticFeedback.mediumImpact();
    setState(() => _isSharing = true);

    try {
      final pngBytes = await _captureClean();
      if (pngBytes == null) throw const ApiException('इमेज कैप्चर नहीं हो सकी');

      final platform = await StatusExportService.sharePng(pngBytes, text: 'Status Go ऐप से साझा किया गया 📲');
      if (platform != null) {
        final repo = ref.read(templateRepositoryProvider);
        repo.recordShare(widget.templateId, platform);
        repo.recordUse(widget.templateId);
        if (mounted) AppSnack.success(context, 'स्टेटस शेयर हो गया 🎉');
      }
    } catch (e) {
      if (mounted) AppSnack.error(context, 'शेयर करने में समस्या: ${apiErrorMessage(e)}');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _saveToGallery() async {
    if (_isSavingGallery) return;
    HapticFeedback.lightImpact();
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
    if (!SessionStore.instance.isLoggedIn) {
      if (mounted) {
        AppSnack.info(context, 'स्टेटस सेव करने के लिए कृपया लॉगिन करें');
        context.push('/login');
      }
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _isTogglingSave = true);
    try {
      // Optimistic update with rollback inside the notifier.
      final nowSaved = await ref.read(savedIdsProvider.notifier).toggle(widget.templateId);
      if (mounted) {
        if (nowSaved) {
          AppSnack.success(context, 'स्टेटस सेव हो गया 🔖');
        } else {
          AppSnack.info(context, 'स्टेटस सेव से हटा दिया गया');
        }
      }
    } catch (e) {
      debugPrint('TemplatePreviewScreen _toggleSaved error: $e');
      if (mounted) {
        AppSnack.error(context, apiErrorMessage(e, fallback: 'सेव नहीं हो सका। कृपया दोबारा कोशिश करें।'));
      }
    } finally {
      if (mounted) setState(() => _isTogglingSave = false);
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final templateAsync = ref.watch(singleTemplateProvider(widget.templateId));
    final currentUser = ref.watch(currentUserProvider);
    final isSaved = ref.watch(savedIdsProvider).contains(widget.templateId);

    if (_displayName.isEmpty) {
      _displayName = SessionStore.instance.displayName ?? currentUser?.name ?? '';
    }
    final userPhoto = _photoOverride ?? currentUserPhotoProvider(serverPhoto: currentUser?.profilePhoto);
    final hasTemplate = templateAsync.valueOrNull != null;

    return GradientScaffold(
      extendBodyBehindAppBar: false,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              isSaved: isSaved,
              showActions: hasTemplate,
              savingBusy: _isTogglingSave,
              onBack: () => context.canPop() ? context.pop() : context.go('/home'),
              onToggleSaved: _toggleSaved,
              onShareMore: _shareImage,
              onDownload: _saveToGallery,
            ),
            Expanded(
              child: templateAsync.when(
                loading: () => const _CanvasSkeleton(),
                error: (err, _) => ErrorState(
                  title: 'स्टेटस लोड नहीं हो सका',
                  message: apiErrorMessage(err, fallback: 'कृपया इंटरनेट जांचें और दोबारा कोशिश करें।'),
                  onRetry: () => ref.invalidate(singleTemplateProvider(widget.templateId)),
                ),
                data: (template) {
                  if (template == null) {
                    return EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'स्टेटस नहीं मिला',
                      message: 'यह स्टेटस अब उपलब्ध नहीं है।',
                      actionLabel: 'वापस जाएं',
                      onAction: () => context.canPop() ? context.pop() : context.go('/home'),
                    );
                  }
                  return _buildEditor(template, userPhoto);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor(TemplateModel template, ImageProvider? userPhoto) {
    final locked = template.isLocked;
    return Column(
      children: [
        // 1. Canvas
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xs),
            child: Center(
              child: FadeSlideIn(
                dy: 12,
                child: GestureDetector(
                  onTap: locked ? () => context.push('/premium') : null,
                  child: RepaintBoundary(
                    key: _repaintBoundaryKey,
                    child: TemplateComposition(
                      template: template,
                      displayName: _displayName,
                      userPhoto: userPhoto,
                      customQuote: _customQuote,
                      brandingFrame: _brandingFrame,
                      playVideo: !_exporting,
                      showName: _showName,
                      showPhoto: _showPhoto,
                      editable: !_exporting && !locked,
                      onPhotoTap: locked ? null : _showPhotoSheet,
                      onNameTap: locked ? null : _showEditNameSheet,
                      borderRadius: _exporting ? 0 : AppRadius.lg,
                      boxShadow: _exporting
                          ? null
                          : [
                              BoxShadow(
                                color: AppColors.ink.withValues(alpha: 0.6),
                                blurRadius: 28,
                                offset: const Offset(0, 12),
                              ),
                            ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // 2. Dock
        _Dock(
          locked: locked,
          child: locked ? _buildLockedActions() : _buildEditActions(),
        ),
      ],
    );
  }

  Widget _buildEditActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _DockTool(
                icon: Icons.badge_outlined,
                label: 'नाम',
                active: _showName,
                onTap: _showEditNameSheet,
              ),
            ),
            Expanded(
              child: _DockTool(
                icon: Icons.account_circle_outlined,
                label: 'फोटो',
                active: _showPhoto,
                onTap: _showPhotoSheet,
              ),
            ),
            Expanded(
              child: _DockTool(
                icon: Icons.filter_frames_outlined,
                label: 'फ्रेम',
                active: _brandingFrame != null,
                onTap: _showFramePickerSheet,
              ),
            ),
            Expanded(
              child: _DockTool(
                icon: Icons.format_quote_rounded,
                label: 'कोट्स',
                active: _customQuote != null,
                onTap: _showQuotePickerSheet,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: GradientButton(
                label: 'WhatsApp स्टेटस पर शेयर करें',
                icon: Icons.share_rounded,
                variant: GradientButtonVariant.whatsapp,
                isLoading: _isSharing,
                onPressed: _isSharing ? null : _shareImage,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _SquareAction(
              icon: Icons.download_rounded,
              semanticLabel: 'गैलरी में डाउनलोड करें',
              busy: _isSavingGallery,
              onTap: _isSavingGallery ? null : _saveToGallery,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLockedActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.premiumGradient),
              child: const Icon(Icons.workspace_premium_rounded, color: AppColors.ink, size: 24),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'यह प्रीमियम स्टेटस है। इसे इस्तेमाल करने के लिए प्रीमियम सदस्यता लें।',
                style: AppText.body(size: 15.5, weight: FontWeight.w600, color: AppColors.onDark, height: 1.35),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        GradientButton(
          label: 'Premium लें',
          icon: Icons.lock_open_rounded,
          variant: GradientButtonVariant.premium,
          onPressed: () => context.push('/premium'),
        ),
      ],
    );
  }
}

// ─── Top bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final bool isSaved;
  final bool showActions;
  final bool savingBusy;
  final VoidCallback onBack;
  final VoidCallback onToggleSaved;
  final VoidCallback onShareMore;
  final VoidCallback onDownload;

  const _TopBar({
    required this.isSaved,
    required this.showActions,
    required this.savingBusy,
    required this.onBack,
    required this.onToggleSaved,
    required this.onShareMore,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.xxs, AppSpacing.xs, 0),
      child: Row(
        children: [
          AppIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            iconSize: 20,
            glass: true,
            semanticLabel: 'वापस जाएं',
            onPressed: onBack,
          ),
          Expanded(
            child: Text(
              'स्टेटस तैयार करें',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.heading(size: 18, color: AppColors.onDark),
            ),
          ),
          if (showActions) ...[
            AppIconButton(
              icon: isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              glass: true,
              color: isSaved ? AppColors.gold : AppColors.white,
              semanticLabel: isSaved ? 'सेव से हटाएं' : 'सेव करें',
              onPressed: savingBusy ? null : onToggleSaved,
            ),
            PopupMenuButton<int>(
              tooltip: 'और विकल्प',
              icon: const Icon(Icons.more_vert_rounded, color: AppColors.white),
              iconSize: 24,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.glassStrong,
                minimumSize: const Size(44, 44),
                side: const BorderSide(color: AppColors.glassBorder),
              ),
              onSelected: (v) => v == 0 ? onShareMore() : onDownload(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 0, height: 48, child: Text('दूसरे ऐप्स में शेयर करें')),
                PopupMenuItem(value: 1, height: 48, child: Text('गैलरी में डाउनलोड करें')),
              ],
            ),
          ] else
            const SizedBox(width: AppSpacing.minTouch),
        ],
      ),
    );
  }
}

// ─── Dock ─────────────────────────────────────────────────────────────────────

class _Dock extends StatelessWidget {
  final Widget child;
  final bool locked;
  const _Dock({required this.child, required this.locked});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        border: Border(top: BorderSide(color: locked ? AppColors.gold : p.border)),
        boxShadow: AppShadows.bottomDock,
      ),
      child: child,
    );
  }
}

class _DockTool extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _DockTool({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PressableScale(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      semanticLabel: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: AppMotion.fast,
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: active ? AppColors.brandGradient : null,
                color: active ? null : p.surfaceMuted,
                border: active ? null : Border.all(color: p.border),
              ),
              child: Icon(icon, size: 24, color: active ? AppColors.white : p.textSecondary),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: AppText.body(size: 13.5, weight: FontWeight.w700, color: p.textPrimary, height: 1.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SquareAction extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final bool busy;
  final VoidCallback? onTap;

  const _SquareAction({required this.icon, required this.semanticLabel, required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PressableScale(
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: p.surfaceMuted,
          shape: BoxShape.circle,
          border: Border.all(color: p.border),
        ),
        child: busy
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2.6),
              )
            : Icon(icon, color: p.textPrimary, size: 26),
      ),
    );
  }
}

// ─── Loading skeleton ─────────────────────────────────────────────────────────

class _CanvasSkeleton extends StatelessWidget {
  const _CanvasSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.xl),
      child: Center(
        child: AspectRatio(
          aspectRatio: kStatusAspectRatio,
          child: const ShimmerBox(radius: AppRadius.lg),
        ),
      ),
    );
  }
}

// ─── Edit name sheet ──────────────────────────────────────────────────────────

class _EditNameSheet extends StatefulWidget {
  final String initialName;
  final bool initialShow;
  final void Function(String name, bool show) onSave;

  const _EditNameSheet({required this.initialName, required this.initialShow, required this.onSave});

  @override
  State<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends State<_EditNameSheet> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialName);
  late bool _show = widget.initialShow;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    widget.onSave(_controller.text.trim(), _show);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return EditorSheetFrame(
      title: 'स्टेटस पर दिखने वाला नाम',
      footer: GradientButton(label: 'सेव करें', icon: Icons.check_rounded, onPressed: _save),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LabeledSwitchTile(
            icon: Icons.visibility_outlined,
            title: 'नाम दिखाएं',
            subtitle: 'बंद करने पर स्टेटस पर नाम नहीं दिखेगा',
            value: _show,
            onChanged: (v) => setState(() => _show = v),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _controller,
            label: 'आपका नाम',
            hint: 'उदा. राजेश शर्मा',
            prefixIcon: Icons.person_outline_rounded,
            autofocus: true,
            enabled: _show,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
    );
  }
}

// ─── Photo sheet ──────────────────────────────────────────────────────────────

class _PhotoSheet extends StatefulWidget {
  final bool initialShow;
  final ImageProvider? initialPhoto;
  final ImageProvider? profilePhoto;
  final void Function(bool show, ImageProvider? photoOverride) onChanged;

  const _PhotoSheet({
    required this.initialShow,
    required this.initialPhoto,
    required this.profilePhoto,
    required this.onChanged,
  });

  @override
  State<_PhotoSheet> createState() => _PhotoSheetState();
}

class _PhotoSheetState extends State<_PhotoSheet> {
  late bool _show = widget.initialShow;
  late ImageProvider? _override = widget.initialPhoto;

  Future<void> _pick() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() {
      _override = FileImage(File(picked.path));
      _show = true;
    });
    widget.onChanged(_show, _override);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final preview = _override ?? widget.profilePhoto;
    return EditorSheetFrame(
      title: 'आपकी फोटो',
      subtitle: 'स्टेटस पर लगने वाली फोटो चुनें',
      footer: GradientButton(
        label: 'हो गया',
        icon: Icons.check_rounded,
        onPressed: () => Navigator.of(context).pop(),
      ),
      child: Column(
        children: [
          AppAvatar(image: preview, radius: 48, ring: true),
          const SizedBox(height: AppSpacing.md),
          LabeledSwitchTile(
            icon: Icons.visibility_outlined,
            title: 'फोटो दिखाएं',
            value: _show,
            onChanged: (v) {
              setState(() => _show = v);
              widget.onChanged(_show, _override);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: 'गैलरी से फोटो चुनें',
            icon: Icons.photo_library_outlined,
            onPressed: _pick,
          ),
          if (_override != null) ...[
            const SizedBox(height: AppSpacing.xs),
            TextButton.icon(
              onPressed: () {
                setState(() => _override = null);
                widget.onChanged(_show, null);
              },
              icon: Icon(Icons.restart_alt_rounded, color: p.textSecondary),
              label: const Text('प्रोफ़ाइल फोटो इस्तेमाल करें'),
            ),
          ],
        ],
      ),
    );
  }
}
