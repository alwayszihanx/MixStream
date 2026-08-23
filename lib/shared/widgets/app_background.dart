import 'package:flutter/material.dart';

/// Cinematic layered background used as the app shell backdrop.
///
/// Paints the surface color, a soft accent glow near the top, and a subtle
/// vignette toward the edges so every screen gains depth without per-screen
/// changes. Designed to sit behind the navigator (scaffolds are transparent).
class AppBackground extends StatelessWidget {
  final Widget child;
  final bool includeVignette;

  const AppBackground({
    super.key,
    required this.child,
    this.includeVignette = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = cs.surface;

    return Container(
      color: base,
      child: Stack(
        children: [
          // Soft accent glow rising from the top-center.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.65),
                  radius: 1.15,
                  colors: [
                    cs.primary.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6],
                ),
              ),
            ),
          ),
          // Subtle vignette darkening the edges.
          if (includeVignette)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.0,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.45),
                  ],
                    stops: const [0.55, 1.0],
                  ),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}
