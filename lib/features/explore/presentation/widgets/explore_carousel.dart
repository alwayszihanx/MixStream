import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/router/app_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../core/utils/layout_constants.dart';
import '../../../../shared/widgets/cards_wrapper.dart';
import '../../../../core/utils/responsive_breakpoints.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/device_info_provider.dart';

import '../../../../shared/widgets/thumbnail_error_placeholder.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../../core/domain/entity/multimedia_item.dart';

/// Lightweight controller for the hero carousel.
/// API-compatible with the old CarouselSliderController (nextPage/previousPage).
class HeroCarouselController {
  VoidCallback? onNextPage;
  VoidCallback? onPreviousPage;

  void nextPage({Duration? duration, Curve? curve}) => onNextPage?.call();
  void previousPage({Duration? duration, Curve? curve}) =>
      onPreviousPage?.call();
}

class ExploreCarousel extends ConsumerStatefulWidget {
  final List<MultimediaItem> movies;
  final ScrollController? scrollController;
  final void Function(MultimediaItem)? onTap;
  final VoidCallback? onNavigateUp;

  /// Called once after initState with the internal [HeroCarouselController]
  /// so the parent can drive prev/next from an external UI (e.g. header arrows).
  final void Function(HeroCarouselController controller)? onControllerReady;

  const ExploreCarousel({
    super.key,
    required this.movies,
    this.scrollController,
    this.onTap,
    this.onNavigateUp,
    this.onControllerReady,
  });

  @override
  ConsumerState<ExploreCarousel> createState() => _ExploreCarouselState();
}

// Intents used by the carousel's keyboard shortcuts. Defined at file scope so
// they're const-constructible and stable across rebuilds.
class _CarouselUpIntent extends Intent {
  const _CarouselUpIntent();
}

class _CarouselPrevIntent extends Intent {
  const _CarouselPrevIntent();
}

class _CarouselNextIntent extends Intent {
  const _CarouselNextIntent();
}

class _ExploreCarouselState extends ConsumerState<ExploreCarousel>
    with TickerProviderStateMixin {
  final ValueNotifier<int> _currentIndexNotifier = ValueNotifier<int>(0);
  final HeroCarouselController _heroCarouselController =
      HeroCarouselController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0.0);
  // Single anchor focus node so the carousel acts as ONE focus target on TV/
  // keyboard. Otherwise each slide is independently focusable and pages cause
  // focus to drop into the next row when slides unmount.
  final FocusNode _carouselFocusNode = FocusNode(debugLabel: 'carousel_anchor');
  bool _isFocusHighlighted = false;
  // True while the carousel occupies any visible viewport. Drives autoPlay
  // so the 5s slide loop pauses when the user scrolls past it — eliminates
  // off-screen frame work and the resulting battery / raster drain.
  bool _isVisibleOnScreen = true;

  // Crossfade + scale transition
  late final AnimationController _transitionController;
  late final Animation<double> _transitionAnimation;
  int _currentSlide = 0;
  int? _previousSlide;
  bool _isTransitioning = false;

  // Progress bar fill — also serves as the auto-advance timer (5s).
  late final AnimationController _fillController;

  @override
  void initState() {
    super.initState();

    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _transitionAnimation = CurvedAnimation(
      parent: _transitionController,
      curve: Curves.fastOutSlowIn,
    );
    _transitionController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _isTransitioning = false;
          _previousSlide = null;
        });
      }
    });

    _fillController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _fillController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _goToNextSlide();
      }
    });

    _heroCarouselController.onNextPage = _goToNextSlide;
    _heroCarouselController.onPreviousPage = _goToPreviousSlide;

    widget.scrollController?.addListener(_onParentScroll);
    // Expose the internal controller to the parent so header arrows can
    // drive carousel navigation. Deferred to post-frame to avoid calling
    // setState on an ancestor while the widget tree is still building.
    if (widget.onControllerReady != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onControllerReady!(_heroCarouselController);
      });
    }

    _fillController.forward();
  }

  void _goToNextSlide() {
    if (widget.movies.length <= 1) return;
    final next = (_currentSlide + 1) % widget.movies.length;
    _startTransitionTo(next);
  }

  void _goToPreviousSlide() {
    if (widget.movies.length <= 1) return;
    final prev =
        (_currentSlide - 1 + widget.movies.length) % widget.movies.length;
    _startTransitionTo(prev);
  }

  void _startTransitionTo(int nextIndex) {
    if (_isTransitioning || nextIndex == _currentSlide || !mounted) return;
    setState(() {
      _previousSlide = _currentSlide;
      _currentSlide = nextIndex;
      _isTransitioning = true;
    });
    _currentIndexNotifier.value = nextIndex;
    _transitionController.forward(from: 0.0);
    _restartFill();
  }

  void _restartFill() {
    _fillController.reset();
    if (_isVisibleOnScreen) {
      _fillController.forward();
    }
  }

  void _onParentScroll() {
    // Always update — do NOT gate on _isVisibleOnScreen. Earlier we tried
    // to skip rebuilds while the carousel was off-screen, but that left
    // _scrollOffset frozen at a stale value; when the user scrolled back
    // up, syncing the offset on visibility-change caused a visible snap
    // (VisibilityDetector throttles, so the catch-up frame lands after
    // the user has already scrolled past it). The rebuild cost here is
    // negligible — Transform/RenderTransform reuses its RenderObject, the
    // CachedNetworkImage is cache-hit, and the whole carousel page is
    // wrapped in a RepaintBoundary so off-screen rebuilds don't ripple.
    if (widget.scrollController!.hasClients) {
      _scrollOffset.value = widget.scrollController!.offset;
    }
  }

  void _activateCurrent() {
    final movie = widget.movies[_currentSlide];
    if (widget.onTap != null) {
      widget.onTap!(movie);
    } else {
      _navigateToDetails(context, movie);
    }
  }

  @override
  void dispose() {
    _transitionController.dispose();
    _fillController.dispose();
    widget.scrollController?.removeListener(_onParentScroll);
    _scrollOffset.dispose();
    _currentIndexNotifier.dispose();
    _carouselFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.movies.isEmpty) return const SizedBox.shrink();

    final size = MediaQuery.sizeOf(context);
    final heroHeight = size.height * 0.60;
    final isDesktop =
        size.width > LayoutConstants.exploreCarouselDesktopBreakpoint;

    final profile = ref.watch(deviceProfileProvider).asData?.value;
    final isTv = profile?.isTv ?? context.isTv;

    return VisibilityDetector(
      key: const Key('explore-carousel-visibility'),
      // Visibility is still tracked — but only to gate the 5s auto-advance
      // timer (so we don't fire page transitions for an audience that
      // isn't watching). Parallax offset updates ignore this flag; see
      // [_onParentScroll] for the rationale.
      onVisibilityChanged: (info) {
        final visible = info.visibleFraction > 0.1;
        if (visible != _isVisibleOnScreen && mounted) {
          setState(() => _isVisibleOnScreen = visible);
          if (visible) {
            _fillController.forward();
          } else {
            _fillController.stop();
          }
        }
      },
      child: FocusableActionDetector(
        focusNode: _carouselFocusNode,
        // Only auto-focus on TV where D-pad is the primary input. On desktop
        // we skip autofocus so the focus ring doesn't appear on app launch
        // (Flutter defaults to 'traditional' highlight mode until a mouse
        // event arrives, which would show the ring immediately).
        autofocus: false,
        mouseCursor: SystemMouseCursors.click,
        // Arrow keys are wired as explicit Shortcuts/Actions at this level so
        // they fire when _carouselFocusNode has focus. Using a nested
        // Focus(onKeyEvent:) for arrows is unreliable here — that child Focus
        // is a descendant of _carouselFocusNode, and key events only propagate
        // UP from the focused node, so the child's handler never runs. Worse,
        // unhandled arrow keys fall through to Flutter's default ScrollAction
        // which then scrolls the outer vertical CustomScrollView — exactly the
        // "Right pages carousel AND scrolls page vertically" bug we saw.
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.arrowUp): _CarouselUpIntent(),
          SingleActivator(LogicalKeyboardKey.arrowLeft): _CarouselPrevIntent(),
          SingleActivator(LogicalKeyboardKey.arrowRight): _CarouselNextIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activateCurrent();
              return null;
            },
          ),
          _CarouselUpIntent: CallbackAction<_CarouselUpIntent>(
            onInvoke: (_) {
              widget.onNavigateUp?.call();
              return null;
            },
          ),
          _CarouselPrevIntent: CallbackAction<_CarouselPrevIntent>(
            onInvoke: (_) {
              _goToPreviousSlide();
              return null;
            },
          ),
          _CarouselNextIntent: CallbackAction<_CarouselNextIntent>(
            onInvoke: (_) {
              _goToNextSlide();
              return null;
            },
          ),
        },
        onShowFocusHighlight: (show) =>
            setState(() => _isFocusHighlighted = show),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity == null) return;
            if (details.primaryVelocity! < -300) {
              _goToNextSlide();
            } else if (details.primaryVelocity! > 300) {
              _goToPreviousSlide();
            }
          },
          child: isDesktop
              ? RepaintBoundary(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      LayoutConstants.dashboardContentPadding,
                      LayoutConstants.spacingSm,
                      LayoutConstants.dashboardContentPadding,
                      0,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: _isFocusHighlighted
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2.5,
                              )
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: SizedBox(
                          height: heroHeight,
                          child: _buildCarouselStack(
                            heroHeight,
                            isDesktop: isDesktop || isTv,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : Padding(
                  padding: EdgeInsets.zero,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      border: _isFocusHighlighted
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2.5,
                            )
                          : null,
                    ),
                    child: SizedBox(
                      height: heroHeight,
                      child: _buildCarouselStack(
                        heroHeight,
                        isDesktop: isDesktop || isTv,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Custom carousel with crossfade + scale transition
  // Entry: scale 0.8→1, opacity 0→1  |  Exit: scale 1→1.2, opacity 1→0  |  400ms
  // ---------------------------------------------------------------------------

  Widget _buildCarouselStack(double height, {required bool isDesktop}) {
    return Stack(
      children: [
        // Previous slide (exiting) — only during transition
        if (_isTransitioning && _previousSlide != null)
          AnimatedBuilder(
            animation: _transitionAnimation,
            builder: (context, _) {
              final t = _transitionAnimation.value;
              return Opacity(
                opacity: 1.0 - t,
                child: Transform.scale(
                  scale: 1.0 + 0.2 * t,
                  child: _buildSlideForIndex(
                    height,
                    _previousSlide!,
                    isDesktop: isDesktop,
                  ),
                ),
              );
            },
          ),

        // Current slide (entering or static)
        _isTransitioning
            ? AnimatedBuilder(
                animation: _transitionAnimation,
                builder: (context, _) {
                  final t = _transitionAnimation.value;
                  return Opacity(
                    opacity: t,
                    child: Transform.scale(
                      scale: 0.8 + 0.2 * t,
                      child: _buildSlideForIndex(
                        height,
                        _currentSlide,
                        isDesktop: isDesktop,
                        entranceT: t,
                      ),
                    ),
                  );
                },
              )
            : _buildSlideForIndex(height, _currentSlide, isDesktop: isDesktop),

        // Thin auto-advance segment bar (story-style dots replacement)
        if (widget.movies.length > 1)
          Positioned(
            left: 24,
            right: 24,
            bottom: 14,
            child: _buildSegmentIndicator(),
          ),
      ],
    );
  }

  Widget _buildSlideForIndex(
    double height,
    int index, {
    required bool isDesktop,
    double? entranceT,
  }) {
    final movie = widget.movies[index];
    if (widget.scrollController == null) {
      return _buildStaticItem(
        context,
        movie,
        height,
        isDesktop: isDesktop,
        entranceT: entranceT,
      );
    }
    return _buildCarouselItem(
      context,
      movie,
      height,
      isDesktop: isDesktop,
      entranceT: entranceT,
    );
  }

  void _navigateToDetails(BuildContext context, MultimediaItem movie) {
    // Standardize media type mapping (prevents TMDB ID collisions)
    final String mediaType = movie.tmdbMediaType;

    TmdbDetailsRoute(
      movieId: movie.id,
      mediaType: mediaType,
      heroTag: 'hero_${movie.id}',
      source: movie.source,
    ).push<void>(context);
  }

  Widget _buildCarouselItem(
    BuildContext context,
    MultimediaItem movie,
    double height, {
    bool isDesktop = false,
    double? entranceT,
  }) {
    final theme = Theme.of(context);
    final scaffoldColor = theme.scaffoldBackgroundColor;

    return CardsWrapper(
      scaleFactor: 1.0,
      onTap: () {
        if (widget.onTap != null) {
          widget.onTap!(movie);
        } else {
          _navigateToDetails(context, movie);
        }
      },
      borderRadius: BorderRadius.zero,
      child: RepaintBoundary(
        child: ValueListenableBuilder<double>(
          valueListenable: _scrollOffset,
          builder: (context, scrollOffset, child) {
            final parallaxOffset = scrollOffset * 0.1;
            final contentOffset = -scrollOffset * 0.2;
            final opacity = (1.0 - (scrollOffset / (height * 0.5))).clamp(
              0.0,
              1.0,
            );

            return _buildSlideBase(
              context: context,
              movie: movie,
              height: height,
              isDesktop: isDesktop,
              parallaxOffset: parallaxOffset,
              contentOffset: contentOffset,
              opacity: opacity,
              entranceT: entranceT,
              scaffoldColor: scaffoldColor,
              theme: theme,
            );
          },
        ),
      ),
    );
  }

  Widget _buildStaticItem(
    BuildContext context,
    MultimediaItem movie,
    double height, {
    bool isDesktop = false,
    double? entranceT,
  }) {
    final theme = Theme.of(context);
    return CardsWrapper(
      scaleFactor: 1.0,
      onTap: () {
        if (widget.onTap != null) {
          widget.onTap!(movie);
        } else {
          _navigateToDetails(context, movie);
        }
      },
      borderRadius: BorderRadius.zero,
      child: _buildSlideBase(
        context: context,
        movie: movie,
        height: height,
        isDesktop: isDesktop,
        parallaxOffset: 0,
        contentOffset: 0,
        opacity: 1.0,
        entranceT: entranceT,
        scaffoldColor: theme.scaffoldBackgroundColor,
        theme: theme,
      ),
    );
  }

  Widget _buildSlideBase({
    required BuildContext context,
    required MultimediaItem movie,
    required double height,
    required bool isDesktop,
    required double parallaxOffset,
    required double contentOffset,
    required double opacity,
    double? entranceT,
    required Color scaffoldColor,
    required ThemeData theme,
  }) {
    final imageUrl = movie.backdropImageUrl;
    final title = movie.title;

    const bleed = 60.0;

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Image
          Positioned(
            top: -bleed + parallaxOffset,
            bottom: -bleed - parallaxOffset,
            left: 0,
            right: 0,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  Container(color: theme.colorScheme.surfaceContainerHighest),
              errorWidget: (_, _, _) =>
                  ThumbnailErrorPlaceholder(label: title, isBackdrop: true),
            ),
          ),

          // 2. Parallax Gradients
          Positioned(
            top: -bleed + parallaxOffset,
            bottom: -bleed - parallaxOffset,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDesktop
                      ? [
                          Colors.black.withValues(alpha: 0.25),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.5),
                          Colors.black.withValues(alpha: 0.8),
                        ]
                      : [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.45),
                          Colors.black.withValues(alpha: 0.85),
                        ],
                  stops: isDesktop
                      ? const [0.0, 0.3, 0.65, 1.0]
                      : const [0.0, 0.35, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // 2.5. Bottom gradient
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 140,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.6),
                    Colors.black.withValues(alpha: 0.9),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // 2.6. Left edge fade — blends the backdrop into the page background
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            width: 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    scaffoldColor,
                    scaffoldColor.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.85],
                ),
              ),
            ),
          ),

          // 2.7. Right edge fade — blends the backdrop into the page background
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    scaffoldColor,
                    scaffoldColor.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.85],
                ),
              ),
            ),
          ),

          // 2.8. Overlay badges (rating / year)
          if (movie.score != null || movie.year != null)
            Positioned(
              top: isDesktop ? 16 : 12,
              right: isDesktop ? 16 : 12,
              child: Row(
                children: [
                  if (movie.score != null) ...[
                    _buildBadge(
                      icon: 'star',
                      label: movie.score!.toStringAsFixed(1),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (movie.year != null)
                    _buildBadge(label: movie.year.toString()),
                ],
              ),
            ),

          // 3. Title
          Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Transform.translate(
              offset: Offset(0, contentOffset),
              child: _withEntrance(
                entranceT,
                opacity >= 0.999
                    ? _buildTitle(title)
                    : Opacity(opacity: opacity, child: _buildTitle(title)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _withEntrance(double? t, Widget child) {
    if (t == null) return child;
    return Opacity(
      opacity: (0.3 + 0.7 * t).clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 0.94 + 0.06 * t,
        alignment: Alignment.bottomLeft,
        child: child,
      ),
    );
  }

  Widget _buildBadge({String? icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            const AppIcon(
              'star',
              size: 12,
              color: Color(0xFFFFD54F),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentIndicator() {
    final count = widget.movies.length;
    final filled = Colors.white.withValues(alpha: 0.9);
    final idle = Colors.white.withValues(alpha: 0.25);
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                height: 3,
                child: i < _currentSlide
                    ? ColoredBox(color: filled)
                    : i == _currentSlide
                        ? AnimatedBuilder(
                            animation: _fillController,
                            builder: (context, _) => Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: _fillController.value,
                                child: ColoredBox(color: filled),
                              ),
                            ),
                          )
                        : ColoredBox(color: idle),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        textAlign: TextAlign.left,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black, blurRadius: 8)],
        ),
      ),
    );
  }
}
