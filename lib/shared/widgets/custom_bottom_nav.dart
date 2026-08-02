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
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onTap,
        backgroundColor: theme.scaffoldBackgroundColor,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 56,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: AppIcon('home_outlined', color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            selectedIcon: AppIcon('home', color: theme.colorScheme.primary),
            label: l10n.home,
          ),
          NavigationDestination(
            icon: AppIcon('search_outlined', color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            selectedIcon: AppIcon('search', color: theme.colorScheme.primary),
            label: l10n.search,
          ),
          NavigationDestination(
            icon: AppIcon('explore_outlined', color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            selectedIcon: AppIcon('explore', color: theme.colorScheme.primary),
            label: l10n.explore,
          ),
          NavigationDestination(
            icon: AppIcon('video_library_outlined', color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            selectedIcon: AppIcon('video_library', color: theme.colorScheme.primary),
            label: l10n.library,
          ),
          NavigationDestination(
            icon: AppIcon('settings_outlined', color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            selectedIcon: AppIcon('settings', color: theme.colorScheme.primary),
            label: l10n.settings,
          ),
        ],
      ),
    );
  }
}
