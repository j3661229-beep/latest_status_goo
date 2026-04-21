// lib/features/auth/presentation/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signInWithGoogle() async {
    setState(() { _loading = true; _error = null; });
    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.signInWithGoogle();
      if (user != null && mounted) {
        context.go('/home');
      }
    } catch (e) {
      setState(() => _error = 'Sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            height: MediaQuery.of(context).size.height * 0.55,
            decoration: const BoxDecoration(gradient: AppColors.brandGradient),
          ),
          // White bottom card
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.52,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'Join Status Go',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Access 300+ devotional, motivational & festival\nstatus templates. Share your personality!',
                    style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500,
                      color: AppColors.textMuted, height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Benefits
                  ...[
                    '🙏 Devotional, Festival, Motivational Status',
                    '📸 Personalise with your name & photo',
                    '📲 Share directly to WhatsApp Status',
                    '⭐ Free to use — Premium for unlimited access',
                  ].map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Text(b.split(' ').first, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Text(
                            b.substring(b.indexOf(' ') + 1),
                            style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Google Sign-In Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _signInWithGoogle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.surfaceBorder, width: 1.5),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('G', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF4285F4))),
                                const SizedBox(width: 12),
                                const Text('Continue with Google', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'By continuing, you agree to our Terms & Privacy Policy',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Illustration in top half
          Positioned(
            top: 60,
            left: 0, right: 0,
            child: Column(
              children: [
                const Text('📲', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 12),
                const Text(
                  'Status Go',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                Text(
                  'स्टेटस गो',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
