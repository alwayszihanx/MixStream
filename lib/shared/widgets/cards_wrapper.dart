import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CardsWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double scaleFactor;
  final bool autoFocus;
  final BorderRadius? borderRadius;
  final FocusNode? focusNode;

  const CardsWrapper({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.scaleFactor = 1.03,
    this.autoFocus = false,
    this.borderRadius,
    this.focusNode,
  });

  @override
  State<CardsWrapper> createState() => _CardsWrapperState();
}

class _CardsWrapperState extends State<CardsWrapper>
    with TickerProviderStateMixin {
  // Lazily-built. Hundreds of cards live offscreen in long rails and never
  // get focused or hovered — creating an AnimationController for each one
  // up front wastes vsync registrations and Tween allocations.
  AnimationController? _controller;
  Animation<double>? _scaleAnimation;

  // Press depth: scale to 0.97 on tap down, spring back on release.
  late AnimationController _pressController;
  Animation<double>? _pressAnimation;

  // Animated gradient border on focus.
  late AnimationController _borderController;
  Animation<double>? _borderAnimation;

  bool _isFocused = false;
  bool _isHovered = false;
  late FocusNode _node;

  /// Whether the select/enter key is currently held down.
  bool _selectKeyDown = false;

  /// Set to true once the first KeyRepeatEvent fires (OS-level long press).
  bool _longPressTriggered = false;

  @override
  void initState() {
    super.initState();
    _node = widget.focusNode ?? FocusNode();

    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );

    _borderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _node.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant CardsWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      if (oldWidget.focusNode == null) _node.dispose();
      _node = widget.focusNode ?? FocusNode();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _pressController.dispose();
    _borderController.dispose();
    if (widget.focusNode == null) {
      _node.dispose();
    } else {
      if (widget.focusNode!.hasFocus) {
        widget.focusNode!.unfocus();
      }
    }
    super.dispose();
  }

  void _ensureController() {
    if (_controller != null) return;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(parent: _controller!, curve: Curves.easeInOut));
  }

  void _updateAnimation() {
    // In D-pad/keyboard mode the border+glow is the focus indicator; skip scale
    // to prevent edge items from overflowing the viewport.
    final isDpad =
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    final shouldScale = _isHovered || (_isFocused && !isDpad);
    if (shouldScale) {
      _ensureController();
      _controller!.forward();
    } else {
      _controller?.reverse();
    }
  }

  void _onFocusChange(bool hasFocus) {
    if (!hasFocus) {
      _selectKeyDown = false;
      _longPressTriggered = false;
      _borderController.stop();
    }
    setState(() {
      _isFocused = hasFocus;
    });
    _updateAnimation();
    if (hasFocus) {
      // Start the animated gradient border cycling.
      _borderController.repeat(reverse: true);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ro = context.findRenderObject();
        if (ro is! RenderBox || !ro.hasSize) return;
        const duration = Duration(milliseconds: 380);
        const curve = Curves.fastOutSlowIn;

        // Horizontal: always center the focused card inside its row so the
        // active card stays in the middle of the screen as the user walks
        // along the row.
        Scrollable.maybeOf(
          context,
          axis: Axis.horizontal,
        )?.position.ensureVisible(
          ro,
          alignment: 0.5,
          duration: duration,
          curve: curve,
        );

        // Vertical: only scroll if the row is actually clipped. Target the
        // horizontal parent scrollable row's RenderObject to prevent
        // horizontal animation coordinate mutations from fighting with
        // vertical scrolling, which causes screen jitter/jumping.
        final vScroll = Scrollable.maybeOf(context, axis: Axis.vertical);
        if (vScroll != null) {
          final scrollBox = vScroll.context.findRenderObject();
          if (scrollBox is RenderBox && scrollBox.hasSize) {
            final hScroll = Scrollable.maybeOf(context, axis: Axis.horizontal);
            final targetContext = hScroll?.context ?? context;
            final targetRo = targetContext.findRenderObject();
            if (targetRo is RenderBox && targetRo.hasSize) {
              final top = targetRo
                  .localToGlobal(Offset.zero, ancestor: scrollBox)
                  .dy;
              final bottom = top + targetRo.size.height;
              final viewportH = scrollBox.size.height;
              if (top < 0 || bottom > viewportH) {
                vScroll.position.ensureVisible(
                  targetRo,
                  alignment: 0.5,
                  duration: duration,
                  curve: curve,
                );
              }
            }
          }
        }
      });
    }
  }

  void _onHover(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });
    _updateAnimation();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Lazily build press animation.
    _pressAnimation = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(
      parent: _pressController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.elasticOut,
    ));

    // Lazily build border animation.
    _borderAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _borderController,
      curve: Curves.easeInOut,
    ));

    return Focus(
      focusNode: _node,
      onFocusChange: _onFocusChange,
      onKeyEvent: (node, event) {
        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.space) {
          if (event is KeyDownEvent) {
            // Animate press down.
            _pressController.forward();
            if (widget.onLongPress == null) {
              // No long-press handler — fire tap immediately.
              widget.onTap();
              return KeyEventResult.handled;
            }
            // Start tracking the press; don't fire anything yet.
            _selectKeyDown = true;
            _longPressTriggered = false;
            return KeyEventResult.handled;
          } else if (event is KeyRepeatEvent) {
            // The OS fires KeyRepeatEvent after the platform key-repeat
            // delay (~500 ms). Treat the first repeat as a long press.
            if (_selectKeyDown &&
                !_longPressTriggered &&
                widget.onLongPress != null) {
              _longPressTriggered = true;
              widget.onLongPress!();
            }
            return KeyEventResult.handled;
          } else if (event is KeyUpEvent) {
            // Animate press release with spring.
            _pressController.reverse();
            // Short press: no repeat was received before release → tap.
            if (_selectKeyDown && !_longPressTriggered) {
              widget.onTap();
            }
            _selectKeyDown = false;
            _longPressTriggered = false;
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) => _onHover(true),
        onExit: (_) => _onHover(false),
        child: GestureDetector(
          onTapDown: (_) {
            _pressController.forward();
          },
          onTapUp: (_) {
            _pressController.reverse();
          },
          onTapCancel: () {
            _pressController.reverse();
          },
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: Builder(
            builder: (context) {
              // Build the animated gradient border.
              Widget buildCard() {
                final card = Container(
                  decoration: BoxDecoration(
                    borderRadius:
                        widget.borderRadius ?? BorderRadius.circular(16),
                    border:
                        (_isFocused &&
                            FocusManager.instance.highlightMode ==
                                FocusHighlightMode.traditional)
                            ? null
                            : null,
                    boxShadow: [
                      // Subtle hover shadow.
                      if (_isHovered)
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      // Focus/hover glow.
                      if (_isHovered || _isFocused)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: widget.child,
                );
                return card;
              }

              // Animated gradient border on focus.
              Widget withAnimatedBorder(Widget card) {
                if (!_isFocused ||
                    FocusManager.instance.highlightMode !=
                        FocusHighlightMode.traditional) {
                  return card;
                }

                return AnimatedBuilder(
                  animation: _borderAnimation!,
                  builder: (context, child) {
                    final opacity =
                        0.3 * (0.5 + 0.5 * _borderAnimation!.value);
                    final borderRadius =
                        widget.borderRadius ?? BorderRadius.circular(16);
                    return Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        borderRadius: borderRadius,
                        gradient: LinearGradient(
                          colors: [
                            primaryColor.withValues(alpha: opacity),
                            primaryColor.withValues(alpha: opacity * 0.5),
                            primaryColor.withValues(alpha: opacity),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: borderRadius,
                        child: child,
                      ),
                    );
                  },
                  child: card,
                );
              }

              final card = withAnimatedBorder(buildCard());
              final animation = _scaleAnimation;
              final pressAnim = _pressAnimation;

              // Combine hover/focus scale with press scale.
              Widget result = card;
              if (animation != null && pressAnim != null) {
                result = ScaleTransition(
                  scale: animation,
                  child: ScaleTransition(
                    scale: pressAnim,
                    child: card,
                  ),
                );
              } else if (animation != null) {
                result = ScaleTransition(scale: animation, child: card);
              } else if (pressAnim != null) {
                result = ScaleTransition(scale: pressAnim, child: card);
              }

              return result;
            },
          ),
        ),
      ),
    );
  }
}
