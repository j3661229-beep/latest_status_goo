// lib/features/legal/presentation/screens/legal_screens.dart
import 'package:flutter/material.dart';

import '../../../../core/auth/session_store.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/app_actions.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../data/legal_content.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const LegalDocumentScreen(doc: LegalContent.privacy, webUrl: AppConstants.privacyUrl, icon: Icons.privacy_tip_rounded);
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const LegalDocumentScreen(doc: LegalContent.terms, webUrl: AppConstants.termsUrl, icon: Icons.gavel_rounded);
}

class RefundPolicyScreen extends StatelessWidget {
  const RefundPolicyScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const LegalDocumentScreen(doc: LegalContent.refund, webUrl: AppConstants.refundUrl, icon: Icons.currency_rupee_rounded);
}

/// Renders a [LegalDocument] with EN / हिंदी toggle, table-of-contents chips and
/// numbered sections. Works logged out.
class LegalDocumentScreen extends StatefulWidget {
  final LegalDocument doc;
  final String webUrl;
  final IconData icon;

  const LegalDocumentScreen({super.key, required this.doc, required this.webUrl, required this.icon});

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  late bool _hindi;
  late final List<GlobalKey> _keys = List.generate(widget.doc.sections.length, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    // Default to Hindi unless the user picked English.
    _hindi = SessionStore.instance.language != 'ENGLISH';
  }

  void _jump(int i) {
    final ctx = _keys[i].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx, duration: AppMotion.slow, curve: AppMotion.standard, alignment: 0.02);
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;
    final p = context.palette;
    final title = _hindi ? doc.titleHi : doc.titleEn;

    return AppScaffold(
      title: title,
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          // Hero
          Container(
            margin: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: AppRadius.xlAll,
              boxShadow: AppShadows.primaryGlow,
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.glassStrong),
                  child: Icon(widget.icon, color: AppColors.white, size: 28),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppText.heading(size: 20, color: AppColors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _hindi ? 'अंतिम अपडेट: ${doc.lastUpdated}' : 'Last updated: ${doc.lastUpdated}',
                        style: AppText.body(size: 13.5, color: AppColors.white, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Language toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                CategoryChip(label: 'English', selected: !_hindi, onTap: () => setState(() => _hindi = false)),
                CategoryChip(label: 'हिंदी', selected: _hindi, onTap: () => setState(() => _hindi = true)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Intro
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: Text(
              _hindi ? doc.introHi : doc.introEn,
              style: AppText.body(size: 16, color: p.textSecondary, height: 1.65),
            ),
          ),

          // Table of contents
          SectionHeader(title: _hindi ? 'विषय-सूची' : 'Contents'),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              itemCount: doc.sections.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (_, i) => Center(
                child: CategoryChip(
                  label: '${i + 1}. ${_hindi ? doc.sections[i].titleHi : doc.sections[i].titleEn}',
                  onTap: () => _jump(i),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Sections
          for (var i = 0; i < doc.sections.length; i++)
            _SectionCard(
              key: _keys[i],
              number: i + 1,
              title: _hindi ? doc.sections[i].titleHi : doc.sections[i].titleEn,
              paragraphs: _hindi ? doc.sections[i].bodyHi : doc.sections[i].bodyEn,
            ),

          // Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, 0),
            child: Column(
              children: [
                InfoCard(
                  tone: InfoTone.brand,
                  icon: Icons.mail_outline_rounded,
                  title: _hindi ? 'कोई सवाल है?' : 'Have a question?',
                  message: AppConstants.supportEmail,
                  actionLabel: _hindi ? 'ईमेल करें' : 'Email us',
                  onAction: () => AppActions.email(context, subject: widget.doc.titleEn),
                ),
                const SizedBox(height: AppSpacing.sm),
                SecondaryButton(
                  label: _hindi ? 'वेबसाइट पर खोलें' : 'Open on website',
                  icon: Icons.open_in_new_rounded,
                  onPressed: () => AppActions.openUrl(context, widget.webUrl),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final int number;
  final String title;
  final List<String> paragraphs;

  const _SectionCard({super.key, required this.number, required this.title, required this.paragraphs});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.brandGradient),
                child: Text('$number', style: AppText.heading(size: 14, color: AppColors.white, height: 1)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(title, style: AppText.heading(size: 17.5, color: p.textPrimary)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final para in paragraphs) _Paragraph(para),
        ],
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  final String text;
  const _Paragraph(this.text);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = AppText.body(size: 15.5, color: p.textSecondary, height: 1.65);
    final isBullet = text.startsWith('• ');
    return Padding(
      padding: EdgeInsets.only(bottom: 10, left: isBullet ? 4 : 0),
      child: isBullet
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 9, right: 10),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: p.primary),
                  ),
                ),
                Expanded(child: Text(text.substring(2), style: style)),
              ],
            )
          : Text(text, style: style),
    );
  }
}
