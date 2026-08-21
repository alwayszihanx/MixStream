import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:mixstream/l10n/generated/app_localizations.dart';
import './app_icon.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.92),
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: onTap,
            backgroundColor: Colors.transparent,
            indicatorColor: Colors.transparent,
            elevation: 0,
            height: 60,
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                );
              }
              return TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              );
            }),
            destinations: [
              _destination(context, 'home_outlined', 'home', l10n.home),
              _destination(
                  context, 'search_outlined', 'search', l10n.search),
              _destination(
                  context, 'explore_outlined', 'explore', l10n.explore),
              _destination(
                  context,
                  'video_library_outlined',
                  'video_library',
                  l10n.library),
              _destination(
                  context, 'settings_outlined', 'settings', l10n.settings),
            ],
          ),
        ),
      ),
    );
  }

  Widget _destination(
    BuildContext context,
    String outlinedIcon,
    String filledIcon,
    String label,
  ) {
    final theme = Theme.of(context);
    return NavigationDestination(
      icon: AppIcon(
        outlinedIcon,
        size: 23,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
      ),
      selectedIcon: AppIcon(
        filledIcon,
        size: 23,
        color: theme.colorScheme.primary,
      ),
      label: label,
    );
  }
}
