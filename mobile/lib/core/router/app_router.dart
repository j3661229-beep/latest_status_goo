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
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../core/theme/app_theme.dart';

part 'app_router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

@riverpod
GoRouter appRouter(AppRouterRef ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    routes: [
      // ── Auth / full-screen routes ────────────────────────────
      GoRoute(path: '/splash', builder: (ctx, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (ctx, state) => const LoginScreen()),
      GoRoute(path: '/onboarding', builder: (ctx, state) => const OnboardingScreen()),
      GoRoute(path: '/profile-setup', builder: (ctx, state) => const ProfileSetupScreen()),
      GoRoute(path: '/premium', builder: (ctx, state) => const PremiumScreen()),
      GoRoute(path: '/search', builder: (ctx, state) => const SearchScreen()),
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
    int selectedIndex = 0;
    for (int i = 0; i < _destinations.length; i++) {
      if (location.startsWith(_destinations[i].path)) {
        selectedIndex = i;
        break;
      }
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) => context.go(_destinations[i].path),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: _destinations
            .map((d) => NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.activeIcon, color: AppColors.primary),
                  label: d.label,
                ))
            .toList(),
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
