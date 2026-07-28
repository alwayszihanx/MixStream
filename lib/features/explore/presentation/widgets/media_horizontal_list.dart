import 'dart:collection';

import 'package:flutter/material.dart';
import '../../../../core/router/app_router.dart';
import 'package:mixstream/l10n/generated/app_localizations.dart';
import '../../../../core/utils/layout_constants.dart';
import '../../../../shared/widgets/cards_wrapper.dart';
import '../../../../shared/widgets/custom_widgets.dart';

import '../../../../core/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/multimedia_card.dart';
import '../view_all_screen.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../shared/widgets/app_icon.dart';

class MediaHorizontalList extends StatefulWidget {
  final String title;
  final List<MultimediaItem> mediaList;
  final ViewAllCategory category;
  final void Function(MultimediaItem)? onTap;
  final bool showViewAll;
  final String? heroTagPrefix;

  const MediaHorizontalList({
    super.key,
    required this.title,
    required this.mediaList,
    required this.category,
    this.onTap,
    this.showViewAll = true,
    this.heroTagPrefix,
  });

  @override
  State<MediaHorizontalList> createState() => _MediaHorizontalListState();
}

class _MediaHorizontalListState extends State<MediaHorizontalList> {
  late ScrollController _scrollController;
  bool _isPortrait = true;

  // Cache the aspect ratio for a given URL to prevent layout shifts
  // when the widget is destroyed and recreated during scrolling. Bounded
  // because a power user can scroll thousands of unique posters over a
  // session; LRU eviction keeps the working set bounded.
  static const int _aspectRatioCacheMax = 5000;
  static final LinkedHashMap<String, bool> _aspectRatioCache =
      LinkedHashMap<String, bool>();

  static bool? _lookupCached(String url) {
    if (!_aspectRatioCache.containsKey(url)) return null;
    // Move to most-recently-used.
    final v = _aspectRatioCache.remove(url)!;
    _aspectRatioCache[url] = v;
    return v;
  }

  static void _storeCached(String url, bool isPortrait) {
    _aspectRatioCache.remove(url);
    _aspectRatioCache[url] = isPortrait;
    while (_aspectRatioCache.length > _aspectRatioCacheMax) {
      _aspectRatioCache.remove(_aspectRatioCache.keys.first);
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    if (widget.mediaList.isNotEmpty) {
      final url = widget.mediaList.first.posterImageUrl;
      final cached = _lookupCached(url);
      if (cached != null) {
        _isPortrait = cached;
      } else {
        _checkAspectRatio();
      }
    }
  }

  @override
  void didUpdateWidget(MediaHorizontalList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mediaList.isNotEmpty &&
        oldWidget.mediaList != widget.mediaList) {
      final url = widget.mediaList.first.posterImageUrl;
      final cached = _lookupCached(url);
      if (cached != null) {
        if (_isPortrait != cached) {
          setState(() => _isPortrait = cached);
        }
      } else {
        _checkAspectRatio();
      }
    }
  }

  Future<void> _checkAspectRatio() async {
    if (widget.mediaList.isEmpty) return;
    final url = widget.mediaList.first.posterImageUrl;
    if (url.isEmpty) return;
    final isPortrait = await ImageUtils.isImagePortrait(url);
    _storeCached(url, isPortrait);
    if (mounted && _isPortrait != isPortrait) {
      setState(() {
        _isPortrait = isPortrait;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollBy(double delta) {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + delta).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaList.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;

    final isDesktop = context.isDesktop;

    final double cardWidth = isDesktop
        ? (_isPortrait ? 200.0 : 300.0)
        : (_isPortrait ? 130.0 : 200.0);

    final double imageHeight = cardWidth / (_isPortrait ? (2 / 3) : (16 / 9));
    final double listHeight = imageHeight + 40.0;

    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            isDesktop
                ? LayoutConstants.dashboardContentPadding
                : LayoutConstants.spacingMd,
            LayoutConstants.spacingMd,
            isDesktop
                ? LayoutConstants.dashboardContentPadding
                : LayoutConstants.spacingMd,
            LayoutConstants.spacingXs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isDesktop ? 20 : 16,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ),
              if (isDesktop) ...[
                _HeaderArrowButton(
                  icon: const AppIcon('arrow_back_ios_new', size: 12),
                  onTap: () => _scrollBy(-400),
                ),
                const SizedBox(width: 4),
                _HeaderArrowButton(
                  icon: const AppIcon('arrow_forward_ios', size: 12),
                  onTap: () => _scrollBy(400),
                ),
              ],
              if (widget.showViewAll)
                const SizedBox(width: LayoutConstants.spacingXs),
              const SizedBox(width: 8),
              if (widget.showViewAll)
                CardsWrapper(
                  onTap: () {
                    ViewAllRoute(
                      $extra: ViewAllRouteExtra(
                        title: widget.title,
                        initialMediaList: widget.mediaList,
                        category: widget.category,
                        onTap: widget.onTap,
                      ),
                    ).push<void>(context);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: LayoutConstants.spacingSm,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Text(
                          l10n.viewAll,
                          style: TextStyle(
                            color: cs.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        AppIcon('arrow_forward_ios', size: 10,
                          color: cs.primary,
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
          child: Builder(
            builder: (context) {
              final double spacing = isDesktop
                  ? LayoutConstants.spacingLg
                  : LayoutConstants.spacingSm;

              return ListView.builder(
                controller: _scrollController,
                clipBehavior: Clip.none,
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop
                      ? LayoutConstants.dashboardContentPadding
                      : LayoutConstants.spacingMd,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: widget.mediaList.length,
                itemExtent: cardWidth + spacing,
                itemBuilder: (context, index) {
                  final item = widget.mediaList[index];
                  final imageUrl = item.posterImageUrl;
                  final itemTitle = item.title;
                  final prefix = widget.heroTagPrefix ?? 'list';
                  final uniqueTag =
                      '${prefix}_${widget.title}_${item.id}_${itemTitle.hashCode}_$index';

                  return Padding(
                    padding: EdgeInsets.only(right: spacing),
                    child: MultimediaCard(
                      imageUrl: imageUrl,
                      title: itemTitle,
                      heroTag: uniqueTag,
                      isPortrait: _isPortrait,
                      badgeText: item.score != null
                          ? item.score!.toStringAsFixed(1)
                          : null,
                      onTap: () {
                        if (widget.onTap != null) {
                          widget.onTap!(item);
                        } else {
                          TmdbDetailsRoute(
                            movieId: item.id,
                            mediaType: item.tmdbMediaType,
                            heroTag: uniqueTag,
                            placeholderPoster: imageUrl,
                            source: item.source,
                          ).push<void>(context);
                        }
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Small arrow button used in section headers on desktop.
class _HeaderArrowButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback onTap;

  const _HeaderArrowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: CustomButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: icon,
      ),
    );
  }
}
