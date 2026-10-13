// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:google_fonts/google_fonts.dart';

import 'core/auth/session_store.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/constants/app_constants.dart';
import 'core/services/notification_service.dart';
import 'features/auth/presentation/providers/current_user_provider.dart';
import 'features/home/presentation/providers/home_data_provider.dart';
import 'features/user/data/saved_templates.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  GoogleFonts.config.allowRuntimeFetching = true;
  // Offline GoogleFonts fetch failures are noisy but harmless (system font
  // fallback) — log them briefly. Every other framework error is reported.
  FlutterError.onError = (details) {
    final errStr = details.exception.toString();
    if (errStr.contains('google_fonts') || errStr.contains('Failed to load font')) {
      debugPrint('GoogleFonts: ${details.exceptionAsString()}');
      return;
    }
    FlutterError.presentError(details);
  };

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
  await Hive.openBox(AppConstants.hiveBoxNotifications);

  // Consolidate legacy duplicated user/photo keys into one source of truth.
  await SessionStore.instance.migrateLegacy();

  // Initialize OneSignal Push & In-App Notification Service
  try {
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint('NotificationService init error: $e');
  }

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
    final themeMode = ref.watch(themeModeProvider);

    // Drop per-account cached data when the session ends (logout or refresh
    // failure) so the next account never sees stale feed / bookmarks.
    ref.listen<bool>(sessionStoreProvider.select((s) => s.isLoggedIn), (prev, next) {
      if (prev == true && !next) {
        ref.invalidate(homeDataProvider);
        ref.invalidate(savedIdsProvider);
      }
    });

    return MaterialApp.router(
      title: 'Status Go',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        // Respect system text scale but cap at 1.3x for UI consistency
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(
              mediaQuery.textScaler.scale(1.0).clamp(0.9, 1.3),
            ),
          ),
          // Cap content width on tablets / foldables; phones are unaffected.
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
    );
  }
}
