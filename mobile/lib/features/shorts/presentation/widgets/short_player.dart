// lib/features/shorts/presentation/widgets/short_player.dart
//
// Playback for the shorts feed. Design rules (learned from the Home feed crash in
// PROJECT_AUDIT.md — Media3 release while VideoPlayer is still mounted):
//   1. The FEED owns at most ONE controller, for the active page only. Pages never
//      create controllers.
//   2. Switching/disposing: first remove the controller from the widget tree
//      (setState → null), and dispose it on the NEXT frame.
//   3. Never setState from a layout/visibility callback; always hop to a post-frame.
//   4. A generation counter drops results of in-flight initialisations.
//   5. Pause on app background / when another route covers the feed.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

typedef ControllerFactory = VideoPlayerController Function(Uri url);

VideoPlayerController defaultControllerFactory(Uri url) => VideoPlayerController.networkUrl(
      url,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );

/// Owns the single active controller for a feed.
class ShortPlaybackController extends ChangeNotifier with WidgetsBindingObserver {
  ShortPlaybackController({ControllerFactory? factory}) : _factory = factory ?? defaultControllerFactory {
    WidgetsBinding.instance.addObserver(this);
  }

  final ControllerFactory _factory;
  VideoPlayerController? _controller;
  String? _activeId;
  int _generation = 0;
  bool _disposed = false;
  bool _suspended = false; // route covered / app backgrounded
  bool _userPaused = false;
  bool _muted = false;
  Object? _error;

  VideoPlayerController? get controller => _controller;
  String? get activeId => _activeId;
  bool get muted => _muted;
  Object? get error => _error;
  bool get isPlaying => _controller?.value.isPlaying ?? false;

  /// Activate [id]/[url]; releases the previous controller safely.
  Future<void> activate(String id, String? url) async {
    if (_disposed || _activeId == id) return;
    final gen = ++_generation;
    _activeId = id;
    _error = null;
    _userPaused = false;
    _release(); // drop from tree now, dispose next frame
    if (url == null) {
      _notify();
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _notify();
      return;
    }
    final c = _factory(uri);
    try {
      await c.initialize();
      if (_disposed || gen != _generation) {
        unawaited(c.dispose());
        return;
      }
      await c.setLooping(true);
      await c.setVolume(_muted ? 0 : 1);
      _controller = c;
      _notify();
      if (!_suspended) await c.play();
    } catch (e) {
      unawaited(c.dispose());
      if (_disposed || gen != _generation) return;
      _error = e;
      _notify();
    }
  }

  /// Release the active video (the card feed only plays when the user opens the viewer).
  void stop() {
    if (_disposed) return;
    _generation++;
    _activeId = null;
    _error = null;
    _release();
    _notify();
  }

  void togglePlay() {
    final c = _controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      _userPaused = true;
      c.pause();
    } else {
      _userPaused = false;
      if (!_suspended) c.play();
    }
    _notify();
  }

  void toggleMute() {
    _muted = !_muted;
    _controller?.setVolume(_muted ? 0 : 1);
    _notify();
  }

  /// Another route covers the feed (detail screen, sheets) or the tab is hidden.
  void suspend() {
    _suspended = true;
    _controller?.pause();
    _notify();
  }

  void resume() {
    _suspended = false;
    if (!_userPaused) _controller?.play();
    _notify();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      resume();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
      suspend();
    }
  }

  /// Detach from the tree first, dispose on the next frame.
  void _release() {
    final old = _controller;
    _controller = null;
    if (old == null) return;
    _notify();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(old.dispose()));
    // If no frame is scheduled (e.g. tests / idle app), make sure one runs.
    WidgetsBinding.instance.scheduleFrame();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    final old = _controller;
    _controller = null;
    if (old != null) {
      // The owning widget is being torn down; its VideoPlayer leaves the tree this frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(old.dispose()));
      WidgetsBinding.instance.scheduleFrame(); // guarantee the callback runs even if the tree is idle
    }
    super.dispose();
  }
}

/// Renders the active controller (if any) over [placeholder]. Tap toggles play/pause.
class ShortVideoSurface extends StatelessWidget {
  const ShortVideoSurface({
    super.key,
    required this.playback,
    required this.id,
    required this.placeholder,
  });

  final ShortPlaybackController playback;
  final String id;
  final Widget placeholder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: playback,
      builder: (context, _) {
        final c = playback.activeId == id ? playback.controller : null;
        return Stack(
          fit: StackFit.expand,
          children: [
            placeholder,
            if (c != null && c.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: c.value.aspectRatio == 0 ? 9 / 16 : c.value.aspectRatio,
                  child: VideoPlayer(c),
                ),
              ),
          ],
        );
      },
    );
  }
}
