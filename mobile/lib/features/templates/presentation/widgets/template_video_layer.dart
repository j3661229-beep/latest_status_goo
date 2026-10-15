// lib/features/templates/presentation/widgets/template_video_layer.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../core/services/video_cache_service.dart';

/// Only one [TemplateVideoLayer] may own a decoder. A new claimant yields the
/// previous owner on the next frame so VideoPlayer is never unmounted during
/// another widget's build (that trip `semantics.parentDataDirty`).
class _VideoExclusiveLock {
  static _TemplateVideoLayerState? _owner;

  static void claim(_TemplateVideoLayerState next) {
    final prev = _owner;
    _owner = next;
    if (prev != null && !identical(prev, next)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (prev.mounted) prev.yieldToOther();
      });
    }
  }

  static void release(_TemplateVideoLayerState owner) {
    if (identical(_owner, owner)) _owner = null;
  }
}

/// Looping video artwork that loads in chunks and caches to disk.
///
/// Lifecycle rules (Media3 + Flutter semantics):
/// 1. Never [VideoPlayerController.dispose] while a [VideoPlayer] is still
///    mounted — drop it from the tree first, dispose next frame.
/// 2. Never [setState] from a [VisibilityDetector] callback (those fire during
///    layout). Always hop to a post-frame callback.
/// 3. Insert the [VideoPlayer] texture only in a post-frame callback so it is
///    not attached in the middle of a PageView / semantics pass.
/// 4. A generation counter invalidates in-flight [_start].
/// 5. A process-wide lock keeps a single decoder even if Home + Preview overlap.
class TemplateVideoLayer extends StatefulWidget {
  final String videoUrl;
  final BoxFit fit;

  /// Play without sound.
  final bool muted;

  /// Fraction of the card that must be visible to start playback.
  final double playThreshold;

  /// When false, skip [VisibilityDetector] (parent already mounts this widget
  /// only for the active page). Avoids layout-time callbacks on the Home pager.
  final bool pauseWhenObscured;

  const TemplateVideoLayer({
    super.key,
    required this.videoUrl,
    this.fit = BoxFit.cover,
    this.muted = false,
    this.playThreshold = 0.6,
    this.pauseWhenObscured = true,
  });

  @override
  State<TemplateVideoLayer> createState() => _TemplateVideoLayerState();
}

class _TemplateVideoLayerState extends State<TemplateVideoLayer> with WidgetsBindingObserver {
  static final _playerOptions = VideoPlayerOptions(mixWithOthers: false);

  VideoPlayerController? _controller;
  int _gen = 0;
  bool _starting = false;
  bool _failed = false;
  bool _wantPlay = true;
  bool _visibilityScheduled = false;
  double? _pendingVisible;
  Timer? _releaseTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _VideoExclusiveLock.claim(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _wantPlay) _start();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _safePause(_controller);
    } else if (_wantPlay) {
      _safePlay(_controller);
    }
  }

  /// Called by [_VideoExclusiveLock] when another layer takes the decoder.
  void yieldToOther() {
    _wantPlay = false;
    _dropController(rebuild: true);
  }

  Future<void> _start() async {
    _releaseTimer?.cancel();
    if (_controller != null || _starting || _failed || !_wantPlay) return;

    final cleanUrl = widget.videoUrl.trim();
    final uri = Uri.tryParse(cleanUrl);
    if (uri == null || !uri.hasScheme) {
      _setFailed();
      return;
    }

    _VideoExclusiveLock.claim(this);
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

      if (!mounted || gen != _gen || !_wantPlay) {
        await controller.dispose();
        return;
      }

      // Attach the texture on the next frame — never during layout/semantics.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || gen != _gen || !_wantPlay) {
          controller?.dispose();
          return;
        }
        setState(() => _controller = controller);
        _safePlay(controller);
      });
    } catch (e) {
      debugPrint('Template video failed to load: $e');
      if (controller != null) {
        await controller.dispose();
      }
      if (mounted && gen == _gen) _setFailed();
    } finally {
      if (gen == _gen) _starting = false;
    }
  }

  void _setFailed() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  /// Remove the player from the tree, then dispose on the next frame so
  /// [VideoPlayer] is not attached to a disposed controller.
  void _dropController({required bool rebuild}) {
    _releaseTimer?.cancel();
    final c = _controller;
    _controller = null;
    _gen++;
    _starting = false;
    if (c == null) {
      if (rebuild && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }
      return;
    }
    if (rebuild && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
        c.dispose();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        c.dispose();
      });
    }
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
    if (c == null || !_wantPlay) return;
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
    _pendingVisible = info.visibleFraction;
    if (_visibilityScheduled) return;
    _visibilityScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityScheduled = false;
      if (!mounted) return;
      final visible = _pendingVisible;
      if (visible == null) return;
      _applyVisibility(visible);
    });
  }

  void _applyVisibility(double visible) {
    if (visible >= widget.playThreshold) {
      _wantPlay = true;
      _releaseTimer?.cancel();
      _VideoExclusiveLock.claim(this);
      final c = _controller;
      if (c == null) {
        _start();
      } else {
        _safePlay(c);
      }
    } else {
      _wantPlay = false;
      _safePause(_controller);
      if (visible < 0.15) {
        _scheduleRelease();
      }
    }
  }

  @override
  void didUpdateWidget(TemplateVideoLayer old) {
    super.didUpdateWidget(old);
    if (old.muted != widget.muted) {
      try {
        _controller?.setVolume(widget.muted ? 0 : 1);
      } catch (_) {}
    }
    if (old.videoUrl != widget.videoUrl) {
      _failed = false;
      _wantPlay = true;
      _dropController(rebuild: true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _wantPlay) _start();
      });
    }
  }

  @override
  void dispose() {
    _VideoExclusiveLock.release(this);
    WidgetsBinding.instance.removeObserver(this);
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
              child: ExcludeSemantics(child: VideoPlayer(c)),
            ),
          ),
        ),
      );
    }
    if (!widget.pauseWhenObscured) return child;
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
