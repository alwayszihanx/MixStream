import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/utils/responsive_breakpoints.dart';
import '../../core/utils/app_utils.dart';
import 'cards_wrapper.dart';
import 'shimmer_placeholder.dart';
import 'thumbnail_error_placeholder.dart';

class MultimediaCard extends StatefulWidget {
  final String? imageUrl;
  final String title;
  final VoidCallback onTap;
  final String heroTag;
  final bool isPortrait;
  final FocusNode? focusNode;
  final String? badgeText;
  final String? rating;
  final int? rank;
  final String? metadata;
  final List<String>? badges;
  final List<PopupMenuEntry<String>> Function(BuildContext)? contextMenuBuilder;
  final void Function(String value)? onContextMenuAction;

  const MultimediaCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.onTap,
    required this.heroTag,
    this.isPortrait = true,
    this.focusNode,
    this.badgeText,
    this.rating,
    this.rank,
    this.metadata,
    this.badges,
    this.contextMenuBuilder,
    this.onContextMenuAction,
  });

  @override
  State<MultimediaCard> createState() => _MultimediaCardState();
}

class _MultimediaCardState extends State<MultimediaCard> {
  static const double _posterRadius = 10;

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktop;
    final cardWidth = isDesktop
        ? (widget.isPortrait ? 200.0 : 300.0)
        : (widget.isPortrait ? 130.0 : 200.0);
    final displayTitle = AppUtils.cleanDisplayTitle(widget.title);
    final showBadges = widget.badges?.isNotEmpty == true;
    final showRating = widget.rating != null && widget.rating!.isNotEmpty;

    return RepaintBoundary(
      child: CardsWrapper(
        onTap: widget.onTap,
        focusNode: widget.focusNode,
        scaleFactor: 1.05,
        contextMenuBuilder: widget.contextMenuBuilder,
        onContextMenuAction: widget.onContextMenuAction,
        child: SizedBox(
          width: cardWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(_posterRadius),
                child: AspectRatio(
                  aspectRatio: widget.isPortrait ? 2 / 3 : 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: widget.heroTag,
                        child: CachedNetworkImage(
                          imageUrl: widget.imageUrl ?? '',
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              ShimmerPlaceholder(borderRadius: _posterRadius),
                          errorWidget: (_, _, _) =>
                              ThumbnailErrorPlaceholder(label: displayTitle),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 70,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.65),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (showRating)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5C518),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 12,
                                  color: Color(0xFF1A1A1A),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  widget.rating!,
                                  style: const TextStyle(
                                    color: Color(0xFF1A1A1A),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (widget.badgeText != null &&
                          widget.badgeText!.isNotEmpty)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.badgeText!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      if (showBadges)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final badge in widget.badges!.take(2))
                                Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF01B4E4),
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    badge,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (widget.rank != null && widget.rank! <= 10)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          child: _RankBadge(rank: widget.rank!),
                        ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                displayTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isDesktop ? 13 : 11.5,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.7,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.metadata != null &&
                                  widget.metadata!.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  widget.metadata!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: isDesktop ? 11 : 9.5,
                                    fontWeight: FontWeight.w500,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.7,
                                        ),
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.red.shade700,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(6),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$rank',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: -0.5,
            ),
          ),
          const Text(
            '#',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 7,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
