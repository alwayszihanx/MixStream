import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Cinematic 7‑stage MixStream splash:
/// 1. Black + subtle ambient green glow.
/// 2. Posters emerge from different directions (fade + scale + rotation).
/// 3. Posters drift toward center (gravity pull), depth via opacity.
/// 4. Posters collapse into the logo (M badge → wordmark).
/// 5. Light sweep across the logo.
/// 6. Hold.
/// 7. Content fades to black, then the app is revealed seamlessly.
///
/// IMPORTANT: no `ImageFilter.blur` / `ShaderMask` (they hang Impeller on this
/// device) and no full‑screen `Opacity` (caused a gray washout). Depth "blur"
/// is faked with per‑card opacity, and the sweep is a moving gradient.
class AppSplashScreen extends StatefulWidget {
  const AppSplashScreen({super.key, this.onFinished});

  final VoidCallback? onFinished;

  @override
  State<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends State<AppSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 3500),
      )..forward();

  static const Color _accent = Color(0xFF66E29F);

  // Stage boundaries as fractions of the 3.5s timeline (rebalanced for a
  // calmer, more cinematic pace): glow 0–0.16, posters emerge 0.16–0.46,
  // collapse+logo 0.46–0.66, sweep 0.66–0.76, hold 0.76–0.88, fade 0.88–1.0.
  static const double _s1 = 0.16;
  static const double _s2 = 0.46;
  static const double _s3 = 0.60;
  static const double _s4 = 0.66;
  static const double _s5 = 0.76;
  static const double _s6 = 0.88;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onFinished?.call();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _range(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);
  double _lerp(double a, double b, double x) => a + (b - a) * x;
  double _easeOutCubic(double x) => 1 - math.pow(1 - x, 3).toDouble();
  double _easeOutQuart(double x) => 1 - math.pow(1 - x, 4).toDouble();
  double _easeInOutCubic(double x) =>
      x < 0.5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3) / 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          return Stack(
            children: [
              _buildGlow(t),
              Center(child: _buildPosters(t)),
              Center(child: _buildLogo(t)),
              _buildSubtitle(t),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGlow(double t) {
    final contentFade = 1 - _range(t, _s6, 1.0);
    final glow = (0.15 * _range(t, 0, _s1) + 0.13 * _range(t, _s3, _s4))
        .clamp(0.0, 0.28) *
        contentFade;
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.15,
            colors: [
              _accent.withValues(alpha: glow),
              Colors.transparent,
            ],
            stops: const [0.0, 0.65],
          ),
        ),
      ),
    );
  }

  Widget _buildPosters(double t) {
    final contentFade = 1 - _range(t, _s6, 1.0);
    final emerge = _range(t, _s1, _s2);
    final emergeE = _easeOutCubic(emerge);
    final collapse = _range(t, _s3, _s4);

    // Spread shrinks from far → scattered → center across stages 2‑4.
    double spread;
    if (t < _s2) {
      spread = _lerp(1.0, 0.52, emergeE);
    } else if (t < _s4) {
      spread = _lerp(0.52, 0.0, _easeInOutCubic(_range(t, _s2, _s4)));
    } else {
      spread = 0.0;
    }

    final rotCorrect = _range(t, _s1, _s4); // rotation eases to 0 by stage 4

    final children = <Widget>[];
    for (var i = 0; i < _posters.length; i++) {
      final p = _posters[i];
      final dx = p.dir.dx * spread * 250;
      final dy = p.dir.dy * spread * 250;

      double scale;
      if (t < _s2) {
        scale = _lerp(0.7, 1.0, emergeE);
      } else {
        scale = _lerp(1.0, 0.0, _easeInOutCubic(collapse));
      }

      final rot = (p.rot * (1 - rotCorrect)) * (math.pi / 180);

      double opacity;
      if (t < _s2) {
        opacity = emerge;
      } else {
        opacity = 1.0 - collapse;
      }
      // Faked depth: back cards are dimmer (never a real blur layer).
      opacity *= (1 - p.depth * 0.45);
      opacity *= contentFade;
      if (opacity <= 0.01) continue;

      children.add(
        Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.rotate(
            angle: rot,
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: _posterCard(p),
              ),
            ),
          ),
        ),
      );
    }
    return Stack(
      alignment: Alignment.center,
      children: children,
    );
  }

  Widget _posterCard(_Poster p) {
    final fallback = Container(
      width: 112,
      height: 164,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: p.colors,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            p.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
            ),
          ),
        ),
      ),
    );

    final Widget content = p.imagePath != null
        ? Image.asset(
            p.imagePath!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          )
        : fallback;

    return Container(
      width: 112,
      height: 164,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: content,
      ),
    );
  }

  Widget _buildLogo(double t) {
    final contentFade = 1 - _range(t, _s6, 1.0);
    final logoAppear = _range(t, _s3, _s4);
    final logoE = _easeOutQuart(logoAppear);
    final logoScale = _lerp(0.7, 1.0, logoE);
    final logoOp = logoAppear * contentFade;

    // M badge first, then the wordmark cross‑fades in.
    final mBadgeOp = _range(t, _s3, _s3 + 0.07) *
        (1 - _range(t, _s3 + 0.09, _s4)) *
        contentFade;
    final wordmarkOp = _range(t, _s3 + 0.08, _s4) * contentFade;

    // Light sweep across the logo during stage 5.
    final sweepP = _range(t, _s4, _s5);
    final sweepX = _lerp(-170.0, 170.0, sweepP);
    final sweepVisible = sweepP > 0.001 && sweepP < 0.999;

    return ClipRect(
      child: SizedBox(
        width: 340,
        height: 240,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: logoScale,
              child: Opacity(
                opacity: logoOp,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: mBadgeOp,
                      child: Container(
                        width: 128,
                        height: 128,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _accent.withValues(alpha: 0.55),
                              blurRadius: 34,
                              spreadRadius: 6,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/mixstream.png',
                          width: 128,
                          height: 128,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: wordmarkOp,
                      child: Image.asset(
                        'assets/images/wordmark.png',
                        width: 260,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (sweepVisible)
              Transform.translate(
                offset: Offset(sweepX, 0),
                child: Opacity(
                  opacity: math.sin(sweepP * math.pi).clamp(0.0, 1.0),
                  child: Container(
                    width: 70,
                    height: 220,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: 0.35),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitle(double t) {
    final contentFade = 1 - _range(t, _s6, 1.0);
    final subOp = _range(t, _s5, _s6) * contentFade;
    if (subOp <= 0.01) return const SizedBox.shrink();
    return Positioned(
      bottom: 90,
      left: 0,
      right: 0,
      child: Opacity(
        opacity: subOp,
        child: const Text(
          'Unlimited Movies & Shows',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 15,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _Poster {
  const _Poster({
    required this.label,
    required this.colors,
    required this.dir,
    required this.rot,
    required this.depth,
    this.imagePath,
  });

  final String label;
  final List<Color> colors;
  final Offset dir;
  final double rot; // degrees
  final double depth; // 0 = front, 1 = back
  final String? imagePath;
}

const List<_Poster> _posters = [
  _Poster(
    label: 'HORROR',
    colors: [Color(0xFF6B2D6E), Color(0xFF1A0A1E)],
    dir: Offset(-1, -0.7),
    rot: -8,
    depth: 0.2,
    imagePath: 'assets/images/horror.jpg',
  ),
  _Poster(
    label: 'THRILLER',
    colors: [Color(0xFF8C7BF0), Color(0xFF2A1F5E)],
    dir: Offset(0.7, 0),
    rot: 6,
    depth: 0.7,
    imagePath: 'assets/images/thriller.jpg',
  ),
  _Poster(
    label: 'ACTION',
    colors: [Color(0xFFE23B4B), Color(0xFF7A1420)],
    dir: Offset(-1, -0.7),
    rot: -8,
    depth: 0.2,
    imagePath: 'assets/images/action.jpg',
  ),
  _Poster(
    label: 'SCI-FI',
    colors: [Color(0xFF5B8DEF), Color(0xFF2A1A6E)],
    dir: Offset(1, -0.8),
    rot: 7,
    depth: 0.6,
    imagePath: 'assets/images/scifi.jpg',
  ),
  _Poster(
    label: 'ANIME',
    colors: [Color(0xFFFF7AC6), Color(0xFF7A2BD0)],
    dir: Offset(-1, 0.8),
    rot: -5,
    depth: 0.4,
    imagePath: 'assets/images/anime.jpg',
  ),
  _Poster(
    label: 'DRAMA',
    colors: [Color(0xFFE0A458), Color(0xFF8A4B1E)],
    dir: Offset(1, 0.7),
    rot: 8,
    depth: 0.1,
    imagePath: 'assets/images/drama.jpg',
  ),
  _Poster(
    label: 'COMEDY',
    colors: [Color(0xFFF2D750), Color(0xFF9A6B12)],
    dir: Offset(-0.7, 0),
    rot: -6,
    depth: 0.3,
    imagePath: 'assets/images/comedy.jpg',
  ),
  _Poster(
    label: 'DOCUMENTARY',
    colors: [Color(0xFF7BD66A), Color(0xFF1E5E2A)],
    dir: Offset(0, 1),
    rot: 4,
    depth: 0.5,
    imagePath: 'assets/images/documentary.jpg',
  ),
];
