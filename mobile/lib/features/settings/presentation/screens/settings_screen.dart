// lib/features/settings/presentation/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../../core/utils/app_actions.dart';
import '../../../../core/utils/app_info.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/providers/current_user_provider.dart';
import '../../../auth/presentation/screens/profile_setup_screen.dart' show kAppLanguages, AppLanguage;
import '../../../home/presentation/providers/home_data_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Box get _box => Hive.box(AppConstants.hiveBoxSettings);

  late bool _push = NotificationService.instance.isPushOptedIn;
  late bool _daily = _box.get(AppConstants.keyDailyReminder, defaultValue: true) == true;
  late bool _festival = _box.get(AppConstants.keyFestivalAlerts, defaultValue: true) == true;
  bool _busy = false;

  AppLanguage _languageFor(String code) =>
      kAppLanguages.firstWhere((l) => l.code == code, orElse: () => kAppLanguages.first);

  Future<void> _togglePush(bool v) async {
    final result = await NotificationService.instance.setPushEnabled(v);
    if (!mounted) return;
    setState(() => _push = result);
    await _box.put(AppConstants.keyPushEnabled, result);
    if (v && !result && mounted) {
      AppSnack.info(context, 'सूचनाएं चालू करने के लिए फ़ोन की सेटिंग्स में अनुमति दें।');
    }
  }

  Future<void> _toggleDaily(bool v) async {
    setState(() => _daily = v);
    await _box.put(AppConstants.keyDailyReminder, v);
    await NotificationService.instance.setPreferenceTag('daily_reminder', v);
  }

  Future<void> _toggleFestival(bool v) async {
    setState(() => _festival = v);
    await _box.put(AppConstants.keyFestivalAlerts, v);
    await NotificationService.instance.setPreferenceTag('festival_alerts', v);
  }

  Future<void> _pickLanguage(String current) async {
    final selected = await AppBottomSheet.show<String>(
      context,
      title: 'भाषा चुनें (Language)',
      subtitle: 'आपके स्टेटस इसी भाषा में दिखेंगे',
      builder: (ctx) => Column(
        children: [
          for (final l in kAppLanguages)
            _LanguageOption(
              language: l,
              selected: l.code == current,
              onTap: () => Navigator.of(ctx).pop(l.code),
            ),
        ],
      ),
    );
    if (selected == null || selected == current || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).updateLanguage(selected);
      ref.invalidate(homeDataProvider); // reload the feed in the new language
      if (mounted) AppSnack.success(context, 'भाषा बदल दी गई: ${_languageFor(selected).name}');
    } catch (e) {
      if (mounted) AppSnack.error(context, apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
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

  Future<void> _deleteAccount() async {
    final user = ref.read(currentUserProvider);
    final hasPlan = user?.isPremium ?? false;
    final ok = await ConfirmDialog.show(
      context,
      title: 'खाता हमेशा के लिए हटाएं?',
      message: 'आपका नाम, फ़ोटो, बिज़नेस जानकारी, सेव किए गए स्टेटस और सूचनाएं हटा दी जाएंगी और आप लॉगआउट हो जाएंगे। '
          'यह कार्य वापस नहीं हो सकता।',
      confirmLabel: 'हाँ, खाता हटाएं',
      cancelLabel: 'नहीं, रहने दें',
      destructive: true,
      icon: Icons.delete_forever_rounded,
      extra: hasPlan
          ? const InfoCard(
              tone: InfoTone.warning,
              message: 'आपका प्रीमियम प्लान भी समाप्त हो जाएगा और उसका रिफ़ंड नहीं मिलेगा।',
            )
          : null,
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      if (!mounted) return;
      context.go('/login');
    } catch (e) {
      if (mounted) {
        AppSnack.error(context, apiErrorMessage(e, fallback: 'खाता नहीं हटाया जा सका। कृपया बाद में कोशिश करें।'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);
    final version = ref.watch(appVersionProvider).valueOrNull ?? AppConstants.appVersion;
    final langCode = user?.language ?? 'HINDI';
    final name = user?.displayName ?? user?.name;
    final contact = user?.phoneNumber ?? user?.email;

    return AppScaffold(
      title: 'सेटिंग्स',
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.xxl),
            children: [
              // Profile summary
              FadeSlideIn(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.lg),
                  child: PressableScale(
                    onTap: () => context.push('/edit-profile'),
                    semanticLabel: 'प्रोफ़ाइल संपादित करें',
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: AppRadius.xlAll,
                        boxShadow: AppShadows.primaryGlow,
                      ),
                      child: Row(
                        children: [
                          AppAvatar(
                            image: currentUserPhotoProvider(serverPhoto: user?.profilePhoto),
                            name: name,
                            radius: 30,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name ?? 'उपयोगकर्ता',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.heading(size: 19, color: AppColors.white),
                                ),
                                if (contact != null)
                                  Text(
                                    contact,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.body(size: 14, color: AppColors.white, height: 1.4),
                                  ),
                                const SizedBox(height: 6),
                                if (user?.isPremium ?? false)
                                  const PremiumBadge(compact: true)
                                else
                                  Text(
                                    'प्रोफ़ाइल संपादित करें',
                                    style: AppText.body(size: 13.5, weight: FontWeight.w700, color: AppColors.white),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.white),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              FadeSlideIn(
                index: 1,
                child: SettingsSection(
                  title: 'खाता (ACCOUNT)',
                  children: [
                    SettingsTile(
                      icon: Icons.person_outline_rounded,
                      title: 'प्रोफ़ाइल संपादित करें',
                      subtitle: 'नाम, फ़ोटो, राज्य, बिज़नेस ब्रांडिंग',
                      onTap: () => context.push('/edit-profile'),
                    ),
                    SettingsTile(
                      icon: Icons.workspace_premium_rounded,
                      iconColor: AppColors.goldDark,
                      title: 'मेरा प्लान',
                      subtitle: (user?.isPremium ?? false) ? 'प्रीमियम सक्रिय' : 'फ़्री प्लान',
                      onTap: () => context.push('/my-plan'),
                    ),
                  ],
                ),
              ),

              FadeSlideIn(
                index: 2,
                child: SettingsSection(
                  title: 'भाषा और दिखावट (PREFERENCES)',
                  children: [
                    SettingsTile(
                      icon: Icons.translate_rounded,
                      title: 'भाषा (Language)',
                      value: _languageFor(langCode).name,
                      onTap: _busy ? null : () => _pickLanguage(langCode),
                    ),
                    _ThemeTile(
                      mode: themeMode,
                      onChanged: (m) => ref.read(themeModeProvider.notifier).setMode(m),
                    ),
                  ],
                ),
              ),

              FadeSlideIn(
                index: 3,
                child: SettingsSection(
                  title: 'सूचनाएं (NOTIFICATIONS)',
                  children: [
                    LabeledSwitchTile(
                      icon: Icons.notifications_active_outlined,
                      title: 'पुश सूचनाएं',
                      subtitle: 'नए स्टेटस और ऑफ़र की सूचना',
                      value: _push,
                      onChanged: _togglePush,
                    ),
                    LabeledSwitchTile(
                      icon: Icons.wb_sunny_outlined,
                      title: 'रोज़ सुबह की याद',
                      subtitle: 'हर सुबह नया स्टेटस',
                      value: _daily,
                      onChanged: _push ? _toggleDaily : null,
                    ),
                    LabeledSwitchTile(
                      icon: Icons.celebration_outlined,
                      title: 'त्योहार अलर्ट',
                      subtitle: 'त्योहार से पहले शुभकामना स्टेटस',
                      value: _festival,
                      onChanged: _push ? _toggleFestival : null,
                    ),
                    SettingsTile(
                      icon: Icons.inbox_outlined,
                      title: 'सूचना इनबॉक्स',
                      onTap: () => context.push('/notifications'),
                    ),
                  ],
                ),
              ),

              FadeSlideIn(
                index: 4,
                child: SettingsSection(
                  title: 'गोपनीयता और कानूनी (PRIVACY & LEGAL)',
                  children: [
                    SettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'गोपनीयता नीति',
                      subtitle: 'Privacy Policy',
                      onTap: () => context.push('/privacy-policy'),
                    ),
                    SettingsTile(
                      icon: Icons.gavel_rounded,
                      title: 'नियम और शर्तें',
                      subtitle: 'Terms & Conditions',
                      onTap: () => context.push('/terms'),
                    ),
                    SettingsTile(
                      icon: Icons.currency_rupee_rounded,
                      title: 'रिफ़ंड नीति',
                      subtitle: 'Refund & Cancellation',
                      onTap: () => context.push('/refund-policy'),
                    ),
                  ],
                ),
              ),

              FadeSlideIn(
                index: 5,
                child: SettingsSection(
                  title: 'सहायता (SUPPORT)',
                  children: [
                    SettingsTile(
                      icon: Icons.help_outline_rounded,
                      title: 'मदद और FAQ',
                      onTap: () => context.push('/help'),
                    ),
                    SettingsTile(
                      icon: Icons.mail_outline_rounded,
                      title: 'हमसे संपर्क करें',
                      subtitle: AppConstants.supportEmail,
                      onTap: () => AppActions.email(context, subject: '${AppConstants.appName} support'),
                    ),
                    SettingsTile(
                      icon: Icons.star_outline_rounded,
                      iconColor: AppColors.goldDark,
                      title: 'ऐप को रेट करें',
                      onTap: () => AppActions.rateApp(context),
                    ),
                    SettingsTile(
                      icon: Icons.share_outlined,
                      title: 'दोस्तों को ऐप शेयर करें',
                      onTap: AppActions.shareApp,
                    ),
                  ],
                ),
              ),

              FadeSlideIn(
                index: 6,
                child: SettingsSection(
                  title: 'ऐप के बारे में (ABOUT)',
                  children: [
                    SettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: 'Status Go के बारे में',
                      value: version,
                      onTap: () => context.push('/about'),
                    ),
                  ],
                ),
              ),

              FadeSlideIn(
                index: 7,
                child: SettingsSection(
                  title: 'खाता प्रबंधन (DANGER ZONE)',
                  children: [
                    SettingsTile(
                      icon: Icons.logout_rounded,
                      title: 'लॉगआउट',
                      destructive: true,
                      showChevron: false,
                      onTap: _busy ? null : _logout,
                    ),
                    SettingsTile(
                      icon: Icons.delete_forever_rounded,
                      title: 'खाता हटाएं (Delete Account)',
                      subtitle: 'सारा डेटा हमेशा के लिए हटेगा',
                      destructive: true,
                      showChevron: false,
                      onTap: _busy ? null : _deleteAccount,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: AppColors.scrim,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final AppLanguage language;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageOption({required this.language, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: PressableScale(
        onTap: onTap,
        semanticLabel: language.name,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? p.primarySurface : p.surface,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: selected ? p.primary : p.border, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Text(language.flag, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(language.name, style: AppText.heading(size: 17, color: p.textPrimary)),
                    Text(language.english, style: AppText.body(size: 13.5, color: p.textMuted, height: 1.3)),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle_rounded, color: p.primary, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeTile({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: p.primarySurface, borderRadius: AppRadius.smAll),
                child: Icon(Icons.brightness_6_outlined, color: p.primary, size: 22),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'थीम (Appearance)',
                  style: AppText.body(size: 16, weight: FontWeight.w600, color: p.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              CategoryChip(
                label: 'सिस्टम',
                icon: Icons.phone_android_rounded,
                selected: mode == ThemeMode.system,
                onTap: () => onChanged(ThemeMode.system),
              ),
              CategoryChip(
                label: 'लाइट',
                icon: Icons.light_mode_rounded,
                selected: mode == ThemeMode.light,
                onTap: () => onChanged(ThemeMode.light),
              ),
              CategoryChip(
                label: 'डार्क',
                icon: Icons.dark_mode_rounded,
                selected: mode == ThemeMode.dark,
                onTap: () => onChanged(ThemeMode.dark),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
