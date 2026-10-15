import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:status_go/core/widgets/app_ui.dart';
import 'package:status_go/features/shorts/data/short_models.dart';
import 'package:status_go/features/shorts/data/shorts_repository.dart';
import 'package:status_go/features/shorts/presentation/screens/short_detail_screen.dart';
import 'package:status_go/features/shorts/presentation/screens/shorts_screen.dart';

import 'fake_repo.dart';
import 'fake_video_platform.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // google_fonts can't load files in tests; those failures are harmless.
  void ignoreFontErrors(WidgetTester t) {
    final original = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exception.toString().contains('google_fonts') || d.exception.toString().contains('GoogleFonts')) return;
      original?.call(d);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  late FakeVideoPlatform platform;
  late ControllerStats stats;
  setUp(() {
    platform = FakeVideoPlatform();
    VideoPlayerPlatform.instance = platform;
    stats = ControllerStats();
  });

  // NOTE: no runAsync here — giving real time to async work lets google_fonts' asset lookups fail
  // loudly. Platform-level disposal timing is covered in short_playback_test.dart instead.
  Future<void> settle(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    await t.pump(const Duration(milliseconds: 50));
  }


  /// Hosts the screen in a router with a stub detail route, returning the visited paths.
  Future<List<String>> pumpFeed(WidgetTester t, FakeRepo repo) async {
    ignoreFontErrors(t);
    t.view.physicalSize = const Size(1080, 2200);
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.reset);
    final visited = <String>[];
    final router = GoRouter(initialLocation: '/shorts', routes: [
      GoRoute(path: '/shorts', builder: (_, __) => Scaffold(body: ShortsScreen(controllerFactory: stats.factory))),
      GoRoute(
        path: '/shorts/:id',
        builder: (_, s) {
          visited.add(s.pathParameters['id']!);
          return Scaffold(appBar: AppBar(), body: const Text('DETAIL'));
        },
      ),
    ]);
    await t.pumpWidget(ProviderScope(
      overrides: [shortsRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ));
    await settle(t);
    return visited;
  }

  group('ShortsScreen', () {
    testWidgets('shows title, publisher, relative time, AI disclaimer and actions', (t) async {
      final repo = FakeRepo(onList: (f, c, p) async => ShortPage([mkNews('1', video: 'https://cdn.test/1.mp4')], false));
      await pumpFeed(t, repo);
      expect(find.text('ख़बर 1'), findsOneWidget);
      expect(find.textContaining('PIB · 3 घंटे पहले'), findsOneWidget);
      expect(find.textContaining('AI-सहायता प्राप्त सारांश'), findsOneWidget);
      for (final tip in ['सहेजें', 'शेयर', 'रिपोर्ट', 'म्यूट करें']) {
        expect(find.byTooltip(tip), findsOneWidget, reason: tip);
      }
      expect(find.text('विवरण और स्रोत'), findsOneWidget);
      expect(repo.events, contains('1:VIEW'));
    });

    testWidgets('old news is labelled so it is never mistaken for breaking news', (t) async {
      final old = DateTime.now().subtract(const Duration(days: 5)).toUtc().toIso8601String();
      final repo = FakeRepo(onList: (f, c, p) async => ShortPage([mkNews('1', publishedAt: old)], false));
      await pumpFeed(t, repo);
      expect(find.text('पुरानी खबर'), findsOneWidget);
    });

    testWidgets('empty state', (t) async {
      await pumpFeed(t, FakeRepo(onList: (f, c, p) async => const ShortPage([], false)));
      expect(find.text('अभी कोई वीडियो नहीं'), findsOneWidget);
    });

    testWidgets('error state with retry that recovers', (t) async {
      var fail = true;
      final repo = FakeRepo(onList: (f, c, p) async {
        if (fail) throw DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionError);
        return ShortPage([mkNews('1')], false);
      });
      await pumpFeed(t, repo);
      expect(find.text('लोड नहीं हो सका'), findsOneWidget);
      fail = false;
      await t.tap(find.text('फिर से कोशिश करें'));
      await settle(t);
      expect(find.text('ख़बर 1'), findsOneWidget);
    });

    testWidgets('switching tabs / categories queries the right feed; saved hides category chips', (t) async {
      final repo = FakeRepo(onList: (f, c, p) async => ShortPage([f == ShortsFeed.news ? mkNews('n') : mkScheme('s')], false));
      await pumpFeed(t, repo);
      expect(repo.listCalls.last, 'news|-|1');

      await t.tap(find.text('योजना'));
      await settle(t);
      expect(repo.listCalls.last, 'scheme|-|1');
      expect(find.text('योजना s'), findsOneWidget);

      await t.drag(find.byType(ListView).first, const Offset(-300, 0)); // chips scroll horizontally
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.text('छात्रवृत्ति'));
      await settle(t);
      expect(repo.listCalls.last, 'scheme|SCHOLARSHIP|1');

      await t.tap(find.text('सहेजे गए'));
      await settle(t);
      expect(repo.listCalls.last, 'saved|-|1');
      expect(find.text('छात्रवृत्ति'), findsNothing);
    });

    testWidgets('bookmark: optimistic, and rolls back with an error message on failure', (t) async {
      final repo = FakeRepo(
        onList: (f, c, p) async => ShortPage([mkNews('1')], false),
        onSave: (id, s) async => throw DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionError),
      );
      await pumpFeed(t, repo);
      await t.tap(find.byTooltip('सहेजें'));
      await settle(t);
      expect(find.byTooltip('सहेजें'), findsOneWidget); // rolled back (not 'सहेजा गया')
      expect(find.textContaining('सर्वर से कनेक्ट नहीं हो सका'), findsOneWidget);

      repo.onSave = (id, s) async {};
      await t.pump(const Duration(seconds: 5));
      await t.tap(find.byTooltip('सहेजें'));
      await settle(t);
      expect(find.byTooltip('सहेजा गया'), findsOneWidget);
    });

    testWidgets('report sheet sends the chosen reason', (t) async {
      String? sent;
      final repo = FakeRepo(
        onList: (f, c, p) async => ShortPage([mkNews('1')], false),
        onReport: (id, reason, note) async => sent = '$id|$reason',
      );
      await pumpFeed(t, repo);
      await t.tap(find.byTooltip('रिपोर्ट'));
      await settle(t);
      await t.pump(const Duration(milliseconds: 400)); // let the sheet finish sliding in
      final send = find.widgetWithText(FilledButton, 'रिपोर्ट भेजें');
      expect(t.widget<FilledButton>(send).onPressed, isNull); // needs a reason first
      await t.tap(find.text('जानकारी पुरानी है'));
      await t.pump();
      await t.tap(send);
      await settle(t);
      expect(sent, '1|OUTDATED');
    });

    testWidgets('opening details pauses playback, and returning resumes it', (t) async {
      final repo = FakeRepo(onList: (f, c, p) async => ShortPage([mkNews('1', video: 'https://cdn.test/1.mp4')], false));
      final visited = await pumpFeed(t, repo);
      expect(platform.playing, isNotEmpty);

      await t.tap(find.text('विवरण और स्रोत'));
      await settle(t);
      expect(visited, ['1']);
      expect(find.text('DETAIL'), findsOneWidget);
      expect(platform.playing, isEmpty, reason: 'feed video must pause while another route covers it');

      await t.pageBack();
      await settle(t);
      expect(platform.playing, isNotEmpty);
    });

    testWidgets('swiping loads the next item with a single live decoder and releases all on leave', (t) async {
      final repo = FakeRepo(onList: (f, c, p) async => ShortPage([
            mkNews('1', video: 'https://cdn.test/1.mp4'),
            mkNews('2', video: 'https://cdn.test/2.mp4'),
            mkNews('3', video: 'https://cdn.test/3.mp4'),
          ], false));
      await pumpFeed(t, repo);
      expect(stats.created, 1, reason: 'neighbouring pages must not be preloaded');

      await t.fling(find.byType(PageView), const Offset(0, -600), 1500);
      await settle(t);
      expect(find.text('ख़बर 2'), findsOneWidget);
      expect(stats.created, 2);
      expect(stats.outstanding, 1, reason: 'previous page controller must have been released');
      expect(repo.events, containsAll(['1:VIEW', '2:VIEW']));

      // Leave the screen entirely (tab switch): everything must be disposed.
      await t.pumpWidget(const SizedBox());
      await settle(t);
      expect(stats.outstanding, 0, reason: 'leaving the tab must release every controller');
    });
  });

  group('ShortDetailScreen', () {
    Future<void> pumpDetail(WidgetTester t, FakeRepo repo, {String id = 's1'}) async {
      ignoreFontErrors(t);
      t.view.physicalSize = const Size(1080, 4000);
      t.view.devicePixelRatio = 2.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(ProviderScope(
        overrides: [shortsRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(theme: AppTheme.light, home: ShortDetailScreen(id: id)),
      ));
      await settle(t);
    }

    testWidgets('scheme: eligibility, documents, steps, official link, sources, verified date, AI notice', (t) async {
      final repo = FakeRepo(onDetail: (id) async => ShortDetail(mkScheme('s1'), [mkNews('r1')]));
      await pumpDetail(t, repo);
      expect(find.text('योजना s1'), findsOneWidget);
      expect(find.text('पात्रता'), findsOneWidget);
      expect(find.text('किसान परिवार'), findsOneWidget);
      expect(find.text('आधार'), findsOneWidget);
      expect(find.text('पोर्टल खोलें'), findsOneWidget);
      expect(find.text('आधिकारिक आवेदन वेबसाइट खोलें'), findsOneWidget);
      expect(find.text('https://pmkisan.gov.in/about'), findsOneWidget);
      expect(find.textContaining('अंतिम सत्यापन: 1 अक्टूबर 2026'), findsOneWidget);
      expect(find.textContaining('गारंटी नहीं'), findsOneWidget);
      expect(find.textContaining('AI-सहायता प्राप्त सारांश'), findsOneWidget);
      expect(find.text('यह वीडियो का पूरा पाठ है।'), findsOneWidget); // text alternative to the video
      expect(find.text('मुख्य तथ्य एक'), findsOneWidget);
      expect(find.text('ख़बर r1'), findsOneWidget); // related
    });

    testWidgets('scheme with missing details never invents them and shows no official button without a URL', (t) async {
      final item = ShortItem.fromJson(schemeJson('s1', detail: false, scheme: {'applicationUrl': null}));
      await pumpDetail(t, FakeRepo(onDetail: (id) async => ShortDetail(item, const [])));
      expect(find.text('पात्रता की जानकारी आधिकारिक वेबसाइट पर देखें।'), findsOneWidget);
      expect(find.text('दस्तावेज़ों की सूची आधिकारिक वेबसाइट पर देखें।'), findsOneWidget);
      expect(find.text('आधिकारिक आवेदन वेबसाइट खोलें'), findsNothing);
    });

    testWidgets('news: publisher, date AND time, source check, stale/developing/corrected notices, original link', (t) async {
      final old = DateTime.now().subtract(const Duration(days: 4)).toUtc().toIso8601String();
      final item = mkNews('n1', publishedAt: old, news: {
        'isDeveloping': true,
        'correctionStatus': 'CORRECTED',
        'lastVerifiedAt': '2026-10-14T10:30:00.000Z',
      });
      await pumpDetail(t, FakeRepo(onDetail: (id) async => ShortDetail(item, const [])), id: 'n1');
      expect(find.text('स्रोत: PIB'), findsOneWidget);
      expect(find.textContaining('प्रकाशित:'), findsOneWidget);
      expect(find.textContaining(RegExp(r'\d{2}:\d{2}')), findsWidgets);
      expect(find.textContaining('स्रोत की जाँच:'), findsOneWidget);
      expect(find.textContaining('पुरानी खबर है'), findsOneWidget);
      expect(find.textContaining('विकसित हो रही है'), findsOneWidget);
      expect(find.textContaining('सुधार किया है'), findsOneWidget);
      expect(find.text('मूल खबर पढ़ें'), findsOneWidget);
    });

    testWidgets('load failure shows retry; retry recovers', (t) async {
      var fail = true;
      final repo = FakeRepo(onDetail: (id) async {
        if (fail) throw DioException(requestOptions: RequestOptions(), response: Response(requestOptions: RequestOptions(), statusCode: 404, data: {'message': 'x'}));
        return ShortDetail(mkScheme('s1'), const []);
      });
      await pumpDetail(t, repo);
      expect(find.text('सामग्री नहीं मिली'), findsOneWidget);
      fail = false;
      await t.tap(find.text('फिर से कोशिश करें'));
      await settle(t);
      expect(find.text('योजना s1'), findsOneWidget);
    });

    testWidgets('save toggles and report is reachable from the detail screen', (t) async {
      final saves = <bool>[];
      String? reported;
      final repo = FakeRepo(
        onDetail: (id) async => ShortDetail(mkScheme('s1'), const []),
        onSave: (id, s) async => saves.add(s),
        onReport: (id, r, n) async => reported = r,
      );
      await pumpDetail(t, repo);
      await t.ensureVisible(find.text('सहेजें'));
      await t.tap(find.text('सहेजें'));
      await settle(t);
      expect(saves, [true]);
      expect(find.text('सहेजा गया'), findsOneWidget);

      await t.ensureVisible(find.text('गलत या पुरानी जानकारी बताएं'));
      await t.tap(find.text('गलत या पुरानी जानकारी बताएं'));
      await settle(t);
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.text('जानकारी गलत है'));
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'रिपोर्ट भेजें'));
      await settle(t);
      expect(reported, 'INCORRECT');
    });
  });
}
