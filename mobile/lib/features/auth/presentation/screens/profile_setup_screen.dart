// lib/features/auth/presentation/screens/profile_setup_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/data/indian_states.dart';
import '../../data/auth_repository.dart';

// ─── Steps ───────────────────────────────────────────────────────────────────

enum _SetupStep { namePhoto, state, region }

class _SetupState {
  final _SetupStep step;
  final bool loading;
  final String? error;
  final String name;
  final File? imageFile;
  final String? uploadedPhotoUrl;
  final IndianState? selectedState;
  final String? selectedRegion;

  const _SetupState({
    this.step = _SetupStep.namePhoto,
    this.loading = false,
    this.error,
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
    String? name,
    File? imageFile,
    bool clearImage = false,
    String? uploadedPhotoUrl,
    IndianState? selectedState,
    bool clearState = false,
    String? selectedRegion,
    bool clearRegion = false,
  }) =>
      _SetupState(
        step: step ?? this.step,
        loading: loading ?? this.loading,
        error: error,
        name: name ?? this.name,
        imageFile: clearImage ? null : imageFile ?? this.imageFile,
        uploadedPhotoUrl: uploadedPhotoUrl ?? this.uploadedPhotoUrl,
        selectedState: clearState ? null : selectedState ?? this.selectedState,
        selectedRegion: clearRegion ? null : selectedRegion ?? this.selectedRegion,
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked != null) {
      setState(() => _state = _state.copyWith(imageFile: File(picked.path)));
    }
  }

  // ── Step 1 → 2 (name + photo) ─────────────────────────────────────────────

  Future<void> _proceedToStateSelection() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      setState(() => _state = _state.copyWith(error: 'कृपया अपना नाम दर्ज करें (कम से कम 2 अक्षर)'));
      return;
    }

    setState(() => _state = _state.copyWith(loading: true, error: null, name: name));

    String? photoUrl;
    if (_state.imageFile != null) {
      try {
        photoUrl = await ref.read(authRepositoryProvider).uploadProfilePhoto(_state.imageFile!.path);
      } catch (e) {
        // Continue even if photo upload fails
      }
    }

    setState(() => _state = _state.copyWith(
          loading: false,
          step: _SetupStep.state,
          uploadedPhotoUrl: photoUrl,
        ));

    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // ── Step 2 → 3 (state) ────────────────────────────────────────────────────

  void _proceedToRegionSelection(IndianState state) {
    setState(() => _state = _state.copyWith(
          selectedState: state,
          step: _SetupStep.region,
          clearRegion: true,
        ));
    _pageController.animateToPage(
      2,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // ── Step 3 → Complete ─────────────────────────────────────────────────────

  Future<void> _completeSetup(String region) async {
    setState(() => _state = _state.copyWith(loading: true, selectedRegion: region, error: null));

    final selectedState = _state.selectedState;
    final language = selectedState != null
        ? IndianStates.languageForState(selectedState.name)
        : 'HINDI';

    try {
      await ref.read(authRepositoryProvider).completeProfile(
            name: _state.name,
            profilePhoto: _state.uploadedPhotoUrl,
            state: selectedState?.name,
            region: region,
            language: language,
          );

      if (mounted) context.go('/home');
    } catch (e) {
      setState(() => _state = _state.copyWith(
          loading: false,
          error: 'सेटअप पूरा नहीं हो सका। कृपया पुनः प्रयास करें।'));
    }
  }

  void _goBack() {
    if (_state.step == _SetupStep.region) {
      setState(() => _state = _state.copyWith(step: _SetupStep.state));
      _pageController.animateToPage(1, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else if (_state.step == _SetupStep.state) {
      setState(() => _state = _state.copyWith(step: _SetupStep.namePhoto));
      _pageController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final stepTitles = ['आपकी प्रोफाइल (Your Profile)', 'राज्य चुनें (Select State)', 'क्षेत्र चुनें (Select Region)'];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: _state.step != _SetupStep.namePhoto
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
                onPressed: _goBack,
              )
            : null,
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'कदम ${_state.step.index + 1} / 3',
                        style: GoogleFonts.hind(
                          color: AppColors.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        stepTitles[_state.step.index],
                        style: GoogleFonts.hind(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_state.step.index + 1) / 3.0,
                      backgroundColor: AppColors.surfaceBorder,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.surfaceBorder),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 1 — Name + Photo ─────────────────────────────────────────────────

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'नमस्ते! अपनी जानकारी जोड़ें 👋',
            style: GoogleFonts.hind(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'यह नाम आपके स्टेटस और पोस्टर्स पर दिखाई देगा',
            style: GoogleFonts.hind(
              fontSize: 15,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 28),

          // Photo Selector
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primarySurface,
                          border: Border.all(color: AppColors.primary, width: 2),
                          image: _state.imageFile != null
                              ? DecorationImage(
                                  image: FileImage(_state.imageFile!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _state.imageFile == null
                            ? const Icon(
                                Icons.person,
                                size: 64,
                                color: AppColors.primary,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'फोटो जोड़ें (वैकल्पिक)',
                    style: GoogleFonts.hind(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Name Field
          Text(
            'आपका पूरा नाम *',
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
            style: GoogleFonts.hind(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'उदा. राजेश शर्मा',
              prefixIcon: const Icon(Icons.person_outline, color: AppColors.primary),
              fillColor: AppColors.surface,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.surfaceBorder),
              ),
            ),
          ),

          if (_state.error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.danger),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _state.error!,
                      style: GoogleFonts.hind(color: AppColors.danger, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 36),

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
                        const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2 — State Selection ──────────────────────────────────────────────

  Widget _buildStep2() {
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
            'आपके राज्य के प्रमुख त्यौहार और स्टेटस पहले दिखाए जाएंगे',
            style: GoogleFonts.hind(
              fontSize: 14,
              color: AppColors.textMuted,
            ),
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
            ),
          ),
          const SizedBox(height: 16),

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
                                  'मुख्य भाषा: ${s.defaultLanguage}',
                                  style: GoogleFonts.hind(
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textMuted),
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

  // ── Step 3 — Region Selection ─────────────────────────────────────────────

  Widget _buildStep3() {
    final regions = _state.selectedState?.regions ?? [];

    return Padding(
      padding: const EdgeInsets.all(20),
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
          const SizedBox(height: 4),
          Text(
            '${_state.selectedState?.name ?? ''} में अपने नजदीकी क्षेत्र का चयन करें',
            style: GoogleFonts.hind(
              fontSize: 14,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),

          if (_state.error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.danger),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _state.error!,
                      style: GoogleFonts.hind(color: AppColors.danger, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _state.loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
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
                                    Icons.location_pin,
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
                                const Icon(Icons.chevron_right, size: 22, color: AppColors.primary),
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
