// lib/features/support/presentation/screens/about_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/app_actions.dart';
import '../../../../core/utils/app_info.dart';
import '../../../../core/widgets/app_ui.dart';

/// About / app info. Public (works while logged out).
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final version = ref.watch(appVersionProvider).valueOrNull ?? AppConstants.appVersion;

    return AppScaffold(
      title: 'ऐप के बारे में',
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          FadeSlideIn(
            child: Container(
              margin: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.lg),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: AppColors.brandSoftGradient,
                borderRadius: AppRadius.xlAll,
                border: Border.all(color: p.border),
              ),
              child: Column(
                children: [
                  const AppLogo(size: 88, showWordmark: true),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'रोज़ बनाएं अपना खास स्टेटस',
                    textAlign: TextAlign.center,
                    style: AppText.heading(size: 18, color: AppColors.ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Make your daily WhatsApp status with your name & photo',
                    textAlign: TextAlign.center,
                    style: AppText.body(size: 14, color: AppColors.textMuted, height: 1.4),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  StatPill(icon: Icons.verified_rounded, value: 'v$version', color: p.primary),
                ],
              ),
            ),
          ),
          SettingsSection(
            title: 'कानूनी (LEGAL)',
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
                icon: Icons.code_rounded,
                title: 'ओपन-सोर्स लाइसेंस',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: AppConstants.appName,
                  applicationVersion: version,
                  applicationIcon: const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: AppLogo(size: 56),
                  ),
                ),
              ),
            ],
          ),
          SettingsSection(
            title: 'हमारे साथ जुड़ें',
            children: [
              SettingsTile(
                icon: Icons.star_rounded,
                iconColor: AppColors.goldDark,
                title: 'हमें रेट करें',
                subtitle: 'Play Store पर 5 स्टार दें',
                onTap: () => AppActions.rateApp(context),
              ),
              SettingsTile(
                icon: Icons.share_rounded,
                title: 'दोस्तों को शेयर करें',
                onTap: AppActions.shareApp,
              ),
              SettingsTile(
                icon: Icons.language_rounded,
                title: 'वेबसाइट',
                subtitle: AppConstants.websiteUrl,
                onTap: () => AppActions.openUrl(context, AppConstants.websiteUrl),
              ),
              SettingsTile(
                icon: Icons.help_outline_rounded,
                title: 'मदद और सहायता',
                onTap: () => context.push('/help'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Text.rich(
              TextSpan(
                style: AppText.body(size: 15, weight: FontWeight.w600, color: p.textMuted),
                children: const [
                  TextSpan(text: 'Made in India with '),
                  TextSpan(text: '❤', style: TextStyle(color: AppColors.danger)),
                  TextSpan(text: '  •  भारत में निर्मित'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              '© ${DateTime.now().year} ${AppConstants.companyName}',
              textAlign: TextAlign.center,
              style: AppText.body(size: 12.5, color: p.textHint),
            ),
          ),
        ],
      ),
    );
  }
}
