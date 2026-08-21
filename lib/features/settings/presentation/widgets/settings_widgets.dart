import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_icon.dart';

class SettingsGroup extends StatefulWidget {
  final String title;
  final Widget? icon;
  final String? description;
  final List<Widget> children;

  const SettingsGroup({
    super.key,
    required this.title,
    this.icon,
    this.description,
    required this.children,
  });

  @override
  State<SettingsGroup> createState() => _SettingsGroupState();
}

class _SettingsGroupState extends State<SettingsGroup> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _isCollapsed = !_isCollapsed),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              children: [
                if (widget.icon != null) ...[
                  widget.icon!,
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (widget.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.description!,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _isCollapsed ? -0.25 : 0.25,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(children: widget.children),
                ),
              ],
            ),
          ),
          secondChild: const SizedBox.shrink(),
          crossFadeState: _isCollapsed
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

class SettingsTile extends StatefulWidget {
  final Widget icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isLast;
  final bool isBeta;
  final FocusNode? focusNode;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.isLast = false,
    this.isBeta = false,
    this.focusNode,
  });

  @override
  State<SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<SettingsTile>
    with SingleTickerProviderStateMixin {
  bool _isFocused = false;
  bool _isPressed = false;
  late AnimationController _pressController;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final pressColor = ColorTween(
      begin: Colors.transparent,
      end: theme.colorScheme.primary.withValues(alpha: 0.06),
    ).animate(CurvedAnimation(parent: _pressController, curve: Curves.easeOut));

    return Column(
      children: [
        Focus(
          focusNode: widget.focusNode,
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (f) {
            setState(() => _isFocused = f);
            if (f) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final ctx = FocusManager.instance.primaryFocus?.context;
                final ro = ctx?.findRenderObject();
                if (ctx != null && ctx.mounted && ro != null) {
                  Scrollable.maybeOf(ctx)?.position.ensureVisible(
                    ro,
                    alignment: 0.5,
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.fastOutSlowIn,
                  );
                }
              });
            }
          },
          child: GestureDetector(
            onTapDown: (_) {
              setState(() => _isPressed = true);
              _pressController.forward();
            },
            onTapUp: (_) {
              setState(() => _isPressed = false);
              _pressController.reverse();
            },
            onTapCancel: () {
              setState(() => _isPressed = false);
              _pressController.reverse();
            },
            child: AnimatedBuilder(
              animation: pressColor,
              builder: (context, child) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _isPressed
                        ? pressColor.value
                        : _isFocused
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.05)
                            : Colors.transparent,
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      focusColor: Colors.transparent,
                      hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.03),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: widget.icon,
                      ),
                      title: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              widget.title,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (widget.isBeta) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                "BETA",
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: widget.subtitle != null
                          ? Text(
                              widget.subtitle!,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            )
                          : null,
                      trailing:
                          widget.trailing ??
                          AppIcon('chevron_right_rounded', size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.38)),
                      onTap: widget.onTap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (!widget.isLast && !_isFocused)
          Divider(
            height: 1,
            indent: 56,
            endIndent: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
      ],
    );
  }
}
