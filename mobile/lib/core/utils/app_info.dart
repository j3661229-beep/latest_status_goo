// lib/core/utils/app_info.dart
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../constants/app_constants.dart';

/// App version + build number ("1.0.0 (1)"), falling back to the constant.
final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return '${info.version} (${info.buildNumber})';
  } catch (_) {
    return AppConstants.appVersion;
  }
});

/// Short multi-line description of the device/app for support emails.
Future<String> buildSupportDiagnostics() async {
  final lines = <String>[];
  try {
    final info = await PackageInfo.fromPlatform();
    lines.add('App: ${info.appName} ${info.version} (${info.buildNumber})');
  } catch (_) {
    lines.add('App: ${AppConstants.appName} ${AppConstants.appVersion}');
  }
  try {
    if (!kIsWeb && Platform.isAndroid) {
      final a = await DeviceInfoPlugin().androidInfo;
      lines.add('Device: ${a.manufacturer} ${a.model}');
      lines.add('Android: ${a.version.release} (SDK ${a.version.sdkInt})');
    } else if (!kIsWeb && Platform.isIOS) {
      final i = await DeviceInfoPlugin().iosInfo;
      lines.add('Device: ${i.utsname.machine}');
      lines.add('iOS: ${i.systemVersion}');
    }
  } catch (_) {}
  return lines.join('\n');
}
