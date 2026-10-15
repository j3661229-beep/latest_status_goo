import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:status_go/core/router/app_shell.dart';
import 'package:status_go/core/widgets/app_ui.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('bottom nav keeps the original four tabs and adds Shorts; each routes correctly', (t) async {
    final original = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exception.toString().contains('GoogleFonts')) return;
      original?.call(d);
    };
    addTearDown(() => FlutterError.onError = original);
    t.view.physicalSize = const Size(1080, 2000);
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.reset);

    Widget page(String name) => Center(child: Text('PAGE:$name'));
    final router = GoRouter(initialLocation: '/home', routes: [
      ShellRoute(
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          for (final p in ['home', 'discover', 'shorts', 'saved', 'profile'])
            GoRoute(path: '/$p', builder: (_, __) => page(p)),
        ],
      ),
    ]);
    await t.pumpWidget(MaterialApp.router(theme: AppTheme.light, routerConfig: router));
    await t.pump();
    final semantics = t.ensureSemantics();

    // Every destination is exposed to screen readers by its label.
    for (final label in ['होम', 'खोजें', 'शॉर्ट्स', 'सहेजें', 'प्रोफ़ाइल']) {
      expect(find.bySemanticsLabel(label), findsAtLeastNWidgets(1), reason: label);
    }
    expect(find.text('PAGE:home'), findsOneWidget);

    // Inactive tabs are tapped by icon; each tap moves to the matching route.
    for (final (icon, path) in [
      (Icons.play_circle_outline_rounded, 'shorts'),
      (Icons.bookmark_outline_rounded, 'saved'),
      (Icons.explore_outlined, 'discover'),
      (Icons.person_outline_rounded, 'profile'),
      (Icons.home_outlined, 'home'),
    ]) {
      await t.tap(find.byIcon(icon));
      await t.pump(); // go_router applies the new location asynchronously
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('PAGE:$path'), findsOneWidget, reason: path);
    }
    semantics.dispose(); // must be released before the test ends
  });
}
