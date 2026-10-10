// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/profile_setup_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/discover_screen.dart';
import '../../features/templates/presentation/screens/template_preview_screen.dart';
import '../../features/user/presentation/screens/profile_screen.dart';
import '../../features/user/presentation/screens/saved_screen.dart';
import '../../features/premium/presentation/screens/premium_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/home/presentation/screens/notifications_screen.dart';
import '../../features/auth/presentation/screens/intro_screen.dart';
import '../../features/legal/presentation/screens/legal_screens.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/edit_profile_screen.dart';
import '../../features/premium/presentation/screens/my_plan_screen.dart';
import '../../features/support/presentation/screens/help_screen.dart';
import '../../features/support/presentation/screens/about_screen.dart';
import '../../features/support/presentation/screens/not_found_screen.dart';
import 'app_shell.dart';
import '../../core/auth/session_store.dart';
import '../../core/services/notification_service.dart';

part 'app_router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Routes reachable without a session.
const _publicRoutes = {'/splash', '/login', '/intro'};

/// Informational pages that must always be viewable (logged out, or logged in
/// but not yet onboarded) — required for Play Store / Razorpay compliance.
const _infoRoutes = {'/privacy-policy', '/terms', '/refund-policy', '/about', '/help'};

/// Auth guard. Splash decides the first destination itself; afterwards the
/// session store drives redirects (login, logout, refresh-token failure).
String? _authRedirect(GoRouterState state) {
  final session = SessionStore.instance;
  final path = state.uri.path;
  if (path == '/splash') return null;
  if (_infoRoutes.contains(path)) return null;

  final loggedIn = session.isLoggedIn;
  if (!loggedIn) {
    // Fresh install: show the intro slides once, before login.
    if (path == '/login' && !introSeen) return '/intro';
    return _publicRoutes.contains(path) ? null : '/login';
  }

  final onboarded = session.onboardingCompleted;
  if (path == '/login' || path == '/intro') {
    return onboarded ? '/home' : '/profile-setup';
  }
  if (!onboarded && path != '/profile-setup') {
    return '/profile-setup';
  }
  return null;
}

@Riverpod(keepAlive: true)
GoRouter appRouter(AppRouterRef ref) {
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    refreshListenable: SessionStore.instance,
    redirect: (context, state) => _authRedirect(state),
    errorBuilder: (ctx, state) => NotFoundScreen(path: state.uri.path),
    routes: [
      // ── Auth / full-screen routes ────────────────────────────
      GoRoute(path: '/splash', builder: (ctx, state) => const SplashScreen()),
      GoRoute(path: '/intro', builder: (ctx, state) => const IntroScreen()),
      GoRoute(path: '/login', builder: (ctx, state) => const LoginScreen()),
      GoRoute(path: '/profile-setup', builder: (ctx, state) => const ProfileSetupScreen()),
      GoRoute(path: '/premium', builder: (ctx, state) => const PremiumScreen()),
      GoRoute(
        path: '/search',
        builder: (ctx, state) => SearchScreen(initialQuery: state.uri.queryParameters['q']),
      ),
      GoRoute(path: '/notifications', builder: (ctx, state) => const NotificationsScreen()),
      GoRoute(path: '/settings', builder: (ctx, state) => const SettingsScreen()),
      GoRoute(path: '/edit-profile', builder: (ctx, state) => const EditProfileScreen()),
      GoRoute(path: '/my-plan', builder: (ctx, state) => const MyPlanScreen()),
      // Public informational pages
      GoRoute(path: '/privacy-policy', builder: (ctx, state) => const PrivacyPolicyScreen()),
      GoRoute(path: '/terms', builder: (ctx, state) => const TermsScreen()),
      GoRoute(path: '/refund-policy', builder: (ctx, state) => const RefundPolicyScreen()),
      GoRoute(path: '/about', builder: (ctx, state) => const AboutScreen()),
      GoRoute(path: '/help', builder: (ctx, state) => const HelpScreen()),
      GoRoute(
        path: '/template/:id',
        builder: (ctx, state) => TemplatePreviewScreen(
          templateId: state.pathParameters['id']!,
        ),
      ),

      // ── Shell with bottom nav ────────────────────────────────
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (ctx, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (ctx, state) => const HomeScreen()),
          GoRoute(path: '/discover', builder: (ctx, state) => const DiscoverScreen()),
          GoRoute(path: '/saved', builder: (ctx, state) => const SavedScreen()),
          GoRoute(path: '/profile', builder: (ctx, state) => const ProfileScreen()),
        ],
      ),
    ],
  );

  // Registering the handler flushes any deep link buffered from a cold-start
  // notification tap. Delivery waits until the session is ready (not on splash).
  NotificationService.instance.setNavigationHandler((route, data) {
    if (!SessionStore.instance.isLoggedIn || !SessionStore.instance.onboardingCompleted) return false;
    // Not ready while the splash screen is still deciding where to go (it
    // would replace the stack); Home flushes the buffered link once shown.
    final current = router.routerDelegate.currentConfiguration;
    if (current.isEmpty || current.uri.path == '/splash') return false;
    const tabs = {'/home', '/discover', '/saved', '/profile'};
    if (tabs.contains(route)) {
      router.go(route);
    } else {
      router.push(route);
    }
    return true;
  });
  ref.onDispose(NotificationService.instance.clearNavigationHandler);

  return router;
}
