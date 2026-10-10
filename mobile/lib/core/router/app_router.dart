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
import '../../core/auth/session_store.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_theme.dart';

part 'app_router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Routes reachable without a session.
const _publicRoutes = {'/splash', '/login'};

/// Auth guard. Splash decides the first destination itself; afterwards the
/// session store drives redirects (login, logout, refresh-token failure).
String? _authRedirect(GoRouterState state) {
  final session = SessionStore.instance;
  final path = state.uri.path;
  if (path == '/splash') return null;

  final loggedIn = session.isLoggedIn;
  if (!loggedIn) {
    return _publicRoutes.contains(path) ? null : '/login';
  }

  final onboarded = session.onboardingCompleted;
  if (path == '/login') {
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
    routes: [
      // ── Auth / full-screen routes ────────────────────────────
      GoRoute(path: '/splash', builder: (ctx, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (ctx, state) => const LoginScreen()),
      GoRoute(path: '/profile-setup', builder: (ctx, state) => const ProfileSetupScreen()),
      GoRoute(path: '/premium', builder: (ctx, state) => const PremiumScreen()),
      GoRoute(
        path: '/search',
        builder: (ctx, state) => SearchScreen(initialQuery: state.uri.queryParameters['q']),
      ),
      GoRoute(path: '/notifications', builder: (ctx, state) => const NotificationsScreen()),
      GoRoute(
        path: '/template/:id',
        builder: (ctx, state) => TemplatePreviewScreen(
          templateId: state.pathParameters['id']!,
        ),
      ),

      // ── Shell with bottom nav ────────────────────────────────
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (ctx, state, child) => _MainShell(child: child),
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

// ── Main Shell ─────────────────────────────────────────────────────────────────

class _MainShell extends StatelessWidget {
  final Widget child;
  const _MainShell({required this.child});

  static const _destinations = [
    _Dest(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'होम', path: '/home'),
    _Dest(icon: Icons.explore_outlined, activeIcon: Icons.explore_rounded, label: 'खोजें', path: '/discover'),
    _Dest(icon: Icons.bookmark_outline_rounded, activeIcon: Icons.bookmark_rounded, label: 'सहेजें', path: '/saved'),
    _Dest(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'प्रोफ़ाइल', path: '/profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    // The bottom nav is shown on every tab — including the full-screen Home feed —
    // so the rest of the app stays reachable.
    int selectedIndex = 0;
    for (int i = 0; i < _destinations.length; i++) {
      if (location.startsWith(_destinations[i].path)) {
        selectedIndex = i;
        break;
      }
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.surfaceBorder, width: 0.8),
          ),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (i) => context.go(_destinations[i].path),
          backgroundColor: AppColors.surface,
          elevation: 0,
          height: 62,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: _destinations
              .map((d) => NavigationDestination(
                    icon: Icon(d.icon, size: 22),
                    selectedIcon: Icon(d.activeIcon, color: AppColors.primary, size: 23),
                    label: d.label,
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _Dest {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
  const _Dest({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
  });
}
