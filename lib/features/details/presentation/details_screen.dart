import 'dart:async';

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
import '../../../core/utils/app_utils.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mixstream/core/utils/responsive_breakpoints.dart';

import 'package:mixstream/shared/widgets/custom_widgets.dart';

import '../../library/presentation/library_provider.dart';
import '../../library/presentation/library_state.dart';

import 'package:mixstream/core/storage/history_repository.dart';

import 'details_controller.dart';
import "widgets/details_layout_widgets.dart";
import "widgets/details_desktop_hero.dart";
import "widgets/premium_details_widgets.dart";
import 'package:mixstream/core/extensions/extension_manager.dart';
import "../../../shared/widgets/expandable_text.dart";
import "../../../shared/widgets/loading_indicator.dart";
import 'package:mixstream/l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_icon.dart';
import 'widgets/episode_watched_action_sheet.dart';
import '../../../shared/widgets/network_offline_card.dart';

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
  final GlobalKey _overviewKey = GlobalKey();
  final GlobalKey _episodesKey = GlobalKey();
  final GlobalKey _castKey = GlobalKey();
  final GlobalKey _trailersKey = GlobalKey();
  final GlobalKey _similarKey = GlobalKey();

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

  Future<void> _scrollToSection(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      alignment: 0.08,
    );
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

    // ── Mobile: Cinematic editorial layout ──
    final heroHeight =
        (MediaQuery.sizeOf(context).height * 0.45).clamp(340.0, 520.0);
    final canPlay =
        details != null &&
        details.episodes != null &&
        details.episodes!.isNotEmpty;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // ── Cinematic hero backdrop ──
              SliverAppBar(
                pinned: true,
                expandedHeight: heroHeight,
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
                      final parallaxOffset = scrollOffset * 0.4;
                      return ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(28),
                        ),
                        child: Stack(
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
                                  placeholder: (context, url) => Container(
                                    color: theme.dividerColor,
                                  ),
                                  errorWidget: (_, _, _) =>
                                      ThumbnailErrorPlaceholder(
                                        label: item.title,
                                        isBackdrop: true,
                                      ),
                                ),
                              ),
                            ),
                            // Top scrim + bottom gradient into page bg
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.5),
                                      Colors.black.withValues(alpha: 0.12),
                                      Colors.black.withValues(alpha: 0.15),
                                      Colors.black.withValues(alpha: 0.65),
                                    ],
                                    stops: const [0.0, 0.3, 0.6, 1.0],
                                  ),
                                ),
                              ),
                            ),
                            // Centered circular play CTA
                            Center(
                              child: _HeroPlayButton(
                                enabled: canPlay,
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  ref
                                      .read(
                                        detailsControllerProvider(
                                          widget.item.url,
                                        ).notifier,
                                      )
                                      .handlePlayPress(context, details!);
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                leading: Padding(
                  padding: const EdgeInsets.all(6),
                  child: _RoundedSquareIconButton(
                    icon: 'arrow_back_rounded',
                    tooltip: 'Back',
                    darkSurface: true,
                    onPressed: () => context.pop(),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: _RoundedSquareIconButton(
                      icon: isBookmarked
                          ? 'bookmark_rounded'
                          : 'bookmark_border_rounded',
                      active: isBookmarked,
                      tooltip: isBookmarked
                          ? 'Remove from My List'
                          : 'Add to My List',
                      darkSurface: true,
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        if (isBookmarked) {
                          libraryNotifier.removeItem(item.url);
                        } else {
                          libraryNotifier.addItem(item);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: _RoundedSquareIconButton(
                      icon: 'public_rounded',
                      tooltip: 'Open source page',
                      darkSurface: true,
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _openSourceWebpage(item);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: _RoundedSquareIconButton(
                      icon: 'share_rounded',
                      tooltip: 'Share',
                      darkSurface: true,
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Share.share('${item.title}\n${item.url}');
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
              // ── Network offline banner ──
              SliverToBoxAdapter(
                child: const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: NetworkOfflineCard(),
                ),
              ),
              // ── Hero stretch section ──
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

  Widget _buildTagChips(BuildContext context, List<String> tags) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
          ),
          child: Text(
            tag,
            style: TextStyle(
              color: cs.primary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildScoreStrip(BuildContext context, double score) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        _RatingRing(score: score),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Score',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${score.toStringAsFixed(1)} / 10',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Compact metadata rows shown inside the Overview section (Details block).
  List<Widget> _buildMetaRows(
    BuildContext context,
    MultimediaItem item,
    MultimediaItem? details,
    bool isMovie,
  ) {
    final rows = <Widget>[];
    if (item.year != null) {
      rows.add(
        _MetaRow(
          icon: 'calendar_today_rounded',
          label: 'Release',
          value: item.year.toString(),
        ),
      );
    }
    rows.add(
      _MetaRow(
        icon: 'movie_rounded',
        label: 'Type',
        value: _contentTypeLabel(item.contentType),
      ),
    );
    if (item.duration != null) {
      rows.add(
        _MetaRow(
          icon: 'timer_outlined',
          label: 'Runtime',
          value: _formatRuntime(item.duration!),
        ),
      );
    }
    if (!isMovie && details?.episodes != null) {
      final state = ref.watch(detailsControllerProvider(widget.item.url));
      final seasonCount = state.seasonMap.keys.length;
      if (seasonCount > 0) {
        rows.add(
          _MetaRow(
            icon: 'playlist_rounded',
            label: 'Seasons',
            value: seasonCount.toString(),
          ),
        );
      }
      rows.add(
        _MetaRow(
          icon: 'playlist_02_rounded',
          label: 'Episodes',
          value: details!.episodes!.length.toString(),
        ),
      );
    }
    if (item.contentRating != null) {
      rows.add(
        _MetaRow(
          icon: 'id_verified_rounded',
          label: 'Rating',
          value: item.contentRating!,
        ),
      );
    } else if (item.score != null) {
      rows.add(
        _MetaRow(
          icon: 'star_rounded',
          label: 'Rating',
          value: item.score!.toStringAsFixed(1),
        ),
      );
    }
    final providerName = _providerDisplayName(item);
    if (providerName.isNotEmpty) {
      rows.add(
        _MetaRow(
          icon: 'extension_rounded',
          label: 'Provider',
          value: providerName,
        ),
      );
    }
    return rows;
  }

  /// Video / Audio compact badge sections for the Overview.
  List<Widget> _buildQualitySection(
    BuildContext context,
    MultimediaItem item,
    MultimediaItem? details,
  ) {
    final sections = <Widget>[];
    final videoBadges = <String>[
      if (item.playbackPolicy != null &&
          item.playbackPolicy != 'none' &&
          item.playbackPolicy!.isNotEmpty)
        item.playbackPolicy!,
    ];
    if (videoBadges.isNotEmpty) {
      sections.add(_BadgeSection(icon: 'hd_rounded', label: 'Video', badges: videoBadges));
    }

    final hasDub =
        item.episodes?.any((e) => e.dubStatus == DubStatus.dubbed) ?? false;
    final hasSub =
        item.episodes?.any((e) => e.dubStatus == DubStatus.subbed) ?? false;
    final audioBadges = <String>[
      if (hasDub) 'DUB',
      if (hasSub) 'SUB',
    ];
    if (audioBadges.isNotEmpty) {
      sections.add(
        const SizedBox(height: 10),
      );
      sections.add(_BadgeSection(icon: 'audio_wave_rounded', label: 'Audio', badges: audioBadges));
    }
    return sections;
  }

  /// Available stream qualities and subtitle languages, derived from the
  /// episodes' stream data (no external API).
  List<Widget> _buildAvailableSection(
    BuildContext context,
    MultimediaItem item,
    MultimediaItem? details,
  ) {
    final sections = <Widget>[];
    final qualities = <String>{};
    final languages = <String>{};

    final episodes = details?.episodes ?? item.episodes ?? const <Episode>[];
    for (final e in episodes) {
      for (final s in (e.streams ?? const <StreamResult>[])) {
        final q = s.source.trim();
        if (q.isNotEmpty && !q.toLowerCase().contains('unknown')) {
          qualities.add(q);
        }
        for (final sub in (s.subtitles ?? const <SubtitleFile>[])) {
          final label = (sub.label.isNotEmpty ? sub.label : sub.lang)
              ?.trim();
          if (label != null && label.isNotEmpty) {
            languages.add(label);
          }
        }
      }
    }

    if (qualities.isNotEmpty) {
      final sorted = qualities.toList()
        ..sort((a, b) => _qualityRank(b).compareTo(_qualityRank(a)));
      sections.add(
        _BadgeSection(icon: 'high_quality_rounded', label: 'Quality', badges: sorted),
      );
    }
    if (languages.isNotEmpty) {
      sections.add(const SizedBox(height: 10));
      sections.add(
        _BadgeSection(
          icon: 'translate_rounded',
          label: 'Languages',
          badges: languages.toList()..sort(),
        ),
      );
    }
    return sections;
  }

  /// Rough rank so resolutions sort from highest to lowest (4K > 1080 > 720).
  int _qualityRank(String quality) {
    final lower = quality.toLowerCase();
    if (lower.contains('8k')) return 4320;
    if (lower.contains('4k') || lower.contains('2160')) return 2160;
    final match = RegExp(r'(\d+)').firstMatch(quality);
    if (match == null) return 100;
    return int.tryParse(match.group(1)!) ?? 100;
  }

  /// Resolves the extension display name instead of the package identifier.
  String _providerDisplayName(MultimediaItem item) {
    final raw = item.provider;
    if (raw == null || raw.isEmpty) return '';
    try {
      final manager = ref.read(extensionManagerProvider.notifier);
      final p = manager.getAllProviders().firstWhere(
        (p) => p.packageName == raw || p.name == raw,
      );
      return p.name;
    } catch (_) {
      return raw;
    }
  }

  String _contentTypeLabel(MultimediaContentType type) {
    switch (type) {
      case MultimediaContentType.movie:
        return 'Movie';
      case MultimediaContentType.series:
        return 'TV Series';
      case MultimediaContentType.anime:
        return 'Anime';
      case MultimediaContentType.livestream:
        return 'Live';
      case MultimediaContentType.other:
        return 'Other';
    }
  }

  String _formatRuntime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
        const NetworkOfflineCard(),
        // Loading / Error / Season chips
        if (detailsState is AsyncLoading)
          const Center(child: AppLoadingIndicator())
        else if (detailsState is AsyncError)
          _DetailsErrorView(
            error: detailsState.error.toString(),
            onRetry: () => ref
                .read(
                  detailsControllerProvider(
                    widget.item.url,
                  ).notifier,
                )
                .loadDetails(details ?? widget.item),
          )
        else if (details == null)
          const _DetailsEmptyView()
        else if (!isMovie && details!.episodes!.isNotEmpty)
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
            onItemTap: (rec) => rec.pushDetails(context),
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
    final cs = Theme.of(context).colorScheme;

    // Local-only "Because you watched" rail, derived from watch history.
    final historyItems =
        ref.read(historyRepositoryProvider).getWatchHistory();
    final becauseYouWatched = <MultimediaItem>[];
    final seenUrls = <String>{item.url};
    for (final h in historyItems) {
      final it = h.item;
      if (it.url.isEmpty || seenUrls.contains(it.url)) continue;
      if (it.provider == item.provider) {
        becauseYouWatched.add(it);
        seenUrls.add(it.url);
      }
      if (becauseYouWatched.length >= 10) break;
    }
    if (becauseYouWatched.length < 10) {
      for (final h in historyItems) {
        final it = h.item;
        if (it.url.isEmpty || seenUrls.contains(it.url)) continue;
        becauseYouWatched.add(it);
        seenUrls.add(it.url);
        if (becauseYouWatched.length >= 10) break;
      }
    }

    return [
      // ── Info block: title, metadata, primary actions ──
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              item.logoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: item.logoUrl!,
                      height: 52,
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                      fadeInDuration: const Duration(milliseconds: 200),
                      errorWidget: (_, _, _) => Text(
                        AppUtils.cleanDisplayTitle(item.title),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          height: 1.15,
                        ),
                      ),
                    )
                  : Text(
                      AppUtils.cleanDisplayTitle(item.title),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.15,
                      ),
                    ),
              const SizedBox(height: 12),
              MetadataBar(
                item: item,
                isLoading: detailsState is AsyncLoading,
              ),
              const SizedBox(height: 20),
              DetailsActionButtons(
                key: _actionButtonsKey,
                item: widget.item,
                details: details,
                itemUrl: widget.item.url,
              ),
            ],
          ),
        ),
      ),
      // ── Overview: Synopsis + Genres + Basic Info + Audio/Video ──
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
          child: KeyedSubtree(
            key: _overviewKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(context, 'Overview'),
                const SizedBox(height: 12),
                ExpandableText(
                  text: item.description ?? l10n.noDescription,
                  maxLines: 4,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.72),
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
                if (item.nextAiring != null) ...[
                  const SizedBox(height: 16),
                  NextAiringWidget(nextAiring: item.nextAiring!),
                ],
                // Score ring
                if (item.score != null) ...[
                  const SizedBox(height: 20),
                  _buildScoreStrip(context, item.score!),
                ],
                // Genres chips
                if (item.tags != null && item.tags!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _SectionHeader(context, 'Genres'),
                  const SizedBox(height: 12),
                  _buildTagChips(context, item.tags!),
                ],
                // Basic information rows
                if (_buildMetaRows(context, item, details, isMovie).isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _SectionHeader(context, 'Details'),
                  const SizedBox(height: 14),
                  ..._buildMetaRows(context, item, details, isMovie),
                ],
                // Audio & Video badges
                if (_buildQualitySection(context, item, details).isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _SectionHeader(context, 'Audio & Video'),
                  const SizedBox(height: 12),
                  ..._buildQualitySection(context, item, details),
                ],
                // Available qualities & languages (from stream data)
                if (_buildAvailableSection(context, item, details).isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _SectionHeader(context, 'Qualities & Languages'),
                  const SizedBox(height: 12),
                  ..._buildAvailableSection(context, item, details),
                ],
                // Because you watched (local history)
                if (becauseYouWatched.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  RecommendationsCarousel(
                    title: 'Because you watched',
                    items: becauseYouWatched,
                    onItemTap: (rec) => rec.pushDetails(context),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      // ── Loading / Error ──
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
child: detailsState is AsyncLoading
                  ? const Center(child: AppLoadingIndicator())
                  : detailsState is AsyncError
                  ? _DetailsErrorView(
                      error: detailsState.error.toString(),
                      onRetry: () => ref
                          .read(
                            detailsControllerProvider(
                              widget.item.url,
                            ).notifier,
                          )
                          .loadDetails(details ?? widget.item),
                    )
                  : details == null
                  ? const _DetailsEmptyView()
                  : const SizedBox.shrink(),
        ),
      ),
      // ── Section tabs ──
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: _DetailsSectionTabs(
            isMovie: isMovie,
            hasEpisodes: !isMovie && details?.episodes != null,
            hasCast: item.cast?.isNotEmpty == true,
            hasTrailers: item.trailers?.isNotEmpty == true,
            hasSimilar: item.recommendations?.isNotEmpty == true,
            onSelect: (section) {
              switch (section) {
                case _DetailsSection.overview:
                  unawaited(_scrollToSection(_overviewKey));
                case _DetailsSection.episodes:
                  unawaited(_scrollToSection(_episodesKey));
                case _DetailsSection.cast:
                  unawaited(_scrollToSection(_castKey));
                case _DetailsSection.trailers:
                  unawaited(_scrollToSection(_trailersKey));
                case _DetailsSection.similar:
                  unawaited(_scrollToSection(_similarKey));
              }
            },
          ),
        ),
      ),
      // ── Season selector ──
      if (!isMovie && details?.episodes != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DetailsSeasonListWrapper(itemUrl: widget.item.url),
          ),
        ),
      // ── Episodes ──
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        sliver: SliverDetailsEpisodeList(
          key: _episodesKey,
          parentItem: item,
          itemUrl: widget.item.url,
          isMovie: isMovie,
        ),
      ),
      // ── Cast / Trailers / More Like This ──
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.cast != null && item.cast!.isNotEmpty) ...[
                const SizedBox(height: 8),
                KeyedSubtree(
                  key: _castKey,
                  child: CastCarousel(cast: item.cast!),
                ),
              ],
              if (item.trailers != null && item.trailers!.isNotEmpty) ...[
                const SizedBox(height: 28),
                KeyedSubtree(
                  key: _trailersKey,
                  child: TrailersSection(trailers: item.trailers!),
                ),
              ],
              if (item.recommendations != null &&
                  item.recommendations!.isNotEmpty) ...[
                const SizedBox(height: 28),
                KeyedSubtree(
                  key: _similarKey,
                  child: RecommendationsCarousel(
                    items: item.recommendations!,
                    onItemTap: (rec) => rec.pushDetails(context),
                  ),
                ),
              ],
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    ];
  }
}

/// Friendly error state with a retry button.
class _DetailsErrorView extends ConsumerWidget {
  final Object error;
  final VoidCallback onRetry;

  const _DetailsErrorView({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
            const SizedBox(height: 12),
            Text(
              l10n.generalError,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when a provider returned no usable metadata.
class _DetailsEmptyView extends StatelessWidget {
  const _DetailsEmptyView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline_rounded, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'No details available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This title has no metadata from the selected source. '
              'Try another source or install a metadata extension.',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
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

enum _DetailsSection { overview, episodes, cast, trailers, similar }

/// Compact tab row with an animated accent underline. Taps scroll to the
/// matching content section.
class _DetailsSectionTabs extends StatefulWidget {
  final bool isMovie;
  final bool hasEpisodes;
  final bool hasCast;
  final bool hasTrailers;
  final bool hasSimilar;
  final void Function(_DetailsSection section) onSelect;

  const _DetailsSectionTabs({
    required this.isMovie,
    required this.hasEpisodes,
    required this.hasCast,
    required this.hasTrailers,
    required this.hasSimilar,
    required this.onSelect,
  });

  @override
  State<_DetailsSectionTabs> createState() => _DetailsSectionTabsState();
}

class _DetailsSectionTabsState extends State<_DetailsSectionTabs> {
  _DetailsSection _selected = _DetailsSection.overview;

  @override
  Widget build(BuildContext context) {
    final tabs = <_DetailsSection, String>{
      _DetailsSection.overview: 'Overview',
      if (widget.hasEpisodes) _DetailsSection.episodes: 'Episodes',
      if (widget.hasCast) _DetailsSection.cast: 'Cast',
      if (widget.hasTrailers) _DetailsSection.trailers: 'Trailers',
      if (widget.hasSimilar) _DetailsSection.similar: 'More Like This',
    };

    if (tabs.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final entry in tabs.entries) ...[
            _SectionTab(
              label: entry.value,
              selected: _selected == entry.key,
              onTap: () {
                setState(() => _selected = entry.key);
                widget.onSelect(entry.key);
              },
            ),
            const SizedBox(width: 22),
          ],
        ],
      ),
    );
  }
}

class _SectionTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SectionTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? primary : cs.onSurfaceVariant,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: selected ? 28 : 0,
              height: 2.5,
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section heading with the small gradient accent bar.
class _SectionHeader extends StatelessWidget {
  final BuildContext context;
  final String title;
  const _SectionHeader(this.context, this.title);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SectionAccentBar(context),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// Small accent gradient bar used in section headers.
class _SectionAccentBar extends StatelessWidget {
  final BuildContext context;
  const _SectionAccentBar(this.context);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 4,
      height: 18,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [cs.primary, cs.tertiary, cs.secondary],
        ),
      ),
    );
  }
}

/// Reusable rounded-square icon container (44dp, 13dp radius) with a press
/// scale animation.
class _RoundedSquareIconButton extends StatefulWidget {
  final String icon;
  final bool darkSurface;
  final bool active;
  final String tooltip;
  final VoidCallback onPressed;

  const _RoundedSquareIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.darkSurface = false,
    this.active = false,
  });

  @override
  State<_RoundedSquareIconButton> createState() =>
      _RoundedSquareIconButtonState();
}

class _RoundedSquareIconButtonState extends State<_RoundedSquareIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      reverseDuration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = widget.active;
    final surface =
        widget.darkSurface
            ? Colors.black.withValues(alpha: 0.5)
            : active
            ? cs.primary.withValues(alpha: 0.15)
            : cs.surfaceContainerHighest.withValues(alpha: 0.8);
    final iconColor =
        widget.darkSurface
            ? Colors.white
            : active
            ? cs.primary
            : cs.onSurface;

    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) => _pressController.reverse(),
      onTapCancel: () => _pressController.reverse(),
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) {
          return Transform.scale(scale: _scale.value, child: child);
        },
        child: Tooltip(
          message: widget.tooltip,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: active
                    ? cs.primary.withValues(alpha: 0.5)
                    : cs.outlineVariant.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Center(
              child: AppIcon(widget.icon, size: 22, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}

/// Large circular Play button centered over the hero artwork. Pulsates
/// gently and scales down on press; disabled until streams are ready.
class _HeroPlayButton extends StatefulWidget {
  final bool enabled;
  final VoidCallback onPressed;
  const _HeroPlayButton({required this.enabled, required this.onPressed});

  @override
  State<_HeroPlayButton> createState() => _HeroPlayButtonState();
}

class _HeroPlayButtonState extends State<_HeroPlayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      reverseDuration: const Duration(milliseconds: 120),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _press, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: 'Play',
      child: GestureDetector(
        onTapDown: (_) {
          if (widget.enabled) _press.forward();
        },
        onTapUp: (_) => _press.reverse(),
        onTapCancel: () => _press.reverse(),
        onTap: widget.enabled ? widget.onPressed : null,
        child: AnimatedBuilder(
          animation: _pressScale,
          builder: (context, child) {
            return Transform.scale(
              scale: _pressScale.value,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: AppIcon(
                    'play_arrow_rounded',
                    size: 36,
                    color: widget.enabled
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Compact metadata row: rounded-square icon + label + value.
class _MetaRow extends StatelessWidget {
  final String icon;
  final String label;
  final String value;

  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Center(
              child: AppIcon(icon, size: 18, color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular score ring (0–10) used in the Overview.
class _RatingRing extends StatelessWidget {
  final double score;
  const _RatingRing({required this.score});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: (score / 10).clamp(0.0, 1.0),
              strokeWidth: 4,
              strokeCap: StrokeCap.round,
              backgroundColor: cs.onSurface.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
            ),
          ),
          Text(
            score.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeSection extends StatelessWidget {
  final String icon;
  final String label;
  final List<String> badges;

  const _BadgeSection({
    required this.icon,
    required this.label,
    required this.badges,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Center(
              child: AppIcon(icon, size: 20, color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: badges.map((badge) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: cs.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: cs.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
