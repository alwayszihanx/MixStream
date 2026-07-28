import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/utils/image_fallbacks.dart';
import '../../../../shared/widgets/thumbnail_error_placeholder.dart';
import '../../../../shared/widgets/expandable_text.dart';
import 'premium_details_widgets.dart';
import 'details_layout_widgets.dart';
import 'package:mixstream/l10n/generated/app_localizations.dart';

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

  final MultimediaItem displayItem;
  final MultimediaItem baseItem;
  final MultimediaItem? details;
  final AsyncValue<MultimediaItem?> detailsState;
  final bool isMovie;
  final String itemUrl;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final backdropUrl =
        AppImageFallbacks.optional(displayItem.bannerUrl) ??
        AppImageFallbacks.poster(
          displayItem.posterUrl,
          label: displayItem.title,
        ) ??
        '';

    final posterUrl =
        AppImageFallbacks.poster(displayItem.posterUrl, label: displayItem.title) ?? '';

    final screenWidth = MediaQuery.sizeOf(context).width;
    final heroHeight = screenWidth * 0.45;

    return Column(
      children: [
        // ── Hero section ──
        SizedBox(
          height: heroHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Backdrop
              CachedNetworkImage(
                imageUrl: backdropUrl,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                memCacheWidth: (screenWidth * MediaQuery.devicePixelRatioOf(context)).round(),
                errorWidget: (_, _, _) => ThumbnailErrorPlaceholder(
                  label: displayItem.title,
                  isBackdrop: true,
                ),
              ),
              // Bottom gradient fade
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        theme.scaffoldBackgroundColor,
                        theme.scaffoldBackgroundColor.withValues(alpha: 0.7),
                        Colors.transparent,
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.3, 0.6, 1.0],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Content section ──
        // Poster + Info row sits just below/between the hero
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster
              Transform.translate(
                offset: const Offset(0, -60),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: SizedBox(
                      width: 180,
                      child: CachedNetworkImage(
                        imageUrl: posterUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => ThumbnailErrorPlaceholder(label: displayItem.title),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 32),

              // Info
              Expanded(
                child: Transform.translate(
                  offset: const Offset(0, -20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayItem.title,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      MetadataBar(
                        item: displayItem,
                        isLoading: detailsState is AsyncLoading,
                      ),
                      const SizedBox(height: 16),
                      ExpandableText(
                        text: displayItem.description ?? l10n.noDescription,
                        maxLines: 3,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          height: 1.5,
                        ),
                      ),
                      if (displayItem.nextAiring != null) ...[
                        const SizedBox(height: 16),
                        NextAiringWidget(nextAiring: displayItem.nextAiring!),
                      ],
                      const SizedBox(height: 20),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: DetailsActionButtons(
                          item: baseItem,
                          details: details,
                          itemUrl: itemUrl,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // ── Content below (full width) ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: child,
        ),

        const SizedBox(height: 48),
      ],
    );
  }
}
