// Layout stress test for every app screen.
//
// Renders each screen on small / medium / large phones with the app's MAXIMUM accessibility text scale
// (main.dart caps it at 1.3) and fails on ANY framework error: RenderFlex overflows, null-check errors,
// invalid slivers, exceptions thrown from build/init. The shared HTTP client is replaced with a fake that
// serves canned API data (or failures), so the real repositories/providers run end to end.
//
// This catches layout/crash bugs; it is NOT a substitute for looking at the screens on a real device.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:status_go/core/api/api_client.dart';
import 'package:status_go/core/auth/session_store.dart';
import 'package:status_go/core/constants/app_constants.dart';
import 'package:status_go/core/theme/app_theme.dart';
import 'package:status_go/features/auth/domain/models/user_model.dart';
import 'package:status_go/features/auth/presentation/screens/intro_screen.dart';
import 'package:status_go/features/auth/presentation/screens/login_screen.dart';
import 'package:status_go/features/auth/presentation/screens/profile_setup_screen.dart';
import 'package:status_go/features/home/presentation/screens/discover_screen.dart';
import 'package:status_go/features/home/presentation/screens/home_screen.dart';
import 'package:status_go/features/home/presentation/screens/notifications_screen.dart';
import 'package:status_go/features/legal/presentation/screens/legal_screens.dart';
import 'package:status_go/features/premium/presentation/screens/my_plan_screen.dart';
import 'package:status_go/features/premium/presentation/screens/premium_screen.dart';
import 'package:status_go/features/search/presentation/screens/search_screen.dart';
import 'package:status_go/features/settings/presentation/screens/edit_profile_screen.dart';
import 'package:status_go/features/settings/presentation/screens/settings_screen.dart';
import 'package:status_go/features/shorts/presentation/screens/shorts_screen.dart';
import 'package:status_go/features/support/presentation/screens/about_screen.dart';
import 'package:status_go/features/templates/presentation/screens/template_preview_screen.dart';
import 'package:status_go/features/support/presentation/screens/help_screen.dart';
import 'package:status_go/features/support/presentation/screens/not_found_screen.dart';
import 'package:status_go/features/user/presentation/screens/profile_screen.dart';
import 'package:status_go/features/user/presentation/screens/saved_screen.dart';

import '../shorts/fake_video_platform.dart';
import 'fake_api.dart';

class _Size {
  final String name;
  final Size logical;
  final double textScale;
  const _Size(this.name, this.logical, this.textScale);
}

const _sizes = [
  _Size('320x568 @1.3x', Size(320, 568), 1.3), // smallest supported phone, max accessibility text
  _Size('360x740 @1.0x', Size(360, 740), 1.0),
  _Size('360x740 @1.3x', Size(360, 740), 1.3),
  _Size('412x915 @1.3x', Size(412, 915), 1.3),
];

class _Screen {
  final String name;
  final Widget Function() build;
  const _Screen(this.name, this.build);
}

final _screens = <_Screen>[
  _Screen('Intro', () => const IntroScreen()),
  _Screen('Login', () => const LoginScreen()),
  _Screen('ProfileSetup', () => const ProfileSetupScreen()),
  _Screen('Home', () => const HomeScreen()),
  _Screen('Discover', () => const DiscoverScreen()),
  _Screen('Search', () => const SearchScreen()),
  _Screen('Saved', () => const SavedScreen()),
  _Screen('Shorts', () => const ShortsScreen()),
  _Screen('Profile', () => const ProfileScreen()),
  _Screen('Settings', () => const SettingsScreen()),
  _Screen('EditProfile', () => const EditProfileScreen()),
  _Screen('Premium', () => const PremiumScreen()),
  _Screen('MyPlan', () => const MyPlanScreen()),
  _Screen('TemplatePreview(image)', () => const TemplatePreviewScreen(templateId: 't1')),
  _Screen('TemplatePreview(video)', () => const TemplatePreviewScreen(templateId: 't3')),
  _Screen('Notifications', () => const NotificationsScreen()),
  _Screen('Privacy', () => const PrivacyPolicyScreen()),
  _Screen('Terms', () => const TermsScreen()),
  _Screen('Refund', () => const RefundPolicyScreen()),
  _Screen('About', () => const AboutScreen()),
  _Screen('Help', () => const HelpScreen()),
  _Screen('NotFound', () => const NotFoundScreen(path: '/nope')),
];

Widget _host(Widget screen, _Size s, {bool dark = false}) {
  final router = GoRouter(initialLocation: '/', routes: [
    GoRoute(path: '/', builder: (_, __) => screen),
    GoRoute(path: '/:rest(.*)', builder: (_, st) => Scaffold(body: Text('NAV ${st.uri}'))),
  ]);
  return ProviderScope(
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      // Mirror main.dart: same text-scale cap and tablet width cap.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(s.textScale)),
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: child ?? const SizedBox.shrink())),
          ),
        );
      },
    ),
  );
}

/// Errors that are environmental noise in tests, not app bugs.
bool _ignorable(FlutterErrorDetails d) {
  final t = d.exceptionAsString();
  return t.contains('GoogleFonts') || t.contains('google_fonts') || t.contains('Failed to load font');
}

void main() {
  late Directory tmp;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    tmp = Directory.systemTemp.createTempSync('statusgo_ui_test_');
    Hive.init(tmp.path);
    await Hive.openBox(AppConstants.hiveBoxUser);
    await Hive.openBox(AppConstants.hiveBoxSettings);
    await Hive.openBox(AppConstants.hiveBoxSaved);
    await Hive.openBox(AppConstants.hiveBoxNotifications);
    await SessionStore.instance.saveTokens(accessToken: 'test-access', refreshToken: 'test-refresh');
    await SessionStore.instance.writeUser(const UserModel(
      id: 'u1', name: 'रमेश कुमार शर्मा', phoneNumber: '+919876543210', language: 'HINDI', plan: 'FREE',
      state: 'Maharashtra', onboardingCompleted: true, streakCount: 12, totalShares: 340, totalSaves: 58,
      businessName: 'शर्मा इलेक्ट्रॉनिक्स एंड होम अप्लायंसेज़ प्राइवेट लिमिटेड',
    ));
  });

  tearDownAll(() async {
    // Hive.close() can block on open box files; the OS temp dir is cleaned up best-effort.
    try { tmp.deleteSync(recursive: true); } catch (_) {}
  });

  // Screens with text inputs: also stress them with the soft keyboard open.
  const formScreens = {'Login', 'ProfileSetup', 'EditProfile', 'Search', 'Help'};

  final scenarios = <({String label, FakeApiMode mode, bool dark, double keyboard, List<_Size> sizes, bool Function(_Screen) only})>[
    for (final mode in FakeApiMode.values)
      (label: 'light/${mode.name}', mode: mode, dark: false, keyboard: 0.0, sizes: _sizes, only: (_) => true),
    (label: 'dark/data', mode: FakeApiMode.data, dark: true, keyboard: 0.0, sizes: [_sizes[0], _sizes[1]], only: (_) => true),
    (label: 'keyboard-open/data', mode: FakeApiMode.data, dark: false, keyboard: 300.0, sizes: [_sizes[0], _sizes[1]], only: (sc) => formScreens.contains(sc.name)),
  ];

  for (final sc in scenarios) {
    group('layout [${sc.label}]', () {
      for (final screen in _screens.where(sc.only)) {
        for (final size in sc.sizes) {
          testWidgets('${screen.name} @ ${size.name}', (t) async {
            final api = FakeApi(sc.mode);
            apiClient.httpClientAdapter = api;
            publicApiClient.httpClientAdapter = api;
            VideoPlayerPlatform.instance = FakeVideoPlatform();

            final errors = <String>[];
            final original = FlutterError.onError;
            FlutterError.onError = (d) {
              if (!_ignorable(d)) {
                final deep = d.toDiagnosticsNode().toStringDeep();
                errors.add(deep.length > 1400 ? '${deep.substring(0, 1400)}…' : deep);
              }
            };

            t.view.physicalSize = size.logical * 2.0;
            t.view.devicePixelRatio = 2.0;
            if (sc.keyboard > 0) t.view.viewInsets = FakeViewPadding(bottom: sc.keyboard * 2.0);
            addTearDown(t.view.reset);

            await t.pumpWidget(_host(screen.build(), size, dark: sc.dark));
            // Let async loads resolve and entrance animations run — without pumpAndSettle (feeds animate forever).
            for (final ms in [50, 300, 600, 1200]) {
              await t.pump(Duration(milliseconds: ms));
            }
            // Unmount, then flush pending timers so disposal bugs surface here, not in the next test.
            await t.pumpWidget(const SizedBox());
            await t.pump(const Duration(seconds: 12));

            FlutterError.onError = original; // restore BEFORE asserting (flutter_test requirement)
            expect(errors, isEmpty, reason: '${screen.name} @ ${size.name} [${sc.label}]\n${errors.join('\n---\n')}');
          });
        }
      }
    });
  }
}
