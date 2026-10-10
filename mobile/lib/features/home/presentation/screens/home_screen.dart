// lib/features/home/presentation/screens/home_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/auth/session_store.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/data/notification_repository.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/status_export_service.dart';
import '../../../../core/widgets/profile_photo.dart';
import '../../../auth/presentation/providers/current_user_provider.dart';
import '../../../templates/data/template_repository.dart';
import '../../../templates/domain/models/template_model.dart';
import '../../../templates/presentation/widgets/template_composition.dart';
import '../providers/home_data_provider.dart';

// ─── Main Home Screen (Pure Real-Data Crafto Feed) ─────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedCategory = 'all';
  int _currentIndex = 0;
  late final PageController _pageController;

  bool _isSharing = false;
  bool _isDownloading = false;

  final GlobalKey _cardRepaintKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Every login flow ends on Home: deliver a deep link buffered from a
    // cold-start notification tap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.flushPendingDeepLink();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String get _userName => SessionStore.instance.displayName ?? '';

  ImageProvider? get _userPhoto => currentUserPhotoProvider();

  // ─── Navigation ────────────────────────────────────────────────────────────

  void _openTemplate(TemplateModel template) {
    context.push(template.isLocked ? '/premium' : '/template/${template.id}');
  }

  // ─── WhatsApp / System Share ───────────────────────────────────────────────

  Future<void> _handleShare(TemplateModel template) async {
    if (template.isLocked) return _openTemplate(template);
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final bytes = await StatusExportService.capture(_cardRepaintKey);
      if (bytes == null) throw const ApiException('इमेज कैप्चर नहीं हो सकी');

      final platform = await StatusExportService.sharePng(bytes, text: 'Status Go ऐप से भेजा गया 📲');
      if (platform != null) {
        final repo = ref.read(templateRepositoryProvider);
        repo.recordShare(template.id, platform);
        repo.recordUse(template.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('शेयर करने में समस्या: ${apiErrorMessage(e)}', style: GoogleFonts.hind()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  // ─── Save To Phone Gallery ─────────────────────────────────────────────────

  Future<void> _handleDownload(TemplateModel template) async {
    if (template.isLocked) return _openTemplate(template);
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      final bytes = await StatusExportService.capture(_cardRepaintKey);
      final result = bytes == null ? GallerySaveResult.failed : await StatusExportService.saveToGallery(bytes);
      if (result == GallerySaveResult.saved) {
        ref.read(templateRepositoryProvider).recordUse(template.id);
      }
      if (mounted) StatusExportService.showSaveResult(context, result);
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  // ─── Bottom Sheet: Change Photo & Name ────────────────────────────────────

  void _showChangePhotoDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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

    return list.where((t) {
      final tagMatch = t.tags.any((tag) => tag.toLowerCase() == _selectedCategory.toLowerCase());
      final catMatch = t.category?.slug.toLowerCase() == _selectedCategory.toLowerCase();
      final nameMatch = (t.nameHi ?? '').toLowerCase().contains(_selectedCategory.toLowerCase());
      return tagMatch || catMatch || nameMatch;
    }).toList();
  }

  Future<void> _refresh() => ref.read(homeDataProvider.notifier).refresh();

  // ─── Build UI ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(homeDataProvider);
    // Rebuild when the session (name / photo / user) changes.
    ref.watch(sessionStoreProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        bottom: false,
        child: feedAsync.when(
          skipLoadingOnRefresh: true,
          loading: () => Column(
            children: [
              _buildTopHeader(),
              const Expanded(child: _LoadingState()),
            ],
          ),
          error: (err, _) => Column(
            children: [
              _buildTopHeader(),
              Expanded(
                child: _EmptyState(
                  message: 'डेटाबेस से कनेक्ट नहीं हो सका\n${apiErrorMessage(err, fallback: '')}'.trim(),
                  onRefresh: _refresh,
                ),
              ),
            ],
          ),
          data: (data) {
            // ONLY real templates from database
            final realTemplates = [
              ...data.featured,
              ...data.trending,
              ...data.coordinatorPicks,
            ];

            // Remove any duplicates by id
            final seen = <String>{};
            final uniqueTemplates = realTemplates.where((t) => seen.add(t.id)).toList();
            final filtered = _filterTemplates(uniqueTemplates);
            final safeIndex = filtered.isEmpty ? 0 : _currentIndex.clamp(0, filtered.length - 1);
            final activeTemplate = filtered.isEmpty ? null : filtered[safeIndex];

            return Column(
              children: [
                // 1. Top Header
                _buildTopHeader(),

                // 2. Dynamic Categories from DB (All + DB categories)
                _buildCategoryBar(data.categories),

                // 3. Status Viewport Feed (or Empty State if DB has 0 templates)
                Expanded(
                  child: uniqueTemplates.isEmpty
                      ? _EmptyState(
                          message: 'डेटाबेस में अभी कोई स्टेटस नहीं है\nक्रिएटर स्टूडियो से स्टेटस अपलोड करें',
                          onRefresh: _refresh,
                        )
                      : (filtered.isEmpty
                          ? Center(
                              child: Text(
                                'इस श्रेणी में कोई स्टेटस नहीं मिला',
                                style: GoogleFonts.hind(fontSize: 15, color: Colors.grey.shade600),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _refresh,
                              child: PageView.builder(
                                controller: _pageController,
                                scrollDirection: Axis.vertical,
                                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                itemCount: filtered.length,
                                onPageChanged: (i) => setState(() => _currentIndex = i),
                                itemBuilder: (ctx, i) {
                                  final template = filtered[i];
                                  final isCurrent = i == safeIndex;
                                  final card = _buildCardContent(template);

                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                                      child: GestureDetector(
                                        onTap: () => _openTemplate(template),
                                        child: isCurrent
                                            ? RepaintBoundary(key: _cardRepaintKey, child: card)
                                            : card,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )),
                ),

                // 4. Sticky Bottom Action Controls
                _buildBottomActionBar(activeTemplate),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── 1. Top Header ──────────────────────────────────────────────────────────

  Widget _buildTopHeader() {
    final unread = ref.watch(unreadNotificationsCountProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF8B5CF6), // Purple
            Color(0xFFC084FC), // Lavender
            Color(0xFFEC4899), // Pink
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          // Logo pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  AppConstants.appName,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),

          // Search
          _HeaderIconButton(
            icon: Icons.search_rounded,
            tooltip: 'खोजें (Search)',
            onTap: () => context.push('/search'),
          ),
          const SizedBox(width: 8),

          // Notifications
          _HeaderIconButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'सूचनाएं (Notifications)',
            badgeCount: unread,
            onTap: () => context.push('/notifications'),
          ),
          const SizedBox(width: 10),

          // User Profile Avatar on Right
          Semantics(
            button: true,
            label: 'अपनी फोटो और नाम बदलें',
            child: GestureDetector(
              onTap: _showChangePhotoDialog,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: ProfilePhotoAvatar(
                  radius: 19,
                  backgroundColor: const Color(0xFF5B4296),
                  image: _userPhoto,
                  fallback: const Icon(Icons.person_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Category Filter Bar (from DB) ───────────────────────────────────────

  Widget _buildCategoryBar(List<CategoryModel> dbCategories) {
    // Combine 'All' + real categories from DB
    final chips = <Map<String, String>>[
      {'slug': 'all', 'label': 'All', 'emoji': ''},
      ...dbCategories.map((c) => {
            'slug': c.slug,
            'label': (c.nameHi != null && c.nameHi!.isNotEmpty)
                ? c.nameHi!
                : (c.nameEn ?? c.slug),
            'emoji': c.emoji ?? '',
          }),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: chips.map((cat) {
            final isSelected = _selectedCategory == cat['slug'];
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = cat['slug']!;
                  _currentIndex = 0;
                });
                if (_pageController.hasClients) {
                  _pageController.jumpToPage(0);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF3B0764) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF3B0764) : const Color(0xFFE5E7EB),
                    width: 1.2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF3B0764).withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if ((cat['emoji'] ?? '').isNotEmpty) ...[
                      Text(cat['emoji']!, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      cat['label'] ?? '',
                      style: GoogleFonts.hind(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── 3. Real Status Card (shared composition with the preview screen) ──────

  Widget _buildCardContent(TemplateModel template) {
    final title = template.nameHi ?? template.category?.nameHi ?? '';

    return TemplateComposition(
      template: template,
      displayName: _userName,
      userPhoto: _userPhoto,
      headerTitle: title,
      showVideoBadge: true,
      borderRadius: 18,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.12),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  // ── 4. Bottom Sticky Action Controls ───────────────────────────────────────

  Widget _buildBottomActionBar(TemplateModel? active) {
    final hasActiveCard = active != null;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Share Button
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: (hasActiveCard && !_isSharing) ? () => _handleShare(active) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      disabledBackgroundColor: Colors.grey.shade300,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                              const Icon(Icons.chat_bubble_rounded, size: 20, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Share',
                                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Download Button
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: (hasActiveCard && !_isDownloading) ? () => _handleDownload(active) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5B4296),
                      disabledBackgroundColor: Colors.grey.shade300,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: _isDownloading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.download_rounded, size: 22, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Download',
                                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Change Your Photo Button
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: _showChangePhotoDialog,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF5B4296), width: 1.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      backgroundColor: Colors.white,
                    ),
                    child: Text(
                      'Change Your Photo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF5B4296),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Customize → template editor
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: hasActiveCard ? () => _openTemplate(active) : null,
                  icon: Icon(active?.isLocked == true ? Icons.lock_rounded : Icons.edit_rounded, size: 18),
                  label: Text(
                    'Edit',
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF5B4296),
                    side: const BorderSide(color: Color(0xFF5B4296), width: 1.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Header Icon Button ───────────────────────────────────────────────────────

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badgeCount;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withOpacity(0.22),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Badge(
              isLabelVisible: badgeCount > 0,
              label: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
              offset: const Offset(4, -4),
              alignment: Alignment.topRight,
              child: Center(child: Icon(icon, color: Colors.white, size: 22)),
            ),
          ),
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    final ImageProvider? preview =
        _pickedPhotoPath != null ? FileImage(File(_pickedPhotoPath!)) : widget.initialPhoto;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'अपनी फोटो और नाम बदलें',
            style: GoogleFonts.hind(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            button: true,
            label: 'फोटो बदलें',
            child: GestureDetector(
              onTap: _pick,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  ProfilePhotoAvatar(
                    radius: 46,
                    backgroundColor: const Color(0xFFE9D5FF),
                    image: preview,
                    fallback: const Icon(Icons.person_rounded, size: 52, color: Color(0xFF5B4296)),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF5B4296),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'फोटो बदलने के लिए टैप करें',
            style: GoogleFonts.hind(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            style: GoogleFonts.hind(fontSize: 16, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'आपका नाम (Your Name)',
              hintText: 'अपना नाम यहाँ दर्ज करें',
              labelStyle: GoogleFonts.hind(color: const Color(0xFF5B4296)),
              prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFF5B4296)),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF5B4296), width: 1.8),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                await widget.onSave(_nameCtrl.text.trim(), _pickedPhotoPath ?? widget.initialPhotoPath);
                navigator.pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B4296),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                elevation: 0,
              ),
              child: Text(
                'सुरक्षित करें (Save)',
                style: GoogleFonts.hind(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Loading & Empty State Components ─────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Color(0xFF8B5CF6)),
          const SizedBox(height: 14),
          Text(
            'डेटाबेस से स्टेटस लोड हो रहे हैं...',
            style: GoogleFonts.hind(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final VoidCallback onRefresh;
  const _EmptyState({required this.message, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                size: 54,
                color: Color(0xFF5B4296),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.hind(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF374151),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('रिफ्रेश करें (Refresh)', style: GoogleFonts.hind(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B4296),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
