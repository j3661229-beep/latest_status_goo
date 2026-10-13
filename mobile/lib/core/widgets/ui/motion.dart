// lib/core/widgets/ui/motion.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

/// Wraps any widget with a tap-scale micro-animation (and optional haptics).
///
/// ```dart
/// PressableScale(onTap: () => ..., semanticLabel: 'Open', child: card)
/// ```
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;
  final String? semanticLabel;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.96,
    this.haptic = false,
    this.semanticLabel,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    final gesture = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap?.call();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: AppMotion.instant,
        curve: AppMotion.standard,
        child: widget.child,
      ),
    );

    if (widget.semanticLabel != null && widget.semanticLabel!.isNotEmpty) {
      return Semantics(
        button: enabled,
        label: widget.semanticLabel,
        child: gesture,
      );
    }
    return gesture;
  }
}

/// Entrance animation: fades in while sliding up. Use [index] for staggered lists.
///
/// ```dart
/// FadeSlideIn(index: i, child: tile)
/// ```
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;
  final Duration duration;
  final double dy;
  final double dx;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.delay = Duration.zero,
    this.duration = AppMotion.slow,
    this.dy = 18,
    this.dx = 0,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _curve = CurvedAnimation(parent: _c, curve: AppMotion.standard);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final stagger = AppMotion.stagger * widget.index.clamp(0, 8);
    final total = widget.delay + stagger;
    if (total == Duration.zero) {
      _c.forward();
    } else {
      _timer = Timer(total, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: AnimatedBuilder(
        animation: _curve,
        child: widget.child,
        builder: (context, child) => Transform.translate(
          offset: Offset(widget.dx * (1 - _curve.value), widget.dy * (1 - _curve.value)),
          child: child,
        ),
      ),
    );
  }
}

/// Dot page indicator; the active dot stretches into a pill.
///
/// ```dart
/// PageIndicator(count: 3, index: page)
/// ```
class PageIndicator extends StatelessWidget {
  final int count;
  final int index;
  final Color? activeColor;
  final Color? inactiveColor;
  final double dotSize;

  const PageIndicator({
    super.key,
    required this.count,
    required this.index,
    this.activeColor,
    this.inactiveColor,
    this.dotSize = 8,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final active = activeColor ?? p.primary;
    final inactive = inactiveColor ?? p.border;
    return Semantics(
      label: 'Page ${index + 1} of $count',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(count, (i) {
          final sel = i == index;
          return AnimatedContainer(
            duration: AppMotion.normal,
            curve: AppMotion.standard,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: sel ? dotSize * 3 : dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: sel ? active : inactive,
              borderRadius: BorderRadius.circular(dotSize),
            ),
          );
        }),
      ),
    );
  }
}
