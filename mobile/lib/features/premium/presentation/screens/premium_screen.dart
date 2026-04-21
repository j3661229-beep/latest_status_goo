// lib/features/premium/presentation/screens/premium_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _annualSelected = true;

  final _features = [
    {'icon': '🖼', 'title': 'Unlimited Images', 'sub': 'No daily download limit'},
    {'icon': '🎬', 'title': 'Unlimited Videos', 'sub': 'All video status templates'},
    {'icon': '🎉', 'title': 'Festival Packs', 'sub': 'Exclusive festival collections'},
    {'icon': '✏️', 'title': 'Custom Name & Photo', 'sub': 'Personalise every status'},
    {'icon': '📲', 'title': 'Share Anywhere', 'sub': 'WhatsApp, Facebook, Instagram'},
    {'icon': '🚫', 'title': 'No Ads', 'sub': 'Clean, distraction-free experience'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(height: 320, decoration: const BoxDecoration(gradient: AppColors.brandGradient)),

          Column(
            children: [
              // Top bar
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Crown & headline
              const Text('⭐', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              const Text('Status Go Premium', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('Unlimited status, zero restrictions', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
              const SizedBox(height: 24),

              // Plan cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Monthly
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _annualSelected = false),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _annualSelected ? Colors.white.withOpacity(0.15) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: !_annualSelected ? Border.all(color: AppColors.primary, width: 2) : null,
                          ),
                          child: Column(
                            children: [
                              Text('Monthly', style: TextStyle(fontWeight: FontWeight.w800, color: _annualSelected ? Colors.white : AppColors.textPrimary, fontSize: 13)),
                              const SizedBox(height: 6),
                              Text('₹99', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: _annualSelected ? Colors.white : AppColors.primary)),
                              Text('/month', style: TextStyle(fontSize: 10, color: _annualSelected ? Colors.white60 : AppColors.textMuted)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Annual (best value)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _annualSelected = true),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _annualSelected ? Colors.white : Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: _annualSelected ? Border.all(color: AppColors.primary, width: 2) : null,
                              ),
                              child: Column(
                                children: [
                                  Text('Annual', style: TextStyle(fontWeight: FontWeight.w800, color: _annualSelected ? AppColors.textPrimary : Colors.white, fontSize: 13)),
                                  const SizedBox(height: 6),
                                  Text('₹799', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: _annualSelected ? AppColors.primary : Colors.white)),
                                  Text('₹66/mo', style: TextStyle(fontSize: 10, color: _annualSelected ? AppColors.textMuted : Colors.white60)),
                                ],
                              ),
                            ),
                            // Best value badge
                            Positioned(
                              top: -10, right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.warning,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('Save 33%', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.black)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Features
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
                  ),
                  child: Column(
                    children: [
                      ...(_features.map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          children: [
                            Text(f['icon']!, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(f['title']!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                  Text(f['sub']!, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                ],
                              ),
                            ),
                            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                          ],
                        ),
                      ))),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {/* Launch Razorpay */},
                          child: Text(
                            _annualSelected ? 'Get Premium — ₹799/year' : 'Get Premium — ₹99/month',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Cancel anytime · Secure payment via Razorpay',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        textAlign: TextAlign.center,
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
