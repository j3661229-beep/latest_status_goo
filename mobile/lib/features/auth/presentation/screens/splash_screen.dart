// lib/features/auth/presentation/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/session_store.dart';
import '../../../../core/widgets/app_ui.dart';

/// Animated brand splash. Routing logic: login -> profile-setup -> home.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _loop;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();
    _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();
    _logoScale = Tween<double>(begin: 0.6, end: 1).animate(
      CurvedAnimation(parent: _intro, curve: const Interval(0, 0.65, curve: Curves.easeOutBack)),
    );
    _logoFade = CurvedAnimation(parent: _intro, curve: const Interval(0, 0.45, curve: Curves.easeOut));
    _textFade = CurvedAnimation(parent: _intro, curve: const Interval(0.45, 1, curve: Curves.easeOut));
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final session = SessionStore.instance;
    final onboarded = session.onboardingCompleted;
    final userName = session.displayName;

    if (!session.isLoggedIn) {
      // First time / not logged in: OTP login screen.
      context.go('/login');
    } else if (!onboarded || userName == null || userName.trim().isEmpty) {
      // Logged in but name / photo / region not set up yet.
      context.go('/profile-setup');
    } else {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ImmersiveTheme(
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.brandGradient),
          child: SafeArea(
            child: SizedBox.expand(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: const AppLogo(size: 104, showWordmark: true, wordmarkColor: AppColors.white),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FadeTransition(
                    opacity: _textFade,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                      child: Text(
                        'हर दिन, आपके नाम के साथ नया स्टेटस',
                        textAlign: TextAlign.center,
                        style: AppText.body(
                          size: 16,
                          weight: FontWeight.w600,
                          color: AppColors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                  FadeTransition(
                    opacity: _textFade,
                    child: Semantics(
                      label: 'लोड हो रहा है',
                      child: _ShimmerBar(animation: _loop),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Slim pill track with a sweeping highlight.
class _ShimmerBar extends StatelessWidget {
  final Animation<double> animation;
  const _ShimmerBar({required this.animation});

  @override
  Widget build(BuildContext context) {
    const width = 120.0;
    const height = 5.0;
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: AppRadius.pillAll,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: AppColors.glassStrong),
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(animation.value);
              return Stack(
                children: [
                  Positioned(
                    left: -48 + (width + 48) * t,
                    top: 0,
                    bottom: 0,
                    width: 48,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.transparent, AppColors.white, AppColors.transparent],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
