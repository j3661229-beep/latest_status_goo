import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:status_go/core/constants/app_constants.dart';
import 'package:status_go/core/router/app_shell.dart';
import 'package:status_go/features/home/data/home_repository.dart';
import 'package:status_go/features/home/presentation/providers/home_data_provider.dart';
import 'package:status_go/features/home/presentation/screens/home_screen.dart';
import 'package:status_go/features/templates/domain/models/template_model.dart';

class FakeHome extends HomeData {
  @override
  Future<HomeFeedData> build() async => HomeFeedData(
        featured: [
          for (var i = 0; i < 4; i++)
            TemplateModel(id: '$i', type: i.isEven ? 'VIDEO' : 'IMAGE', status: 'PUBLISHED',
                videoUrl: 'http://x/$i.mp4', imageUrl: i == 1 ? 'http://x/a.png' : null, nameHi: 'T$i', isLocked: i == 3),
        ],
        trending: const [],
        coordinatorPicks: const [],
        categories: const [],
      );
}

void main() {
  testWidgets('home semantics', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final dir = Directory.systemTemp.createTempSync();
    Hive.init(dir.path);
    await Hive.openBox(AppConstants.hiveBoxSettings);
    final h = tester.ensureSemantics();
    final router = GoRouter(initialLocation: '/home', routes: [
      ShellRoute(
        builder: (c, s, child) => MainShell(child: child),
        routes: [GoRoute(path: '/home', builder: (c, s) => const HomeScreen()), GoRoute(path: '/discover', builder: (c, s) => const Scaffold())],
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [homeDataProvider.overrideWith(FakeHome.new)],
      child: MaterialApp.router(routerConfig: router),
    ));
    for (var k = 0; k < 10; k++) { await tester.pump(const Duration(milliseconds: 300)); }
    for (var k = 0; k < 3; k++) {
      await tester.fling(find.byType(PageView), const Offset(0, -400), 1000);
      for (var j = 0; j < 10; j++) { await tester.pump(const Duration(milliseconds: 200)); }
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    h.dispose();
  });
}
