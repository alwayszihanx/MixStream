import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A smooth "pulse" loading indicator made of dots.
///
/// Several dots are arranged around the circle. As time flows, brightness and
/// size travel through the dots one by one: the leading dot grows bright and
/// larger, the trailing ones shrink and dim — a smooth, continuous pulsing
/// rhythm (no spinning). The dots cycle through the theme's primary /
/// tertiary / secondary accents so it always matches the app.
///
/// On small render sizes (thumbnails, buttons) the dot count drops so the
/// indicator still looks clean instead of cramped.
class AppLoadingIndicator extends StatefulWidget {
  /// The color of the loading indicator. If null, the theme's color scheme is
  /// used to build a colorful gradient (primary → tertiary → secondary).
  final Color? color;

  /// Sizing constraints for the indicator. Defaults to 48x48.
  final BoxConstraints? constraints;

  const AppLoadingIndicator({
    super.key,
    this.color,
    this.constraints,
  });

  /// Small convenience variant used inside buttons, thumbnails and inline
  /// rows where a 48px indicator would be too large.
  const AppLoadingIndicator.small({
    super.key,
    this.color,
  }) : constraints = const BoxConstraints(
         minWidth: 16,
         minHeight: 16,
         maxWidth: 20,
         maxHeight: 20,
       );

  @override
  State<AppLoadingIndicator> createState() => _AppLoadingIndicatorState();
}

class _AppLoadingIndicatorState extends State<AppLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final constraints = widget.constraints;
    final double width = constraints?.hasBoundedWidth == true
        ? constraints!.maxWidth
        : 48.0;
    final double height = constraints?.hasBoundedHeight == true
        ? constraints!.maxHeight
        : 48.0;

    // Very small containers feel cleaner with fewer, larger dots.
    final shortest = math.min(width, height);
    final int dotCount = shortest <= 22 ? 6 : 8;

    return RepaintBoundary(
      child: SizedBox(
        width: width,
        height: height,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final scheme = Theme.of(context).colorScheme;
            final List<Color> colors;
            if (widget.color != null) {
              colors = [
                widget.color!,
                widget.color!.withValues(alpha: 0.6),
                widget.color!.withValues(alpha: 0.3),
              ];
            } else {
              colors = [scheme.primary, scheme.tertiary, scheme.secondary];
            }

            return CustomPaint(
              painter: _DotPulsePainter(
                t: _controller.value,
                colors: colors,
                dotCount: dotCount,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DotPulsePainter extends CustomPainter {
  final double t;
  final List<Color> colors;
  final int dotCount;

  _DotPulsePainter({
    required this.t,
    required this.colors,
    required this.dotCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);

    // Design space is 48px; scale everything linearly for any size.
    final s = size.shortestSide / 48.0;
    final ringRadius = 18.0 * s;
    final baseDot = 4.2 * s;

    for (var i = 0; i < dotCount; i++) {
      // A traveling wave: the "peak" (bright + large) sweeps around the
      // circle; dots ahead smear off toward dim/small, dots behind swell.
      final phase = (t - i / dotCount) % 1.0;

      // 1.0 at the peak → falls to ~0.15 at the tail. Smooth sine so there
      // are no jumps as the wave wraps around.
      final intensity = (math.cos(phase * 2 * math.pi) + 1) / 2;
      final eased = 1 - math.cos(intensity * math.pi / 2);

      final angle = -math.pi / 2 + i / dotCount * 2 * math.pi;
      final p = Offset(
        center.dx + ringRadius * math.cos(angle),
        center.dy + ringRadius * math.sin(angle),
      );

      final radius = baseDot * (0.45 + 0.55 * eased);
      final base = colors[i % colors.length];
      final color = Color.lerp(
        base.withValues(alpha: 0.16),
        base,
        eased,
      )!;

      canvas.drawCircle(p, radius, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_DotPulsePainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.colors != colors ||
        oldDelegate.dotCount != dotCount;
  }
}