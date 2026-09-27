import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/utils/image_fallbacks.dart';
import '../../../../core/utils/app_utils.dart';
import 'package:collection/collection.dart';
import 'package:mixstream/core/services/download_service.dart';
import '../../../../shared/widgets/thumbnail_error_placeholder.dart';
import '../../../../shared/widgets/expandable_text.dart';
import '../../../../shared/widgets/app_icon.dart';
import 'package:mixstream/shared/widgets/custom_widgets.dart';
import 'premium_details_widgets.dart';
import 'details_layout_widgets.dart';
import '../details_controller.dart';
import '../downloaded_file_provider.dart';
import '../download_launcher.dart';
import 'download_progress_dialog.dart';
import 'download_management_dialog.dart';
import '../../../library/presentation/library_provider.dart';
import '../../../library/presentation/library_state.dart';
import 'package:mixstream/l10n/generated/app_localizations.dart';
import 'poster_zoom_overlay.dart';

/// Cinematic editorial hero for desktop/TV details.
///
/// A single full-bleed backdrop with a cinematic scrim, and an overlaid
/// content block (logo/title, metadata, genre chips, a prominent Play + My
/// List cluster, and the synopsis) anchored bottom-left, with a floating
/// poster on the right. [child] (episodes, cast, trailers, …) renders below
/// inside a centred, width-constrained column.
class DetailsDesktopHero extends HookConsumerWidget {
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
    final cs = theme.colorScheme;
    final textColor = cs.onSurface;
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

    final libraryState = ref.watch(libraryProvider);
    final isBookmarked = libraryState is LibrarySuccess &&
        libraryState.items.any((i) => i.url == itemUrl);
    final libraryNotifier = ref.read(libraryProvider.notifier);

    final isLaunching = ref.watch(
      detailsControllerProvider(itemUrl).select((s) => s.isLaunching),
    );
    final canPlay = details != null &&
        details!.episodes != null &&
        details!.episodes!.isNotEmpty;

    // ── Download affordance (single-episode VOD only) ──
    final isLivestream =
        displayItem.contentType == MultimediaContentType.livestream;
    final epList = details?.episodes;
    final showDownload = epList != null && epList.length == 1 && !isLivestream;
    final episodeUrl = epList?.firstOrNull?.url ?? displayItem.url;

    final activeDownloads = ref.watch(activeDownloadsProvider);
    final isDownloading = activeDownloads.contains(episodeUrl);
    final progressMap = ref.watch(downloadProgressProvider);
    final downloadProgressData =
        progressMap[episodeUrl] ?? progressMap[displayItem.url];
    final downloadedFile = ref.watch(downloadedFilesProvider)[episodeUrl];

    useEffect(() {
      if (details != null && !isDownloading) {
        Future.microtask(
          () => ref
              .read(downloadedFilesProvider.notifier)
              .checkFile(
                details!,
                episode: epList?.firstWhereOrNull((e) => e.url == episodeUrl),
              ),
        );
      }
      return null;
    }, [details, episodeUrl, isDownloading]);

    final titleBlock = displayItem.logoUrl != null
        ? CachedNetworkImage(
            imageUrl: displayItem.logoUrl!,
            height: 76,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            placeholder: (_, _) => _titleText(),
            errorWidget: (_, _, _) => _titleText(),
          )
        : _titleText();

    final poster = PosterZoomOverlay(
      imageUrl: posterUrl,
      onPlay: canPlay
          ? () => ref
              .read(detailsControllerProvider(itemUrl).notifier)
              .handlePlayPress(context, details!)
          : null,
      onDownload: showDownload && downloadedFile != null
          ? () => DownloadManagementDialog.show(
                context,
                details ?? displayItem,
                downloadedFile,
                episode: epList.firstWhereOrNull((e) => e.url == episodeUrl),
              )
          : showDownload
          ? () => ref
              .read(downloadLauncherProvider)
              .launch(context, details ?? displayItem,
                  episodeUrl: episodeUrl)
          : null,
      isBookmarked: isBookmarked,
      onBookmarkToggle: () {
        if (isBookmarked) {
          libraryNotifier.removeItem(itemUrl);
        } else {
          libraryNotifier.addItem(displayItem);
        }
      },
      onAddToList: null,
    );

    final infoBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        titleBlock,
        const SizedBox(height: 18),
        MetadataBar(
          item: displayItem,
          isLoading: detailsState is AsyncLoading,
        ),
        if (displayItem.tags != null && displayItem.tags!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: displayItem.tags!.map((tag) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: cs.primary.withValues(alpha: 0.32),
                  ),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    color: cs.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 26),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            CustomButton(
              isPrimary: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onPressed: canPlay
                  ? () => ref
                      .read(detailsControllerProvider(itemUrl).notifier)
                      .handlePlayPress(context, details!)
                  : null,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 13, horizontal: 24),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: isLaunching
                      ? [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.resolving,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ]
                      : [
                          const AppIcon(
                            'play_arrow_rounded',
                            size: 22,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            l10n.play,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                ),
              ),
            ),
            CustomButton(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onPressed: () {
                if (isBookmarked) {
                  libraryNotifier.removeItem(itemUrl);
                } else {
                  libraryNotifier.addItem(displayItem);
                }
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 13, horizontal: 20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(
                      isBookmarked
                          ? 'bookmark_rounded'
                          : 'bookmark_border_rounded',
                      size: 20,
                      color: isBookmarked ? cs.primary : textColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isBookmarked ? 'In My List' : 'My List',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (showDownload)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xCC1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0x33FFFFFF),
                    width: 1,
                  ),
                ),
                child: CustomButton(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onPressed: () {
                    if (downloadedFile != null) {
                      DownloadManagementDialog.show(
                        context,
                        details ?? displayItem,
                        downloadedFile,
                        episode:
                            epList.firstWhereOrNull((e) => e.url == episodeUrl),
                      );
                    } else if (isDownloading) {
                      DownloadProgressDialog.show(
                        context,
                        details?.title ?? displayItem.title,
                        episodeUrl,
                      );
                    } else {
                      ref
                          .read(downloadLauncherProvider)
                          .launch(context, details ?? displayItem,
                              episodeUrl: episodeUrl);
                    }
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon(
                          downloadedFile != null
                              ? 'download_done_sharp'
                              : 'download_rounded',
                          size: 20,
                          color: downloadedFile != null
                              ? Colors.green
                              : textColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          downloadedFile != null
                              ? l10n.downloaded
                              : isDownloading
                                  ? ((downloadProgressData?.progress ?? 0) * 100)
                                              .toInt() >
                                          0
                                      ? '${((downloadProgressData?.progress ?? 0) * 100).toInt()}%'
                                      : l10n.starting
                                  : l10n.download,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 26),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ExpandableText(
            text: displayItem.description ?? l10n.noDescription,
            maxLines: 5,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.78),
              fontSize: 16,
              height: 1.6,
            ),
          ),
        ),
        if (displayItem.nextAiring != null) ...[
          const SizedBox(height: 18),
          NextAiringWidget(nextAiring: displayItem.nextAiring!),
        ],
      ],
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Layer 1: full-screen mood backdrop ──
        Positioned.fill(
          child: CachedNetworkImage(
            imageUrl: backdropUrl,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            memCacheWidth: (MediaQuery.sizeOf(context).width *
                    MediaQuery.devicePixelRatioOf(context))
                .round(),
            errorWidget: (_, _, _) => ThumbnailErrorPlaceholder(
              label: displayItem.title,
              isBackdrop: true,
            ),
          ),
        ),
        // ── Layer 2: cinematic scrim (subtle top, strong bottom fade) ──
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.55),
                  scaffoldColor,
                ],
                stops: const [0.0, 0.35, 0.7, 1.0],
              ),
            ),
          ),
        ),
        // ── Layer 3: scrollable content ──
        Positioned.fill(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(56, 100, 56, 64),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 820;
                        if (narrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              poster,
                              const SizedBox(height: 28),
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 640),
                                child: infoBlock,
                              ),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: infoBlock),
                            const SizedBox(width: 44),
                            SizedBox(width: 260, child: poster),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 56),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _titleText() {
    return Text(
      AppUtils.cleanDisplayTitle(displayItem.title),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 44,
        fontWeight: FontWeight.bold,
        height: 1.05,
        letterSpacing: -0.5,
      ),
    );
  }
}
