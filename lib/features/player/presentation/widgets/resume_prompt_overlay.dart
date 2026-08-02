import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mixstream/l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../../shared/widgets/custom_widgets.dart';
import 'hotstar_player_style.dart';
import 'player_prompt_placement.dart';

class ResumePromptOverlay extends StatelessWidget {
  final int? positionMs;
  final double? percentage;
  final VoidCallback onResume;
  final VoidCallback onStartOver;
  final bool isTv;
  final FocusNode? focusNode;

  const ResumePromptOverlay({
    super.key,
    this.positionMs,
    this.percentage,
    required this.onResume,
    required this.onStartOver,
    this.isTv = false,
    this.focusNode,
  });

  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String subtitle = '';
    if (positionMs != null && positionMs! > 0) {
      subtitle = l10n.pausedAt(_formatDuration(positionMs!));
    } else if (percentage != null && percentage! > 0) {
      subtitle = 'Synced progress: ${percentage!.toStringAsFixed(0)}%';
    }
    return PlayerPromptPlacement(
      isTv: isTv,
      child: CountdownFillButton(
        focusNode: focusNode,
        label: l10n.resumeNow,
        subtitle: subtitle,
        duration: const Duration(seconds: 8),
        onPressed: onResume,
        onTimeout: onStartOver,
        isTv: isTv,
      ),
    );
  }
}

class CountdownFillButton extends StatefulWidget {
  final String label;
  final String? subtitle;
  final Duration duration;
  final VoidCallback onPressed;
  final VoidCallback onTimeout;
  final bool showDismiss;
  final VoidCallback? onDismiss;
  final bool isTv;
  final FocusNode? focusNode;

  const CountdownFillButton({
    super.key,
    required this.label,
    this.subtitle,
    required this.duration,
    required this.onPressed,
    required this.onTimeout,
    this.showDismiss = false,
    this.onDismiss,
    this.isTv = false,
    this.focusNode,
  });

  @override
  State<CountdownFillButton> createState() => _CountdownFillButtonState();
}

class _CountdownFillButtonState extends State<CountdownFillButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final FocusNode _focusNode;
  Timer? _timer;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
    _timer = Timer(widget.duration, _handleTimeout);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void _handlePressed() {
    if (_completed) return;
    _completed = true;
    _timer?.cancel();
    widget.onPressed();
  }

  void _handleTimeout() {
    if (_completed) return;
    _completed = true;
    widget.onTimeout();
  }

  void _handleDismiss() {
    if (_completed) return;
    _completed = true;
    _timer?.cancel();
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.shortestSide < 600;
    final buttonWidth = isCompact ? 190.0 : 260.0;
    final buttonHeight = widget.subtitle == null || widget.subtitle!.isEmpty
        ? (isCompact ? 46.0 : 52.0)
        : (isCompact ? 58.0 : 64.0);
    const radius = ButtonDesign.borderRadius;
    final borderRadius = BorderRadius.circular(radius);

    return FocusTraversalGroup(
      child: Focus(
        focusNode: _focusNode,
        autofocus: widget.isTv,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.space) {
            _handlePressed();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.escape ||
              key == LogicalKeyboardKey.goBack) {
            widget.onDismiss != null ? _handleDismiss() : _handleTimeout();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Builder(
          builder: (context) {
            final isFocused = Focus.of(context).hasFocus;

            return SizedBox(
              width: buttonWidth,
              height: buttonHeight,
              child: AnimatedContainer(
                duration: HotstarPlayerStyle.fastMotionDuration,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.52),
                  borderRadius: borderRadius,
                  border: Border.all(
                    color: isFocused && widget.isTv
                        ? HotstarPlayerStyle.accent
                        : Colors.white.withValues(alpha: 0.22),
                    width: isFocused && widget.isTv
                        ? 2
                        : ButtonDesign.borderWidth,
                  ),
                  boxShadow: isFocused && widget.isTv
                      ? [
                          BoxShadow(
                            color: HotstarPlayerStyle.accent.withValues(
                              alpha: 0.2,
                            ),
                            blurRadius: 8,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) => DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            HotstarPlayerStyle.accent.withValues(alpha: 0.92),
                            HotstarPlayerStyle.accent.withValues(alpha: 0.92),
                            Colors.transparent,
                            Colors.transparent,
                          ],
                          stops: [0, _controller.value, _controller.value, 1],
                        ),
                      ),
                      child: child,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: borderRadius,
                        onTap: _handlePressed,
                        child: Padding(
                          padding: ButtonDesign.padding,
                          child: Row(
                            children: [
                              const AppIcon(
                                'play_arrow_rounded',
                                color: Colors.white,
                                size: 22,
                              ),
                              const SizedBox(width: ButtonDesign.contentGap),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isCompact ? 13 : 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (widget.subtitle != null &&
                                        widget.subtitle!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        widget.subtitle!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.78,
                                          ),
                                          fontSize: isCompact ? 10 : 11,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (widget.showDismiss &&
                                  widget.onDismiss != null)
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 28,
                                    minHeight: 28,
                                  ),
                                  onPressed: _handleDismiss,
                                  icon: const AppIcon(
                                    'close_rounded',
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
