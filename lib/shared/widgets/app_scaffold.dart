import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mixstream/core/providers/device_info_provider.dart';
import 'package:mixstream/core/utils/layout_constants.dart';
import 'package:mixstream/core/utils/responsive_breakpoints.dart';
import 'package:mixstream/shared/widgets/custom_bottom_nav.dart';
import 'package:mixstream/shared/widgets/app_sidebar.dart';

import 'package:mixstream/l10n/generated/app_localizations.dart';
import '../../features/settings/presentation/general_settings_provider.dart';
import 'loading_indicator.dart';

class AppScaffold extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const AppScaffold({super.key, required this.navigationShell});

  @override
  ConsumerState<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends ConsumerState<AppScaffold> {
  // Owned here so the content-area LEFT key handler can focus them directly,
  // crossing the Branch Navigator's FocusScope boundary. Count comes from
  // [kSidebarDestinationCount] in app_sidebar.dart — single source of truth.
  late final List<FocusNode> _sidebarNodes = List.generate(
    kSidebarDestinationCount,
    (i) => FocusNode(debugLabel: 'sidebar_$i'),
  );

  @override
  void dispose() {
    for (final n in _sidebarNodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _onItemTapped(int index, BuildContext context) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  int _getRouteIndex(String route) {
    switch (route) {
      case '/home':
        return 0;
      case '/search':
        return 1;
      case '/explore':
        return 2;
      case '/library':
        return 3;
      case '/settings':
        return 4;
      default:
        return 0;
    }
  }

  // Intercepts D-pad DOWN only when the currently focused widget has no
  // focusable neighbour below within the content area. In that case we
  // explicitly focus the dock item (different FocusScope, so directional
  // traversal can't bridge it on its own). Otherwise we let the event continue
  // so normal in-row navigation works.
  KeyEventResult _onContentKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey != LogicalKeyboardKey.arrowDown) {
      return KeyEventResult.ignored;
    }
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return KeyEventResult.ignored;

    final moved = primary.focusInDirection(TraversalDirection.down);
    if (moved) {
      return KeyEventResult.handled;
    }
    // No focusable below in this scope — fall back to the dock. Bail
    // back to ignored if the target node is out of range or unfocusable so
    // we don't silently swallow the Down key when focus can't move.
    final idx = widget.navigationShell.currentIndex;
    if (idx < 0 || idx >= _sidebarNodes.length) {
      return KeyEventResult.ignored;
    }
    final target = _sidebarNodes[idx];
    if (!target.canRequestFocus) {
      return KeyEventResult.ignored;
    }
    target.requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final deviceProfileAsync = ref.watch(deviceProfileProvider);
    final defaultHome = ref.watch(
      generalSettingsProvider.select((s) => s.defaultHomeScreen),
    );
    final defaultIndex = _getRouteIndex(defaultHome);
    final isAtDefaultHome = widget.navigationShell.currentIndex == defaultIndex;

    return deviceProfileAsync.when(
      data: (profile) {
        if (profile.isTv || context.isTabletOrLarger) {
          return PopScope(
            canPop: isAtDefaultHome,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) {
                widget.navigationShell.goBranch(defaultIndex);
              }
            },
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) {
                ref
                    .read<DpadActiveNotifier>(isDpadActiveProvider.notifier)
                    .set(false);
              },
              onPointerHover: (_) {
                ref
                    .read<DpadActiveNotifier>(isDpadActiveProvider.notifier)
                    .set(false);
              },
              child: Focus(
                canRequestFocus: false,
                skipTraversal: true,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    final key = event.logicalKey;
                    if (key == LogicalKeyboardKey.arrowDown ||
                        key == LogicalKeyboardKey.arrowUp ||
                        key == LogicalKeyboardKey.arrowLeft ||
                        key == LogicalKeyboardKey.arrowRight ||
                        key == LogicalKeyboardKey.enter ||
                        key == LogicalKeyboardKey.select ||
                        key == LogicalKeyboardKey.space ||
                        key == LogicalKeyboardKey.tab) {
                      ref
                          .read<DpadActiveNotifier>(
                            isDpadActiveProvider.notifier,
                          )
                          .set(true);
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: Material(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: SafeArea(
                    bottom: false,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Content in its own traversal group, positioned first (bottom layer)
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              bottom: LayoutConstants.sidebarDockHeight,
                            ),
                            child: FocusTraversalGroup(
                              policy: WidgetOrderTraversalPolicy(),
                              child: Focus(
                                canRequestFocus: false,
                                skipTraversal: true,
                                onKeyEvent: _onContentKeyEvent,
                                child: widget.navigationShell,
                              ),
                            ),
                          ),
                        ),
                        // Dock in its own traversal group, positioned second (top layer)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: LayoutConstants.sidebarDockHeight,
                          child: FocusTraversalGroup(
                            policy: WidgetOrderTraversalPolicy(),
                            child: AppSidebar(
                              currentIndex: widget.navigationShell.currentIndex,
                              onItemTapped: (int index) =>
                                  _onItemTapped(index, context),
                              focusNodes: _sidebarNodes,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        // Mobile uses Bottom Navigation
        return PopScope(
          canPop: isAtDefaultHome,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              widget.navigationShell.goBranch(defaultIndex);
            }
          },
          child: Scaffold(
            body: widget.navigationShell,
            bottomNavigationBar: CustomBottomNavBar(
              currentIndex: widget.navigationShell.currentIndex,
              onTap: (index) => _onItemTapped(index, context),
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: AppLoadingIndicator())),
      error: (err, stack) => Scaffold(
        body: Center(
          child: Text(
            AppLocalizations.of(context)!.errorPrefix(err.toString()),
          ),
        ),
      ),
    );
  }
}
