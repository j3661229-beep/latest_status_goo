// lib/features/legal/presentation/widgets/legal_consent_text.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';

/// "By continuing you agree to our Terms & Privacy Policy" with tappable links.
///
/// ```dart
/// const LegalConsentText()
/// ```
class LegalConsentText extends StatefulWidget {
  final TextAlign textAlign;
  const LegalConsentText({super.key, this.textAlign = TextAlign.center});

  @override
  State<LegalConsentText> createState() => _LegalConsentTextState();
}

class _LegalConsentTextState extends State<LegalConsentText> {
  late final TapGestureRecognizer _terms = TapGestureRecognizer()..onTap = () => context.push('/terms');
  late final TapGestureRecognizer _privacy = TapGestureRecognizer()..onTap = () => context.push('/privacy-policy');

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final base = AppText.body(size: 13.5, color: p.textMuted, height: 1.6);
    final link = base.copyWith(color: p.primary, fontWeight: FontWeight.w700, decoration: TextDecoration.underline);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'आगे बढ़ने पर आप हमारी '),
          TextSpan(text: 'उपयोग की शर्तों (Terms)', style: link, recognizer: _terms),
          const TextSpan(text: ' और '),
          TextSpan(text: 'गोपनीयता नीति (Privacy Policy)', style: link, recognizer: _privacy),
          const TextSpan(text: ' से सहमत होते हैं।'),
        ],
      ),
      textAlign: widget.textAlign,
    );
  }
}
