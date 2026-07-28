import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mixstream/core/utils/responsive_breakpoints.dart';
import 'package:mixstream/core/utils/layout_constants.dart';

import 'package:mixstream/features/home/presentation/widgets/continue_watching_card.dart';
import 'package:mixstream/features/library/presentation/history_provider.dart';
import 'package:mixstream/shared/widgets/custom_widgets.dart';
import 'package:mixstream/shared/widgets/desktop_scroll_wrapper.dart';
import 'package:mixstream/l10n/generated/app_localizations.dart';
import 'package:mixstream/core/services/notification_service.dart';
import '../../../../shared/widgets/app_icon.dart';

class ContinueWatchingSection extends ConsumerStatefulWidget {
  final String title;
  final List<HistoryItem> items;
  final double? topPadding;

  const ContinueWatchingSection({
    super.key,
    required this.title,
    required this.items,
    this.topPadding,
  });

  @override
  ConsumerState<ContinueWatchingSection> createState() =>
      _ContinueWatchingSectionState();
}

class _ContinueWatchingSectionState
    extends ConsumerState<ContinueWatchingSection> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final isLarge = context.isTabletOrLarger;

    final double width = isLarge ? 360.0 : 280.0;
    final double listHeight = isLarge ? 200.0 : 150.0;

    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            isLarge ? LayoutConstants.dashboardContentPadding : 16,
            widget.topPadding ?? 20,
            isLarge ? LayoutConstants.dashboardContentPadding : 16,
            10,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: isLarge ? 20 : 16,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ),
              CustomButton(
                onPressed: () {
                  final l10n = AppLocalizations.of(context)!;
                  showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(l10n.clearAllHistory),
                      content: Text(l10n.confirmClearHistory),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(l10n.cancel),
                        ),
                        TextButton(
                          onPressed: () {
                            ref
                                .read(watchHistoryProvider.notifier)
                                .clearAllHistory();
                            Navigator.pop(context);
                            ref
                                .read(notificationServiceProvider)
                                .showSuccess(l10n.watchHistoryCleared);
                          },
                          child: Text(
                            l10n.clearAll,
                            style: TextStyle(
                              color: cs.error,
                            ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppIcon('delete_outline', size: 16, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context)!.clearAll,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: listHeight,
          child: DesktopScrollWrapper(
            controller: _scrollController,
            showButtons: isLarge, // Show nav buttons on desktop and TV
            child: Builder(
              builder: (context) {
                const double spacing = 16.0;
                return ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(
                    horizontal: isLarge
                        ? LayoutConstants.dashboardContentPadding
                        : 16,
                    vertical: 8,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.items.length,
                  itemExtent: width + spacing,
                  itemBuilder: (context, index) {
                    final historyItem = widget.items[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: spacing),
                      child: ContinueWatchingCard(
                        key: ValueKey(historyItem.item.url),
                        historyItem: historyItem,
                        width: width,
                        isLarge: isLarge,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
