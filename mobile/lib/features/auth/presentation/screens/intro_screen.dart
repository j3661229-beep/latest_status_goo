// lib/features/auth/presentation/screens/intro_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_ui.dart';

/// Marks the intro as seen (settings_box) so it is only shown once.
Future<void> markIntroSeen() async {
  await Hive.box(AppConstants.hiveBoxSettings)
      .put(AppConstants.keyIntroSeen, true);
}

bool get introSeen =>
    Hive.box(AppConstants.hiveBoxSettings)
        .get(AppConstants.keyIntroSeen, defaultValue: false) ==
    true;

class _Slide {
  final String title;
  final String subtitle;
  final IconData icon;
  final IconData badgeIcon;
  final Gradient gradient;
  final Color glow;

  const _Slide({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badgeIcon,
    required this.gradient,
    required this.glow,
  });
}

const _slides = <_Slide>[
  _Slide(
    title: '1 टैप में बनाएं\nअपना स्टेटस',
    subtitle: 'हज़ारों त्योहार, सुविचार और भक्ति स्टेटस — बस पसंद का चुनें।',
    icon: Icons.touch_app_rounded,
    badgeIcon: Icons.bolt_rounded,
    gradient: AppColors.festivalGradient,
    glow: AppColors.accent,
  ),
  _Slide(
    title: 'अपनी फ़ोटो और\nनाम से बनाएं खास',
    subtitle: 'हर स्टेटस पर अपना नाम और फ़ोटो अपने-आप — सबसे अलग दिखें।',
    icon: Icons.face_retouching_natural_rounded,
    badgeIcon: Icons.auto_awesome_rounded,
    gradient: AppColors.brandGradient,
    glow: AppColors.magenta,
  ),
  _Slide(
    title: 'सीधे WhatsApp\nपर शेयर करें',
    subtitle: 'एक बटन दबाएं और स्टेटस तुरंत WhatsApp पर लगाएं।',
    icon: Icons.share_rounded,
    badgeIcon: Icons.check_circle_rounded,
    gradient: AppColors.whatsappGradient,
    glow: AppColors.whatsapp,
  ),
];

/// First-run intro (shown once before /login on a fresh install).
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _controller = PageController();
  int _page = 0;

  bool get _last => _page == _slides.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await markIntroSeen();
    if (mounted) context.go('/login');
  }

  void _next() {
    if (_last) {
      _finish();
    } else {
      _controller.nextPage(duration: AppMotion.slow, curve: AppMotion.standard);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      extendBodyBehindAppBar: false,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page, AppSpacing.xs, AppSpacing.xs, 0),
              child: Row(
                children: [
                  const AppLogo(
                      size: 40,
                      showWordmark: true,
                      horizontal: true,
                      wordmarkColor: AppColors.onDark),
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: _last ? 0 : 1,
                    duration: AppMotion.fast,
                    child: TextButton(
                      onPressed: _last ? null : _finish,
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.onDark),
                      child: const Text('छोड़ें'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.lg),
              child: Column(
                children: [
                  PageIndicator(
                    count: _slides.length,
                    index: _page,
                    activeColor: AppColors.white,
                    inactiveColor: AppColors.glassBorder,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  GradientButton(
                    label: _last ? 'शुरू करें (Get Started)' : 'आगे (Next)',
                    icon: _last
                        ? Icons.rocket_launch_rounded
                        : Icons.arrow_forward_rounded,
                    onPressed: _next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _Illustration(slide: slide),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: AppText.heading(
                size: 28,
                weight: FontWeight.w800,
                color: AppColors.onDark,
                height: 1.25),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: AppText.body(
                size: 16.5, color: AppColors.onDarkMuted, height: 1.55),
          ),
        ],
      ),
    );
  }
}

/// Phone-poster illustration built from gradients + icons.
class _Illustration extends StatelessWidget {
  final _Slide slide;
  const _Illustration({required this.slide});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: 300,
        height: 340,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  slide.glow.withValues(alpha: 0.45),
                  AppColors.transparent
                ]),
              ),
            ),
            Transform.rotate(
              angle: -0.06,
              child: Container(
                width: 190,
                height: 290,
                decoration: BoxDecoration(
                  gradient: slide.gradient,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: AppShadows.floating,
                  border: Border.all(color: AppColors.glassBorder, width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: AppColors.glassStrong),
                      child: Icon(slide.icon, size: 54, color: AppColors.white),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: 110,
                      height: 12,
                      decoration: BoxDecoration(
                          color: AppColors.glassBorder,
                          borderRadius: AppRadius.pillAll),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 74,
                      height: 12,
                      decoration: BoxDecoration(
                          color: AppColors.glass,
                          borderRadius: AppRadius.pillAll),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 24,
              child: GlassContainer(
                radius: AppRadius.pill,
                padding: const EdgeInsets.all(14),
                child: Icon(slide.badgeIcon, color: AppColors.gold, size: 30),
              ),
            ),
            Positioned(
              left: 4,
              bottom: 40,
              child: GlassContainer(
                radius: AppRadius.pill,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite_rounded,
                        color: AppColors.rose, size: 20),
                    const SizedBox(width: 6),
                    Text('1.2K',
                        style: AppText.heading(
                            size: 14, color: AppColors.white, height: 1)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
