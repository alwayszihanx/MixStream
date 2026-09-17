import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixstream/features/home/presentation/widgets/continue_watching_card.dart';
import 'package:mixstream/features/library/presentation/history_provider.dart';
import 'package:mixstream/core/utils/responsive_breakpoints.dart';
import 'package:mixstream/shared/widgets/desktop_scroll_wrapper.dart';
import 'package:mixstream/l10n/generated/app_localizations.dart';

class ContinueWatchingHeroSlot extends ConsumerStatefulWidget {
  const ContinueWatchingHeroSlot({super.key});

  @override
  ConsumerState<ContinueWatchingHeroSlot> createState() =>
      _ContinueWatchingHeroSlotState();
}

class _ContinueWatchingHeroSlotState
    extends ConsumerState<ContinueWatchingHeroSlot> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(watchHistoryProvider);
    if (items.isEmpty) return const SizedBox.shrink();

    final isLarge = context.isTabletOrLarger;
    final heroHeight = isLarge ? 280.0 : 200.0;
    final cardWidth = isLarge ? 300.0 : 220.0;
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      height: heroHeight,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.play_circle_fill, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  l10n.continueWatching,
                  style: TextStyle(
                    fontSize: isLarge ? 18 : 14,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    ref.read(watchHistoryProvider.notifier).clearAllHistory();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Icon(Icons.clear, size: 16, color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: DesktopScrollWrapper(
              controller: _scrollController,
              showButtons: isLarge,
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                itemExtent: cardWidth + 16,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: ContinueWatchingCard(
                      key: ValueKey(items[index].item.url),
                      historyItem: items[index],
                      width: cardWidth,
                      isLarge: isLarge,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ContinueWatchingHeroViewportReserve extends StatelessWidget {
  final double height;
  final Widget child;

  const ContinueWatchingHeroViewportReserve({
    super.key,
    required this.height,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: height, child: child);
  }
}
