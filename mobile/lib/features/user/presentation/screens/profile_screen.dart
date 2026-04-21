// lib/features/user/presentation/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/providers/current_user_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final displayName = user?.displayName ?? user?.name ?? 'User';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    final isPremium = user?.isPremium ?? false;
    final language = _langLabel(user?.language ?? 'HINDI');

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // ── Profile Header ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(gradient: AppColors.brandGradient),
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 28),
              child: FadeInDown(
                duration: const Duration(milliseconds: 600),
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        color: Colors.white.withOpacity(0.2),
                        image: user?.profilePhoto != null
                            ? DecorationImage(
                                image: NetworkImage(user!.profilePhoto!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: user?.profilePhoto == null
                          ? Center(
                              child: Text(
                                initial,
                                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      displayName,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    if (user?.email != null || user?.phoneNumber != null)
                      Text(
                        user?.email ?? user?.phoneNumber ?? '',
                        style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13),
                      ),
                    const SizedBox(height: 14),
                    // Plan + Language badges
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _PillBadge(
                          text: isPremium ? '⭐ Premium' : '🆓 Free Plan',
                          color: isPremium ? AppColors.warning : Colors.white.withOpacity(0.25),
                          textColor: isPremium ? Colors.black : Colors.white,
                        ),
                        const SizedBox(width: 10),
                        _PillBadge(
                          text: '🌐 $language',
                          color: Colors.white.withOpacity(0.2),
                          textColor: Colors.white,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Stats Row ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeIn(
              duration: const Duration(milliseconds: 700),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.surfaceBorder),
                  boxShadow: AppColors.cardShadow,
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _StatTile(
                      emoji: '🔥',
                      value: user?.streakCount.toString() ?? '0',
                      label: 'Day Streak',
                    ),
                    _VerticalDivider(),
                    _StatTile(
                      emoji: '📤',
                      value: user?.totalShares.toString() ?? '0',
                      label: 'Shares',
                    ),
                    _VerticalDivider(),
                    _StatTile(
                      emoji: '🔖',
                      value: user?.totalSaves.toString() ?? '0',
                      label: 'Saved',
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Premium CTA (if not premium) ────────────────────────────────
          if (!isPremium)
            SliverToBoxAdapter(
              child: FadeInUp(
                duration: const Duration(milliseconds: 700),
                child: GestureDetector(
                  onTap: () => context.push('/premium'),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppColors.cardShadowFor(AppColors.primary),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                          child: const Text('⭐', style: TextStyle(fontSize: 22)),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Upgrade to Premium', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                              Text('Unlimited status · Starting ₹99/month', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Settings Sections ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeInUp(
              duration: const Duration(milliseconds: 800),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _SectionLabel('Account'),
                    _SettingsCard(children: [
                      _SettingRow(icon: Icons.person_outline_rounded, label: 'Edit Profile', onTap: () {}),
                      _SettingRow(icon: Icons.language_rounded, label: 'Language', value: language, onTap: () {}),
                      _SettingRow(icon: Icons.notifications_outlined, label: 'Notifications', value: 'On', onTap: () {}),
                    ]),

                    const SizedBox(height: 16),
                    _SectionLabel('Support'),
                    _SettingsCard(children: [
                      _SettingRow(icon: Icons.help_outline_rounded, label: 'Help & FAQ', onTap: () {}),
                      _SettingRow(icon: Icons.star_outline_rounded, label: 'Rate the App', onTap: () {}),
                      _SettingRow(icon: Icons.share_outlined, label: 'Share with Friends', onTap: () {}),
                    ]),

                    const SizedBox(height: 16),
                    _SectionLabel('About'),
                    _SettingsCard(children: [
                      _SettingRow(icon: Icons.info_outline_rounded, label: 'App Version', value: '1.0.0', onTap: null),
                      _SettingRow(icon: Icons.privacy_tip_outlined, label: 'Privacy Policy', onTap: () {}),
                    ]),

                    const SizedBox(height: 16),
                    // Sign Out
                    GestureDetector(
                      onTap: () async {
                        await ref.read(authRepositoryProvider).signOut();
                        if (context.mounted) context.go('/login');
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.danger.withOpacity(0.15)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout_rounded, color: AppColors.danger, size: 20),
                            SizedBox(width: 10),
                            Text('Sign Out', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800, fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _langLabel(String code) {
    switch (code) {
      case 'HINDI': return 'Hindi';
      case 'MARATHI': return 'Marathi';
      case 'ENGLISH': return 'English';
      default: return code;
    }
  }
}

class _PillBadge extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;
  const _PillBadge({required this.text, required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  const _StatTile({required this.emoji, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.primary)),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 50, color: AppColors.surfaceBorder);
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 1),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: List.generate(children.length, (i) {
          if (i == children.length - 1) return children[i];
          return Column(
            children: [
              children[i],
              const Divider(height: 1, color: AppColors.surfaceBorder, indent: 56),
            ],
          );
        }),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  const _SettingRow({required this.icon, required this.label, this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary))),
            if (value != null)
              Text(value!, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(width: 8),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
