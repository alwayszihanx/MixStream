import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:mixstream/l10n/generated/app_localizations.dart';
import './app_icon.dart';

class FloatingPillNav extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const FloatingPillNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final items = [
      (_NavEntry('home', 'home_outlined', l10n.home)),
      (_NavEntry('search', 'search_outlined', l10n.search)),
      (_NavEntry('explore', 'explore_outlined', l10n.explore)),
      (_NavEntry('video_library', 'video_library_outlined', l10n.library)),
      (_NavEntry('settings', 'settings_outlined', l10n.settings)),
    ];

    const radius = 32.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 16,
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        theme.colorScheme.surface.withValues(alpha: 0.96),
                        theme.colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.88,
                        ),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.22),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(items.length, (index) {
                      final item = items[index];
                      final isActive = index == currentIndex;

                      return _PillNavItem(
                        icon: item.icon,
                        outlinedIcon: item.outlinedIcon,
                        label: item.label,
                        isActive: isActive,
                        activeColor: theme.colorScheme.primary,
                        onTap: () => onTap(index),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavEntry {
  final String icon;
  final String outlinedIcon;
  final String label;

  const _NavEntry(this.icon, this.outlinedIcon, this.label);
}

class _PillNavItem extends StatelessWidget {
  final String icon;
  final String outlinedIcon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _PillNavItem({
    required this.icon,
    required this.outlinedIcon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inactiveColor = theme.colorScheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: isActive ? 1.12 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            width: isActive ? 52 : 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive
                  ? activeColor.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: isActive
                  ? Border.all(
                      color: activeColor.withValues(alpha: 0.35),
                      width: 1.2,
                    )
                  : null,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AppIcon(
                    isActive ? icon : outlinedIcon,
                    size: 22,
                    color: isActive
                        ? activeColor
                        : inactiveColor.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}