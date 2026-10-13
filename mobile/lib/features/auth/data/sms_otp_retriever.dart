// lib/features/auth/data/sms_otp_retriever.dart
import 'package:smart_auth/smart_auth.dart';
import 'package:pinput/pinput.dart';

/// Auto-reads the 6-digit login OTP on Android via the SMS User Consent API.
/// No READ_SMS permission is needed: Android shows a one-tap consent sheet
/// for the incoming OTP message. (iOS uses the `oneTimeCode` autofill hint.)
class SmsOtpRetriever implements SmsRetriever {
  SmsOtpRetriever([SmartAuth? smartAuth]) : _smartAuth = smartAuth ?? SmartAuth.instance;

  final SmartAuth _smartAuth;

  @override
  bool get listenForMultipleSms => true;

  @override
  Future<String?> getSmsCode() async {
    final res = await _smartAuth.getSmsWithUserConsentApi(matcher: r'(?<!\d)\d{6}(?!\d)');
    return res.hasData ? res.requireData.code : null;
  }

  @override
  Future<void> dispose() async {
    await _smartAuth.removeUserConsentApiListener();
  }
}
