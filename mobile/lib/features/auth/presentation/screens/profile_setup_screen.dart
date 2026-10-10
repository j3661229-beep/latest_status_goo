// lib/features/auth/presentation/screens/profile_setup_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/auth/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/data/indian_states.dart';
import '../../data/auth_repository.dart';
import '../../../home/presentation/providers/home_data_provider.dart';

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
  final _stateSearchController = TextEditingController();
  final PageController _pageController = PageController();

  var _state = const _SetupState();
  List<IndianState> _filteredStates = IndianStates.all;

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

    _state = _state.copyWith(
      language: savedLang ?? 'HINDI',
      name: savedName ?? '',
      imageFile: (savedPhoto != null && File(savedPhoto).existsSync()) ? File(savedPhoto) : null,
      // Already uploaded photo (re-used unless the user picks a new one)
      uploadedPhotoUrl: session.profilePhotoUrl,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stateSearchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _filterStates(String query) {
    setState(() {
      _filteredStates = query.isEmpty
          ? IndianStates.all
          : IndianStates.all
              .where((s) => s.name.toLowerCase().contains(query.toLowerCase()))
              .toList();
    });
  }

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
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'प्रोफ़ाइल फ़ोटो जोड़ें',
                style: GoogleFonts.hind(fontSize: 18, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                ),
                title: Text('कैमरा से फोटो लें', style: GoogleFonts.hind(fontWeight: FontWeight.w600, fontSize: 16)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                ),
                title: Text('गैलरी से चुनें', style: GoogleFonts.hind(fontWeight: FontWeight.w600, fontSize: 16)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_state.imageFile != null) ...[
                const Divider(),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEE2E2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                  ),
                  title: Text('फ़ोटो हटाएं', style: GoogleFonts.hind(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 16)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _state = _state.copyWith(clearImage: true, clearUploadedPhotoUrl: true));
                    SessionStore.instance.setLocalPhotoPath(null);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Step 1 → 2 (Language → Name & Photo) ──────────────────────────────────

  void _proceedToNamePhoto(String languageCode) {
    setState(() => _state = _state.copyWith(
          language: languageCode,
          step: _SetupStep.namePhoto,
          clearError: true,
        ));
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // ── Step 2 → 3 (Name & Photo → State) ─────────────────────────────────────

  Future<void> _proceedToStateSelection() async {
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

    _pageController.animateToPage(
      2,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<_UploadFailureChoice?> _showUploadFailedDialog(String message) {
    return showDialog<_UploadFailureChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(
          'फ़ोटो अपलोड नहीं हो सकी',
          style: GoogleFonts.hind(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: Text(
          '$message\n\nआप दोबारा कोशिश कर सकते हैं या बिना फ़ोटो आगे बढ़ सकते हैं (फ़ोटो बाद में जोड़ सकते हैं)।',
          style: GoogleFonts.hind(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _UploadFailureChoice.continueWithoutPhoto),
            child: Text(
              'बिना फ़ोटो आगे बढ़ें',
              style: GoogleFonts.hind(color: AppColors.textMuted, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, _UploadFailureChoice.retry),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: Text('दोबारा कोशिश करें', style: GoogleFonts.hind(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Step 3 → 4 (State → Region) ───────────────────────────────────────────

  void _proceedToRegionSelection(IndianState state) {
    setState(() => _state = _state.copyWith(
          selectedState: state,
          step: _SetupStep.region,
          clearRegion: true,
          clearError: true,
        ));
    _pageController.animateToPage(
      3,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // ── Step 4 → Complete Setup ───────────────────────────────────────────────

  Future<void> _completeSetup(String region) async {
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
          );
      // State / language drive the home feed query.
      ref.invalidate(homeDataProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  'स्वागत है ${_state.name}! प्रोफ़ाइल तैयार है 🎉',
                  style: GoogleFonts.hind(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
        context.go('/home');
      }
    } catch (e) {
      debugPrint('Setup complete error: $e');
      if (!mounted) return;
      // Keep the entered values; let the user retry.
      setState(() => _state = _state.copyWith(
            loading: false,
            error: apiErrorMessage(e, fallback: 'प्रोफ़ाइल सेव नहीं हो सकी। कृपया दोबारा कोशिश करें।'),
          ));
    }
  }

  void _goBack() {
    if (_state.step == _SetupStep.region) {
      setState(() => _state = _state.copyWith(step: _SetupStep.state));
      _pageController.animateToPage(2, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
    } else if (_state.step == _SetupStep.state) {
      setState(() => _state = _state.copyWith(step: _SetupStep.namePhoto));
      _pageController.animateToPage(1, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
    } else if (_state.step == _SetupStep.namePhoto) {
      setState(() => _state = _state.copyWith(step: _SetupStep.language));
      _pageController.animateToPage(0, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    const stepLabels = [
      'भाषा चुनें (Language)',
      'नाम व फोटो (Name & Photo)',
      'राज्य चुनें (Select State)',
      'क्षेत्र चुनें (Select Region)',
    ];

    final progressValue = (_state.step.index + 1) / 4.0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: _goBack,
        ),
        title: Text(
          'प्रोफाइल बनाएं (Profile Setup)',
          style: GoogleFonts.hind(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar & Step Header
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'कदम ${_state.step.index + 1} / 4',
                        style: GoogleFonts.hind(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        stepLabels[_state.step.index],
                        style: GoogleFonts.hind(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressValue,
                      backgroundColor: AppColors.surfaceBorder,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.surfaceBorder),

            // Step Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1Language(),
                  _buildStep2NamePhoto(),
                  _buildStep3State(),
                  _buildStep4Region(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 1 — Language Selection ───────────────────────────────────────────

  Widget _buildStep1Language() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.language_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'अपनी भाषा चुनें 🌐',
                      style: GoogleFonts.hind(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Select Your Preferred Language',
                      style: GoogleFonts.hind(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'आपके स्टेटस और त्यौहार कार्ड्स इसी भाषा में प्राथमिकता से दिखाए जाएंगे।',
            style: GoogleFonts.hind(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),

          Expanded(
            child: ListView.separated(
              itemCount: kAppLanguages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final lang = kAppLanguages[i];
                final isSelected = _state.language == lang.code;

                return Material(
                  color: isSelected ? AppColors.primarySurface : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () {
                      setState(() => _state = _state.copyWith(language: lang.code));
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(lang.flag, style: const TextStyle(fontSize: 26)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang.name,
                                  style: GoogleFonts.hind(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${lang.english} • ${lang.desc}',
                                  style: GoogleFonts.hind(fontSize: 13, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 24)
                          else
                            const Icon(Icons.radio_button_unchecked_rounded, color: AppColors.textMuted, size: 22),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => _proceedToNamePhoto(_state.language),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'आगे बढ़ें (Continue)',
                    style: GoogleFonts.hind(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2 — Name + Photo ─────────────────────────────────────────────────

  Widget _buildStep2NamePhoto() {
    final displayName = _nameController.text.trim();
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'अपनी जानकारी जोड़ें 👋',
            style: GoogleFonts.hind(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'यह नाम और फ़ोटो आपके स्टेटस, फ्रेम और पोस्टर्स पर ब्रांडिंग के लिए दिखाई देगा।',
            style: GoogleFonts.hind(fontSize: 14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),

          // Photo Selector
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _showImagePickerSheet,
                  child: Stack(
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primarySurface,
                          border: Border.all(color: AppColors.primary, width: 2.5),
                          image: _state.imageFile != null
                              ? DecorationImage(
                                  image: FileImage(_state.imageFile!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _state.imageFile == null
                            ? Center(
                                child: Text(
                                  initial,
                                  style: GoogleFonts.hind(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _showImagePickerSheet,
                  icon: const Icon(Icons.add_a_photo_outlined, size: 18, color: AppColors.primary),
                  label: Text(
                    _state.imageFile == null ? 'फोटो जोड़ें (Add Photo)' : 'फोटो बदलें (Change Photo)',
                    style: GoogleFonts.hind(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Name Field
          Text(
            'आपका पूरा नाम (Full Name) *',
            style: GoogleFonts.hind(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            onChanged: (val) => setState(() {}),
            style: GoogleFonts.hind(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'उदा. राजेश शर्मा',
              prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.primary),
              fillColor: AppColors.surface,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.surfaceBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.surfaceBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),

          if (_state.error != null) ...[
            const SizedBox(height: 14),
            _ErrorBox(_state.error!),
          ],

          const SizedBox(height: 20),

          // Live Card Watermark Preview
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.visibility_outlined, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      'कार्ड प्रिव्यू (Card Preview)',
                      style: GoogleFonts.hind(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                          image: _state.imageFile != null
                              ? DecorationImage(image: FileImage(_state.imageFile!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: _state.imageFile == null
                            ? Center(
                                child: Text(
                                  initial,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName.isNotEmpty ? displayName : 'आपका नाम',
                              style: GoogleFonts.hind(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'स्टेटस गो • Status Go',
                              style: GoogleFonts.hind(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.verified_rounded, color: Colors.amber, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _state.loading ? null : _proceedToStateSelection,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _state.loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'आगे बढ़ें (Continue)',
                          style: GoogleFonts.hind(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3 — State Selection ──────────────────────────────────────────────

  Widget _buildStep3State() {
    final currentLangConfig = kAppLanguages.firstWhere(
      (l) => l.code == _state.language,
      orElse: () => kAppLanguages[0],
    );

    final recommendedStateNames = currentLangConfig.recommendedStates;
    final recommendedStates = IndianStates.all.where((s) => recommendedStateNames.contains(s.name)).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'अपना राज्य चुनें (Select State) 🗺️',
            style: GoogleFonts.hind(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'आपके राज्य के प्रमुख त्यौहार और लोकल स्टेटस प्राथमिकता से दिखाए जाएंगे।',
            style: GoogleFonts.hind(fontSize: 14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),

          // Search Field
          TextField(
            controller: _stateSearchController,
            onChanged: _filterStates,
            style: GoogleFonts.hind(fontSize: 16),
            decoration: InputDecoration(
              hintText: 'राज्य खोजें (Search state)...',
              prefixIcon: const Icon(Icons.search, color: AppColors.primary),
              fillColor: AppColors.surface,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.surfaceBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.surfaceBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Recommended banner (if not searching)
          if (_stateSearchController.text.isEmpty && recommendedStates.isNotEmpty) ...[
            Text(
              '⭐ आपकी चुनी हुई भाषा (${currentLangConfig.name}) के अनुसार:',
              style: GoogleFonts.hind(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recommendedStates.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final s = recommendedStates[i];
                  return InkWell(
                    onTap: () => _proceedToRegionSelection(s),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary),
                      ),
                      child: Row(
                        children: [
                          Text(s.emoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            s.name,
                            style: GoogleFonts.hind(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],

          Expanded(
            child: ListView.separated(
              itemCount: _filteredStates.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final s = _filteredStates[i];
                return Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () => _proceedToRegionSelection(s),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Row(
                        children: [
                          Text(s.emoji, style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.name,
                                  style: GoogleFonts.hind(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'मुख्य भाषा: ${s.defaultLanguage} • ${s.regions.length} क्षेत्र',
                                  style: GoogleFonts.hind(
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textMuted),
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

  // ── Step 4 — Region Selection ─────────────────────────────────────────────

  Widget _buildStep4Region() {
    final regions = _state.selectedState?.regions ?? [];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_state.selectedState?.emoji ?? '📍', style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'अपना क्षेत्र / संभाग चुनें 📍',
                      style: GoogleFonts.hind(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${_state.selectedState?.name ?? ''} में अपने शहर या क्षेत्र का चयन करें',
                      style: GoogleFonts.hind(fontSize: 14, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_state.error != null) ...[
            _ErrorBox(_state.error!),
            const SizedBox(height: 12),
          ],

          Expanded(
            child: _state.loading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 16),
                        Text('प्रोफ़ाइल तैयार की जा रही है...'),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: regions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final region = regions[i];
                      return Material(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          onTap: () => _completeSetup(region),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.surfaceBorder),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySurface,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.location_on_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    region,
                                    style: GoogleFonts.hind(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, size: 24, color: AppColors.primary),
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

// ─── Helper Widgets ───────────────────────────────────────────────────────────

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.danger),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.hind(color: AppColors.danger, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
