import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/layout_constants.dart';
import '../../../../core/utils/responsive_breakpoints.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../home/presentation/widgets/continue_watching_card.dart';
import '../history_provider.dart';

class ContinueWatchingTab extends ConsumerWidget {
  const ContinueWatchingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(watchHistoryProvider);
    final isLarge = context.isTabletOrLarger;

    final inProgress = history
        .where((h) => h.duration > 0 && h.progress > 0 && h.progress < 0.98)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (inProgress.isEmpty) {
      return _buildEmpty(context);
    }

    const double cardWidth = 320;
    const double cardHeight = cardWidth * 9 / 16;

    if (isLarge) {
      return GridView.builder(
        padding: const EdgeInsets.all(LayoutConstants.spacingMd),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: cardWidth + LayoutConstants.spacingMd,
          mainAxisExtent: cardHeight,
          crossAxisSpacing: LayoutConstants.spacingMd,
          mainAxisSpacing: LayoutConstants.spacingMd,
        ),
        itemCount: inProgress.length,
        itemBuilder: (context, index) {
          final entry = inProgress[index];
          return ContinueWatchingCard(
            historyItem: entry,
            width: double.infinity,
            isLarge: isLarge,
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(LayoutConstants.spacingMd),
      itemCount: inProgress.length,
      itemBuilder: (context, index) {
        final entry = inProgress[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: LayoutConstants.spacingMd),
          child: ContinueWatchingCard(
            historyItem: entry,
            width: double.infinity,
          ),
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  cs.primary.withValues(alpha: 0.15),
                  cs.primary.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: AppIcon(
              'play_circle_outline_rounded',
              size: 48,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context)!.libraryEmpty,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pick up where you left off',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}