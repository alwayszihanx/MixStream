import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixstream/core/utils/layout_constants.dart';
import 'package:mixstream/core/extensions/extension_manager.dart';
import 'package:mixstream/l10n/generated/app_localizations.dart';
import 'package:mixstream/features/home/presentation/delegates/home_search_delegate.dart';
import 'package:mixstream/features/home/presentation/home_provider.dart';
import 'dart:async';
import '../../../../shared/widgets/app_icon.dart';

/// A custom header bar for the widescreen dashboard layout.
///
/// Contains: carousel prev/next arrows, capsule search, provider chip.
class DashboardHeaderBar extends ConsumerWidget {
  final FocusNode searchFocusNode;
  final VoidCallback onShowProviderSelector;

  /// Called when the user taps the left arrow (carousel previous).
  final VoidCallback? onPrevious;

  /// Called when the user taps the right arrow (carousel next).
  final VoidCallback? onNext;

  const DashboardHeaderBar({
    super.key,
    required this.searchFocusNode,
    required this.onShowProviderSelector,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final activeProvider = ref.watch(activeProviderProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final hasCarousel = onPrevious != null && onNext != null;

    return Container(
      height: LayoutConstants.dashboardHeaderHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: LayoutConstants.dashboardContentPadding,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => onPrevious?.call(),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              child: AppIcon(
                'arrow_back_ios_new',
                size: 14,
                color: hasCarousel
                    ? cs.onSurface
                    : cs.onSurface.withValues(alpha: 0.38),
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => onNext?.call(),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              child: AppIcon(
                'arrow_forward_ios',
                size: 14,
                color: hasCarousel
                    ? cs.onSurface
                    : cs.onSurface.withValues(alpha: 0.38),
              ),
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: GestureDetector(
              onTap: () {
                unawaited(
                  showSearch<void>(
                    context: context,
                    delegate: HomeSearchDelegate(),
                    useRootNavigator: false,
                    maintainState: true,
                  ),
                );
              },
              child: Container(
                height: 38,
                constraints: const BoxConstraints(maxWidth: 500),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                    LayoutConstants.radiusPill,
                  ),
                ),
                child: Row(
                  children: [
                    AppIcon('search', size: 18,
                      color: cs.onSurface.withValues(alpha: 0.54),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${l10n.search}...',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withValues(alpha: 0.54),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          GestureDetector(
            onTap: () => ref.read(homeDataProvider.notifier).fetch(),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.onSurface.withValues(alpha: 0.1),
              ),
              child: AppIcon(
                'refresh',
                color: cs.onSurface,
                size: 18,
              ),
            ),
          ),

          const SizedBox(width: 12),

          GestureDetector(
            onTap: onShowProviderSelector,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon('extension', color: cs.onSurface, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    activeProvider?.name ?? l10n.none,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
