// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/language_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/discover_screen.dart';
import '../../features/templates/presentation/screens/template_preview_screen.dart';
import '../../features/user/presentation/screens/profile_screen.dart';
import '../../features/user/presentation/screens/saved_screen.dart';
import '../../features/premium/presentation/screens/premium_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';

part 'app_router.g.dart';

// Shell for bottom nav
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

@riverpod
GoRouter appRouter(AppRouterRef ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    routes: [
      // ── Full-screen routes (no bottom nav) ──────────────
      GoRoute(path: '/splash', builder: (ctx, state) => const SplashScreen()),
      GoRoute(path: '/language', builder: (ctx, state) => const LanguageSelectionScreen()),
      GoRoute(path: '/login', builder: (ctx, state) => const LoginScreen()),
      GoRoute(path: '/onboarding', builder: (ctx, state) => const OnboardingScreen()),
      GoRoute(path: '/premium', builder: (ctx, state) => const PremiumScreen()),

      // ── Shell with bottom nav ────────────────────────────
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

      // ── Template Detail ──────────────────────────────────
      GoRoute(
        path: '/template/:id',
        builder: (ctx, state) => TemplatePreviewScreen(
          templateId: state.pathParameters['id']!,
        ),
      ),

      // ── Search ──────────────────────────────────────────
      GoRoute(path: '/search', builder: (ctx, state) => const SearchScreen()),
    ],
  );
}

// Bottom Navigation Shell
class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: _BottomNavBar(),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    int currentIndex = 0;
    if (location.startsWith('/home')) currentIndex = 0;
    if (location.startsWith('/discover')) currentIndex = 1;
    if (location.startsWith('/saved')) currentIndex = 2;
    if (location.startsWith('/profile')) currentIndex = 3;

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        switch (index) {
          case 0: context.go('/home'); break;
          case 1: context.go('/discover'); break;
          case 2: context.go('/saved'); break;
          case 3: context.go('/profile'); break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.explore_rounded), label: 'Discover'),
        BottomNavigationBarItem(icon: Icon(Icons.bookmark_rounded), label: 'Saved'),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
      ],
    );
  }
}
