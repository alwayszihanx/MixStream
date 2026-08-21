import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/utils/image_fallbacks.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../core/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/thumbnail_error_placeholder.dart';
import '../../../../shared/widgets/expandable_text.dart';
import 'premium_details_widgets.dart';
import 'details_layout_widgets.dart';
import 'package:mixstream/l10n/generated/app_localizations.dart';

/// Cinematic editorial hero for desktop/TV details.
///
/// A two-panel layout: a large rounded backdrop panel on the left with the
/// title, metadata and synopsis overlaid, and a floating poster + action
/// panel on the right. [child] renders below (episodes, cast, trailers).
class DetailsDesktopHero extends ConsumerWidget {
  const DetailsDesktopHero({
    super.key,
    required this.displayItem,
    required this.baseItem,
    required this.details,
    required this.detailsState,
    required this.isMovie,
    required this.itemUrl,
    required this.child,
  });

  /// The resolved item for display (details ?? widget.item).
  final MultimediaItem displayItem;

  /// The original item — used by [DetailsActionButtons] for URL matching.
  final MultimediaItem baseItem;

  /// Loaded details (nullable while loading).
  final MultimediaItem? details;

  /// Async state for loading/error indicators.
  final AsyncValue<MultimediaItem?> detailsState;

  final bool isMovie;
  final String itemUrl;

  /// Content rendered below the hero section (episodes, cast, etc.).
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scaffoldColor = theme.scaffoldBackgroundColor;
    final textColor = theme.colorScheme.onSurface;
    final textSecondary = textColor.withValues(alpha: 0.72);
    final l10n = AppLocalizations.of(context)!;
    final isTv = context.isTv;

    final backdropUrl =
        AppImageFallbacks.optional(displayItem.bannerUrl) ??
        AppImageFallbacks.poster(
          displayItem.posterUrl,
          label: displayItem.title,
        ) ??
        '';
    final posterUrl =
        AppImageFallbacks.poster(displayItem.posterUrl, label: displayItem.title) ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Layer 1: full-screen mood backdrop ──
        Positioned.fill(
          child: CachedNetworkImage(
            imageUrl: backdropUrl,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            memCacheWidth:
                (MediaQuery.sizeOf(context).width *
                        MediaQuery.devicePixelRatioOf(context))
                    .round(),
            errorWidget: (_, _, _) => ThumbnailErrorPlaceholder(
              label: displayItem.title,
              isBackdrop: true,
            ),
          ),
        ),
        // ── Layer 2: dark tint for text legibility ──
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.65),
                  Colors.black.withValues(alpha: 0.4),
                  scaffoldColor,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        // ── Layer 3: scrollable content ──
        Positioned.fill(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(48, 40, 48, 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero two-panel row ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: rounded backdrop panel with title overlay
                    Expanded(
                      flex: 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: SizedBox(
                          height: isTv ? 380 : 300,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: backdropUrl,
                                fit: BoxFit.cover,
                                memCacheWidth:
                                    (MediaQuery.sizeOf(context).width *
                                            0.6 *
                                            MediaQuery.devicePixelRatioOf(context))
                                        .round(),
                                errorWidget: (_, _, _) =>
                                    ThumbnailErrorPlaceholder(
                                      label: displayItem.title,
                                      isBackdrop: true,
                                    ),
                              ),
                              // Bottom gradient scrim
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.75),
                                      ],
                                      stops: const [0.4, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              // Title block at bottom-left of the panel
                              Positioned(
                                left: 24,
                                right: 24,
                                bottom: 20,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (displayItem.logoUrl != null)
                                      CachedNetworkImage(
                                        imageUrl: displayItem.logoUrl!,
                                        height: 52,
                                        fit: BoxFit.contain,
                                        alignment: Alignment.centerLeft,
                                        placeholder: (_, _) => _buildTitle(
                                          textColor,
                                        ),
                                        errorWidget: (_, _, _) => _buildTitle(
                                          textColor,
                                        ),
                                      )
                                    else
                                      _buildTitle(Colors.white),
                                    const SizedBox(height: 12),
                                    MetadataBar(
                                      item: displayItem,
                                      isLoading: detailsState is AsyncLoading,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 28),
                    // Right: floating poster + action panel
                    SizedBox(
                      width: 220,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: AspectRatio(
                              aspectRatio: 2 / 3,
                              child: CachedNetworkImage(
                                imageUrl: posterUrl,
                                fit: BoxFit.cover,
                                memCacheWidth:
                                    (220 * MediaQuery.devicePixelRatioOf(context))
                                        .round(),
                                placeholder: (context, url) => Container(
                                  color: theme.dividerColor,
                                ),
                                errorWidget: (_, _, _) =>
                                    ThumbnailErrorPlaceholder(
                                      label: displayItem.title,
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 220),
                            child: DetailsActionButtons(
                              item: baseItem,
                              details: details,
                              itemUrl: itemUrl,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // ── Synopsis block ──
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExpandableText(
                        text: displayItem.description ?? l10n.noDescription,
                        maxLines: 5,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 16,
                          height: 1.6,
                        ),
                      ),
                      if (displayItem.nextAiring != null) ...[
                        const SizedBox(height: 20),
                        NextAiringWidget(nextAiring: displayItem.nextAiring!),
                      ],
                      if (displayItem.tags != null &&
                          displayItem.tags!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: displayItem.tags!.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // ── Content below hero (full width) ──
                child,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitle(Color color) {
    return Text(
      AppUtils.cleanDisplayTitle(displayItem.title),
      style: TextStyle(
        color: color,
        fontSize: 44,
        fontWeight: FontWeight.bold,
        height: 1.1,
      ),
    );
  }
}