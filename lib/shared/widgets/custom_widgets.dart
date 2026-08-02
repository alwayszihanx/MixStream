import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/layout_constants.dart';

/// A Slider widget that handles D-pad navigation properly on TV.
/// Left/Right D-pad adjusts the value, Up/Down D-pad navigates to other focusable elements.
class CustomSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final double step;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final Color? activeColor;
  final Color? inactiveColor;
  final FocusNode? focusNode;
  final VoidCallback? onArrowUp;
  final VoidCallback? onArrowDown;

  /// When false the slider is removed from focus traversal entirely (it can't be
  /// focused and doesn't intercept arrow keys). Use when the value is driven by
  /// external −/+ controls and the slider is just a visual indicator.
  final bool focusable;

  const CustomSlider({
    super.key,
    required this.value,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.step = 1.0,
    this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.activeColor,
    this.inactiveColor,
    this.focusNode,
    this.onArrowUp,
    this.onArrowDown,
    this.focusable = true,
  });

  @override
  State<CustomSlider> createState() => _CustomSliderState();
}

class _CustomSliderState extends State<CustomSlider> {
  late final FocusNode _focusNode;
  bool _isFocused = false;
  bool _isDragging = false;
  Timer? _seekCommitTimer;
  late final VoidCallback _focusListener;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusListener = () {
      if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
    };
    _focusNode.addListener(_focusListener);
  }

  @override
  void dispose() {
    _seekCommitTimer?.cancel();
    _focusNode.removeListener(_focusListener);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleDpadSeek(double newValue) {
    if (!_isDragging) {
      _isDragging = true;
      widget.onChangeStart?.call(newValue);
    }
    widget.onChanged?.call(newValue);

    _seekCommitTimer?.cancel();
    _seekCommitTimer = Timer(const Duration(milliseconds: 500), () {
      widget.onChangeEnd?.call(newValue);
      _isDragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      canRequestFocus: widget.focusable,
      skipTraversal: !widget.focusable,
      onKeyEvent: (node, event) {
        if (!widget.focusable) return KeyEventResult.ignored;
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }

        final logicalKey = event.logicalKey;

        // Left arrow: decrease value
        if (logicalKey == LogicalKeyboardKey.arrowLeft) {
          final newValue = (widget.value - widget.step).clamp(
            widget.min,
            widget.max,
          );
          if (newValue != widget.value) {
            _handleDpadSeek(newValue);
          }
          return KeyEventResult.handled;
        }

        // Right arrow: increase value
        if (logicalKey == LogicalKeyboardKey.arrowRight) {
          final newValue = (widget.value + widget.step).clamp(
            widget.min,
            widget.max,
          );
          if (newValue != widget.value) {
            _handleDpadSeek(newValue);
          }
          return KeyEventResult.handled;
        }

        // Up arrow: move focus up — operate on our own node so traversal is
        // anchored to the slider and not to whatever happens to be the
        // enclosing FocusScope.
        if (logicalKey == LogicalKeyboardKey.arrowUp) {
          if (widget.onArrowUp != null) {
            widget.onArrowUp!();
            return KeyEventResult.handled;
          }
          final success = _focusNode.focusInDirection(TraversalDirection.up);
          if (!success) {
            _focusNode.previousFocus();
          }
          return KeyEventResult.handled;
        }

        // Down arrow: move focus down
        if (logicalKey == LogicalKeyboardKey.arrowDown) {
          if (widget.onArrowDown != null) {
            widget.onArrowDown!();
            return KeyEventResult.handled;
          }
          final success = _focusNode.focusInDirection(TraversalDirection.down);
          if (!success) {
            _focusNode.nextFocus();
          }
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: _isFocused
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                )
              : Border.all(color: Colors.transparent, width: 2),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: LayoutConstants.spacingXs,
          vertical: 4,
        ),
        child: ExcludeFocus(
          child: Slider(
            value: widget.value.clamp(widget.min, widget.max),
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            onChanged: widget.onChanged,
            onChangeStart: widget.onChangeStart,
            onChangeEnd: widget.onChangeEnd,
            activeColor:
                widget.activeColor ??
                (_isFocused ? Theme.of(context).colorScheme.primary : null),
            inactiveColor: widget.inactiveColor,
          ),
        ),
      ),
    );
  }
}

/// A TextField widget that allows D-pad navigation out of the text field.
/// Up/Down D-pad navigates to other focusable elements instead of being trapped.
/// When keyboard OK is pressed, focus automatically moves to the next element.
class CustomTextField extends StatefulWidget {
  final TextEditingController? controller;
  final InputDecoration? decoration;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String? hintText;
  final bool obscureText;
  final TextInputType? keyboardType;

  const CustomTextField({
    super.key,
    this.controller,
    this.decoration,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
    this.hintText,
    this.obscureText = false,
    this.keyboardType,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        final key = event.logicalKey;

        // Use sequential focus traversal for D-pad Up/Down instead of spatial.
        // Spatial traversal (focusInDirection) is erratic in complex dialogs.
        if (key == LogicalKeyboardKey.arrowUp) {
          _focusNode.previousFocus();
          return KeyEventResult.handled;
        }

        if (key == LogicalKeyboardKey.arrowDown) {
          _focusNode.nextFocus();
          return KeyEventResult.handled;
        }

        // Let left/right pass through for text cursor navigation
        return KeyEventResult.ignored;
      },
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Define consistent premium borders for the project
    final enabledBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: colorScheme.outline.withValues(alpha: 0.5),
        width: 1,
      ),
    );

    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colorScheme.primary, width: 2),
    );

    // Merge the provided decoration with our consistent styling
    final effectiveDecoration = (widget.decoration ?? const InputDecoration())
        .copyWith(
          hintText: widget.hintText ?? widget.decoration?.hintText,
          enabledBorder: widget.decoration?.enabledBorder ?? enabledBorder,
          focusedBorder: widget.decoration?.focusedBorder ?? focusedBorder,
          border: widget.decoration?.border ?? enabledBorder,
        );

    return TextField(
      focusNode: _focusNode,
      controller: widget.controller,
      decoration: effectiveDecoration,
      autofocus: widget.autofocus,
      textInputAction: widget.textInputAction ?? TextInputAction.done,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      onSubmitted: (value) {
        // Call user callback first — it may navigate away or close a host
        // dialog, so bail out if we got unmounted before moving focus.
        widget.onSubmitted?.call(value);
        if (mounted) {
          _focusNode.nextFocus();
        }
      },
    );
  }
}

/// Design constants matching the Button Design Specification.
class ButtonDesign {
  ButtonDesign._();

  static const double borderRadius = 14;
  static const double borderWidth = 1.5;
  static const EdgeInsetsGeometry padding = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 12,
  );
  static const double contentGap = 8;
  static const double hoverTranslateY = -5;
  static const Duration hoverDuration = Duration(milliseconds: 300);
  static const Duration clickDuration = Duration(milliseconds: 120);
  static const double clickScale = 0.98;
  static const String secondarySeparator = '\u2500 ';

  static BoxDecoration restingDecoration(ColorScheme cs, {Color? borderColor}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? cs.outline.withValues(alpha: 0.4),
        width: borderWidth,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  static BoxDecoration hoveredDecoration(ColorScheme cs, {Color? borderColor}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? cs.outline.withValues(alpha: 0.6),
        width: borderWidth,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  static Widget wrapWithHoverClick({
    required Widget child,
    required VoidCallback? onPressed,
    bool enabled = true,
  }) {
    if (!enabled || onPressed == null) return child;
    return _HoverClickWrapper(
      onPressed: onPressed,
      child: child,
    );
  }
}

class _HoverClickWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;

  const _HoverClickWrapper({
    required this.child,
    required this.onPressed,
  });

  @override
  State<_HoverClickWrapper> createState() => _HoverClickWrapperState();
}

class _HoverClickWrapperState extends State<_HoverClickWrapper>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _pressed = false;
  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: ButtonDesign.hoverDuration,
    );
    _hoverAnimation = CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  void _onEnter(PointerEnterEvent _) {
    if (!_hovered) {
      setState(() => _hovered = true);
      _hoverController.forward();
    }
  }

  void _onExit(PointerExitEvent _) {
    setState(() {
      _hovered = false;
      _pressed = false;
    });
    _hoverController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: _onEnter,
      onExit: _onExit,
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedBuilder(
          animation: _hoverAnimation,
          builder: (context, child) {
            final hoverFraction = _hoverAnimation.value;
            final translateY = ButtonDesign.hoverTranslateY * hoverFraction;
            final scale = _pressed ? ButtonDesign.clickScale : 1.0;
            return Transform.translate(
              offset: Offset(0, translateY.toDouble()),
              child: Transform.scale(
                scale: scale,
                child: child,
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// A two-part label widget for buttons: main text + optional secondary text
/// with a decorative separator.
class ButtonLabel extends StatelessWidget {
  final String label;
  final String? secondary;
  final Widget? icon;
  final TextStyle? labelStyle;
  final TextStyle? secondaryStyle;

  const ButtonLabel({
    super.key,
    required this.label,
    this.secondary,
    this.icon,
    this.labelStyle,
    this.secondaryStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          icon!,
          const SizedBox(width: ButtonDesign.contentGap),
        ],
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: labelStyle ??
              TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
        ),
        if (secondary != null && secondary!.isNotEmpty) ...[
          const SizedBox(width: ButtonDesign.contentGap),
          Text(
            '${ButtonDesign.secondarySeparator}$secondary',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: secondaryStyle ??
                TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
          ),
        ],
      ],
    );
  }
}

/// A styled button for TV that shows focus state clearly with proper Material Design styling.
class CustomButton extends StatefulWidget {
  final Widget? child;
  final VoidCallback? onPressed;
  final bool autofocus;
  final bool isPrimary;
  final bool isOutlined;
  final FocusNode? focusNode;
  final Color? backgroundColor;
  final OutlinedBorder? shape;
  final bool showFocusHighlight;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;

  /// Convenience: build label content automatically.
  final String? label;
  final String? secondaryLabel;
  final Widget? icon;

  const CustomButton({
    super.key,
    this.child,
    this.onPressed,
    this.autofocus = false,
    this.isPrimary = false,
    this.isOutlined = false,
    this.focusNode,
    this.backgroundColor,
    this.shape,
    this.showFocusHighlight = true,
    this.padding,
    this.borderRadius,
    this.label,
    this.secondaryLabel,
    this.icon,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton>
    with SingleTickerProviderStateMixin {
  late FocusNode _focusNode;
  bool _isFocused = false;
  bool _hovered = false;
  bool _pressed = false;
  late final VoidCallback _focusListener;
  FocusHighlightMode _highlightMode = FocusManager.instance.highlightMode;
  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusListener = () {
      if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
    };
    _focusNode.addListener(_focusListener);
    FocusManager.instance.addHighlightModeListener(_onHighlightModeChange);
    _hoverController = AnimationController(
      vsync: this,
      duration: ButtonDesign.hoverDuration,
    );
    _hoverAnimation = CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOut,
    );
  }

  void _onHighlightModeChange(FocusHighlightMode mode) {
    if (mounted) setState(() => _highlightMode = mode);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_focusListener);
    FocusManager.instance.removeHighlightModeListener(_onHighlightModeChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _hoverController.dispose();
    super.dispose();
  }

  void _onEnter(PointerEnterEvent _) {
    if (!_hovered) {
      setState(() => _hovered = true);
      _hoverController.forward();
    }
  }

  void _onExit(PointerExitEvent _) {
    setState(() {
      _hovered = false;
      _pressed = false;
    });
    _hoverController.reverse();
  }

  Widget _buildContent() {
    if (widget.child != null) return widget.child!;
    return ButtonLabel(
      label: widget.label ?? '',
      secondary: widget.secondaryLabel,
      icon: widget.icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primaryColor = cs.primary;
    final showHighlight =
        widget.showFocusHighlight &&
        _isFocused &&
        _highlightMode != FocusHighlightMode.touch;

    final effectiveShape = widget.shape ??
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            widget.borderRadius ?? ButtonDesign.borderRadius,
          ),
        );

    final effectivePadding = widget.padding ?? ButtonDesign.padding;

    // Mirror shape for outer focus ring
    final BoxShape outerShape;
    final BorderRadius? outerBorderRadius;
    if (effectiveShape is CircleBorder) {
      outerShape = BoxShape.circle;
      outerBorderRadius = null;
    } else if (effectiveShape is StadiumBorder) {
      outerShape = BoxShape.rectangle;
      outerBorderRadius = BorderRadius.circular(999);
    } else if (effectiveShape is RoundedRectangleBorder) {
      outerShape = BoxShape.rectangle;
      final inner = effectiveShape.borderRadius;
      outerBorderRadius = inner is BorderRadius
          ? inner
          : BorderRadius.circular(ButtonDesign.borderRadius);
    } else {
      outerShape = BoxShape.rectangle;
      outerBorderRadius = BorderRadius.circular(ButtonDesign.borderRadius);
    }

    Widget core;
    if (widget.isPrimary) {
      core = FilledButton(
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        onPressed: widget.onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: showHighlight
              ? Color.lerp(primaryColor, Colors.white, 0.18)
              : (widget.backgroundColor ?? primaryColor),
          foregroundColor: cs.onPrimary,
          disabledBackgroundColor: cs.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: cs.onSurface.withValues(alpha: 0.38),
          side: BorderSide.none,
          shadowColor: Colors.transparent,
          shape: effectiveShape,
          overlayColor: Colors.transparent,
          padding: effectivePadding,
        ),
        child: _buildContent(),
      );
    } else {
      core = TextButton(
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        onPressed: widget.onPressed,
        style: TextButton.styleFrom(
          backgroundColor: showHighlight
              ? primaryColor.withValues(alpha: 0.28)
              : null,
          foregroundColor: _isFocused
              ? cs.onSurface
              : cs.onSurfaceVariant,
          disabledForegroundColor: cs.onSurface.withValues(alpha: 0.38),
          side: widget.isOutlined
              ? BorderSide(color: cs.outline)
              : BorderSide.none,
          shape: effectiveShape,
          overlayColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: effectivePadding,
        ),
        child: _buildContent(),
      );
    }

    final focusShadow = showHighlight
        ? BoxShadow(
            color: primaryColor.withValues(alpha: 0.6),
            blurRadius: 24,
            spreadRadius: 2,
          )
        : null;

    final button = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        shape: outerShape,
        borderRadius: outerBorderRadius,
        border: showHighlight
            ? Border.all(color: primaryColor, width: 2)
            : null,
        boxShadow: [
          if (showHighlight && focusShadow != null) focusShadow,
        ],
      ),
      child: core,
    );

    // Wrap with hover/click animations using AnimatedBuilder
    return MouseRegion(
      onEnter: widget.onPressed != null ? _onEnter : null,
      onExit: widget.onPressed != null ? _onExit : null,
      cursor: widget.onPressed != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: widget.onPressed != null
            ? (_) => setState(() => _pressed = true)
            : null,
        onTapUp: widget.onPressed != null
            ? (_) => setState(() => _pressed = false)
            : null,
        onTapCancel: widget.onPressed != null
            ? () => setState(() => _pressed = false)
            : null,
        child: AnimatedBuilder(
          animation: _hoverAnimation,
          builder: (context, child) {
            final hoverFraction = _hoverAnimation.value;
            final translateY = ButtonDesign.hoverTranslateY * hoverFraction;
            final scale = _pressed ? ButtonDesign.clickScale : 1.0;
            double shadowOpacity = 0.08 + (0.15 - 0.08) * hoverFraction;
            double shadowBlur = 4 + (12 - 4) * hoverFraction;
            double shadowOffset = 2 + (6 - 2) * hoverFraction;
            return Container(
              decoration: BoxDecoration(
                borderRadius: outerBorderRadius,
                boxShadow: showHighlight && focusShadow != null
                    ? [focusShadow]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: shadowOpacity),
                          blurRadius: shadowBlur,
                          offset: Offset(0, shadowOffset),
                        ),
                      ],
              ),
              child: Transform.translate(
                offset: Offset(0, translateY.toDouble()),
                child: Transform.scale(
                  scale: scale,
                  child: child,
                ),
              ),
            );
          },
          child: button,
        ),
      ),
    );
  }
}
