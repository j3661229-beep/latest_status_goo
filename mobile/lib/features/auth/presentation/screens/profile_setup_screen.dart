// lib/features/auth/presentation/screens/profile_setup_screen.dart
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/auth_repository.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  File? _imageFile;
  bool _loading = false;
  String? _error;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<String?> _uploadToCloudinary(File file) async {
    try {
      final dio = Dio();
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path),
        'upload_preset': 'ml_default',
        'cloud_name': 'daxouqjol',
      });
      
      final resp = await dio.post(
        'https://api.cloudinary.com/v1_1/daxouqjol/image/upload',
        data: formData,
      );
      
      return resp.data['secure_url'] as String;
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
      return null;
    }
  }

  Future<void> _completeProfile() async {
    final name = _nameController.text.trim();
    if (name.length < 3) {
      setState(() => _error = 'Please enter your full name (at least 3 characters)');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      String? photoUrl;
      if (_imageFile != null) {
        photoUrl = await _uploadToCloudinary(_imageFile!);
      }

      await ref.read(authRepositoryProvider).updateProfile(
        name: name,
        photoUrl: photoUrl,
      );

      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      setState(() => _error = 'Failed to save profile. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0C29),
      body: Stack(
        children: [
          // ── Background Mesh ────────────────────────────
          Positioned(
            bottom: -100, left: -50,
            child: _AnimatedOrb(color: AppColors.primary.withOpacity(0.4), size: 300),
          ),
          Positioned(
            top: -50, right: -80,
            child: _AnimatedOrb(color: AppColors.secondary.withOpacity(0.3), size: 350),
          ),

          // ── Content ──────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  FadeInDown(
                    duration: const Duration(milliseconds: 800),
                    child: Column(
                      children: [
                        const Text(
                          'Welcome!',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Let\'s personalise your profile',
                          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.6)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  FadeIn(
                    duration: const Duration(milliseconds: 1000),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
                          ),
                          child: Column(
                            children: [
                              // Avatar Picker
                              GestureDetector(
                                onTap: _pickImage,
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 140, height: 140,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppColors.accent.withOpacity(0.5), width: 3),
                                        image: _imageFile != null 
                                          ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                                          : null,
                                      ),
                                      child: _imageFile == null 
                                        ? const Icon(Icons.person_add_rounded, size: 50, color: Colors.white30)
                                        : null,
                                    ),
                                    Positioned(
                                      bottom: 4, right: 4,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Name Field
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('YOUR NAME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white38, letterSpacing: 1)),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _nameController,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                    decoration: InputDecoration(
                                      hintText: 'e.g. John Doe',
                                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                                      fillColor: Colors.white.withOpacity(0.05),
                                      filled: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),

                              if (_error != null) 
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Text(_error!, style: const TextStyle(color: Color(0xFFFF4D4D), fontSize: 12, fontWeight: FontWeight.w600)),
                                ),

                              _PremiumButton(
                                text: 'Complete Setup',
                                loading: _loading,
                                onPressed: _completeProfile,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Reuse shared components (normally these would be moved to a shared folder)
class _AnimatedOrb extends StatelessWidget {
  final Color color;
  final double size;
  const _AnimatedOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 100, spreadRadius: 40)],
      ),
    );
  }
}

class _PremiumButton extends StatelessWidget {
  final String text;
  final bool loading;
  final VoidCallback? onPressed;

  const _PremiumButton({
    required this.text,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8)),
        ],
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
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
      ),
    );
  }
}

