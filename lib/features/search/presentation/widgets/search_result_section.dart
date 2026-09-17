import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixstream/core/utils/responsive_breakpoints.dart';

import 'package:mixstream/core/extensions/extension_manager.dart';
import 'package:mixstream/core/domain/entity/multimedia_item.dart';
import 'package:mixstream/core/router/app_router.dart';
import 'package:mixstream/core/utils/image_fallbacks.dart';
import 'package:mixstream/shared/widgets/desktop_scroll_wrapper.dart';
import 'package:mixstream/shared/widgets/multimedia_card.dart';
import 'stamp_in_label.dart';
import 'bouncy_entry_animation.dart';

/// Animated count pill beside a provider section title.
class _ResultCountBadge extends StatelessWidget {
  final int count;

  const _ResultCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: TweenAnimationBuilder<int>(
        tween: IntTween(begin: 0, end: count),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        builder: (context, value, _) => Text(
          '$value',
          style: TextStyle(
            color: cs.primary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class SearchResultSection extends ConsumerStatefulWidget {
  final String providerName;
  final String providerId;
  final List<MultimediaItem> results;
  final FocusNode? firstCardFocusNode;

  const SearchResultSection({
    super.key,
    required this.providerName,
    required this.providerId,
    required this.results,
    this.firstCardFocusNode,
  });

  @override
  ConsumerState<SearchResultSection> createState() =>
      _SearchResultSectionState();
}

class _SearchResultSectionState extends ConsumerState<SearchResultSection> {
  final ScrollController _scrollController = ScrollController();

  void _openResult(BuildContext context, MultimediaItem item) {
    item.pushDetails(context);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.results.isEmpty) return const SizedBox.shrink();

    final isLarge = context.isTabletOrLarger;
    // Matching MediaHorizontalList/ContinueWatchingSection dimensions
    final double listHeight = isLarge ? 350.0 : 230.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Blue Accent Style
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StampInLabel(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.providerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isLarge ? 24 : 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _ResultCountBadge(count: widget.results.length),
                          _buildDebugTag(context, ref),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: 0,
                        end: isLarge ? 30 : 20,
                      ),
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => Container(
                        width: value,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        SizedBox(
          height: listHeight,
          child: DesktopScrollWrapper(
            controller: _scrollController,
            child: Builder(
              builder: (context) {
                final double cardWidth = isLarge ? 200.0 : 130.0;
                final double spacing = isLarge ? 24.0 : 12.0;

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.results.length,
                  itemExtent: cardWidth + spacing,
                  clipBehavior: Clip.none,
                  itemBuilder: (context, rIndex) {
                    final item = widget.results[rIndex];
                    final uniqueTag =
                        'search_${widget.providerId}_${item.url}_$rIndex';

                    return Padding(
                      padding: EdgeInsets.only(right: spacing),
                      child: BouncyEntryAnimation(
                        delay: Duration(milliseconds: rIndex * 50),
                        child: MultimediaCard(
                          key: ValueKey(item.url),
                          imageUrl: AppImageFallbacks.poster(
                            item.posterUrl,
                            label: item.title,
                          ),
                          title: item.title,
                          heroTag: uniqueTag,
                          focusNode: rIndex == 0
                              ? widget.firstCardFocusNode
                              : null,
                          badgeText: item.score?.toStringAsFixed(1),
                          rating: item.score?.toStringAsFixed(1),
                          metadata: _buildMetadata(item),
                          onTap: () => _openResult(context, item),
                        ),
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

  Widget _buildDebugTag(BuildContext context, WidgetRef ref) {
    bool isDebug = false;
    try {
      final manager = ref.read(extensionManagerProvider.notifier);
      final p = manager.getAllProviders().firstWhere(
        (p) => p.packageName == widget.providerId,
      );
      if (p.isDebug) {
        isDebug = true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SearchResultSection._buildDebugTag: $e');
    }

    if (!isDebug) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'DEBUG',
          style: TextStyle(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String? _buildMetadata(MultimediaItem item) {
    final year = item.year;
    final type = switch (item.contentType) {
      MultimediaContentType.movie => 'Movie',
      MultimediaContentType.series => 'Series',
      MultimediaContentType.anime => 'Anime',
      MultimediaContentType.livestream => 'Live',
      MultimediaContentType.other => null,
    };
    if (year == null && type == null) return null;
    return [if (year != null) '$year', if (type != null) type].join(' • ');
  }
}
