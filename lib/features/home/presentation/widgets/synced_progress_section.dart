import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mixstream/core/utils/responsive_breakpoints.dart';
import 'package:mixstream/core/utils/layout_constants.dart';
import 'package:mixstream/features/tracking/domain/sync_progress_item.dart';
import 'package:mixstream/shared/widgets/desktop_scroll_wrapper.dart';
import 'synced_progress_card.dart';

class SyncedProgressSection extends ConsumerStatefulWidget {
  final String title;
  final List<SyncProgressItem> items;
  final void Function(SyncProgressItem) onItemTap;

  const SyncedProgressSection({
    super.key,
    required this.title,
    required this.items,
    required this.onItemTap,
  });

  @override
  ConsumerState<SyncedProgressSection> createState() =>
      _SyncedProgressSectionState();
}

class _SyncedProgressSectionState extends ConsumerState<SyncedProgressSection> {
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
            20,
            isLarge ? LayoutConstants.dashboardContentPadding : 16,
            10,
          ),
          child: Text(
            widget.title,
            style: TextStyle(
              fontSize: isLarge ? 20 : 16,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
        ),
        SizedBox(
          height: listHeight,
          child: DesktopScrollWrapper(
            controller: _scrollController,
            showButtons: isLarge,
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(
                horizontal: isLarge
                    ? LayoutConstants.dashboardContentPadding
                    : 16,
                vertical: 8,
              ),
              scrollDirection: Axis.horizontal,
              itemCount: widget.items.length,
              itemExtent: width + (isLarge ? 24.0 : 12.0),
              itemBuilder: (context, index) {
                final item = widget.items[index];
                return Padding(
                  padding: EdgeInsets.only(right: isLarge ? 24.0 : 12.0),
                  child: SyncedProgressCard(
                    key: ValueKey(
                      '${item.tmdbId}_${item.imdbId}_${item.title}',
                    ),
                    item: item,
                    width: width,
                    isLarge: isLarge,
                    onTap: () => widget.onItemTap(item),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
