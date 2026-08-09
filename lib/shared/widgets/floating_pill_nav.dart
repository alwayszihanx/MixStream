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

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 16,
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
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
    final inactiveColor = Theme.of(context).colorScheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: isActive ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            width: isActive ? 48 : 40,
            height: 32,
            decoration: BoxDecoration(
              color: isActive
                  ? activeColor.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: AppIcon(
                isActive ? icon : outlinedIcon,
                size: 22,
                color: isActive ? activeColor : inactiveColor.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
