// lib/features/premium/presentation/screens/premium_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/current_user_provider.dart';

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  bool _annualSelected = true;
  bool _isLoading = false;

  static const _features = [
    _FeatureItem(
      title: 'असीमित स्टेटस डाउनलोड',
      sub: 'बिना किसी दैनिक सीमा के जितने चाहें उतने पोस्टर सेव करें',
      icon: Icons.download_done_rounded,
    ),
    _FeatureItem(
      title: 'सभी वीडियो स्टेटस अनलॉक',
      sub: 'सुप्रभात, त्यौहार और प्रेरणादायक वीडियो स्टेटस बनाएं',
      icon: Icons.play_circle_filled_rounded,
    ),
    _FeatureItem(
      title: 'त्यौहार एवं विशेष संग्रह',
      sub: 'दिवाली, होली, रक्षाबंधन, नवरात्रि के एक्सक्लूसिव पोस्टर्स',
      icon: Icons.celebration_rounded,
    ),
    _FeatureItem(
      title: 'बिजनेस और व्यक्तिगत फ्रेम',
      sub: 'अपनी दुकान, व्यवसाय या राजनीतिक पद के आकर्षक फ्रेम',
      icon: Icons.badge_rounded,
    ),
    _FeatureItem(
      title: 'कोई विज्ञापन नहीं (No Ads)',
      sub: 'साफ, तेज और बिना किसी रुकावट का अनुभव',
      icon: Icons.block_rounded,
    ),
    _FeatureItem(
      title: 'सीधे व्हाट्सएप स्टेटस पर शेयर',
      sub: 'एक क्लिक में अपने संपर्कों के साथ साझा करें',
      icon: Icons.chat_bubble_rounded,
    ),
  ];

  Future<void> _initiateCheckout() async {
    setState(() => _isLoading = true);
    final plan = _annualSelected ? 'ANNUAL' : 'PREMIUM';

    try {
      final res = await apiClient.post('/subscribe/create', data: {'plan': plan});
      if (res.statusCode == 200 && mounted) {
        final data = res.data;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.verified, color: AppColors.success, size: 24),
                const SizedBox(width: 8),
                Text('ऑर्डर तैयार है', style: GoogleFonts.hind(fontWeight: FontWeight.w700)),
              ],
            ),
            content: Text(
              'Razorpay ऑर्डर आईडी: ${data['orderId'] ?? 'Order Created'}\nराशि: ₹${data['amount'] != null ? (data['amount'] / 100).toInt() : (_annualSelected ? '799' : '99')}',
              style: GoogleFonts.hind(fontSize: 15),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ref.invalidate(currentUserProvider);
                },
                child: Text('ठीक है (OK)', style: GoogleFonts.hind(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('भुगतान शुरू करने में समस्या आई: $e', style: GoogleFonts.hind()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          'प्रीमियम सदस्यता',
          style: GoogleFonts.hind(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Header Banner
            Container(
              color: AppColors.primary,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 44),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Status Go VIP सदस्य बनें',
                    style: GoogleFonts.hind(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'हर दिन अपने नाम और फोटो के साथ शानदार स्टेटस बनाएं',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.hind(color: Colors.white.withOpacity(0.9), fontSize: 15),
                  ),
                ],
              ),
            ),

            // Plan Selection Cards
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'अपनी पसंद का प्लान चुनें',
                    style: GoogleFonts.hind(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),

                  // Annual Plan (Featured)
                  GestureDetector(
                    onTap: () => setState(() => _annualSelected = true),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _annualSelected ? AppColors.primarySurface : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _annualSelected ? AppColors.primary : AppColors.surfaceBorder,
                          width: _annualSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _annualSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: _annualSelected ? AppColors.primary : AppColors.textMuted,
                            size: 24,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '1 साल का प्लान (वार्षिक)',
                                      style: GoogleFonts.hind(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.accent,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '33% बचत',
                                        style: GoogleFonts.hind(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'मात्र ₹66 प्रति माह (₹799 पूरे साल के लिए)',
                                  style: GoogleFonts.hind(color: AppColors.textSecondary, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₹799',
                            style: GoogleFonts.hind(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Monthly Plan
                  GestureDetector(
                    onTap: () => setState(() => _annualSelected = false),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: !_annualSelected ? AppColors.primarySurface : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: !_annualSelected ? AppColors.primary : AppColors.surfaceBorder,
                          width: !_annualSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            !_annualSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: !_annualSelected ? AppColors.primary : AppColors.textMuted,
                            size: 24,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '1 महीने का प्लान (मासिक)',
                                  style: GoogleFonts.hind(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'हर महीने नवीनीकरण (Cancel anytime)',
                                  style: GoogleFonts.hind(color: AppColors.textSecondary, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₹99',
                            style: GoogleFonts.hind(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Features Checklist
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'प्रीमियम में क्या-क्या मिलेगा:',
                      style: GoogleFonts.hind(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    ..._features.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle, color: AppColors.success, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  f.title,
                                  style: GoogleFonts.hind(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
                                ),
                                Text(
                                  f.sub,
                                  style: GoogleFonts.hind(fontSize: 13, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // CTA Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _initiateCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text(
                          _annualSelected ? 'प्रीमियम शुरू करें — ₹799 / वर्ष' : 'प्रीमियम शुरू करें — ₹99 / माह',
                          style: GoogleFonts.hind(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  '100% सुरक्षित भुगतान · Razorpay द्वारा सुरक्षित',
                  style: GoogleFonts.hind(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem {
  final String title;
  final String sub;
  final IconData icon;

  const _FeatureItem({
    required this.title,
    required this.sub,
    required this.icon,
  });
}
