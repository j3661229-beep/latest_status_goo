// lib/features/home/presentation/screens/home_screen.dart
//
// Immersive, Crafto-style Home feed: full-screen vertical pager of templates
// composed with the user's name + photo, overlay header / category pills,
// a right-side action rail and a caption block.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/auth/session_store.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/data/notification_repository.dart';
import '../../../../core/router/app_shell.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/status_export_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/profile_photo.dart';
import '../../../auth/presentation/providers/current_user_provider.dart';
import '../../data/home_repository.dart';
import '../../../templates/data/template_repository.dart';
import '../../../templates/domain/models/template_model.dart';
import '../../../templates/presentation/widgets/editor_sheet_frame.dart';
import '../../../templates/presentation/widgets/template_composition.dart';
import '../../../user/data/saved_templates.dart';
import '../providers/home_data_provider.dart';
import '../widgets/home_feed_widgets.dart';

const String _kSwipeHintSeenKey = 'home_swipe_hint_seen';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedCategory = 'all';
  late final PageController _pageController;
  final ValueNotifier<int> _pageIndex = ValueNotifier<int>(0);

  // Busy flags live in notifiers so toggling them doesn't rebuild the pager.
  final ValueNotifier<bool> _sharing = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _downloading = ValueNotifier<bool>(false);

  // One stable capture key per template (no subtree remount on page change).
  final Map<String, GlobalKey> _cardKeys = <String, GlobalKey>{};

  bool _showHint = false;
  bool _refreshing = false;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(_syncPageIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppShell.immersive.value = true;
      // Every login flow ends on Home: deliver a deep link buffered from a
      // cold-start notification tap.
      NotificationService.instance.flushPendingDeepLink();
      ref.read(savedIdsProvider.notifier).ensureSynced();
      _maybeShowHint();
    });
  }

  @override
  void dispose() {
    AppShell.immersive.value = false;
    _hintTimer?.cancel();
    _pageController.removeListener(_syncPageIndex);
    _pageController.dispose();
    _pageIndex.dispose();
    _sharing.dispose();
    _downloading.dispose();
    super.dispose();
  }

  // ─── First-launch swipe hint ───────────────────────────────────────────────

  void _maybeShowHint() {
    final box = Hive.box(AppConstants.hiveBoxSettings);
    if (box.get(_kSwipeHintSeenKey) == true) return;
    setState(() => _showHint = true);
    _hintTimer = Timer(const Duration(seconds: 6), _dismissHint);
  }

  void _dismissHint() {
    _hintTimer?.cancel();
    if (!_showHint) return;
    Hive.box(AppConstants.hiveBoxSettings).put(_kSwipeHintSeenKey, true);
    if (mounted) setState(() => _showHint = false);
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  String get _userName => SessionStore.instance.displayName ?? '';
  ImageProvider? get _userPhoto => currentUserPhotoProvider();

  GlobalKey _keyFor(String id) => _cardKeys.putIfAbsent(id, GlobalKey.new);

  void _syncPageIndex() {
    if (!_pageController.hasClients || !_pageController.position.haveDimensions) return;
    final page = _pageController.page;
    if (page == null) return;
    final i = page.round();
    if (_pageIndex.value != i) _pageIndex.value = i;
  }

  String get _lang => (SessionStore.instance.language ?? 'HINDI').toUpperCase();

  String _greeting() {
    final name = _userName.trim();
    final hello = switch (_lang) {
      'ENGLISH' || 'EN' => 'Hello',
      'MARATHI' || 'MR' => 'नमस्कार',
      _ => 'नमस्ते',
    };
    return name.isEmpty ? '$hello 🙏' : '$hello, $name 🙏';
  }

  static const _monthsHi = [
    'जनवरी', 'फ़रवरी', 'मार्च', 'अप्रैल', 'मई', 'जून', 'जुलाई', 'अगस्त', 'सितंबर', 'अक्टूबर', 'नवंबर', 'दिसंबर'
  ];
  static const _monthsEn = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  Widget _infoChip(Map<String, dynamic>? festival) {
    if (festival != null) {
      String? name;
      for (final k in const ['nameHi', 'name_hi', 'nameEn', 'name_en', 'name', 'title']) {
        final v = festival[k];
        if (v is String && v.trim().isNotEmpty) {
          name = v.trim();
          break;
        }
      }
      if (name != null) {
        return HomeInfoChip(label: name, icon: Icons.celebration_rounded, festival: true);
      }
    }
    final now = DateTime.now();
    final english = _lang == 'ENGLISH' || _lang == 'EN';
    final month = (english ? _monthsEn : _monthsHi)[now.month - 1];
    return HomeInfoChip(
      label: english ? 'Today • ${now.day} $month' : 'आज • ${now.day} $month',
      icon: Icons.calendar_today_rounded,
    );
  }

  // ─── Navigation ────────────────────────────────────────────────────────────

  void _openTemplate(TemplateModel template) {
    context.push(template.isLocked ? '/premium' : '/template/${template.id}');
  }

  // ─── WhatsApp / System Share ───────────────────────────────────────────────

  Future<void> _handleShare(TemplateModel template) async {
    if (template.isLocked) return _openTemplate(template);
    if (_sharing.value) return;
    HapticFeedback.mediumImpact();
    _sharing.value = true;

    try {
      final bytes = await StatusExportService.capture(_keyFor(template.id));
      if (bytes == null) throw const ApiException('इमेज कैप्चर नहीं हो सकी');

      final platform = await StatusExportService.sharePng(bytes, text: 'Status Go ऐप से भेजा गया 📲');
      if (platform != null) {
        final repo = ref.read(templateRepositoryProvider);
        repo.recordShare(template.id, platform);
        repo.recordUse(template.id);
        if (mounted) AppSnack.success(context, 'स्टेटस शेयर हो गया 🎉');
      }
    } catch (e) {
      if (mounted) AppSnack.error(context, 'शेयर करने में समस्या: ${apiErrorMessage(e)}');
    } finally {
      _sharing.value = false;
    }
  }

  // ─── Save To Phone Gallery ─────────────────────────────────────────────────

  Future<void> _handleDownload(TemplateModel template) async {
    if (template.isLocked) return _openTemplate(template);
    if (_downloading.value) return;
    HapticFeedback.lightImpact();
    _downloading.value = true;

    try {
      final bytes = await StatusExportService.capture(_keyFor(template.id));
      final result = bytes == null ? GallerySaveResult.failed : await StatusExportService.saveToGallery(bytes);
      if (result == GallerySaveResult.saved) {
        ref.read(templateRepositoryProvider).recordUse(template.id);
      }
      if (mounted) StatusExportService.showSaveResult(context, result);
    } finally {
      _downloading.value = false;
    }
  }

  // ─── Bookmark (optimistic toggle lives in savedIdsProvider) ────────────────

  Future<void> _toggleSaved(TemplateModel template) async {
    HapticFeedback.selectionClick();
    try {
      final nowSaved = await ref.read(savedIdsProvider.notifier).toggle(template.id);
      if (!mounted) return;
      if (nowSaved) {
        AppSnack.success(context, 'स्टेटस सेव हो गया');
      } else {
        AppSnack.info(context, 'स्टेटस सेव से हटा दिया गया');
      }
    } catch (e) {
      if (mounted) {
        AppSnack.error(context, apiErrorMessage(e, fallback: 'सेव नहीं हो सका। कृपया दोबारा कोशिश करें।'));
      }
    }
  }

  // ─── Sheet: Change Photo & Name ────────────────────────────────────────────

  void _showChangePhotoDialog() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (ctx) => _ChangePhotoSheet(
        initialName: _userName,
        initialPhotoPath: SessionStore.instance.localPhotoPath,
        initialPhoto: _userPhoto,
        onSave: (name, photoPath) async {
          final session = SessionStore.instance;
          if (name.isNotEmpty) await session.setDisplayName(name);
          if (photoPath != null) await session.setLocalPhotoPath(photoPath);
          if (mounted) setState(() {});
        },
      ),
    );
  }

  // ─── Filter Templates ──────────────────────────────────────────────────────

  List<TemplateModel> _filterTemplates(List<TemplateModel> list) {
    if (_selectedCategory == 'all') return list;
    final sel = _selectedCategory.toLowerCase();

    return list.where((t) {
      final tagMatch = t.tags.any((tag) => tag.toLowerCase() == sel);
      final catMatch = t.category?.slug.toLowerCase() == sel;
      final nameMatch = (t.nameHi ?? '').toLowerCase().contains(sel);
      return tagMatch || catMatch || nameMatch;
    }).toList();
  }

  void _selectCategory(String slug) {
    setState(() => _selectedCategory = slug);
    _pageIndex.value = 0;
    if (_pageController.hasClients) _pageController.jumpToPage(0);
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await ref.read(homeDataProvider.notifier).refresh();
    } finally {
      _refreshing = false;
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(homeDataProvider);
    // Rebuild when the session (name / photo / user) changes.
    ref.watch(sessionStoreProvider);
    final unread = ref.watch(unreadNotificationsCountProvider);
    final topInset = HomeChrome.topInset(context);
    final data = feedAsync.valueOrNull;

    return ImmersiveTheme(
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.inkGradient),
        child: Stack(
          children: [
            // Feed / states
            Positioned.fill(
              child: feedAsync.when(
                skipLoadingOnRefresh: true,
                loading: () => const HomeFeedSkeleton(),
                error: (err, _) => Padding(
                  padding: EdgeInsets.only(top: topInset),
                  child: ErrorState(
                    title: 'टेम्पलेट लोड नहीं हो सके',
                    message: apiErrorMessage(err, fallback: 'कृपया इंटरनेट जांचें और दोबारा कोशिश करें।'),
                    onRetry: _refresh,
                  ),
                ),
                data: (feed) => _buildFeed(feed, topInset),
              ),
            ),

            // Top scrim + header + category pills
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: DecoratedBox(
                decoration: const BoxDecoration(gradient: AppColors.scrimTop),
                child: Padding(
                  padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HomeHeader(
                        greeting: _greeting(),
                        chip: _infoChip(data?.festivalToday),
                        photo: _userPhoto,
                        name: _userName,
                        unread: unread,
                        onAvatarTap: _showChangePhotoDialog,
                        onSearch: () => context.push('/search'),
                        onNotifications: () => context.push('/notifications'),
                      ),
                      if (data != null)
                        HomeCategoryPills(
                          categories: [
                            const HomeCategory('all', 'सभी'),
                            ...data.categories.map(
                              (c) => HomeCategory(
                                c.slug,
                                (c.nameHi != null && c.nameHi!.isNotEmpty) ? c.nameHi! : (c.nameEn ?? c.slug),
                                c.emoji ?? '',
                              ),
                            ),
                          ],
                          selectedSlug: _selectedCategory,
                          onSelected: (c) => _selectCategory(c.slug),
                        )
                      else
                        const SizedBox(height: HomeChrome.pillsHeight),
                    ],
                  ),
                ),
              ),
            ),

            // First-launch swipe hint
            if (_showHint)
              Positioned(
                left: 0,
                right: 72,
                bottom: 130,
                child: Center(child: SwipeUpHint(key: const ValueKey('swipe-hint'))),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeed(HomeFeedData feed, double topInset) {
    final all = [...feed.featured, ...feed.trending, ...feed.coordinatorPicks];
    final seen = <String>{};
    final unique = all.where((t) => seen.add(t.id)).toList();
    final filtered = _filterTemplates(unique);

    if (unique.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: topInset),
        child: EmptyState(
          icon: Icons.photo_library_outlined,
          title: 'कोई टेम्पलेट नहीं मिला',
          message: 'थोड़ी देर बाद दोबारा कोशिश करें।',
          actionLabel: 'फिर से कोशिश करें',
          onAction: _refresh,
        ),
      );
    }
    if (filtered.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: topInset),
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'कोई टेम्पलेट नहीं मिला',
          message: 'इस श्रेणी में अभी कोई स्टेटस नहीं है।',
          actionLabel: 'सभी देखें',
          onAction: () => _selectCategory('all'),
          compact: true,
        ),
      );
    }

    // Do not wrap PageView in RefreshIndicator and do not Transform.scale
    // pages during swipe — both produce invalid SliverGeometry (layoutExtent
    // > paintExtent) and the Media3 crash cascade seen on device.
    return NotificationListener<OverscrollNotification>(
      onNotification: (n) {
        if (_pageIndex.value == 0 && n.overscroll < -24 && n.metrics.axis == Axis.vertical) {
          _refresh();
        }
        return false;
      },
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
        allowImplicitScrolling: false,
        itemCount: filtered.length,
        onPageChanged: (i) {
          _pageIndex.value = i;
          HapticFeedback.selectionClick();
          if (_showHint) _dismissHint();
        },
        itemBuilder: (ctx, i) {
          final template = filtered[i];
          return ValueListenableBuilder<int>(
            valueListenable: _pageIndex,
            builder: (context, current, _) {
              return _FeedPage(
                key: ValueKey(template.id),
                template: template,
                topInset: topInset,
                displayName: _userName,
                userPhoto: _userPhoto,
                captureKey: _keyFor(template.id),
                sharing: _sharing,
                downloading: _downloading,
                playVideo: i == current,
                onOpen: () => _openTemplate(template),
                onShare: () => _handleShare(template),
                onDownload: () => _handleDownload(template),
                onSave: () => _toggleSaved(template),
              );
            },
          );
        },
      ),
    );
  }
}

// ─── One feed page ────────────────────────────────────────────────────────────

class _FeedPage extends ConsumerWidget {
  final TemplateModel template;
  final double topInset;
  final String displayName;
  final ImageProvider? userPhoto;
  final GlobalKey captureKey;
  final ValueNotifier<bool> sharing;
  final ValueNotifier<bool> downloading;
  final bool playVideo;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onDownload;
  final VoidCallback onSave;

  const _FeedPage({
    super.key,
    required this.template,
    required this.topInset,
    required this.displayName,
    required this.userPhoto,
    required this.captureKey,
    required this.sharing,
    required this.downloading,
    required this.playVideo,
    required this.onOpen,
    required this.onShare,
    required this.onDownload,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = template.isLocked;
    final shareCount = template.shareCount ?? 0;
    final saveCount = template.saveCount ?? 0;

    // The shell does not extend the body behind the floating nav bar, so only a
    // small breathing gap is needed here (nav height: AppShell.navHeight).
    return Padding(
      padding: EdgeInsets.only(top: topInset, bottom: AppSpacing.xs),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Card
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 14, right: 4),
                    child: Center(
                      child: GestureDetector(
                        onTap: onOpen,
                        child: Stack(
                          children: [
                            RepaintBoundary(
                              key: captureKey,
                              child: TemplateComposition(
                                template: template,
                                displayName: displayName,
                                userPhoto: userPhoto,
                                showVideoBadge: true,
                                playVideo: playVideo,
                                borderRadius: AppRadius.lg,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.ink.withValues(alpha: 0.5),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                            ),
                            if (locked)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 16,
                                child: Center(child: UnlockPill(onTap: onOpen)),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Action rail
                SizedBox(
                  width: 72,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ValueListenableBuilder<bool>(
                            valueListenable: sharing,
                            builder: (_, busy, __) => RailButton(
                              icon: Icons.share_rounded,
                              label: 'शेयर',
                              count: shareCount > 0 ? formatCount(shareCount) : null,
                              size: 64,
                              busy: busy,
                              gradient: AppColors.whatsappGradient,
                              shadows: AppShadows.whatsappGlow,
                              onTap: onShare,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ValueListenableBuilder<bool>(
                            valueListenable: downloading,
                            builder: (_, busy, __) => RailButton(
                              icon: Icons.download_rounded,
                              label: 'डाउनलोड',
                              busy: busy,
                              onTap: onDownload,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _SaveRailButton(
                            templateId: template.id,
                            count: saveCount,
                            onTap: onSave,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          RailButton(
                            icon: locked ? Icons.lock_rounded : Icons.edit_rounded,
                            label: 'एडिट',
                            iconColor: locked ? AppColors.gold : null,
                            onTap: onOpen,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Caption
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, 72, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FeedCaption(template: template),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bookmark button — rebuilds only when this template's saved state changes.
class _SaveRailButton extends ConsumerWidget {
  final String templateId;
  final int count;
  final VoidCallback onTap;

  const _SaveRailButton({required this.templateId, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedIdsProvider.select((s) => s.contains(templateId)));
    return RailButton(
      icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
      label: saved ? 'सेव्ड' : 'सेव',
      count: count > 0 ? formatCount(count) : null,
      iconColor: saved ? AppColors.gold : null,
      onTap: onTap,
    );
  }
}

// ─── Change Photo & Name Sheet (owns & disposes its controller) ───────────────

class _ChangePhotoSheet extends StatefulWidget {
  final String initialName;
  final String? initialPhotoPath;
  final ImageProvider? initialPhoto;
  final Future<void> Function(String name, String? photoPath) onSave;

  const _ChangePhotoSheet({
    required this.initialName,
    required this.initialPhotoPath,
    required this.initialPhoto,
    required this.onSave,
  });

  @override
  State<_ChangePhotoSheet> createState() => _ChangePhotoSheetState();
}

class _ChangePhotoSheetState extends State<_ChangePhotoSheet> {
  late final TextEditingController _nameCtrl = TextEditingController(text: widget.initialName);
  String? _pickedPhotoPath;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() => _pickedPhotoPath = picked.path);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    try {
      await widget.onSave(_nameCtrl.text.trim(), _pickedPhotoPath ?? widget.initialPhotoPath);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        navigator.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ImageProvider? preview =
        _pickedPhotoPath != null ? FileImage(File(_pickedPhotoPath!)) : widget.initialPhoto;

    return EditorSheetFrame(
      title: 'अपनी फोटो और नाम बदलें',
      subtitle: 'यही नाम और फोटो हर स्टेटस पर लगेगी',
      footer: GradientButton(
        label: 'सुरक्षित करें',
        icon: Icons.check_rounded,
        isLoading: _saving,
        onPressed: _save,
      ),
      child: Column(
        children: [
          Semantics(
            button: true,
            label: 'फोटो बदलें',
            child: GestureDetector(
              onTap: _pick,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  AppAvatar(image: preview, name: widget.initialName, radius: 48, ring: true),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.surface, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: AppColors.white, size: 18),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('फोटो बदलने के लिए टैप करें', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _nameCtrl,
            label: 'आपका नाम',
            hint: 'अपना नाम यहाँ दर्ज करें',
            prefixIcon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
    );
  }
}
