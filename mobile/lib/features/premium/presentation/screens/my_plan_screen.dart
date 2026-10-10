// lib/features/premium/presentation/screens/my_plan_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_error.dart';
import '../../../../core/widgets/app_ui.dart';

class PlanStatus {
  final String plan; // FREE | PREMIUM | ANNUAL
  final DateTime? expiresAt;
  final int? daysRemaining;

  const PlanStatus({required this.plan, this.expiresAt, this.daysRemaining});

  bool get isActive => plan != 'FREE' && (daysRemaining ?? 1) > 0;
  bool get isAnnual => plan == 'ANNUAL';
  int get totalDays => isAnnual ? 365 : 30;

  factory PlanStatus.fromJson(Map<String, dynamic> json) => PlanStatus(
        plan: (json['plan'] as String?) ?? 'FREE',
        expiresAt: json['expiresAt'] is String ? DateTime.tryParse(json['expiresAt'] as String)?.toLocal() : null,
        daysRemaining: (json['daysRemaining'] as num?)?.toInt(),
      );
}

/// GET /subscribe/status
final planStatusProvider = FutureProvider.autoDispose<PlanStatus>((ref) async {
  final resp = await apiClient.get('/subscribe/status');
  final data = resp.data;
  if (data is! Map) throw const ApiException('सर्वर से अमान्य जवाब मिला।');
  return PlanStatus.fromJson(Map<String, dynamic>.from(data));
});

class MyPlanScreen extends ConsumerWidget {
  const MyPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(planStatusProvider);
    return AppScaffold(
      title: 'मेरा प्लान',
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(planStatusProvider.future),
        child: status.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: const [
              ShimmerBox(height: 200, radius: AppRadius.xl),
              SizedBox(height: AppSpacing.md),
              ShimmerBox(height: 260, radius: AppRadius.lg),
            ],
          ),
          error: (e, _) => ListView(
            children: [
              SizedBox(
                height: 420,
                child: ErrorState(
                  message: apiErrorMessage(e),
                  onRetry: () => ref.invalidate(planStatusProvider),
                ),
              ),
            ],
          ),
          data: (s) => s.isActive ? _ActivePlan(status: s) : const _FreePlan(),
        ),
      ),
    );
  }
}

const _benefits = <(IconData, String, String)>[
  (Icons.all_inclusive_rounded, 'असीमित डाउनलोड', 'रोज़ जितने चाहें इमेज व वीडियो डाउनलोड करें'),
  (Icons.celebration_rounded, 'सभी त्योहार पैक', 'हर त्योहार के खास प्रीमियम टेम्पलेट'),
  (Icons.workspace_premium_rounded, 'प्रीमियम टेम्पलेट अनलॉक', 'लॉक किए गए सभी स्टेटस इस्तेमाल करें'),
  (Icons.support_agent_rounded, 'प्राथमिकता सहायता', 'आपकी समस्या पहले सुलझेगी'),
];

class _ActivePlan extends StatelessWidget {
  final PlanStatus status;
  const _ActivePlan({required this.status});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final days = status.daysRemaining ?? 0;
    final progress = (days / status.totalDays).clamp(0.0, 1.0);
    final expiry = status.expiresAt == null ? '—' : DateFormat('d MMM yyyy').format(status.expiresAt!);
    final expiringSoon = days <= 7;

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.xxl),
      children: [
        FadeSlideIn(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: AppColors.premiumGradient,
              borderRadius: AppRadius.xlAll,
              boxShadow: AppShadows.premiumGlow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.workspace_premium_rounded, color: AppColors.ink, size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        status.isAnnual ? 'प्रीमियम वार्षिक' : 'प्रीमियम मासिक',
                        style: AppText.heading(size: 22, color: AppColors.ink),
                      ),
                    ),
                    const AppBadge(label: 'सक्रिय', icon: Icons.check_circle_rounded, color: AppColors.ink, compact: true),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('$days', style: AppText.heading(size: 52, weight: FontWeight.w800, color: AppColors.ink, height: 1)),
                Text('दिन बाकी', style: AppText.body(size: 16, weight: FontWeight.w700, color: AppColors.ink)),
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: AppRadius.pillAll,
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    color: AppColors.ink,
                    backgroundColor: AppColors.glassStrong,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('समाप्ति: $expiry', style: AppText.body(size: 15, weight: FontWeight.w600, color: AppColors.ink)),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (expiringSoon)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: InfoCard(
              tone: InfoTone.warning,
              title: 'प्लान जल्द खत्म हो रहा है',
              message: 'अभी रिन्यू करें — नई अवधि आपके बचे हुए दिनों के बाद जुड़ेगी, कोई दिन नहीं जाएगा।',
            ),
          ),
        const InfoCard(
          tone: InfoTone.info,
          message: 'आपका प्लान अपने-आप रिन्यू नहीं होता। समाप्ति के बाद आप फ़्री प्लान पर आ जाएंगे।',
        ),
        const SectionHeader(title: 'आपके फ़ायदे', padding: EdgeInsets.fromLTRB(0, AppSpacing.xl, 0, AppSpacing.sm)),
        SettingsSection(
          margin: EdgeInsets.zero,
          children: [
            for (final b in _benefits)
              SettingsTile(
                icon: b.$1,
                iconColor: p.primary,
                title: b.$2,
                subtitle: b.$3,
                showChevron: false,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        GradientButton(
          label: 'प्लान रिन्यू / बढ़ाएं',
          icon: Icons.autorenew_rounded,
          variant: GradientButtonVariant.premium,
          onPressed: () => context.push('/premium'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: () => context.push('/refund-policy'),
          child: const Text('रिफ़ंड और रद्दीकरण नीति'),
        ),
      ],
    );
  }
}

class _FreePlan extends StatelessWidget {
  const _FreePlan();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.xxl),
      children: [
        const SizedBox(height: AppSpacing.md),
        const SizedBox(
          height: 240,
          child: EmptyState(
            icon: Icons.workspace_premium_rounded,
            title: 'आप फ़्री प्लान पर हैं',
            message: 'प्रीमियम लेकर असीमित डाउनलोड और सारे खास टेम्पलेट पाएं।',
            gradient: AppColors.premiumGradient,
            compact: true,
          ),
        ),
        const SectionHeader(title: 'प्रीमियम में क्या मिलेगा', padding: EdgeInsets.fromLTRB(0, AppSpacing.md, 0, AppSpacing.sm)),
        SettingsSection(
          margin: EdgeInsets.zero,
          children: [
            for (final b in _benefits)
              SettingsTile(icon: b.$1, iconColor: p.primary, title: b.$2, subtitle: b.$3, showChevron: false),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        GradientButton(
          label: 'प्रीमियम में अपग्रेड करें',
          icon: Icons.bolt_rounded,
          variant: GradientButtonVariant.premium,
          onPressed: () => context.push('/premium'),
        ),
      ],
    );
  }
}
