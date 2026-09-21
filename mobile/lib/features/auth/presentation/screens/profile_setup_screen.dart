// lib/features/auth/presentation/screens/profile_setup_screen.dart
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:animate_do/animate_do.dart';

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
      setState(() => _state = _state.copyWith(error: 'Please enter your name (at least 2 characters)'));
      return;
    }

    setState(() => _state = _state.copyWith(loading: true, error: null, name: name));

    // Upload photo if selected
    String? photoUrl;
    if (_state.imageFile != null) {
      photoUrl = await ref.read(authRepositoryProvider).uploadProfilePhoto(_state.imageFile!.path);
    }

    setState(() => _state = _state.copyWith(
          loading: false,
          step: _SetupStep.state,
          uploadedPhotoUrl: photoUrl,
        ));

    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
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
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
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
      setState(() => _state = _state.copyWith(loading: false, error: 'Setup failed. Please try again.'));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: Stack(
        children: [
          // Background orbs
          Positioned(
            top: -80, right: -60,
            child: _Orb(color: AppColors.primary.withOpacity(0.25), size: 300),
          ),
          Positioned(
            bottom: -100, left: -60,
            child: _Orb(color: AppColors.secondary.withOpacity(0.2), size: 280),
          ),

          SafeArea(
            child: Column(
              children: [
                // Progress indicator
                _buildProgressBar(),

                // Page view (non-scrollable, programmatic control)
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
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = _state.step.index / 2.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Step ${_state.step.index + 1} of 3',
                style: GoogleFonts.outfit(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                ['Your Profile', 'Select State', 'Your Region'][_state.step.index],
                style: GoogleFonts.outfit(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress + (1 / 3),
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 1 — Name + Photo ─────────────────────────────────────────────────

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: FadeInUp(
        duration: const Duration(milliseconds: 500),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome! 🎉',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Let's set up your profile to get started",
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.white.withOpacity(0.5),
              ),
            ),

            const SizedBox(height: 40),

            // Avatar picker
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.5),
                            AppColors.secondary.withOpacity(0.5),
                          ],
                        ),
                        image: _state.imageFile != null
                            ? DecorationImage(image: FileImage(_state.imageFile!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: _state.imageFile == null
                          ? Icon(Icons.person_rounded, size: 48, color: Colors.white.withOpacity(0.4))
                          : null,
                    ),
                    Positioned(
                      bottom: 2, right: 2,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF0A0A1A), width: 2.5),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Tap to add photo',
                  style: GoogleFonts.outfit(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 12,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Name field
            _FieldLabel('YOUR NAME'),
            const SizedBox(height: 8),
            _GlassTextField(
              controller: _nameController,
              hint: 'e.g. Raj Kumar',
              textCapitalization: TextCapitalization.words,
            ),

            if (_state.error != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(_state.error!),
            ],

            const SizedBox(height: 32),

            _GradientButton(
              text: 'Continue',
              loading: _state.loading,
              icon: Icons.arrow_forward_rounded,
              onPressed: _proceedToStateSelection,
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 2 — State Selection ──────────────────────────────────────────────

  Widget _buildStep2() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          FadeInLeft(
            duration: const Duration(milliseconds: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Your State 🗺️',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'We\'ll show you templates popular in your region',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Search field
          _GlassTextField(
            controller: _stateSearchController,
            hint: 'Search state...',
            prefixIcon: Icons.search_rounded,
            onChanged: _filterStates,
          ),

          const SizedBox(height: 16),

          Expanded(
            child: ListView.builder(
              itemCount: _filteredStates.length,
              itemBuilder: (context, i) {
                final s = _filteredStates[i];
                return _StateListTile(
                  state: s,
                  onTap: () => _proceedToRegionSelection(s),
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          FadeInRight(
            duration: const Duration(milliseconds: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Region 📍',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'In ${_state.selectedState?.name ?? ''} — pick the closest region',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          if (_state.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ErrorBanner(_state.error!),
            ),

          Expanded(
            child: _state.loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ListView.builder(
                    itemCount: regions.length,
                    itemBuilder: (context, i) {
                      final region = regions[i];
                      return _RegionListTile(
                        region: region,
                        onTap: () => _completeSetup(region),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Supporting Widgets ───────────────────────────────────────────────────────

class _Orb extends StatelessWidget {
  final Color color;
  final double size;
  const _Orb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color, blurRadius: 120, spreadRadius: 60)],
        ),
      );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white.withOpacity(0.35),
          letterSpacing: 1.5,
        ),
      );
}

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextCapitalization textCapitalization;
  final IconData? prefixIcon;
  final ValueChanged<String>? onChanged;

  const _GlassTextField({
    required this.controller,
    required this.hint,
    this.textCapitalization = TextCapitalization.none,
    this.prefixIcon,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: TextField(
        controller: controller,
        textCapitalization: textCapitalization,
        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(color: Colors.white.withOpacity(0.25)),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: Colors.white.withOpacity(0.4), size: 20)
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String text;
  final bool loading;
  final VoidCallback? onPressed;
  final IconData? icon;

  const _GradientButton({
    required this.text,
    required this.loading,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: loading ? null : AppColors.brandGradient,
        color: loading ? Colors.white.withOpacity(0.08) : null,
        borderRadius: BorderRadius.circular(18),
        boxShadow: loading
            ? []
            : [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(text, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                  if (icon != null) ...[const SizedBox(width: 8), Icon(icon, size: 18)],
                ],
              ),
      ),
    );
  }
}

class _StateListTile extends StatelessWidget {
  final IndianState state;
  final VoidCallback onTap;

  const _StateListTile({required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Text(state.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.name,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    state.defaultLanguage,
                    style: GoogleFonts.outfit(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.3), size: 20),
          ],
        ),
      ),
    );
  }
}

class _RegionListTile extends StatelessWidget {
  final String region;
  final VoidCallback onTap;

  const _RegionListTile({required this.region, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.location_on_rounded, color: AppColors.primary, size: 16),
            ),
            const SizedBox(width: 14),
            Text(
              region,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.3), size: 20),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String text;
  const _ErrorBanner(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFF4D4D).withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFF4D4D).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFFF4D4D), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.outfit(
                    color: const Color(0xFFFF4D4D), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}
