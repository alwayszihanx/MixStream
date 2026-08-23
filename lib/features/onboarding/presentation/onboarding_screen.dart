import 'package:flutter/material.dart';
import 'package:mixstream/shared/widgets/app_icon.dart';

/// First-run onboarding shown after the splash. Uses only safe, standard
/// widgets (no blur/shader) so it never hangs the Impeller GPU.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.onDone});

  /// Called when the user finishes (Get Started) or skips.
  final VoidCallback? onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _page = 0;

  static const List<_OnboardingPage> _pages = [
    _OnboardingPage(
      icon: 'movie',
      title: 'Unlimited Movies & Shows',
      body:
          'Stream thousands of titles across many providers — all organized in one beautiful library.',
    ),
    _OnboardingPage(
      icon: 'download',
      title: 'Take It Offline',
      body:
          'Download your favorites and watch anywhere, even without a connection. Your library, always with you.',
    ),
    _OnboardingPage(
      icon: 'subtitles',
      title: 'A Premium Player',
      body:
          'Cinematic playback with subtitles, quality controls, and a sleek, distraction-free interface.',
    ),
  ];

  bool get _isLast => _page == _pages.length - 1;

  void _next() {
    if (_isLast) {
      widget.onDone?.call();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF66E29F);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Accent glow rising from the top-center.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.7),
                  radius: 1.2,
                  colors: [
                    accent.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6],
                ),
              ),
            ),
          ),
          // Vignette.
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
          SafeArea(
            child: Column(
              children: [
                // Top: skip only (the splash already presents the logo).
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                  child: Row(
                    children: [
                      const Spacer(),
                      TextButton(
                        onPressed: widget.onDone,
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Page content.
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      final p = _pages[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 36),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 128,
                              height: 128,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    accent.withValues(alpha: 0.35),
                                    accent.withValues(alpha: 0.05),
                                  ],
                                ),
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.5),
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: AppIcon(
                                  p.icon,
                                  size: 60,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 36),
                            Text(
                              p.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              p.body,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // Bottom: indicators + action button.
                Padding(
                  padding: const EdgeInsets.fromLTRB(36, 0, 36, 36),
                  child: Row(
                    children: [
                      Row(
                        children: List.generate(
                          _pages.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.only(right: 8),
                            width: i == _page ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: i == _page
                                  ? accent
                                  : Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(_isLast ? 'Get Started' : 'Next'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final String icon;
  final String title;
  final String body;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
  });
}
