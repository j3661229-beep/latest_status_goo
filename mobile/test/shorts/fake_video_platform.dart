// Fake video_player platform: counts controller creation/disposal so tests can assert the
// feed never holds more than one live decoder and always releases it.
// ignore_for_file: depend_on_referenced_packages
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class FakeVideoPlatform extends VideoPlayerPlatform with MockPlatformInterfaceMixin {
  int _next = 1;
  final Set<int> live = {};
  final List<int> created = [];
  final List<int> disposed = [];
  final Map<int, StreamController<VideoEvent>> _events = {};
  final Map<int, String> urls = {};
  final Set<int> playing = {};

  /// When set, `initialize()` of new players waits for this future (simulates slow network).
  Future<void>? initGate;
  bool failCreate = false;

  int get maxLive => _maxLive;
  int _maxLive = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async {
    if (failCreate) throw Exception('network down');
    final id = _next++;
    live.add(id);
    created.add(id);
    urls[id] = dataSource.uri ?? '';
    if (live.length > _maxLive) _maxLive = live.length;
    final ctrl = StreamController<VideoEvent>();
    _events[id] = ctrl;
    () async {
      if (initGate != null) await initGate;
      if (!ctrl.isClosed) {
        ctrl.add(VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 25),
          size: const Size(1080, 1920),
        ));
      }
    }();
    return id;
  }

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) => create(options.dataSource);

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;

  @override
  Future<void> dispose(int playerId) async {
    live.remove(playerId);
    playing.remove(playerId);
    disposed.add(playerId);
    await _events.remove(playerId)?.close();
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> play(int playerId) async => playing.add(playerId);
  @override
  Future<void> pause(int playerId) async => playing.remove(playerId);
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Widget buildView(int playerId) => SizedBox(key: ValueKey('fake-video-$playerId'));
  @override
  Widget buildViewWithOptions(VideoViewOptions options) => SizedBox(key: ValueKey('fake-video-${options.playerId}'));
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
  @override
  Future<void> setAllowBackgroundPlayback(bool allowBackgroundPlayback) async {}
}

/// Controller that records construction and dispose() calls (without needing real time to pass).
class TrackedController extends VideoPlayerController {
  // ignore: use_super_parameters
  TrackedController(Uri url, this.stats) : super.networkUrl(url) {
    stats.created++;
  }
  final ControllerStats stats;
  bool _counted = false;

  @override
  Future<void> dispose() {
    if (!_counted) {
      _counted = true;
      stats.disposeCalls++;
    }
    return super.dispose();
  }
}

class ControllerStats {
  int created = 0;
  int disposeCalls = 0;
  int get outstanding => created - disposeCalls;
  VideoPlayerController factory(Uri url) => TrackedController(url, this);
}
