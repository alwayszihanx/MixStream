import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../../shared/widgets/custom_widgets.dart';
import 'hotstar_player_style.dart';

/// Translucent capsule that groups a row of player buttons behind one soft
/// backdrop, instead of a chip per icon. Plain alpha (no BackdropFilter) so it
/// costs nothing to composite, and it's the Material the buttons' ripples
/// paint onto.
class _ZBarGroup extends StatelessWidget {
  final List<Widget> children;

  const _ZBarGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

/// Disc backdrop for the centre transport controls. They sit over the middle
/// of the picture where barely any scrim reaches, so they carry more alpha
/// than the bottom capsules. [onLongPressStart]/[onLongPressEnd] let the play
/// disc double as the touch "hold to speed up" affordance.
class TransportDisc extends StatelessWidget {
  const TransportDisc({
    required this.size,
    required this.child,
    this.onTap,
    this.dimmed = false,
    this.onLongPressStart,
    this.onLongPressEnd,
  });

  final double size;
  final Widget child;
  final VoidCallback? onTap;
  final bool dimmed;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressEndCallback? onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    final disc = Material(
      color: Colors.black.withValues(alpha: dimmed ? 0.18 : 0.45),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        splashColor: Colors.white.withValues(alpha: 0.22),
        highlightColor: Colors.white.withValues(alpha: 0.10),
        child: SizedBox(width: size, height: size, child: Center(child: child)),
      ),
    );
    if (onLongPressStart == null && onLongPressEnd == null) return disc;
    return GestureDetector(
      onLongPressStart: onLongPressStart,
      onLongPressEnd: onLongPressEnd,
      behavior: HitTestBehavior.opaque,
      child: disc,
    );
  }
}

/// Centre play/pause disc with an animated play/pause swap.
class PlayPauseDisc extends StatelessWidget {
  const PlayPauseDisc({
    required this.playing,
    required this.onTap,
    this.onLongPressStart,
    this.onLongPressEnd,
  });

  final bool playing;
  final VoidCallback onTap;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressEndCallback? onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    return TransportDisc(
      size: 58,
      onTap: onTap,
      onLongPressStart: onLongPressStart,
      onLongPressEnd: onLongPressEnd,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.72, end: 1).animate(anim),
            child: child,
          ),
        ),
        child: AppIcon(
          playing ? 'pause_rounded' : 'play-bold',
          key: ValueKey<bool>(playing),
          color: Colors.white,
          size: 34,
        ),
      ),
    );
  }
}

/// Prev/next episode step either side of play/pause. A null [onTap] means there
/// is nowhere to step: the disc dims and stops taking touches.
class TransportButton extends StatelessWidget {
  const TransportButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Opacity(
          opacity: enabled ? 1 : 0.28,
          child: TransportDisc(
            size: 46,
            dimmed: !enabled,
            onTap: onTap,
            child: IconTheme(
              data: const IconThemeData(color: Colors.white, size: 26),
              child: icon,
            ),
          ),
        ),
      ),
    );
  }
}

/// A player action descriptor, rendered either inline (TV/desktop) or inside
/// the "⋯ More" sheet (touch).
class PlayerActionItem {
  const PlayerActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;

  PlayerIconButton toButton({required bool isTv}) => PlayerIconButton(
        icon: icon,
        tooltip: label,
        onPressed: onTap,
        isTv: isTv,
        highlight: highlight,
      );
}

/// Bottom sheet listing the secondary player actions behind the "⋯ More"
/// button on touch.
class MoreSheet extends StatelessWidget {
  const MoreSheet({required this.items});

  final List<PlayerActionItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HotstarPlayerStyle.panelElevated,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final item in items) MoreRow(item: item),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class MoreRow extends StatelessWidget {
  const MoreRow({required this.item});

  final PlayerActionItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          item.onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconTheme(
                data: const IconThemeData(color: Colors.white, size: 22),
                child: item.icon,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Top zone: back button + two-line title (primary headline, secondary
/// caption) + optional right-side [actions] (e.g. lock). Paints its own
/// flat top scrim so the chrome needs no separate gradient.
class PlayerTopBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final bool isTv;
  final FocusNode? backFocusNode;

  /// Right-aligned icons (lock, settings, …). Rendered as plain white glyphs
  /// over the scrim, mirroring Zangetsu's top-right cluster.
  final List<Widget>? actions;

  const PlayerTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.isTv = false,
    this.backFocusNode,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.viewPaddingOf(context);
    final edge = isTv
        ? HotstarPlayerStyle.tvEdgeInset
        : HotstarPlayerStyle.edgeInset;
    final double leftPadding = isTv
        ? edge
        : (padding.left > edge ? padding.left : edge);
    final double rightPadding = isTv
        ? edge
        : (padding.right > edge ? padding.right : edge);
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: HotstarPlayerStyle.topGradient),
      child: SafeArea(
        left: false,
        right: false,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(leftPadding, 14, rightPadding, 24),
          child: Row(
            children: [
              PlayerIconButton(
                icon: const AppIcon('arrow_back_rounded'),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: onBack,
                isTv: isTv,
                focusNode: backFocusNode,
                iconSize: isTv ? 30 : 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: HotstarPlayerStyle.primaryText,
                        fontSize: isTv ? 22 : 18,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      const SizedBox(height: 2),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: HotstarPlayerStyle.secondaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(width: 12),
                ...actions!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom zone shell: scrubber row on top, then a single flat controls row —
/// [leading] (playback) pinned left, a [Spacer], then [actions] (everything
/// else) on the right. All buttons are direct siblings of one [Row].
///
/// The [leading] group is pinned left; the [actions] group lives in a
/// horizontal scroll view that is right-anchored when it fits and scrolls to
/// reveal overflow when there are more buttons than fit (otherwise the extras
/// were simply clipped and unreachable).
///
/// On TV, Left/Right are driven explicitly by reading-order focus traversal
/// ([FocusNode.nextFocus]/[previousFocus]) within the row's own
/// [FocusTraversalGroup]; the handler consumes the arrows *before* the inner
/// [Scrollable] sees them, so focus moves cleanly across the whole row (and the
/// scroll view follows focus via the framework's ensureVisible) with no scroll
/// trap. Up/Down still bubble out to move between the scrubber / controls /
/// top-bar rows. (Off TV the handler is null, so desktop keyboard arrows keep
/// their seek/volume behaviour and touch just scrolls.) Paints its own scrim.
class PlayerBottomBar extends StatelessWidget {
  final Widget progressBar;
  final List<Widget> leading;
  final List<Widget> actions;
  final bool isTv;

  /// On touch the [actions] go in a finger-scrollable strip (so a long list is
  /// reachable); on TV/desktop they stay a fixed right-aligned group navigated
  /// by D-pad. A keyboard [Scrollable] would re-introduce the focus trap, so it
  /// is used only where there's no directional focus (touch).
  final bool isTouch;

  const PlayerBottomBar({
    super.key,
    required this.progressBar,
    this.leading = const [],
    this.actions = const [],
    this.isTv = false,
    this.isTouch = false,
  });

  KeyEventResult _handleRowKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final primary = FocusManager.instance.primaryFocus;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      primary?.nextFocus();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      primary?.previousFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.viewPaddingOf(context);
    final edge = isTv
        ? HotstarPlayerStyle.tvEdgeInset
        : HotstarPlayerStyle.edgeInset;
    final double leftPadding = isTv
        ? edge
        : (padding.left > edge ? padding.left : edge);
    final double rightPadding = isTv
        ? edge
        : (padding.right > edge ? padding.right : edge);
    final hasLeading = leading.isNotEmpty;
    final hasActions = actions.isNotEmpty;
    return SafeArea(
      left: false,
      right: false,
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(leftPadding, 2, rightPadding, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            progressBar,
            FocusTraversalGroup(
              child: Focus(
                canRequestFocus: false,
                skipTraversal: true,
                onKeyEvent: isTv ? _handleRowKey : null,
                child: Row(
                  children: [
                    // Left capsule: play/pause, lock, next — always visible.
                    if (hasLeading)
                      _ZBarGroup(children: leading),
                    if (isTouch)
                      // Touch: right-anchored finger-scroll strip so a long
                      // action list is never clipped out of reach.
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          reverse: true,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasActions) _ZBarGroup(children: actions),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      // TV/desktop: fixed right-aligned capsule (D-pad nav).
                      const Spacer(),
                      if (hasActions) _ZBarGroup(children: actions),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact icon-only button for utilities (resize, PiP, fullscreen) and the
/// top-bar back button. Tooltip doubles as the semantics label.
class PlayerIconButton extends StatefulWidget {
  final Widget icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isTv;
  final bool highlight;
  final FocusNode? focusNode;

  /// Optional icon-size override (the tap target grows to match). Used by the
  /// top-bar back button so it reads at the same weight as the title.
  final double? iconSize;

  const PlayerIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isTv = false,
    this.highlight = false,
    this.focusNode,
    this.iconSize,
  });

  @override
  State<PlayerIconButton> createState() => _PlayerIconButtonState();
}

class _PlayerIconButtonState extends State<PlayerIconButton> {
  @override
  Widget build(BuildContext context) {
    final double glyph = widget.iconSize ?? (widget.isTv ? 24 : 22);
    final double box = glyph + (widget.isTv ? 16 : 14);

    return Tooltip(
      message: widget.tooltip,
      child: CustomButton(
        onPressed: widget.onPressed,
        showFocusHighlight: widget.isTv,
        focusNode: widget.focusNode,
        shape: const CircleBorder(),
        padding: EdgeInsets.zero,
        child: SizedBox(width: box, height: box, child: widget.icon),
      ),
    );
  }
}

/// Labelled icon button for the controls row (Sources, Subtitles, Speed, …).
/// Activates on tap and on D-pad/keyboard select/enter/space when focused;
/// directional navigation between buttons is handled natively by the
/// enclosing traversal group — this widget never moves focus itself.
class PlayerActionButton extends StatefulWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;
  final bool isTv;
  final FocusNode? focusNode;

  const PlayerActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
    this.isTv = false,
    this.focusNode,
  });

  @override
  State<PlayerActionButton> createState() => _PlayerActionButtonState();
}

class _PlayerActionButtonState extends State<PlayerActionButton> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = (widget.highlight || _hovered || _focused)
        ? HotstarPlayerStyle.accent
        : Colors.white;
    return Semantics(
      button: true,
      selected: widget.highlight,
      label: widget.label,
      child: Focus(
        focusNode: widget.focusNode,
        onFocusChange: (value) => setState(() => _focused = value),
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.space) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: CustomButton(
            onPressed: widget.onTap,
            showFocusHighlight: widget.isTv,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ButtonDesign.borderRadius),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                widget.icon,
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
