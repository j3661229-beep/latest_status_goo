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
    testWidgets('shows an Inshorts-style card: title, summary, publisher, relative time, AI disclaimer and actions', (t) async {
      final repo = FakeRepo(onList: (f, c, p) async => ShortPage([mkNews('1', video: 'https://cdn.test/1.mp4', summary: 'यह साठ शब्दों का सारांश है।')], false));
      await pumpFeed(t, repo);
      expect(find.text('ख़बर 1'), findsOneWidget);
      expect(find.text('यह साठ शब्दों का सारांश है।'), findsOneWidget);
      expect(find.textContaining('PIB · 3 घंटे पहले'), findsOneWidget);
      expect(find.textContaining('AI-सहायता प्राप्त सारांश'), findsOneWidget);
      for (final tip in ['सहेजें', 'शेयर', 'रिपोर्ट']) {
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
      expect(find.text('अभी कोई खबर नहीं'), findsOneWidget);
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
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(seconds: 1)); // snackbar exit animation (it covers the action row)
      }
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

    testWidgets('a video never autoplays; it plays only in the viewer after tapping the play button, and is released on close', (t) async {
      final repo = FakeRepo(onList: (f, c, p) async => ShortPage([mkNews('1', video: 'https://cdn.test/1.mp4')], false));
      await pumpFeed(t, repo);
      expect(stats.created, 0, reason: 'cards must not load video on their own');
      expect(platform.playing, isEmpty);

      await t.tap(find.byIcon(Icons.play_arrow_rounded));
      await settle(t);
      expect(stats.created, 1);
      expect(platform.playing, isNotEmpty);

      await t.tap(find.byTooltip('बंद करें'));
      await settle(t);
      await settle(t);
      expect(stats.outstanding, 0);
    });

    testWidgets('CARD_ONLY shows no play button or duration and never creates a player, even with a stale video URL', (t) async {
      final repo = FakeRepo(onList: (f, c, p) async => ShortPage(
          [mkNews('1', video: 'https://cdn.test/1.mp4', format: 'CARD_ONLY', duration: 25, summary: 'सारांश')], false));
      await pumpFeed(t, repo);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(find.text('25 सेकंड'), findsNothing);
      expect(find.text('सारांश'), findsOneWidget);
      expect(stats.created, 0);
    });

    testWidgets('CARD_WITH_VIDEO shows the play button and duration; nothing loads until the user taps play', (t) async {
      final repo = FakeRepo(onList: (f, c, p) async => ShortPage(
          [mkNews('1', video: 'https://cdn.test/1.mp4', format: 'CARD_WITH_VIDEO', duration: 25)], false));
      await pumpFeed(t, repo);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.text('25 सेकंड'), findsOneWidget);
      expect(stats.created, 0);
    });

    testWidgets('CARD_WITH_VIDEO whose video is not yet approved (no URL) is a plain card', (t) async {
      final repo = FakeRepo(onList: (f, c, p) async => ShortPage([mkNews('1', format: 'CARD_WITH_VIDEO')], false));
      await pumpFeed(t, repo);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(find.text('ख़बर 1'), findsOneWidget);
    });

    testWidgets('a text-only card (no summary, no image, no video) still renders with all actions', (t) async {
      final repo = FakeRepo(onList: (f, c, p) async => ShortPage([mkNews('1', format: 'CARD_ONLY')], false));
      await pumpFeed(t, repo);
      expect(find.text('ख़बर 1'), findsOneWidget);
      for (final tip in ['सहेजें', 'शेयर', 'रिपोर्ट']) {
        expect(find.byTooltip(tip), findsOneWidget, reason: tip);
      }
    });

    testWidgets('a card without a video shows no play button', (t) async {
      final repo = FakeRepo(onList: (f, c, p) async => ShortPage([mkNews('1')], false));
      await pumpFeed(t, repo);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });

    testWidgets('opening details navigates to the detail route', (t) async {
      final repo = FakeRepo(onList: (f, c, p) async => ShortPage([mkNews('1')], false));
      final visited = await pumpFeed(t, repo);
      await t.tap(find.text('विवरण और स्रोत'));
      await settle(t);
      expect(visited, ['1']);
      expect(find.text('DETAIL'), findsOneWidget);
    });

    testWidgets('swiping shows the next card and counts its view without loading any video', (t) async {
      final repo = FakeRepo(onList: (f, c, p) async => ShortPage([
            mkNews('1', video: 'https://cdn.test/1.mp4'),
            mkNews('2', video: 'https://cdn.test/2.mp4'),
            mkNews('3', video: 'https://cdn.test/3.mp4'),
          ], false));
      await pumpFeed(t, repo);

      await t.fling(find.byType(PageView), const Offset(0, -600), 1500);
      await settle(t);
      expect(find.text('ख़बर 2'), findsOneWidget);
      expect(stats.created, 0);
      expect(repo.events, containsAll(['1:VIEW', '2:VIEW']));
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
