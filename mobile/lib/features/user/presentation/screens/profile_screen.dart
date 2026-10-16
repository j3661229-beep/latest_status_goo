// lib/features/user/presentation/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/app_actions.dart';
import '../../../../core/utils/app_info.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../auth/presentation/providers/current_user_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with WidgetsBindingObserver {
  bool _refreshFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Refresh plan / stats from GET /user/me whenever the profile opens.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshUser(silent: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshUser(silent: true);
  }

  Future<void> _refreshUser({bool silent = false}) async {
    try {
      await ref.read(authRepositoryProvider).refreshCurrentUser();
      if (mounted && _refreshFailed) setState(() => _refreshFailed = false);
    } catch (e) {
      if (!mounted) return;
      // Cached data stays visible; a retry strip tells the user it may be out of date.
      if (!_refreshFailed) setState(() => _refreshFailed = true);
      if (!silent) AppSnack.error(context, apiErrorMessage(e));
    }
  }

  Future<void> _confirmSignOut() async {
    final ok = await ConfirmDialog.show(
      context,
      title: 'लॉगआउट करें?',
      message: 'क्या आप सचमुच ऐप से बाहर निकलना चाहते हैं?',
      confirmLabel: 'लॉगआउट',
      destructive: true,
      icon: Icons.logout_rounded,
    );
    if (!ok || !mounted) return;
    await ref.read(authRepositoryProvider).signOut();
    if (mounted) context.go('/login');
  }

  String _langLabel(String code) {
    switch (code) {
      case 'HINDI':
        return 'हिन्दी';
      case 'MARATHI':
        return 'मराठी';
      case 'ENGLISH':
        return 'English';
      case 'GUJARATI':
        return 'ગુજરાતી';
      case 'PUNJABI':
        return 'ਪੰਜਾਬੀ';
      case 'TAMIL':
        return 'தமிழ்';
      case 'TELUGU':
        return 'తెలుగు';
      default:
        return code;
    }
  }

  String _frameTypeName(String? type) {
    switch (type) {
      case 'businessClassic':
        return 'क्लासिक बिजनेस';
      case 'businessModern':
        return 'मॉडर्न बिजनेस';
      case 'political':
        return 'नेता / राजनेता';
      case 'minimal':
        return 'सादा / मिनिमल';
      default:
        return 'व्यक्तिगत फ्रेम';
    }
  }

  void _editBusiness() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _BusinessBrandingSheet(user: ref.read(currentUserProvider)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final user = ref.watch(currentUserProvider);
    final isPremium = user?.isPremium ?? false;
    final version = ref.watch(appVersionProvider).valueOrNull ?? AppConstants.appVersion;
    final language = _langLabel(user?.language ?? 'HINDI');

    final settingsBox = Hive.box(AppConstants.hiveBoxSettings);
    final userState = user?.state ?? settingsBox.get(AppConstants.keyState) as String?;
    final userRegion = user?.region ?? settingsBox.get(AppConstants.keyRegion) as String?;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppColors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () => _refreshUser(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  user: user,
                  isPremium: isPremium,
                  language: language,
                  state: userState,
                  region: userRegion,
                ),
                if (_refreshFailed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, 0),
                    child: _StaleBanner(onRetry: () => _refreshUser()),
                  ),
                const SizedBox(height: AppSpacing.md),

                // Plan promo
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                  child: FadeSlideIn(
                    index: 1,
                    child: isPremium
                        ? _PlanCard(onTap: () => context.push('/my-plan'))
                        : _PremiumPromo(onTap: () => context.push('/premium')),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Business branding
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                  child: FadeSlideIn(
                    index: 2,
                    child: _BusinessCard(
                      user: user,
                      frameName: _frameTypeName(user?.frameType),
                      onEdit: _editBusiness,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                SettingsSection(
                  title: 'मेरा खाता',
                  children: [
                    SettingsTile(
                      icon: Icons.bookmark_outline_rounded,
                      title: 'सहेजे गए स्टेटस',
                      subtitle: 'आपके पसंदीदा पोस्टर्स',
                      onTap: () => context.push('/saved'),
                    ),
                    SettingsTile(
                      icon: Icons.manage_accounts_outlined,
                      title: 'प्रोफ़ाइल संपादित करें',
                      subtitle: 'नाम, फ़ोटो और बिज़नेस जानकारी',
                      onTap: () => context.push('/edit-profile'),
                    ),
                    SettingsTile(
                      icon: Icons.edit_location_alt_outlined,
                      title: 'भाषा, राज्य व क्षेत्र',
                      subtitle: userState != null && userState.isNotEmpty
                          ? (userRegion != null && userRegion.isNotEmpty ? '$userState ($userRegion)' : userState)
                          : 'राज्य व क्षेत्र सेट करें',
                      value: language,
                      onTap: () => context.push('/profile-setup'),
                    ),
                  ],
                ),
                SettingsSection(
                  title: 'सेटिंग्स और सहायता',
                  children: [
                    SettingsTile(
                      icon: Icons.notifications_none_rounded,
                      title: 'सूचनाएं',
                      onTap: () => context.push('/notifications'),
                    ),
                    SettingsTile(
                      icon: Icons.settings_outlined,
                      title: 'सेटिंग्स',
                      onTap: () => context.push('/settings'),
                    ),
                    SettingsTile(
                      icon: Icons.workspace_premium_outlined,
                      title: 'मेरा प्लान',
                      iconColor: AppColors.goldDark,
                      onTap: () => context.push('/my-plan'),
                    ),
                    SettingsTile(
                      icon: Icons.help_outline_rounded,
                      title: 'मदद और संपर्क',
                      subtitle: 'Help & Support',
                      onTap: () => context.push('/help'),
                    ),
                    SettingsTile(
                      icon: Icons.star_outline_rounded,
                      title: 'हमें रेट करें',
                      subtitle: 'Play Store पर अपनी राय दें',
                      onTap: () => AppActions.rateApp(context),
                    ),
                    SettingsTile(
                      icon: Icons.share_outlined,
                      title: 'दोस्तों को ऐप शेयर करें',
                      onTap: () => AppActions.shareApp(),
                    ),
                  ],
                ),
                SettingsSection(
                  title: 'कानूनी और जानकारी',
                  children: [
                    SettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'गोपनीयता नीति',
                      onTap: () => context.push('/privacy-policy'),
                    ),
                    SettingsTile(
                      icon: Icons.gavel_rounded,
                      title: 'नियम और शर्तें',
                      onTap: () => context.push('/terms'),
                    ),
                    SettingsTile(
                      icon: Icons.currency_rupee_rounded,
                      title: 'रिफ़ंड नीति',
                      onTap: () => context.push('/refund-policy'),
                    ),
                    SettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: 'ऐप के बारे में',
                      value: version,
                      onTap: () => context.push('/about'),
                    ),
                  ],
                ),
                SettingsSection(
                  children: [
                    SettingsTile(
                      icon: Icons.logout_rounded,
                      title: 'लॉगआउट करें',
                      destructive: true,
                      showChevron: false,
                      onTap: _confirmSignOut,
                    ),
                  ],
                ),
                Center(
                  child: Text(
                    '${AppConstants.appName} • v$version',
                    style: AppText.body(size: 13, color: p.textMuted),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StaleBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const _StaleBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 20, color: p.textMuted),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text('प्रोफ़ाइल अपडेट नहीं हो सकी — पुराना डेटा दिख रहा है',
                style: AppText.body(size: 13.5, color: p.textSecondary, height: 1.3)),
          ),
          TextButton(onPressed: onRetry, child: const Text('फिर से')),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final UserModel? user;
  final bool isPremium;
  final String language;
  final String? state;
  final String? region;

  const _Header({
    required this.user,
    required this.isPremium,
    required this.language,
    required this.state,
    required this.region,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final displayName = user?.displayName ?? user?.name ?? 'उपयोगकर्ता';
    final contact = user?.phoneNumber ?? user?.email;
    final photo = currentUserPhotoProvider(serverPhoto: user?.profilePhoto);
    final location = (state != null && state!.isNotEmpty)
        ? (region != null && region!.isNotEmpty ? '$state ($region)' : state!)
        : null;

    return Container(
      padding: EdgeInsets.fromLTRB(AppSpacing.page, top + AppSpacing.xs, AppSpacing.page, AppSpacing.lg),
      decoration: const BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text('मेरी प्रोफ़ाइल', style: AppText.heading(size: 20, color: AppColors.white)),
              ),
              AppIconButton(
                icon: Icons.settings_rounded,
                semanticLabel: 'सेटिंग्स',
                glass: true,
                onPressed: () => context.push('/settings'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          PressableScale(
            onTap: () => context.push('/edit-profile'),
            semanticLabel: 'प्रोफ़ाइल संपादित करें',
            child: SizedBox(
              width: 112,
              height: 112,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.white),
                      child: AppAvatar(image: photo, name: displayName, radius: 48),
                    ),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.premiumGradient,
                        border: Border.all(color: AppColors.white, width: 2.5),
                      ),
                      child: const Icon(Icons.edit_rounded, size: 18, color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppText.heading(size: 22, color: AppColors.white),
          ),
          if (contact != null && contact.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                contact,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(size: 14.5, color: AppColors.white.withValues(alpha: 0.85)),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _PlanBadge(isPremium: isPremium),
              _GlassChip(icon: Icons.translate_rounded, label: language),
              if (location != null) _GlassChip(icon: Icons.location_on_rounded, label: location),
            ],
          ),
          if (user != null) ...[
            const SizedBox(height: AppSpacing.md),
            GlassContainer(
              radius: AppRadius.lg,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    _Stat(icon: Icons.local_fire_department_rounded, value: user!.streakCount, label: 'दिन स्ट्रीक'),
                    const _StatDivider(),
                    _Stat(icon: Icons.share_rounded, value: user!.totalShares, label: 'कुल शेयर'),
                    const _StatDivider(),
                    _Stat(icon: Icons.bookmark_rounded, value: user!.totalSaves, label: 'सहेजे गए'),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  final bool isPremium;
  const _PlanBadge({required this.isPremium});

  @override
  Widget build(BuildContext context) {
    if (isPremium) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(gradient: AppColors.premiumGradient, borderRadius: AppRadius.pillAll),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.workspace_premium_rounded, size: 18, color: AppColors.ink),
            const SizedBox(width: 5),
            Text('प्रीमियम', style: AppText.body(size: 13.5, weight: FontWeight.w800, color: AppColors.ink, height: 1.2)),
          ],
        ),
      );
    }
    return const _GlassChip(icon: Icons.person_outline_rounded, label: 'फ्री प्लान');
  }
}

class _GlassChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _GlassChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.glassStrong,
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.white),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(size: 13.5, weight: FontWeight.w700, color: AppColors.white, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  const _Stat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: '$label: $value',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: AppColors.gold),
            const SizedBox(height: 2),
            Text(
              formatCount(value),
              style: AppText.heading(size: 20, color: AppColors.white, height: 1.15),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppText.body(size: 12.5, weight: FontWeight.w600, color: AppColors.white.withValues(alpha: 0.85), height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, margin: const EdgeInsets.symmetric(vertical: 6), color: AppColors.glassBorder);
}

// ─── Cards ────────────────────────────────────────────────────────────────────

class _PremiumPromo extends StatelessWidget {
  final VoidCallback onTap;
  const _PremiumPromo({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      semanticLabel: 'Premium लें',
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: AppColors.premiumGradient,
          borderRadius: AppRadius.lgAll,
          boxShadow: AppShadows.premiumGlow,
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.ink),
              child: const Icon(Icons.workspace_premium_rounded, color: AppColors.gold, size: 30),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Premium लें', style: AppText.heading(size: 19, color: AppColors.ink)),
                  Text(
                    'सभी प्रीमियम टेम्पलेट अनलॉक करें',
                    style: AppText.body(size: 14, weight: FontWeight.w600, color: AppColors.ink, height: 1.3),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: AppColors.ink),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final VoidCallback onTap;
  const _PlanCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PressableScale(
      onTap: onTap,
      semanticLabel: 'मेरा प्लान',
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: AppColors.gold, width: 1.6),
          boxShadow: AppShadows.subtle,
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.premiumGradient),
              child: const Icon(Icons.workspace_premium_rounded, color: AppColors.ink, size: 28),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('मेरा प्लान', style: AppText.heading(size: 18, color: p.textPrimary)),
                  Text(
                    'आप प्रीमियम सदस्य हैं — प्लान की जानकारी देखें',
                    style: AppText.body(size: 14, color: p.textMuted, height: 1.3),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: p.textHint),
          ],
        ),
      ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  final UserModel? user;
  final String frameName;
  final VoidCallback onEdit;
  const _BusinessCard({required this.user, required this.frameName, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final name = user?.businessName;
    final has = name != null && name.trim().isNotEmpty;
    final logo = photoImageProvider(user?.businessLogo);

    if (!has) {
      return PressableScale(
        onTap: onEdit,
        semanticLabel: 'बिजनेस ब्रांडिंग जोड़ें',
        scale: 0.98,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: p.primarySurface, borderRadius: AppRadius.mdAll),
                child: Icon(Icons.storefront_outlined, color: p.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('बिजनेस ब्रांडिंग जोड़ें', style: AppText.heading(size: 16.5, color: p.textPrimary)),
                    Text(
                      'दुकान का नाम, नंबर और पता अपने स्टेटस पर लगाएं',
                      style: AppText.body(size: 13.5, color: p.textMuted, height: 1.3),
                    ),
                  ],
                ),
              ),
              Icon(Icons.add_circle_rounded, color: p.primary, size: 28),
            ],
          ),
        ),
      );
    }

    final phone = user?.businessPhone;
    final tagline = user?.businessDesignation;
    final address = user?.businessAddress;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: p.border),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: p.primarySurface,
                  borderRadius: AppRadius.mdAll,
                  image: logo == null ? null : DecorationImage(image: logo, fit: BoxFit.cover, onError: (_, __) {}),
                ),
                child: logo == null ? Icon(Icons.storefront_rounded, color: p.primary, size: 28) : null,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.heading(size: 17, color: p.textPrimary, height: 1.25),
                    ),
                    if (tagline != null && tagline.trim().isNotEmpty)
                      Text(tagline, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 14, color: p.textMuted)),
                  ],
                ),
              ),
              AppIconButton(
                icon: Icons.edit_rounded,
                semanticLabel: 'बिजनेस जानकारी बदलें',
                filled: true,
                onPressed: onEdit,
              ),
            ],
          ),
          if (phone != null && phone.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _InfoRow(icon: Icons.phone_rounded, text: phone),
          ],
          if (address != null && address.isNotEmpty) ...[
            const SizedBox(height: 6),
            _InfoRow(icon: Icons.location_on_rounded, text: address),
          ],
          const SizedBox(height: 6),
          _InfoRow(icon: Icons.crop_portrait_rounded, text: frameName),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: p.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: AppText.body(size: 14.5, color: p.textSecondary, height: 1.3))),
      ],
    );
  }
}

// ─── Business branding sheet ──────────────────────────────────────────────────

class _BusinessBrandingSheet extends ConsumerStatefulWidget {
  final UserModel? user;
  const _BusinessBrandingSheet({required this.user});

  @override
  ConsumerState<_BusinessBrandingSheet> createState() => _BusinessBrandingSheetState();
}

class _BusinessBrandingSheetState extends ConsumerState<_BusinessBrandingSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _desigController;
  late final TextEditingController _addressController;
  late String _selectedFrameType;
  bool _isSaving = false;

  static const _frames = <(String, String)>[
    ('personal', 'व्यक्तिगत'),
    ('businessClassic', 'क्लासिक बिजनेस'),
    ('businessModern', 'मॉडर्न बिजनेस'),
    ('political', 'नेता / राजनेता'),
    ('minimal', 'मिनिमल'),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.businessName ?? '');
    _phoneController = TextEditingController(text: widget.user?.businessPhone ?? widget.user?.phoneNumber ?? '');
    _desigController = TextEditingController(text: widget.user?.businessDesignation ?? '');
    _addressController = TextEditingController(text: widget.user?.businessAddress ?? '');
    final ft = widget.user?.frameType ?? 'personal';
    _selectedFrameType = _frames.any((f) => f.$1 == ft) ? ft : 'personal';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _desigController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      // Persists the server copy (PUT /user/me); currentUserProvider rebuilds
      // automatically from the session store.
      await ref.read(authRepositoryProvider).updateBusinessBranding(
            businessName: _nameController.text.trim(),
            businessPhone: _phoneController.text.trim(),
            businessDesignation: _desigController.text.trim(),
            businessAddress: _addressController.text.trim(),
            frameType: _selectedFrameType,
          );
      if (!mounted) return;
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),
                SizedBox(width: 12),
                Expanded(child: Text('बिजनेस जानकारी सुरक्षित हो गई!')),
              ],
            ),
          ),
        );
    } catch (e) {
      if (mounted) {
        AppSnack.error(context, 'सेव करने में समस्या आई: ${apiErrorMessage(e)}');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final p = context.palette;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(),
          const SheetHeader(
            title: 'बिजनेस ब्रांडिंग और फ्रेम',
            subtitle: 'यह जानकारी आपके पोस्टर्स के निचले हिस्से में दिखेगी',
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('फ्रेम स्टाइल चुनें', style: AppText.body(size: 14.5, weight: FontWeight.w700, color: p.textPrimary)),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final f in _frames)
                        CategoryChip(
                          label: f.$2,
                          selected: _selectedFrameType == f.$1,
                          onTap: () => setState(() => _selectedFrameType = f.$1),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _nameController,
                    label: 'दुकान / बिजनेस का नाम',
                    hint: 'उदा. शर्मा इलेक्ट्रॉनिक्स',
                    prefixIcon: Icons.storefront_outlined,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: _phoneController,
                    label: 'फोन / WhatsApp नंबर',
                    hint: '+91 98765 43210',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: _desigController,
                    label: 'पद / टैगलाइन',
                    hint: 'उदा. प्रोपराइटर / संचालक',
                    prefixIcon: Icons.badge_outlined,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: _addressController,
                    label: 'पता / शहर',
                    hint: 'उदा. मेन मार्केट, इंदौर',
                    prefixIcon: Icons.location_on_outlined,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  GradientButton(label: 'सुरक्षित करें', isLoading: _isSaving, onPressed: _save),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
