import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/router/app_router.dart';

import '../../../core/domain/entity/multimedia_item.dart';
import '../../../shared/widgets/thumbnail_error_placeholder.dart';
import '../../../core/utils/image_fallbacks.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mixstream/core/utils/layout_constants.dart';
import 'package:mixstream/core/utils/responsive_breakpoints.dart';

import 'package:mixstream/shared/widgets/custom_widgets.dart';

import '../../library/presentation/library_provider.dart';
import '../../library/presentation/library_state.dart';

import 'details_controller.dart';
import "widgets/details_layout_widgets.dart";
import "widgets/details_desktop_hero.dart";
import "widgets/premium_details_widgets.dart";
import "../../../shared/widgets/expandable_text.dart";
import "../../../shared/widgets/loading_indicator.dart";
import 'package:mixstream/l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_icon.dart';

class DetailsScreen extends ConsumerStatefulWidget {
  final MultimediaItem item;
  final bool autoPlay;

  const DetailsScreen({super.key, required this.item, this.autoPlay = false});

  @override
  ConsumerState<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends ConsumerState<DetailsScreen>
    with SingleTickerProviderStateMixin {
  bool _didTriggerAutoPlay = false;

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _showStickyBar = ValueNotifier(false);
  final GlobalKey _actionButtonsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(detailsControllerProvider(widget.item.url).notifier)
          .loadDetails(widget.item, autoPlay: widget.autoPlay);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _showStickyBar.dispose();
    super.dispose();
  }

  void _onScroll() {
    final key = _actionButtonsKey;
    final ctx = key.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final actionTop = box.localToGlobal(Offset.zero).dy;
    final threshold = MediaQuery.of(context).padding.top + kToolbarHeight + 8;
    final shouldShow = actionTop < threshold;
    if (_showStickyBar.value != shouldShow) {
      _showStickyBar.value = shouldShow;
    }
  }

  Future<void> _openSourceWebpage(MultimediaItem item) async {
    final url = item.url;
    if (url.isNotEmpty) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(detailsControllerProvider(widget.item.url), (prev, next) {
      if (!widget.autoPlay || _didTriggerAutoPlay) return;
      final prevState = prev ?? const DetailsState();
      final nextState = next;
      if (prevState.details.isLoading != true || !nextState.details.hasValue) {
        return;
      }
      final item = nextState.details.value!;
      _didTriggerAutoPlay = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ref
            .read(detailsControllerProvider(widget.item.url).notifier)
            .handlePlayPress(context, item);
      });
    });
    final isBookmarked = ref.watch(
      libraryProvider.select(
        (state) =>
            state is LibrarySuccess &&
            state.items.any((i) => i.url == widget.item.url),
      ),
    );
    final libraryNotifier = ref.read(libraryProvider.notifier);
    final isLarge = context.isTabletOrLarger;

    final detailsAsync = ref.watch(
      detailsControllerProvider(widget.item.url).select((s) => s.details),
    );
    final details = detailsAsync.value;
    final isMovie = ref.watch(
      detailsControllerProvider(widget.item.url).select((s) => s.isMovie),
    );
    final item = details ?? widget.item;

    final l10n = AppLocalizations.of(context)!;

    // ── Desktop / TV: Immersive hero layout ──
    if (isLarge) {
      return _buildDesktopLayout(
        context,
        item,
        details,
        detailsAsync,
        isMovie,
        isBookmarked,
        libraryNotifier,
        l10n,
      );
    }

    final theme = Theme.of(context);

    // ── Mobile: Disney+ style hero ──
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: LayoutConstants.detailsExpandedHeightMobile,
                stretch: true,
                backgroundColor: theme.scaffoldBackgroundColor,
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                  ],
                  background: LayoutBuilder(
                    builder: (context, constraints) {
                      final scrollOffset =
                          _scrollController.hasClients
                              ? _scrollController.offset
                              : 0.0;
                      final parallaxOffset = scrollOffset * 0.5;
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Transform.translate(
                            offset: Offset(0, parallaxOffset),
                            child: Hero(
                              tag: 'banner_${item.url}',
                              child: CachedNetworkImage(
                                imageUrl:
                                    AppImageFallbacks.optional(
                                      item.bannerUrl,
                                    ) ??
                                    AppImageFallbacks.poster(
                                      item.posterUrl,
                                      label: item.title,
                                    ) ??
                                    '',
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                                memCacheWidth:
                                    (MediaQuery.sizeOf(context).width *
                                            MediaQuery.devicePixelRatioOf(
                                              context,
                                            ))
                                        .round(),
                                placeholder: (context, url) =>
                                    Container(color: theme.dividerColor),
                                errorWidget: (_, _, _) =>
                                    ThumbnailErrorPlaceholder(
                                      label: item.title,
                                      isBackdrop: true,
                                    ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.transparent,
                                    theme.colorScheme.surface.withValues(
                                      alpha: 0.6,
                                    ),
                                    theme.colorScheme.surface,
                                  ],
                                  stops: const [0.0, 0.5, 0.8, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                // Mobile: back/bookmark excluded from D-pad traversal.
                // Users navigate back via hardware Back key on TV remotes.
                leading: Focus(
                  descendantsAreTraversable: false,
                  child: CustomButton(
                    shape: const CircleBorder(),
                    backgroundColor: Colors.black45,
                    onPressed: () => context.pop(),
                    child: const AppIcon(
                      'arrow_back_rounded',
                      color: Colors.white,
                    ),
                  ),
                ),
                actions: [
                  Focus(
                    descendantsAreTraversable: false,
                    child: IconButton(
                      icon: AppIcon(
                        isBookmarked
                            ? 'bookmark_rounded'
                            : 'bookmark_border_rounded',
                        color: isBookmarked
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        if (isBookmarked) {
                          libraryNotifier.removeItem(item.url);
                        } else {
                          libraryNotifier.addItem(item);
                        }
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Focus(
                    descendantsAreTraversable: false,
                    child: IconButton(
                      icon: const AppIcon(
                        'public_rounded',
                        color: Colors.white,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _openSourceWebpage(item);
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Focus(
                    descendantsAreTraversable: false,
                    child: IconButton(
                      icon: const AppIcon(
                        'share_rounded',
                        color: Colors.white,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Share.share(
                          '${item.title}\n${item.url}',
                        );
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              ..._buildMobileSlivers(
                context,
                item,
                details,
                detailsAsync,
                isMovie,
                l10n,
              ),
            ],
          ),
          // ── Sticky action bar ──
          ValueListenableBuilder<bool>(
            valueListenable: _showStickyBar,
            builder: (context, show, _) {
              return Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  ignoring: !show,
                  child: AnimatedOpacity(
                    opacity: show ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: _StickyActionBarContent(
                      item: item,
                      details: details,
                      itemUrl: widget.item.url,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  DESKTOP / TV  — Immersive hero layout
  // ─────────────────────────────────────────────────────────────────

  Widget _buildDesktopLayout(
    BuildContext context,
    MultimediaItem item,
    MultimediaItem? details,
    AsyncValue<MultimediaItem?> detailsState,
    bool isMovie,
    bool isBookmarked,
    dynamic libraryNotifier,
    AppLocalizations l10n,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Back button — D-pad reachable (Up from Play)
        leading: IconButton(
          icon: const AppIcon('arrow_back_rounded'),
          onPressed: () => context.pop(),
          style: IconButton.styleFrom(
            backgroundColor: isDark ? Colors.black45 : Colors.white54,
            foregroundColor: textColor,
          ),
        ),
        actions: [
          // Bookmark — D-pad reachable
          IconButton(
            icon: AppIcon(
              isBookmarked
                  ? 'bookmark_rounded'
                  : 'bookmark_border_rounded',
              color: isBookmarked
                  ? Theme.of(context).colorScheme.primary
                  : textColor,
            ),
            onPressed: () {
              if (isBookmarked) {
                libraryNotifier.removeItem(item.url);
              } else {
                libraryNotifier.addItem(item);
              }
            },
            style: IconButton.styleFrom(
              backgroundColor: isDark ? Colors.black45 : Colors.white54,
              foregroundColor: textColor,
            ),
          ),
          // Open source webpage — D-pad reachable
          IconButton(
            icon: AppIcon(
              'public_rounded',
              color: textColor,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              _openSourceWebpage(item);
            },
            style: IconButton.styleFrom(
              backgroundColor: isDark ? Colors.black45 : Colors.white54,
              foregroundColor: textColor,
            ),
          ),
          // Share — D-pad reachable
          IconButton(
            icon: AppIcon(
              'share_rounded',
              color: textColor,
            ),
            onPressed: () {
              Share.share(
                '${item.title}\n${item.url}',
              );
            },
            style: IconButton.styleFrom(
              backgroundColor: isDark ? Colors.black45 : Colors.white54,
              foregroundColor: textColor,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: DetailsDesktopHero(
        displayItem: item,
        baseItem: widget.item,
        details: details,
        detailsState: detailsState,
        isMovie: isMovie,
        itemUrl: widget.item.url,
        child: _buildDesktopContentBelow(
          context,
          item,
          details,
          detailsState,
          isMovie,
          l10n,
        ),
      ),
    );
  }

  /// Content rendered below the hero section: season chips, episodes,
  /// cast, trailers, and recommendations.
  Widget _buildDesktopContentBelow(
    BuildContext context,
    MultimediaItem item,
    MultimediaItem? details,
    AsyncValue<MultimediaItem?> detailsState,
    bool isMovie,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Loading / Error / Season chips
        if (detailsState is AsyncLoading)
          const Center(child: AppLoadingIndicator())
        else if (detailsState is AsyncError)
          Text(
            "Error: ${detailsState.error}",
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          )
        else if (!isMovie && details?.episodes != null)
          DetailsSeasonListWrapper(itemUrl: widget.item.url),

        const SizedBox(height: 16),

        // Episode grid (non-sliver version)
        DetailsDesktopEpisodeColumn(
          parentItem: item,
          itemUrl: widget.item.url,
          isMovie: isMovie,
        ),

        const SizedBox(height: 32),

        // Cast
        if (item.cast != null && item.cast!.isNotEmpty) ...[
          CastCarousel(cast: item.cast!),
        ],

        // Trailers
        if (item.trailers != null && item.trailers!.isNotEmpty) ...[
          const SizedBox(height: 32),
          TrailersSection(trailers: item.trailers!),
        ],

        // Recommendations
        if (item.recommendations != null &&
            item.recommendations!.isNotEmpty) ...[
          const SizedBox(height: 32),
          RecommendationsCarousel(
            items: item.recommendations!,
            onItemTap: (rec) {
              DetailsRoute(
                $extra: DetailsRouteExtra(item: rec),
              ).push<void>(context);
            },
          ),
        ],

        const SizedBox(height: 100),
      ],
    );
  }

  List<Widget> _buildMobileSlivers(
    BuildContext context,
    MultimediaItem item,
    MultimediaItem? details,
    AsyncValue<MultimediaItem?> detailsState,
    bool isMovie,
    AppLocalizations l10n,
  ) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'poster_${item.url}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl:
                            AppImageFallbacks.poster(
                              item.posterUrl,
                              label: item.title,
                            ) ??
                            '',
                        width: 100,
                        height: 150,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) =>
                            ThumbnailErrorPlaceholder(label: item.title),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.logoUrl != null)
                          CachedNetworkImage(
                            imageUrl: item.logoUrl!,
                            height: 50,
                            fit: BoxFit.contain,
                            alignment: Alignment.centerLeft,
                            errorWidget: (_, _, _) => Text(
                              item.title,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          )
                        else
                          Text(
                            item.title,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        const SizedBox(height: 8),
                        MetadataBar(
                          item: item,
                          isLoading: detailsState is AsyncLoading,
                        ),
                        if (item.tags != null && item.tags!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: item.tags!.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontSize: 11,
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
                ],
              ),
              const SizedBox(height: 24),
              DetailsActionButtons(
                key: _actionButtonsKey,
                item: widget.item,
                details: details,
                itemUrl: widget.item.url,
              ),
              if (item.nextAiring != null) ...[
                const SizedBox(height: 16),
                NextAiringWidget(nextAiring: item.nextAiring!),
              ],
              const SizedBox(height: 24),
              Text(
                l10n.synopsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ExpandableText(
                text: item.description ?? l10n.noDescription,
                maxLines: 4,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              if (detailsState is AsyncLoading)
                const Center(child: AppLoadingIndicator())
              else if (detailsState is AsyncError)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.1),
                  child: Text(
                    AppLocalizations.of(
                      context,
                    )!.errorPrefix(detailsState.error.toString()),
                  ),
                )
              else if (!isMovie && details?.episodes != null)
                DetailsSeasonListWrapper(itemUrl: widget.item.url),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        sliver: SliverDetailsEpisodeList(
          parentItem: item,
          itemUrl: widget.item.url,
          isMovie: isMovie,
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.cast != null && item.cast!.isNotEmpty) ...[
                const SizedBox(height: 16),
                CastCarousel(cast: item.cast!),
              ],
              if (item.trailers != null && item.trailers!.isNotEmpty) ...[
                const SizedBox(height: 32),
                TrailersSection(trailers: item.trailers!),
              ],
              if (item.recommendations != null &&
                  item.recommendations!.isNotEmpty) ...[
                const SizedBox(height: 32),
                RecommendationsCarousel(
                  items: item.recommendations!,
                  onItemTap: (rec) {
                    DetailsRoute(
                      $extra: DetailsRouteExtra(item: rec),
                    ).push<void>(context);
                  },
                ),
              ],
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    ];
  }
}

/// Slim sticky bar that appears when scrolling past the main action buttons.
/// Shows mini Play button for quick access.
class _StickyActionBarContent extends ConsumerWidget {
  final MultimediaItem item;
  final MultimediaItem? details;
  final String itemUrl;

  const _StickyActionBarContent({
    required this.item,
    required this.details,
    required this.itemUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final isLaunching = ref.watch(
      detailsControllerProvider(itemUrl).select((s) => s.isLaunching),
    );

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 12,
        right: 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: CustomButton(
              isPrimary: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onPressed:
                  (details != null &&
                      details!.episodes != null &&
                      details!.episodes!.isNotEmpty)
                  ? () => ref
                        .read(detailsControllerProvider(item.url).notifier)
                        .handlePlayPress(context, details!)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: isLaunching
                      ? [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n.resolving,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ]
                      : [
                          const AppIcon('play_arrow_rounded', size: 16),
                          const SizedBox(width: 4),
                          Text(
                            l10n.play,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
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
    );
  }
}
