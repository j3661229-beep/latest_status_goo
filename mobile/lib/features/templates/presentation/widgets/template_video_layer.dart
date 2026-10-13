// lib/features/templates/presentation/widgets/template_video_layer.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../core/services/video_cache_service.dart';

/// Looping video artwork (with sound unless [muted]) that loads in chunks and caches to disk.
///
/// Lifecycle rules (these prevent the Media3 / sliver crash cascade):
/// 1. Never [VideoPlayerController.dispose] while a [VideoPlayer] is still
///    mounted — drop the controller from the tree first, dispose next frame.
/// 2. A generation counter invalidates in-flight [_start] so a stale init
///    cannot assign or play a controller after URL change / unmount.
/// 3. Only one decoder should be live: callers should mount this widget for
///    the on-screen item only. Visibility still pauses when mostly off-screen.
class TemplateVideoLayer extends StatefulWidget {
  final String videoUrl;
  final BoxFit fit;

  /// Play without sound.
  final bool muted;

  /// Fraction of the card that must be visible to start playback.
  final double playThreshold;

  const TemplateVideoLayer({
    super.key,
    required this.videoUrl,
    this.fit = BoxFit.cover,
    this.muted = false,
    this.playThreshold = 0.6,
  });

  @override
  State<TemplateVideoLayer> createState() => _TemplateVideoLayerState();
}

class _TemplateVideoLayerState extends State<TemplateVideoLayer> {
  static final _playerOptions = VideoPlayerOptions(mixWithOthers: false);

  VideoPlayerController? _controller;
  int _gen = 0;
  bool _starting = false;
  bool _failed = false;
  bool _wantPlay = false;
  Timer? _releaseTimer;

  Future<void> _start() async {
    _releaseTimer?.cancel();
    if (_controller != null || _starting || _failed) return;

    final cleanUrl = widget.videoUrl.trim();
    final uri = Uri.tryParse(cleanUrl);
    if (uri == null || !uri.hasScheme) {
      if (mounted) setState(() => _failed = true);
      return;
    }

    _starting = true;
    final gen = ++_gen;
    VideoPlayerController? controller;
    try {
      final cachedFile = await VideoCacheService.instance.getCachedVideoFile(cleanUrl);
      if (cachedFile != null) {
        controller = VideoPlayerController.file(cachedFile, videoPlayerOptions: _playerOptions);
      } else {
        controller = VideoPlayerController.networkUrl(uri, videoPlayerOptions: _playerOptions);
        VideoCacheService.instance.prefetchVideo(cleanUrl);
      }

      await controller.initialize();
      await controller.setVolume(widget.muted ? 0 : 1);
      await controller.setLooping(true);

      if (!mounted || gen != _gen) {
        await controller.dispose();
        return;
      }

      setState(() => _controller = controller);
      if (_wantPlay) {
        await _safePlay(controller);
      }
    } catch (e) {
      debugPrint('Template video failed to load: $e');
      if (controller != null) {
        await controller.dispose();
      }
      if (mounted && gen == _gen) setState(() => _failed = true);
    } finally {
      if (gen == _gen) _starting = false;
    }
  }

  /// Remove the player from the tree, then dispose on the next frame so
  /// [VideoPlayer] is not attached to a disposed controller.
  void _dropController({required bool rebuild}) {
    _releaseTimer?.cancel();
    final c = _controller;
    _controller = null;
    _gen++;
    _starting = false;
    if (rebuild && mounted) setState(() {});
    if (c == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      c.dispose();
    });
  }

  void _scheduleRelease() {
    _releaseTimer?.cancel();
    _safePause(_controller);
    _releaseTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      _dropController(rebuild: true);
    });
  }

  Future<void> _safePlay(VideoPlayerController? c) async {
    if (c == null) return;
    try {
      if (!c.value.isInitialized) return;
      await c.play();
    } catch (e) {
      debugPrint('Template video play skipped: $e');
    }
  }

  void _safePause(VideoPlayerController? c) {
    if (c == null) return;
    try {
      if (c.value.isInitialized && c.value.isPlaying) c.pause();
    } catch (_) {}
  }

  void _onVisibility(VisibilityInfo info) {
    if (!mounted) return;
    final visible = info.visibleFraction;
    if (visible >= widget.playThreshold) {
      _wantPlay = true;
      _releaseTimer?.cancel();
      final c = _controller;
      if (c == null) {
        _start();
      } else {
        _safePlay(c);
      }
    } else {
      _wantPlay = false;
      _safePause(_controller);
      // Release as soon as the card is mostly gone — not only at exactly 0 —
      // so a neighboring PageView page cannot keep a decoder warm.
      if (visible < 0.15) {
        _scheduleRelease();
      }
    }
  }

  @override
  void didUpdateWidget(TemplateVideoLayer old) {
    super.didUpdateWidget(old);
    if (old.muted != widget.muted) {
      _controller?.setVolume(widget.muted ? 0 : 1);
    }
    if (old.videoUrl != widget.videoUrl) {
      _failed = false;
      _wantPlay = false;
      _dropController(rebuild: true);
    }
  }

  @override
  void dispose() {
    _releaseTimer?.cancel();
    _gen++;
    final c = _controller;
    _controller = null;
    super.dispose();
    if (c != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        c.dispose();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    Widget child = const SizedBox.expand();
    if (c != null && _isInitialized(c)) {
      child = ClipRect(
        child: SizedBox.expand(
          child: FittedBox(
            fit: widget.fit,
            child: SizedBox(
              width: _sizeOr(c, isWidth: true),
              height: _sizeOr(c, isWidth: false),
              child: ExcludeSemantics(
                child: VideoPlayer(c),
              ),
            ),
          ),
        ),
      );
    }
    return VisibilityDetector(
      key: ValueKey('tv-${widget.videoUrl}'),
      onVisibilityChanged: _onVisibility,
      child: child,
    );
  }

  static bool _isInitialized(VideoPlayerController c) {
    try {
      return c.value.isInitialized;
    } catch (_) {
      return false;
    }
  }

  static double _sizeOr(VideoPlayerController c, {required bool isWidth}) {
    try {
      final size = c.value.size;
      final v = isWidth ? size.width : size.height;
      if (v > 0) return v;
    } catch (_) {}
    return isWidth ? 360 : 640;
  }
}
