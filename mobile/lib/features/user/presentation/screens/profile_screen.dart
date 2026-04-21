// lib/features/user/presentation/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.brandGradient),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white24,
                        child: Text('R', style: TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.w900)),
                      ),
                      SizedBox(height: 10),
                      Text('Ramesh Gupta', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      Text('FREE Plan', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats row
                  Row(
                    children: [
                      _stat('🔥', '5', 'Streak'),
                      _stat('📤', '43', 'Shares'),
                      _stat('🔖', '12', 'Saved'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Premium CTA
                  GestureDetector(
                    onTap: () => context.push('/premium'),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Text('⭐', style: TextStyle(fontSize: 28)),
                          SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Upgrade to Premium', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                              Text('Unlimited status starting ₹99/month', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          )),
                          Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Settings
                  _settingRow(Icons.language_rounded, 'Language', 'Hindi'),
                  _settingRow(Icons.notifications_rounded, 'Notifications', 'On'),
                  _settingRow(Icons.info_rounded, 'App Version', '1.0.0'),
                  _settingRow(Icons.logout_rounded, 'Sign Out', ''),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String emoji, String value, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.primary)),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _settingRow(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
          if (value.isNotEmpty) Text(value, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 18),
        ],
      ),
    );
  }
}
