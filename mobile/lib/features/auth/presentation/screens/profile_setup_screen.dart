// lib/features/auth/presentation/screens/profile_setup_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/auth/session_store.dart';
import '../../../../core/data/indian_states.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../home/presentation/providers/home_data_provider.dart';
import '../../data/auth_repository.dart';
import '../providers/current_user_provider.dart';

// ─── Supported Languages ──────────────────────────────────────────────────────

class AppLanguage {
  final String code;
  final String name;
  final String english;
  final String flag;
  final String desc;
  final List<String> recommendedStates;

  const AppLanguage({
    required this.code,
    required this.name,
    required this.english,
    required this.flag,
    required this.desc,
    required this.recommendedStates,
  });
}

const List<AppLanguage> kAppLanguages = [
  AppLanguage(
    code: 'HINDI',
    name: 'हिंदी',
    english: 'Hindi',
    flag: '🇮🇳',
    desc: 'भारत की सबसे लोकप्रिय भाषा',
    recommendedStates: ['Madhya Pradesh', 'Uttar Pradesh', 'Rajasthan', 'Bihar', 'Delhi'],
  ),
  AppLanguage(
    code: 'MARATHI',
    name: 'मराठी',
    english: 'Marathi',
    flag: '🟠',
    desc: 'महाराष्ट्र व कोकण',
    recommendedStates: ['Maharashtra', 'Goa'],
  ),
  AppLanguage(
    code: 'GUJARATI',
    name: 'ગુજરાતી',
    english: 'Gujarati',
    flag: '🦁',
    desc: 'ગુજરાત અને સૌરાષ્ટ્ર',
    recommendedStates: ['Gujarat', 'Dadra & Nagar Haveli and Daman & Diu'],
  ),
  AppLanguage(
    code: 'PUNJABI',
    name: 'ਪੰਜਾਬੀ',
    english: 'Punjabi',
    flag: '🌾',
    desc: 'ਪੰਜਾਬ ਅਤੇ ਚੰਡੀਗੜ੍ਹ',
    recommendedStates: ['Punjab', 'Chandigarh', 'Haryana'],
  ),
  AppLanguage(
    code: 'ENGLISH',
    name: 'English',
    english: 'English',
    flag: '🌐',
    desc: 'Universal & Business',
    recommendedStates: ['Karnataka', 'Delhi', 'Maharashtra'],
  ),
  AppLanguage(
    code: 'TAMIL',
    name: 'தமிழ்',
    english: 'Tamil',
    flag: '🏛️',
    desc: 'தமிழ்நாடு',
    recommendedStates: ['Tamil Nadu', 'Puducherry'],
  ),
  AppLanguage(
    code: 'TELUGU',
    name: 'తెలుగు',
    english: 'Telugu',
    flag: '💎',
    desc: 'తెలంగాణ & ఆంధ్రప్రదేశ్',
    recommendedStates: ['Telangana', 'Andhra Pradesh'],
  ),
];

// ─── Setup State & Steps ──────────────────────────────────────────────────────

enum _UploadFailureChoice { retry, continueWithoutPhoto }

enum _SetupStep { language, namePhoto, state, region }

class _SetupState {
  final _SetupStep step;
  final bool loading;
  final String? error;
  final String language;
  final String name;
  final File? imageFile;
  final String? uploadedPhotoUrl;
  final IndianState? selectedState;
  final String? selectedRegion;
  final double? latitude;
  final double? longitude;

  const _SetupState({
    this.step = _SetupStep.language,
    this.loading = false,
    this.error,
    this.language = 'HINDI',
    this.name = '',
    this.imageFile,
    this.uploadedPhotoUrl,
    this.selectedState,
    this.selectedRegion,
    this.latitude,
    this.longitude,
  });

  _SetupState copyWith({
    _SetupStep? step,
    bool? loading,
    String? error,
    bool clearError = false,
    String? language,
    String? name,
    File? imageFile,
    bool clearImage = false,
    String? uploadedPhotoUrl,
    bool clearUploadedPhotoUrl = false,
    IndianState? selectedState,
    bool clearState = false,
    String? selectedRegion,
    bool clearRegion = false,
    double? latitude,
    double? longitude,
  }) =>
      _SetupState(
        step: step ?? this.step,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        language: language ?? this.language,
        name: name ?? this.name,
        imageFile: clearImage ? null : (imageFile ?? this.imageFile),
        uploadedPhotoUrl: clearUploadedPhotoUrl ? null : (uploadedPhotoUrl ?? this.uploadedPhotoUrl),
        selectedState: clearState ? null : (selectedState ?? this.selectedState),
        selectedRegion: clearRegion ? null : (selectedRegion ?? this.selectedRegion),
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
      );
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final PageController _pageController = PageController();

  var _state = const _SetupState();

  static const _titles = [
    ('अपनी भाषा चुनें', 'Select your language'),
    ('अपनी जानकारी जोड़ें', 'Name & photo'),
    ('अपना राज्य चुनें', 'Select your state'),
    ('अपना शहर / क्षेत्र चुनें', 'Select your region'),
  ];

  @override
  void initState() {
    super.initState();
    // Pre-populate existing values if any
    final session = SessionStore.instance;
    final savedLang = session.language;
    final savedName = session.displayName;
    final savedPhoto = session.localPhotoPath;

    if (savedName != null && savedName.isNotEmpty) {
      _nameController.text = savedName;
    }

    // Existing location (when re-opened from the profile screen).
    final user = ref.read(currentUserProvider);
    IndianState? existingState;
    if (user?.state != null) {
      for (final s in IndianStates.all) {
        if (s.name == user!.state) existingState = s;
      }
    }
    final existingRegion =
        existingState != null && existingState.regions.contains(user?.region) ? user!.region : null;

    _state = _state.copyWith(
      language: savedLang ?? 'HINDI',
      name: savedName ?? '',
      imageFile: (savedPhoto != null && File(savedPhoto).existsSync()) ? File(savedPhoto) : null,
      // Already uploaded photo (re-used unless the user picks a new one)
      uploadedPhotoUrl: session.profilePhotoUrl,
      selectedState: existingState,
      selectedRegion: existingRegion,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ── Photo ──────────────────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 80);
      if (picked != null && mounted) {
        setState(() => _state = _state.copyWith(
              imageFile: File(picked.path),
              clearUploadedPhotoUrl: true,
            ));
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
      if (mounted) AppSnack.error(context, 'फ़ोटो नहीं चुनी जा सकी। कृपया अनुमति जांचें।');
    }
  }

  Future<void> _showImagePickerSheet() async {
    final hasPhoto = _state.imageFile != null || _state.uploadedPhotoUrl != null;
    final choice = await AppBottomSheet.show<String>(
      context,
      title: 'प्रोफ़ाइल फ़ोटो जोड़ें',
      builder: (ctx) => SettingsSection(
        margin: EdgeInsets.zero,
        children: [
          SettingsTile(
            icon: Icons.photo_camera_rounded,
            title: 'कैमरा से फोटो लें',
            onTap: () => Navigator.of(ctx).pop('camera'),
          ),
          SettingsTile(
            icon: Icons.photo_library_rounded,
            title: 'गैलरी से चुनें',
            onTap: () => Navigator.of(ctx).pop('gallery'),
          ),
          if (hasPhoto)
            SettingsTile(
              icon: Icons.delete_outline_rounded,
              title: 'फ़ोटो हटाएं',
              destructive: true,
              showChevron: false,
              onTap: () => Navigator.of(ctx).pop('remove'),
            ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'camera':
        await _pickImage(ImageSource.camera);
      case 'gallery':
        await _pickImage(ImageSource.gallery);
      case 'remove':
        setState(() => _state = _state.copyWith(clearImage: true, clearUploadedPhotoUrl: true));
        await SessionStore.instance.setLocalPhotoPath(null);
    }
  }

  // ── Navigation between steps ───────────────────────────────────────────────

  void _animateTo(int page, {int ms = 300}) {
    FocusScope.of(context).unfocus();
    _pageController.animateToPage(page, duration: Duration(milliseconds: ms), curve: Curves.easeInOut);
  }

  /// Step 1 → 2 (Language → Name & Photo)
  void _proceedToNamePhoto(String languageCode) {
    setState(() => _state = _state.copyWith(
          language: languageCode,
          step: _SetupStep.namePhoto,
          clearError: true,
        ));
    _animateTo(1);
  }

  /// Step 2 → 3 (Name & Photo → State). Uploads the photo first.
  Future<void> _proceedToStateSelection() async {
    if (_state.loading) return;
    final name = _nameController.text.trim();
    if (name.length < 2) {
      setState(() => _state = _state.copyWith(error: 'कृपया अपना नाम दर्ज करें (कम से कम 2 अक्षर)'));
      return;
    }

    setState(() => _state = _state.copyWith(loading: true, clearError: true, name: name));

    String? photoUrl = _state.uploadedPhotoUrl;
    final imageFile = _state.imageFile;
    if (imageFile != null && photoUrl == null) {
      try {
        photoUrl = await ref.read(authRepositoryProvider).uploadProfilePhoto(imageFile.path);
      } catch (e) {
        debugPrint('Profile photo upload error: $e');
        if (!mounted) return;
        setState(() => _state = _state.copyWith(loading: false));
        final choice = await _showUploadFailedDialog(apiErrorMessage(e, fallback: 'फ़ोटो अपलोड नहीं हो सकी।'));
        if (!mounted) return;
        if (choice == _UploadFailureChoice.retry) {
          return _proceedToStateSelection();
        }
        if (choice != _UploadFailureChoice.continueWithoutPhoto) return;
        // Continue without a server photo; the picked photo is still used
        // locally on posters from this device.
        await SessionStore.instance.setLocalPhotoPath(imageFile.path);
        photoUrl = null;
      }
    }
    if (!mounted) return;

    setState(() => _state = _state.copyWith(
          loading: false,
          step: _SetupStep.state,
          uploadedPhotoUrl: photoUrl,
          clearUploadedPhotoUrl: photoUrl == null,
        ));
    _animateTo(2);
  }

  Future<_UploadFailureChoice?> _showUploadFailedDialog(String message) {
    return showDialog<_UploadFailureChoice>(
      context: context,
      builder: (ctx) {
        final p = ctx.palette;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.warningSurface),
                    child: const Icon(Icons.cloud_off_rounded, color: AppColors.warning, size: 32),
                  ),
                ),
                Text(
                  'फ़ोटो अपलोड नहीं हो सकी',
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  '$message\n\nआप दोबारा कोशिश कर सकते हैं या बिना फ़ोटो आगे बढ़ सकते हैं (फ़ोटो बाद में जोड़ सकते हैं)।',
                  textAlign: TextAlign.center,
                  style: AppText.body(size: 15, color: p.textSecondary),
                ),
                const SizedBox(height: 24),
                GradientButton(
                  label: 'दोबारा कोशिश करें',
                  icon: Icons.refresh_rounded,
                  onPressed: () => Navigator.of(ctx).pop(_UploadFailureChoice.retry),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(_UploadFailureChoice.continueWithoutPhoto),
                  child: const Text('बिना फ़ोटो आगे बढ़ें'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Selecting a state (does not advance; the Next button does).
  void _selectState(IndianState s) {
    final changed = _state.selectedState?.name != s.name;
    setState(() => _state = _state.copyWith(
          selectedState: s,
          clearRegion: changed,
          clearError: true,
        ));
  }

  /// Step 3 → 4 (State → Region)
  void _proceedToRegionSelection() {
    final s = _state.selectedState;
    if (s == null) {
      AppSnack.info(context, 'कृपया अपना राज्य चुनें');
      return;
    }
    setState(() => _state = _state.copyWith(step: _SetupStep.region, clearError: true));
    _animateTo(3);
  }

  /// Step 4 → complete setup
  Future<void> _completeSetup(String region) async {
    if (_state.loading) return;
    setState(() => _state = _state.copyWith(loading: true, selectedRegion: region, clearError: true));

    final selectedState = _state.selectedState;
    final language = _state.language;

    try {
      await ref.read(authRepositoryProvider).completeProfile(
            name: _state.name,
            // Only ever a remote URL — never a local file path.
            profilePhotoUrl: _state.uploadedPhotoUrl,
            state: selectedState?.name,
            region: region,
            language: language,
            latitude: _state.latitude,
            longitude: _state.longitude,
          );
      // State / language drive the home feed query.
      ref.invalidate(homeDataProvider);

      if (mounted) {
        AppSnack.success(context, 'स्वागत है ${_state.name}! प्रोफ़ाइल तैयार है 🎉');
        context.go('/home');
      }
    } catch (e) {
      debugPrint('Setup complete error: $e');
      if (!mounted) return;
      // Keep the entered values; let the user retry.
      setState(() => _state = _state.copyWith(loading: false));
      AppSnack.error(context, apiErrorMessage(e, fallback: 'प्रोफ़ाइल सेव नहीं हो सकी। कृपया दोबारा कोशिश करें।'));
    }
  }

  void _goBack() {
    if (_state.loading) return;
    if (_state.step == _SetupStep.region) {
      setState(() => _state = _state.copyWith(step: _SetupStep.state, clearError: true));
      _animateTo(2, ms: 250);
    } else if (_state.step == _SetupStep.state) {
      setState(() => _state = _state.copyWith(step: _SetupStep.namePhoto, clearError: true));
      _animateTo(1, ms: 250);
    } else if (_state.step == _SetupStep.namePhoto) {
      setState(() => _state = _state.copyWith(step: _SetupStep.language, clearError: true));
      _animateTo(0, ms: 250);
    } else if (SessionStore.instance.onboardingCompleted) {
      // Opened from the profile screen to edit details.
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/profile');
      }
    } else {
      // First-time setup: going back means using a different account.
      ref.read(authRepositoryProvider).signOut();
    }
  }

  void _onNext() {
    switch (_state.step) {
      case _SetupStep.language:
        _proceedToNamePhoto(_state.language);
      case _SetupStep.namePhoto:
        _proceedToStateSelection();
      case _SetupStep.state:
        _proceedToRegionSelection();
      case _SetupStep.region:
        final r = _state.selectedRegion;
        if (r == null) {
          AppSnack.info(context, 'कृपया अपना शहर / क्षेत्र चुनें');
        } else {
          _completeSetup(r);
        }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final step = _state.step;
    final progressValue = (step.index + 1) / 4.0;
    final title = _titles[step.index];
    final isLast = step == _SetupStep.region;
    final nextEnabled = switch (step) {
      _SetupStep.state => _state.selectedState != null,
      _SetupStep.region => _state.selectedRegion != null,
      _ => true,
    };

    // With the soft keyboard up on a small phone there is no room for the decorative title block and the
    // skip link — hide them so the form + primary button always fit.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return PopScope(
      canPop: step == _SetupStep.language,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              // ── Header: back, step counter, title, progress ──
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.xxs, AppSpacing.page, AppSpacing.xs),
                child: Row(
                  children: [
                    AppIconButton(
                      icon: Icons.arrow_back_rounded,
                      semanticLabel: 'वापस जाएं',
                      onPressed: _state.loading ? null : _goBack,
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Expanded(
                      child: Text(
                        'प्रोफ़ाइल बनाएं',
                        style: AppText.heading(size: 18, color: p.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: p.primarySurface, borderRadius: AppRadius.pillAll),
                      child: Text(
                        'कदम ${step.index + 1} / 4',
                        style: AppText.body(size: 13.5, weight: FontWeight.w800, color: p.primary, height: 1.2),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progressValue),
                  duration: AppMotion.slow,
                  curve: AppMotion.standard,
                  builder: (context, v, _) => ClipRRect(
                    borderRadius: AppRadius.pillAll,
                    child: LinearProgressIndicator(value: v, minHeight: 8),
                  ),
                ),
              ),
              if (!keyboardOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.xs),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedSwitcher(
                    duration: AppMotion.normal,
                    child: Column(
                      key: ValueKey(step),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title.$1, style: AppText.heading(size: 23, color: p.textPrimary)),
                        Text(title.$2, style: AppText.body(size: 14, color: p.textMuted, height: 1.3)),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Step pages ──
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _stepScroll(_buildStep1Language(p)),
                    _stepScroll(_buildStep2NamePhoto(p)),
                    _stepScroll(_buildStep3State(p)),
                    _stepScroll(_buildStep4Region(p)),
                  ],
                ),
              ),

              // ── Sticky bottom bar ──
              Container(
                decoration: BoxDecoration(
                  color: p.surface,
                  boxShadow: AppShadows.bottomDock,
                ),
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.sm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!keyboardOpen && step == _SetupStep.namePhoto && _state.imageFile == null && _state.uploadedPhotoUrl == null)
                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: _state.loading ? null : _proceedToStateSelection,
                          child: const Text('फोटो बाद में जोड़ें (Skip photo)'),
                        ),
                      ),
                    Row(
                      children: [
                        if (step != _SetupStep.language) ...[
                          Expanded(
                            flex: 2,
                            child: SecondaryButton(
                              label: 'पीछे',
                              icon: Icons.arrow_back_rounded,
                              onPressed: _state.loading ? null : _goBack,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Expanded(
                          flex: 3,
                          child: GradientButton(
                            label: isLast ? 'पूरा करें' : 'आगे बढ़ें',
                            icon: isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                            isLoading: _state.loading,
                            onPressed: nextEnabled ? _onNext : null,
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
      ),
    );
  }

  Widget _stepScroll(Widget child) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.lg),
      child: child,
    );
  }

  // ── Step 1 — Language ─────────────────────────────────────────────────────

  Widget _buildStep1Language(AppPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Text(
            'आपके स्टेटस और त्यौहार कार्ड्स इसी भाषा में प्राथमिकता से दिखाए जाएंगे।',
            style: AppText.body(size: 14.5, color: p.textSecondary),
          ),
        ),
        for (var i = 0; i < kAppLanguages.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: FadeSlideIn(
              index: i,
              dy: 12,
              child: _LanguageCard(
                language: kAppLanguages[i],
                selected: _state.language == kAppLanguages[i].code,
                onTap: () => setState(() => _state = _state.copyWith(language: kAppLanguages[i].code)),
              ),
            ),
          ),
      ],
    );
  }

  // ── Step 2 — Name + Photo ─────────────────────────────────────────────────

  Widget _buildStep2NamePhoto(AppPalette p) {
    final displayName = _nameController.text.trim();
    final image = _state.imageFile != null
        ? FileImage(_state.imageFile!) as ImageProvider
        : photoImageProvider(_state.uploadedPhotoUrl);
    final hasPhoto = image != null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadius.xlAll,
        border: Border.all(color: p.border),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'यह नाम और फ़ोटो आपके स्टेटस, फ्रेम और पोस्टर्स पर ब्रांडिंग के लिए दिखाई देगा।',
            style: AppText.body(size: 14.5, color: p.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Semantics(
              button: true,
              label: hasPhoto ? 'फोटो बदलें' : 'फोटो जोड़ें',
              child: GestureDetector(
                onTap: _showImagePickerSheet,
                child: SizedBox(
                  width: 132,
                  height: 132,
                  child: Stack(
                    children: [
                      Container(
                        width: 132,
                        height: 132,
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.brandGradient),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(shape: BoxShape.circle, color: p.surface),
                          child: ClipOval(
                            child: Container(
                              color: p.primarySurface,
                              alignment: Alignment.center,
                              child: hasPhoto
                                  ? Image(image: image, width: 118, height: 118, fit: BoxFit.cover)
                                  : (displayName.isNotEmpty
                                      ? Text(
                                          displayName.characters.first.toUpperCase(),
                                          style: AppText.heading(size: 48, color: p.primary, height: 1),
                                        )
                                      : Icon(Icons.person_rounded, size: 64, color: p.primary)),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.brandGradient,
                            border: Border.all(color: p.surface, width: 3),
                            boxShadow: AppShadows.primaryGlow,
                          ),
                          child: const Icon(Icons.camera_alt_rounded, size: 20, color: AppColors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: TextButton.icon(
              onPressed: _showImagePickerSheet,
              icon: const Icon(Icons.add_a_photo_outlined, size: 20),
              label: Text(hasPhoto ? 'फोटो बदलें' : 'फोटो जोड़ें'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _nameController,
            label: 'आपका पूरा नाम (Full Name)',
            hint: 'उदा. राजेश शर्मा',
            prefixIcon: Icons.person_outline_rounded,
            required: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            maxLength: 50,
            onChanged: (_) => setState(() {
              if (_state.error != null) _state = _state.copyWith(clearError: true);
            }),
            onSubmitted: (_) => _proceedToStateSelection(),
          ),
          if (_state.error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: InfoCard(tone: InfoTone.danger, message: _state.error!),
            ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Icon(Icons.visibility_outlined, size: 18, color: p.textMuted),
              const SizedBox(width: 6),
              Text(
                'स्टेटस पर ऐसा दिखेगा',
                style: AppText.body(size: 13.5, weight: FontWeight.w700, color: p.textMuted, height: 1.2),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _StatusPreviewChip(name: displayName, image: image),
        ],
      ),
    );
  }

  // ── Step 3 — State ────────────────────────────────────────────────────────

  Future<void> _openStatePicker() async {
    final picked = await AppBottomSheet.show<IndianState>(
      context,
      title: 'राज्य चुनें',
      subtitle: 'Search & select your state',
      scrollable: false,
      builder: (ctx) => _StatePickerBody(
        recommendedNames: _currentLanguage.recommendedStates,
        selected: _state.selectedState,
      ),
    );
    if (picked != null && mounted) _selectState(picked);
  }

  bool _detectingLocation = false;

  Future<void> _detectLocationViaGps() async {
    if (_detectingLocation) return;
    setState(() => _detectingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) AppSnack.info(context, 'कृपया डिवाइस की लोकेशन (GPS) चालू करें');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) AppSnack.info(context, 'लोकेशन अनुमति नहीं दी गई');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) AppSnack.info(context, 'सेटिंग्स में जाकर लोकेशन की अनुमति दें');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final lat = position.latitude;
      final lng = position.longitude;

      final stateCentroids = {
        'MH': const [19.75, 75.71],
        'UP': const [26.84, 80.94],
        'MP': const [22.97, 78.65],
        'RJ': const [27.02, 74.21],
        'BR': const [25.09, 85.31],
        'GJ': const [22.25, 71.19],
        'DL': const [28.70, 77.10],
        'PB': const [31.14, 75.34],
        'HR': const [29.05, 76.08],
        'WB': const [22.98, 87.85],
        'KA': const [15.31, 75.71],
        'TN': const [11.12, 78.65],
        'AP': const [15.91, 79.74],
        'TS': const [18.11, 79.01],
        'KL': const [10.85, 76.27],
        'OD': const [20.95, 85.09],
        'JH': const [23.61, 85.27],
        'CG': const [21.27, 81.86],
        'AS': const [26.20, 92.93],
        'UK': const [30.06, 79.01],
        'HP': const [31.10, 77.17],
        'JK': const [33.77, 76.57],
      };

      double minDistance = double.maxFinite;
      String? closestCode;
      stateCentroids.forEach((code, coords) {
        final dLat = lat - coords[0];
        final dLng = lng - coords[1];
        final dist = dLat * dLat + dLng * dLng;
        if (dist < minDistance) {
          minDistance = dist;
          closestCode = code;
        }
      });

      IndianState? matchedState;
      if (closestCode != null) {
        for (final s in IndianStates.all) {
          if (s.code == closestCode) {
            matchedState = s;
            break;
          }
        }
      }

      setState(() {
        _state = _state.copyWith(
          latitude: lat,
          longitude: lng,
          selectedState: matchedState ?? _state.selectedState,
        );
      });

      if (mounted) {
        AppSnack.success(
          context,
          matchedState != null
              ? '📍 आपका स्थान पहचाना गया: ${matchedState.name} (${matchedState.emoji})'
              : '📍 लोकेशन प्राप्त हुई (${lat.toStringAsFixed(2)}, ${lng.toStringAsFixed(2)})',
        );
      }
    } catch (e) {
      debugPrint('Location detection error: $e');
      if (mounted) AppSnack.info(context, 'लोकेशन प्राप्त नहीं हो सकी। कृपया सूची से चुनें।');
    } finally {
      if (mounted) setState(() => _detectingLocation = false);
    }
  }

  AppLanguage get _currentLanguage =>
      kAppLanguages.firstWhere((l) => l.code == _state.language, orElse: () => kAppLanguages.first);

  Widget _buildStep3State(AppPalette p) {
    final lang = _currentLanguage;
    final recommended = IndianStates.all.where((s) => lang.recommendedStates.contains(s.name)).toList();
    final selected = _state.selectedState;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'आपके राज्य के प्रमुख त्यौहार, क्षेत्रीय समाचार और योजनाएं प्राथमिकता से दिखाई जाएंगी।',
          style: AppText.body(size: 14.5, color: p.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        PressableScale(
          onTap: _detectLocationViaGps,
          semanticLabel: 'वर्तमान स्थान पहचानें (Auto Detect Location)',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
            decoration: BoxDecoration(
              color: p.primarySurface,
              borderRadius: AppRadius.lgAll,
              border: Border.all(color: p.primary.withOpacity(0.3), width: 1.2),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: p.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.my_location_rounded, color: p.primary, size: 20),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📍 वर्तमान स्थान पहचानें (Auto-Detect)',
                        style: AppText.body(size: 14, weight: FontWeight.w700, color: p.primary),
                      ),
                      Text(
                        _state.latitude != null
                            ? 'स्थान: ${selected?.name ?? 'सफलतापूर्वक प्राप्त'} (${_state.latitude!.toStringAsFixed(2)}, ${_state.longitude!.toStringAsFixed(2)})'
                            : 'GPS से अपने राज्य की खबरें व योजनाएं तुरंत पाएं',
                        style: AppText.body(size: 12, color: p.textMuted),
                      ),
                    ],
                  ),
                ),
                if (_detectingLocation)
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: p.primary))
                else
                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: p.primary),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PressableScale(
          onTap: _openStatePicker,
          semanticLabel: 'राज्य चुनें',
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: selected != null ? p.primarySurface : p.surface,
              borderRadius: AppRadius.lgAll,
              border: Border.all(color: selected != null ? p.primary : p.border, width: selected != null ? 2 : 1.2),
            ),
            child: Row(
              children: [
                Text(selected?.emoji ?? '🗺️', style: const TextStyle(fontSize: 30)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected?.name ?? 'राज्य चुनने के लिए दबाएं',
                        style: AppText.heading(
                          size: 17,
                          weight: FontWeight.w700,
                          color: selected != null ? p.textPrimary : p.textMuted,
                          height: 1.25,
                        ),
                      ),
                      if (selected != null)
                        Text(
                          '${selected.regions.length} क्षेत्र उपलब्ध',
                          style: AppText.body(size: 13.5, color: p.textMuted, height: 1.3),
                        ),
                    ],
                  ),
                ),
                Icon(selected != null ? Icons.edit_rounded : Icons.search_rounded, color: p.primary),
              ],
            ),
          ),
        ),
        if (recommended.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            '⭐ ${lang.name} के अनुसार सुझाव',
            style: AppText.body(size: 14, weight: FontWeight.w800, color: p.primary, height: 1.2),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final s in recommended)
                CategoryChip(
                  label: s.name,
                  emoji: s.emoji,
                  selected: selected?.name == s.name,
                  onTap: () => _selectState(s),
                ),
            ],
          ),
        ],
      ],
    );
  }

  // ── Step 4 — Region ───────────────────────────────────────────────────────

  Widget _buildStep4Region(AppPalette p) {
    final s = _state.selectedState;
    final regions = s?.regions ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(color: p.primarySurface, borderRadius: AppRadius.mdAll),
          child: Row(
            children: [
              Text(s?.emoji ?? '📍', style: const TextStyle(fontSize: 26)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${s?.name ?? ''} में अपने शहर या क्षेत्र का चयन करें',
                  style: AppText.body(size: 15, weight: FontWeight.w600, color: p.textPrimary, height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final r in regions)
              CategoryChip(
                label: r,
                icon: _state.selectedRegion == r ? Icons.check_rounded : Icons.location_on_outlined,
                selected: _state.selectedRegion == r,
                onTap: _state.loading ? null : () => setState(() => _state = _state.copyWith(selectedRegion: r)),
              ),
          ],
        ),
      ],
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _LanguageCard extends StatelessWidget {
  final AppLanguage language;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageCard({required this.language, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: PressableScale(
        onTap: onTap,
        haptic: true,
        semanticLabel: '${language.name} (${language.english})',
        scale: 0.98,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? p.primarySurface : p.surface,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: selected ? p.primary : p.border, width: selected ? 2 : 1.2),
            boxShadow: selected ? AppShadows.subtle : null,
          ),
          child: Row(
            children: [
              Text(language.flag, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      language.name,
                      style: AppText.heading(size: 22, color: selected ? p.primary : p.textPrimary, height: 1.25),
                    ),
                    Text(
                      '${language.english} • ${language.desc}',
                      style: AppText.body(size: 13.5, color: p.textMuted, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              AnimatedSwitcher(
                duration: AppMotion.fast,
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: selected
                    ? Icon(Icons.check_circle_rounded, key: const ValueKey('on'), color: p.primary, size: 28)
                    : Icon(Icons.radio_button_unchecked_rounded, key: const ValueKey('off'), color: p.textHint, size: 26),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "How it will look on a status" strip.
class _StatusPreviewChip extends StatelessWidget {
  final String name;
  final ImageProvider? image;
  const _StatusPreviewChip({required this.name, required this.image});

  @override
  Widget build(BuildContext context) {
    final shown = name.isEmpty ? 'आपका नाम' : name;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        gradient: AppColors.inkGradient,
        borderRadius: AppRadius.mdAll,
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              border: Border.all(color: AppColors.gold, width: 2),
              image: image == null ? null : DecorationImage(image: image!, fit: BoxFit.cover),
            ),
            alignment: Alignment.center,
            child: image == null
                ? Text(
                    shown.characters.first.toUpperCase(),
                    style: AppText.heading(size: 18, color: AppColors.white, height: 1),
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shown,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.heading(
                    size: 16,
                    color: name.isEmpty ? AppColors.onDarkMuted : AppColors.onDark,
                    height: 1.25,
                  ),
                ),
                Text(
                  'स्टेटस गो • Status Go',
                  style: AppText.body(size: 12.5, color: AppColors.onDarkMuted, height: 1.3),
                ),
              ],
            ),
          ),
          const Icon(Icons.verified_rounded, color: AppColors.gold, size: 22),
        ],
      ),
    );
  }
}

/// Searchable list shown in the state picker bottom sheet.
class _StatePickerBody extends StatefulWidget {
  final List<String> recommendedNames;
  final IndianState? selected;
  const _StatePickerBody({required this.recommendedNames, required this.selected});

  @override
  State<_StatePickerBody> createState() => _StatePickerBodyState();
}

class _StatePickerBodyState extends State<_StatePickerBody> {
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final q = _q.trim().toLowerCase();
    var list = q.isEmpty ? IndianStates.all.toList() : IndianStates.all.where((s) => s.name.toLowerCase().contains(q)).toList();
    if (q.isEmpty) {
      // Recommended states first.
      list.sort((a, b) {
        final ra = widget.recommendedNames.contains(a.name) ? 0 : 1;
        final rb = widget.recommendedNames.contains(b.name) ? 0 : 1;
        return ra.compareTo(rb);
      });
    }
    final height = MediaQuery.of(context).size.height * 0.62;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.sm),
            child: AppSearchField(
              controller: _search,
              hint: 'राज्य खोजें (Search state)...',
              onChanged: (v) => setState(() => _q = v),
              onClear: _q.isEmpty
                  ? null
                  : () {
                      _search.clear();
                      setState(() => _q = '');
                    },
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'कोई राज्य नहीं मिला',
                    message: 'दूसरा नाम लिखकर खोजें।',
                    compact: true,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.xs, 0, AppSpacing.xs, AppSpacing.xl),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final s = list[i];
                      final isSel = widget.selected?.name == s.name;
                      final isRec = q.isEmpty && widget.recommendedNames.contains(s.name);
                      return InkWell(
                        onTap: () => Navigator.of(context).pop(s),
                        borderRadius: AppRadius.mdAll,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 56),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                            child: Row(
                              children: [
                                Text(s.emoji, style: const TextStyle(fontSize: 24)),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    s.name,
                                    style: AppText.body(
                                      size: 16.5,
                                      weight: isSel ? FontWeight.w800 : FontWeight.w600,
                                      color: isSel ? p.primary : p.textPrimary,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                                if (isRec && !isSel)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: Icon(Icons.star_rounded, color: AppColors.gold, size: 20),
                                  ),
                                if (isSel) Icon(Icons.check_circle_rounded, color: p.primary),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
