// lib/features/premium/presentation/screens/premium_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/theme/app_theme.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _annualSelected = true;

  static const _features = [
    _Feature(icon: Icons.image_outlined, emoji: '🖼', title: 'Unlimited Images', sub: 'No daily download limit', color: AppColors.primary),
    _Feature(icon: Icons.play_circle_outline_rounded, emoji: '🎬', title: 'All Video Status', sub: 'Access every video template', color: AppColors.secondary),
    _Feature(icon: Icons.celebration_outlined, emoji: '🎉', title: 'Festival Packs', sub: 'Exclusive seasonal collections', color: Color(0xFFFF8C00)),
    _Feature(icon: Icons.person_pin_outlined, emoji: '✏️', title: 'Name & Photo Overlay', sub: 'Personalise every status you make', color: AppColors.accent),
    _Feature(icon: Icons.share_outlined, emoji: '📲', title: 'Share Anywhere', sub: 'WhatsApp, Instagram & more', color: Color(0xFF25D366)),
    _Feature(icon: Icons.block_outlined, emoji: '🚫', title: 'Zero Ads', sub: 'Clean, distraction-free experience', color: AppColors.textMuted),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Animated Background ─────────────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(gradient: AppColors.brandGradient),
              child: Stack(
                children: [
                  // Decorative orbs
                  Positioned(top: -60, right: -40, child: _Orb(size: 200, opacity: 0.12)),
                  Positioned(top: 100, left: -80, child: _Orb(size: 240, opacity: 0.08)),
                ],
              ),
            ),
          ),

          Column(
            children: [
              // ── Top Section ────────────────────────────────────────────
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // Close button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => context.pop(),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Crown + Headline
                    FadeInDown(
                      duration: const Duration(milliseconds: 500),
                      child: const Column(
                        children: [
                          Text('👑', style: TextStyle(fontSize: 52)),
                          SizedBox(height: 10),
                          Text(
                            'Status Go Premium',
                            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Unlock the full experience',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          SizedBox(height: 6),
                          // Social proof
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('⭐⭐⭐⭐⭐', style: TextStyle(fontSize: 12)),
                              SizedBox(width: 8),
                              Text('10,000+ happy users', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Plan Selector ─────────────────────────────────────
                    FadeIn(
                      duration: const Duration(milliseconds: 600),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              // Monthly
                              Expanded(child: _PlanTile(
                                label: 'Monthly',
                                price: '₹99',
                                sub: 'per month',
                                isSelected: !_annualSelected,
                                onTap: () => setState(() => _annualSelected = false),
                              )),
                              // Annual
                              Expanded(child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  _PlanTile(
                                    label: 'Annual',
                                    price: '₹799',
                                    sub: '₹66 per month',
                                    isSelected: _annualSelected,
                                    onTap: () => setState(() => _annualSelected = true),
                                  ),
                                  Positioned(
                                    top: -10, right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.warning,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [BoxShadow(color: AppColors.warning.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 2))],
                                      ),
                                      child: const Text('SAVE 33%', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black)),
                                    ),
                                  ),
                                ],
                              )),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // ── Features Sheet ─────────────────────────────────────────
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.surfaceBorder, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 20),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: List.generate(_features.length, (i) => FadeInUp(
                              duration: Duration(milliseconds: 400 + i * 60),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _FeatureRow(feature: _features[i]),
                              ),
                            )),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: Column(
                          children: [
                            // CTA Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: AppColors.brandGradient,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: AppColors.cardShadowFor(AppColors.primary),
                                ),
                                child: ElevatedButton(
                                  onPressed: () {/* Launch Razorpay */},
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                  ),
                                  child: Text(
                                    _annualSelected ? 'Start Premium — ₹799/year' : 'Start Premium — ₹99/month',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Cancel anytime · Secured by Razorpay · No hidden fees',
                              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
                          ],
                        ),
                      ),
                    ],
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

class _Orb extends StatelessWidget {
  final double size;
  final double opacity;
  const _Orb({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: Colors.white.withOpacity(opacity), shape: BoxShape.circle),
    );
  }
}

class _PlanTile extends StatelessWidget {
  final String label;
  final String price;
  final String sub;
  final bool isSelected;
  final VoidCallback onTap;
  const _PlanTile({required this.label, required this.price, required this.sub, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4))] : null,
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isSelected ? AppColors.textPrimary : Colors.white70)),
            const SizedBox(height: 4),
            Text(price, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: isSelected ? AppColors.primary : Colors.white)),
            Text(sub, style: TextStyle(fontSize: 10, color: isSelected ? AppColors.textMuted : Colors.white60)),
          ],
        ),
      ),
    );
  }
}

class _Feature {
  final IconData icon;
  final String emoji;
  final String title;
  final String sub;
  final Color color;
  const _Feature({required this.icon, required this.emoji, required this.title, required this.sub, required this.color});
}

class _FeatureRow extends StatelessWidget {
  final _Feature feature;
  const _FeatureRow({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: feature.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(child: Text(feature.emoji, style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(feature.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary)),
              const SizedBox(height: 1),
              Text(feature.sub, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
        Container(
          width: 28, height: 28,
          decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
        ),
      ],
    );
  }
}
