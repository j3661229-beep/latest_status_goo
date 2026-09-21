// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar styling
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Initialize Hive (local storage)
  await Hive.initFlutter();
  await Hive.openBox(AppConstants.hiveBoxUser);
  await Hive.openBox(AppConstants.hiveBoxSettings);
  await Hive.openBox(AppConstants.hiveBoxSaved);

  // Initialize OneSignal
  OneSignal.initialize(const String.fromEnvironment(
    'FLUTTER_ONESIGNAL_APP_ID',
    defaultValue: '',
  ));
  OneSignal.Notifications.requestPermission(true);

  runApp(
    const ProviderScope(
      child: StatusGoApp(),
    ),
  );
}

class StatusGoApp extends ConsumerWidget {
  const StatusGoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Status Go',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      builder: (context, child) {
        // Respect system text scale but cap at 1.2x for UI consistency
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(
              mediaQuery.textScaler.scale(1.0).clamp(0.8, 1.2),
            ),
          ),
          child: child!,
        );
      },
    );
  }
}
