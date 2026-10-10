// lib/core/utils/app_actions.dart
//
// Small helpers for outbound actions (store, share, mail, call, WhatsApp).
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';
import '../widgets/ui/feedback.dart';

class AppActions {
  AppActions._();

  /// Opens [url] in an external app/browser. Shows an error snack on failure.
  static Future<bool> openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    var ok = false;
    if (uri != null) {
      try {
        ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        ok = false;
      }
    }
    if (!ok && context.mounted) AppSnack.error(context, 'लिंक नहीं खुल सका।');
    return ok;
  }

  /// Opens the Play Store listing so the user can rate the app.
  static Future<bool> rateApp(BuildContext context) => openUrl(context, AppConstants.playStoreUrl);

  /// Opens the system share sheet with an invite message.
  static Future<void> shareApp() async {
    await Share.share(
      'रोज़ अपने नाम और फोटो के साथ शानदार स्टेटस बनाएं — ${AppConstants.appName} ऐप डाउनलोड करें 📲\n${AppConstants.playStoreUrl}',
      subject: AppConstants.appName,
    );
  }

  /// Opens the mail app with a pre-filled message.
  static Future<bool> email(
    BuildContext context, {
    String? to,
    String subject = '',
    String body = '',
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: to ?? AppConstants.supportEmail,
      query: _query({'subject': subject, 'body': body}),
    );
    var ok = false;
    try {
      ok = await launchUrl(uri);
    } catch (_) {}
    if (!ok && context.mounted) {
      AppSnack.error(context, 'ईमेल ऐप नहीं मिला। कृपया ${AppConstants.supportEmail} पर लिखें।');
    }
    return ok;
  }

  static Future<bool> whatsappSupport(BuildContext context, {String message = 'नमस्ते, मुझे Status Go में मदद चाहिए।'}) {
    final url = 'https://wa.me/${AppConstants.supportWhatsappNumber}?text=${Uri.encodeComponent(message)}';
    return openUrl(context, url);
  }

  static Future<bool> call(BuildContext context) async {
    final number = AppConstants.supportPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    var ok = false;
    try {
      ok = await launchUrl(Uri(scheme: 'tel', path: number));
    } catch (_) {}
    if (!ok && context.mounted) AppSnack.error(context, 'कॉल शुरू नहीं हो सकी।');
    return ok;
  }

  static String _query(Map<String, String> params) => params.entries
      .where((e) => e.value.isNotEmpty)
      .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
      .join('&');
}
