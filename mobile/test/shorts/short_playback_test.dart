import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:status_go/features/shorts/presentation/widgets/short_player.dart';

import 'fake_video_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeVideoPlatform fake;

  setUp(() {
    fake = FakeVideoPlatform();
    VideoPlayerPlatform.instance = fake;
  });

  /// Run a frame (post-frame disposals fire), then let real time pass: VideoPlayerController.dispose()
  /// awaits a stream cancel that only completes outside FakeAsync.
  Future<void> frames(WidgetTester t) async {
    await t.pump();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
    await t.pump();
  }

  testWidgets('never holds more than one live decoder while swiping through pages', (t) async {
    final pb = ShortPlaybackController();
    for (final id in ['a', 'b', 'c', 'd']) {
      await pb.activate(id, 'https://cdn.test/$id.mp4');
      await frames(t);
      expect(pb.activeId, id);
      expect(pb.controller, isNotNull);
    }
    expect(fake.created.length, 4);
    expect(fake.maxLive <= 2, isTrue, reason: 'old decoder may overlap only until the next frame');
    expect(fake.live.length, 1, reason: 'after frames settle only the active decoder is alive');
    expect(fake.disposed.length, 3);
    pb.dispose();
    await frames(t);
    expect(fake.live, isEmpty);
  });

  testWidgets('old controller is removed from the tree BEFORE it is disposed', (t) async {
    final pb = ShortPlaybackController();
    await pb.activate('a', 'https://cdn.test/a.mp4');
    await frames(t);
    final firstId = fake.created.first;

    var treeHadOldController = true;
    pb.addListener(() {
      // At notification time the old controller must already be detached.
      treeHadOldController = pb.controller != null && pb.controller!.playerId == firstId;
    });
    await pb.activate('b', 'https://cdn.test/b.mp4');
    expect(treeHadOldController, isFalse);
    // Not disposed synchronously — only after the next frame.
    expect(fake.disposed.contains(firstId), isFalse);
    await frames(t);
    expect(fake.disposed.contains(firstId), isTrue);
    pb.dispose();
    await frames(t);
  });

  testWidgets('a slow initialisation that finishes after the user swiped on is discarded and disposed', (t) async {
    final pb = ShortPlaybackController();
    // Gate only the first (slow) player.
    fake.initGate = Future<void>(() async {}).then((_) => Future<void>.delayed(const Duration(milliseconds: 200)));
    final first = pb.activate('a', 'https://cdn.test/a.mp4');
    fake.initGate = null; // later players initialise immediately
    await t.pump(const Duration(milliseconds: 5));
    final second = pb.activate('b', 'https://cdn.test/b.mp4');
    await t.pump(const Duration(milliseconds: 50));
    await second;
    expect(pb.activeId, 'b');
    await t.pump(const Duration(milliseconds: 300));
    await first;
    await frames(t);
    expect(pb.activeId, 'b');
    expect(fake.live.length, 1, reason: 'stale controller for "a" must not stay alive');
    expect(pb.controller, isNotNull);
    expect(fake.urls[pb.controller!.playerId], endsWith('b.mp4'));
    pb.dispose();
    await frames(t);
  });

  testWidgets('init failure surfaces an error state and leaks nothing; later pages still work', (t) async {
    final pb = ShortPlaybackController();
    fake.failCreate = true;
    await pb.activate('a', 'https://cdn.test/a.mp4');
    await frames(t);
    expect(pb.error, isNotNull);
    expect(pb.controller, isNull);
    fake.failCreate = false;
    await pb.activate('b', 'https://cdn.test/b.mp4');
    await frames(t);
    expect(pb.error, isNull);
    expect(pb.controller, isNotNull);
    pb.dispose();
    await frames(t);
    expect(fake.live, isEmpty);
  });

  testWidgets('items without a video just show the poster (no controller created)', (t) async {
    final pb = ShortPlaybackController();
    await pb.activate('a', null);
    await frames(t);
    expect(fake.created, isEmpty);
    expect(pb.controller, isNull);
    pb.dispose();
  });

  testWidgets('suspend pauses (route covered / app backgrounded); resume plays unless the user paused', (t) async {
    final pb = ShortPlaybackController();
    await pb.activate('a', 'https://cdn.test/a.mp4');
    await frames(t);
    final id = fake.created.single;
    expect(fake.playing, contains(id));

    pb.didChangeAppLifecycleState(AppLifecycleState.paused);
    await frames(t);
    expect(fake.playing, isEmpty);
    pb.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await frames(t);
    expect(fake.playing, contains(id));

    pb.togglePlay(); // user pauses
    await frames(t);
    expect(fake.playing, isEmpty);
    pb.suspend();
    pb.resume();
    await frames(t);
    expect(fake.playing, isEmpty, reason: 'resume must not override an explicit user pause');
    pb.dispose();
    await frames(t);
  });

  testWidgets('activating after dispose is a no-op', (t) async {
    final pb = ShortPlaybackController()..dispose();
    await pb.activate('a', 'https://cdn.test/a.mp4');
    expect(fake.created, isEmpty);
  });
}
