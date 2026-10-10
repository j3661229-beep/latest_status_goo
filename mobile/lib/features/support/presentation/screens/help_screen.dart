// lib/features/support/presentation/screens/help_screen.dart
import 'package:flutter/material.dart';

import '../../../../core/auth/session_store.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/app_actions.dart';
import '../../../../core/utils/app_info.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../data/faq_content.dart';

/// Help & Support: searchable FAQ, contact actions and "Report a problem".
/// Public (works while logged out).
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _search = TextEditingController();
  String _query = '';
  int? _open;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reportProblem() async {
    await AppBottomSheet.show<void>(
      context,
      title: 'समस्या बताएं',
      subtitle: 'Report a problem',
      builder: (ctx) => const _ReportForm(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final results = FaqContent.items.where((f) => f.matches(_query)).toList();

    return AppScaffold(
      title: 'मदद और सहायता',
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.sm),
            child: AppSearchField(
              controller: _search,
              hint: 'सवाल खोजें... (Search help)',
              onChanged: (v) => setState(() {
                _query = v;
                _open = null;
              }),
              onClear: _query.isEmpty
                  ? null
                  : () => setState(() {
                        _search.clear();
                        _query = '';
                      }),
            ),
          ),

          const SectionHeader(
            title: 'अक्सर पूछे जाने वाले सवाल',
            subtitle: 'FAQ',
            padding: EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.sm),
          ),

          if (results.isEmpty)
            const SizedBox(
              height: 260,
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'कोई जवाब नहीं मिला',
                message: 'दूसरे शब्द से खोजें या नीचे हमसे संपर्क करें।',
                compact: true,
              ),
            )
          else
            for (var i = 0; i < results.length; i++)
              _FaqTile(
                item: results[i],
                expanded: _open == i,
                onTap: () => setState(() => _open = _open == i ? null : i),
              ),

          const SectionHeader(
            title: 'हमसे संपर्क करें',
            subtitle: 'Contact us',
            padding: EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.lg, AppSpacing.page, AppSpacing.sm),
          ),
          SettingsSection(
            children: [
              SettingsTile(
                icon: Icons.chat_rounded,
                iconColor: AppColors.whatsappDark,
                title: 'WhatsApp पर चैट करें',
                subtitle: 'सबसे तेज़ जवाब',
                onTap: () => AppActions.whatsappSupport(context),
              ),
              SettingsTile(
                icon: Icons.mail_outline_rounded,
                title: 'ईमेल भेजें',
                subtitle: AppConstants.supportEmail,
                onTap: () => AppActions.email(context, subject: '${AppConstants.appName} support'),
              ),
              SettingsTile(
                icon: Icons.call_outlined,
                title: 'कॉल करें',
                subtitle: AppConstants.supportPhone,
                onTap: () => AppActions.call(context),
              ),
              SettingsTile(
                icon: Icons.bug_report_outlined,
                iconColor: AppColors.accentDark,
                title: 'समस्या बताएं',
                subtitle: 'ऐप में कोई गड़बड़ी हो तो यहाँ लिखें',
                onTap: _reportProblem,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: Text(
              'सहायता समय: सोमवार–शनिवार, सुबह 10 से शाम 6 बजे (IST)',
              textAlign: TextAlign.center,
              style: AppText.body(size: 13.5, color: p.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final FaqItem item;
  final bool expanded;
  final VoidCallback onTap;

  const _FaqTile({required this.item, required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xs),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: expanded ? p.primary : p.border, width: expanded ? 1.5 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 60),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.qHi, style: AppText.body(size: 16, weight: FontWeight.w700, color: p.textPrimary, height: 1.35)),
                          const SizedBox(height: 2),
                          Text(item.qEn, style: AppText.body(size: 13.5, color: p.textMuted, height: 1.3)),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: AppMotion.normal,
                      child: Icon(Icons.keyboard_arrow_down_rounded, color: p.primary, size: 28),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: AppMotion.normal,
            curve: AppMotion.standard,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(color: p.divider),
                        const SizedBox(height: 6),
                        Text(item.aHi, style: AppText.body(size: 15.5, color: p.textSecondary, height: 1.6)),
                        const SizedBox(height: 8),
                        Text(item.aEn, style: AppText.body(size: 14.5, color: p.textMuted, height: 1.55)),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _ReportForm extends StatefulWidget {
  const _ReportForm();

  @override
  State<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<_ReportForm> {
  static const _categories = ['ऐप क्रैश / अटकना', 'भुगतान / प्रीमियम', 'लॉगिन / OTP', 'स्टेटस / टेम्पलेट', 'अन्य'];
  final _desc = TextEditingController();
  int _cat = 0;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_desc.text.trim().length < 10) {
      setState(() => _error = 'कृपया समस्या थोड़ी विस्तार से लिखें (कम से कम 10 अक्षर)।');
      return;
    }
    setState(() {
      _error = null;
      _sending = true;
    });
    final diagnostics = await buildSupportDiagnostics();
    final user = SessionStore.instance.readUser();
    final body = '${_desc.text.trim()}\n\n'
        '----- Please do not delete -----\n'
        'Category: ${_categories[_cat]}\n'
        'User ID: ${user?.id ?? 'not logged in'}\n'
        'Plan: ${user?.plan ?? '-'}\n'
        '$diagnostics';
    if (!mounted) return;
    final ok = await AppActions.email(
      context,
      subject: '[${AppConstants.appName}] ${_categories[_cat]}',
      body: body,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (var i = 0; i < _categories.length; i++)
              CategoryChip(label: _categories[i], selected: _cat == i, onTap: () => setState(() => _cat = i)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _desc,
          label: 'समस्या का विवरण',
          hint: 'क्या हुआ? कौन-सी स्क्रीन पर?',
          maxLines: 5,
          minLines: 4,
          maxLength: 1000,
          textInputAction: TextInputAction.newline,
          keyboardType: TextInputType.multiline,
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          InfoCard(tone: InfoTone.danger, message: _error!),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text(
          'आपके डिवाइस और ऐप वर्शन की जानकारी ईमेल में अपने-आप जुड़ जाएगी।',
          style: AppText.body(size: 13, color: context.palette.textMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        GradientButton(label: 'ईमेल तैयार करें', icon: Icons.send_rounded, isLoading: _sending, onPressed: _send),
      ],
    );
  }
}
