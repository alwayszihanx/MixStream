import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/utils/image_fallbacks.dart';
import '../../../../shared/widgets/cards_wrapper.dart';
import '../../../../shared/widgets/shimmer_placeholder.dart';
import '../../../../shared/widgets/thumbnail_error_placeholder.dart';
import '../../../../shared/widgets/desktop_scroll_wrapper.dart';
import '../../../../core/utils/responsive_breakpoints.dart';
import '../../../../core/models/tmdb_details.dart';
import '../tmdb_details_controller.dart';
import 'package:mixstream/l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../sources/presentation/plugin_sources_sheet.dart';
import '../download_launcher.dart';

/// Small pill button used by the batch-download selection controls.
class _PillButton extends StatelessWidget {
  final String label;
  final String icon;
  final VoidCallback? onTap;
  final bool filled;
  final bool enabled;

  const _PillButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.filled = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = !enabled || onTap == null;
    final bg = filled
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainer;
    final fg = filled
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;

    return Material(
      color: disabled ? theme.colorScheme.surfaceContainer : bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: disabled ? theme.colorScheme.surfaceContainer : bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MovieSeasonsList extends ConsumerStatefulWidget {
  final int movieId;
  final List<TmdbSeason> seasons;
  final Color? textColor;
  final String? source;
  final TmdbDetails? data;

  const MovieSeasonsList({
    super.key,
    required this.movieId,
    required this.seasons,
    this.textColor,
    this.source,
    this.data,
  });

  @override
  ConsumerState<MovieSeasonsList> createState() => _MovieSeasonsListState();
}

class _MovieSeasonsListState extends ConsumerState<MovieSeasonsList> {
  late final ScrollController _scrollController;
  late final ScrollController _episodesScrollController;
  int _selectedRangeIndex = 0;

  /// Batch-download selection for TMDB/Nuvio episodes. Keys are `S{season}E{n}`
  /// because these episode models carry no URL of their own.
  bool _selecting = false;
  final Set<String> _selectedEpisodeKeys = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _episodesScrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _episodesScrollController.dispose();
    super.dispose();
  }

  String _keyFor(Map<String, dynamic> ep) {
    final s = ep['season_number'] as int? ?? 0;
    final e = ep['episode_number'] as int? ?? 0;
    return 'S$s-E$e';
  }

  Episode _toEpisodeModel(Map<String, dynamic> ep) => Episode(
    name: (ep['name'] as String?) ?? 'Episode',
    url: '',
    season: ep['season_number'] as int? ?? 0,
    episode: ep['episode_number'] as int? ?? 0,
    airDate: ep['air_date'] as String?,
    description: ep['overview'] as String?,
    rating: (ep['vote_average'] as num?)?.toDouble(),
    runtime: ep['runtime'] as int?,
  );

  void _toggleKey(String key) {
    setState(() {
      if (!_selectedEpisodeKeys.remove(key)) _selectedEpisodeKeys.add(key);
    });
  }

  void _exitSelection() {
    setState(() {
      _selecting = false;
      _selectedEpisodeKeys.clear();
    });
  }

  void _toggleSelectAll(List<Map<String, dynamic>> episodes) {
    setState(() {
      final keys = episodes.map(_keyFor).toSet();
      if (_selectedEpisodeKeys.containsAll(keys)) {
        _selectedEpisodeKeys.removeAll(keys);
      } else {
        _selectedEpisodeKeys.addAll(keys);
      }
    });
  }

  /// The entry-point button shown next to the section title. Selecting is
  /// unavailable when we have no TMDB target to download against.
  Widget _buildSelectButton(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canSelect = widget.data != null && widget.data!.tmdbId != null;
    if (!canSelect) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: _PillButton(
        label: l10n.selectEpisodes,
        icon: 'checklist_rounded',
        onTap: () => setState(() => _selecting = true),
      ),
    );
  }

  /// Action bar shown above the episode strip while multi-select is active.
  Widget _buildSelectionBar(
    BuildContext context,
    List<Map<String, dynamic>> episodes,
  ) {
    if (!_selecting) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final count = _selectedEpisodeKeys.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          _PillButton(
            label: count > 0
                ? l10n.downloadSelectedCount(count)
                : l10n.selectEpisodes,
            icon: 'file_download_outlined',
            filled: true,
            enabled: count > 0,
            onTap: count == 0
                ? null
                : () {
                    final selected = episodes
                        .where((e) => _selectedEpisodeKeys.contains(_keyFor(e)))
                        .map(_toEpisodeModel)
                        .toList();
                    final target = widget.data;
                    if (target == null || selected.isEmpty) return;
                    _exitSelection();
                    ref
                        .read(downloadLauncherProvider)
                        .downloadEpisodes(
                          context,
                          target,
                          selected,
                          skipExisting: true,
                        );
                  },
          ),
          const SizedBox(width: 8),
          _PillButton(
            label: count >= episodes.length
                ? l10n.deselectAll
                : l10n.selectAll,
            icon: 'done_all_rounded',
            onTap: () => _toggleSelectAll(episodes),
          ),
          const SizedBox(width: 8),
          _PillButton(
            label: l10n.done,
            icon: 'close_rounded',
            onTap: _exitSelection,
          ),
        ],
      ),
    );
  }

  /// Checkbox badge drawn on an episode card while selecting.
  Widget _selectionBadge(bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: selected
            ? Theme.of(context).colorScheme.primary
            : Colors.black.withValues(alpha: 0.55),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 2,
        ),
      ),
      child: selected
          ? const AppIcon('check_rounded', color: Colors.white, size: 18)
          : null,
    );
  }

  Widget _buildTmdbLogo(BuildContext context) {
    final isAnilist = widget.source == 'anilist';
    if (isAnilist) {
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: const Color(0xFF02A9FF).withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(4),
        child: SvgPicture.asset(
          'assets/images/anilist_icon.svg',
          fit: BoxFit.contain,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0d253f),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        AppLocalizations.of(context)!.tmdb,
        style: const TextStyle(
          color: Color(0xFF90cea1),
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.seasons.isEmpty) return const SizedBox.shrink();

    final isDesktop = context.isDesktop;

    if (isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppLocalizations.of(context)!.episodes,
                style: TextStyle(
                  color: widget.textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildSelectButton(context),
              const SizedBox(width: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Consumer(
                  builder: (context, ref, _) {
                    return DropdownButton<int>(
                      value: ref
                          .watch(
                            tmdbDetailsControllerProvider(
                              widget.movieId,
                              source: widget.source,
                            ),
                          )
                          .selectedSeason,
                      dropdownColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainer,
                      underline: const SizedBox(),
                      style: TextStyle(color: widget.textColor),
                      icon: AppIcon('arrow_drop_down', color: widget.textColor,),
                      items: widget.seasons.map<DropdownMenuItem<int>>((s) {
                        final num = s.seasonNumber;
                        final count = s.episodeCount;
                        return DropdownMenuItem(
                          value: num,
                          child: Text(
                            AppLocalizations.of(
                              context,
                            )!.seasonWithEpisodes(num, count),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedRangeIndex = 0;
                            _selectedEpisodeKeys.clear();
                          });
                          ref
                              .read(
                                tmdbDetailsControllerProvider(
                                  widget.movieId,
                                  source: widget.source,
                                ).notifier,
                              )
                              .fetchEpisodes(val, source: widget.source);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDesktopEpisodesList(context),
          const SizedBox(height: 50),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppLocalizations.of(context)!.seasons,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildSelectButton(context),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: ListView.separated(
              clipBehavior: Clip.none,
              scrollDirection: Axis.horizontal,
              itemCount: widget.seasons.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final season = widget.seasons[index];
                final seasonNum = season.seasonNumber;

                return Consumer(
                  builder: (context, ref, _) {
                    final isSelected =
                        ref
                            .watch(
                              tmdbDetailsControllerProvider(
                                widget.movieId,
                                source: widget.source,
                              ),
                            )
                            .selectedSeason ==
                        seasonNum;

                    final primary = Theme.of(context).colorScheme.primary;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedRangeIndex = 0;
                          _selectedEpisodeKeys.clear();
                        });
                        ref
                            .read(
                              tmdbDetailsControllerProvider(
                                widget.movieId,
                                source: widget.source,
                              ).notifier,
                            )
                            .fetchEpisodes(seasonNum, source: widget.source);
                      },
                      child: AnimatedScale(
                        scale: isSelected ? 1.0 : 0.94,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutBack,
                        child: AnimatedContainer(
                          width: 120,
                          duration: const Duration(milliseconds: 220),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected
                                  ? primary
                                  : Colors.transparent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: primary.withValues(alpha: 0.35),
                                      blurRadius: 12,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: CachedNetworkImage(
                                    imageUrl: season.posterImageUrl ?? '',
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    errorWidget: (_, _, _) =>
                                        ThumbnailErrorPlaceholder(
                                          label: season.name,
                                        ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                season.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: widget.textColor,
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              Text(
                                AppLocalizations.of(
                                  context,
                                )!.episodeCountOnly(season.episodeCount),
                                style: TextStyle(
                                  color: widget.textColor?.withValues(
                                    alpha: 0.7,
                                  ),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Consumer(
            builder: (context, ref, _) {
              final selectedSeason = ref
                  .watch(
                    tmdbDetailsControllerProvider(
                      widget.movieId,
                      source: widget.source,
                    ),
                  )
                  .selectedSeason;
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(0, 0.04),
                          end: Offset.zero,
                        ).animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey('season_$selectedSeason'),
                  child: _buildMobileEpisodesList(context),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      );
    }
  }

  Widget _buildDesktopEpisodesList(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        if (ref
                .watch(
                  tmdbDetailsControllerProvider(
                    widget.movieId,
                    source: widget.source,
                  ),
                )
                .episodesFuture ==
            null) {
          return const SizedBox.shrink();
        }

        return FutureBuilder<Map<String, dynamic>?>(
          future: ref
              .watch(
                tmdbDetailsControllerProvider(
                  widget.movieId,
                  source: widget.source,
                ),
              )
              .episodesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: AppLoadingIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const SizedBox.shrink();
            }
            final episodes = List<Map<String, dynamic>>.from(
              (snapshot.data!['episodes'] as List?) ?? const <dynamic>[],
            );
            if (episodes.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSelectionBar(context, episodes),
                SizedBox(
                  height: 240,
                  child: DesktopScrollWrapper(
                controller: _scrollController,
                child: ListView.separated(
                  clipBehavior: Clip.none,
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: episodes.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 20),
                  itemBuilder: (context, index) {
                    final ep = episodes[index];
                    final imageUrl = AppImageFallbacks.tmdbStill(
                      ep['still_path'] as String?,
                      label: (ep['name'] as String?) ?? 'Episode',
                    );
                    final voteAverage =
                        (ep['vote_average'] as num?)?.toDouble() ?? 0.0;
                    final runtime = ep['runtime'] as int? ?? 0;
                    final hours = runtime ~/ 60;
                    final minutes = runtime % 60;
                    final runtimeText = hours > 0
                        ? '${hours}h ${minutes}m'
                        : '${minutes}m';

                    return CardsWrapper(
                      onTap: () {
                        if (_selecting) {
                          _toggleKey(_keyFor(ep));
                          return;
                        }
                        if (widget.data == null) return;
                        PluginSourcesSheet.open(
                          context,
                          widget.data!,
                          episode: _toEpisodeModel(ep),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 300,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: _selecting &&
                                  _selectedEpisodeKeys.contains(_keyFor(ep))
                              ? Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 3,
                                )
                              : null,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: imageUrl ?? '',
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    // TMDB still source is w500 — already matches
                                    // 300 dp card × ~2 DPR. Let CNI decode native.
                                    placeholder: (context, url) =>
                                        ShimmerPlaceholder.rectangular(
                                          borderRadius: 8,
                                        ),
                                    errorWidget: (_, _, _) =>
                                        ThumbnailErrorPlaceholder(
                                          label:
                                              (ep['name'] as String?) ??
                                              'Episode',
                                        ),
                                  ),
                                  if (_selecting)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: _selectionBadge(
                                        _selectedEpisodeKeys.contains(
                                          _keyFor(ep),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "E${ep['episode_number']} • ${ep['name']}",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      _buildTmdbLogo(context),
                                      const SizedBox(width: 8),
                                      Text(
                                        voteAverage.toStringAsFixed(1),
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      if (runtime > 0)
                                        Text(
                                          runtimeText,
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.7),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    (ep['overview'] as String?) ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                ),
              ),
            ],
          );
          },
        );
      },
    );
  }

  Widget _buildMobileEpisodesList(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        if (ref
                .watch(
                  tmdbDetailsControllerProvider(
                    widget.movieId,
                    source: widget.source,
                  ),
                )
                .episodesFuture ==
            null) {
          return const SizedBox.shrink();
        }

        return FutureBuilder<Map<String, dynamic>?>(
          future: ref
              .watch(
                tmdbDetailsControllerProvider(
                  widget.movieId,
                  source: widget.source,
                ),
              )
              .episodesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: AppLoadingIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const SizedBox.shrink();
            }
            final episodes = List<Map<String, dynamic>>.from(
              (snapshot.data!['episodes'] as List?) ?? const <dynamic>[],
            );
            if (episodes.isEmpty) return const SizedBox.shrink();

            const int batchSize = 10;
            final int totalEpisodes = episodes.length;
            final int batchCount = (totalEpisodes / batchSize).ceil();

            if (_selectedRangeIndex >= batchCount) {
              _selectedRangeIndex = 0;
            }

            final int start = _selectedRangeIndex * batchSize;
            final int end = (start + batchSize).clamp(0, totalEpisodes);
            final displayedEpisodes = episodes.sublist(start, end);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.episodes,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        _buildSelectButton(context),
                      ],
                    ),
                    if (batchCount > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedRangeIndex,
                            dropdownColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainer,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                            icon: AppIcon(
                              'keyboard_arrow_down_rounded',
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            items: List.generate(batchCount, (index) {
                              final rangeStart = index * batchSize + 1;
                              final rangeEnd = ((index + 1) * batchSize).clamp(
                                1,
                                totalEpisodes,
                              );
                              return DropdownMenuItem(
                                value: index,
                                child: Text("$rangeStart-$rangeEnd"),
                              );
                            }),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedRangeIndex = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSelectionBar(context, episodes),
                ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayedEpisodes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final ep = displayedEpisodes[index];
                    final imageUrl = AppImageFallbacks.tmdbStill(
                      ep['still_path'] as String?,
                      label: (ep['name'] as String?) ?? 'Episode',
                    );
                    final voteAverage =
                        (ep['vote_average'] as num?)?.toDouble() ?? 0.0;
                    final runtime = (ep['runtime'] as int?) ?? 0;
                    final hours = runtime ~/ 60;
                    final minutes = runtime % 60;
                    final runtimeText = hours > 0
                        ? '${hours}h ${minutes}m'
                        : '${minutes}m';

                    return CardsWrapper(
                      onTap: () {
                        if (_selecting) {
                          _toggleKey(_keyFor(ep));
                          return;
                        }
                        if (widget.data == null) return;
                        PluginSourcesSheet.open(
                          context,
                          widget.data!,
                          episode: _toEpisodeModel(ep),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.only(bottom: 8),
                        decoration: _selecting &&
                                _selectedEpisodeKeys.contains(_keyFor(ep))
                            ? BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2,
                                ),
                              )
                            : null,
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: imageUrl ?? '',
                                    width: 120,
                                    height: 68,
                                    // Skip memCacheWidth — source w500 already
                                    // matches 120 dp × ~3 DPR ~ 360 px target.
                                    fit: BoxFit.cover,
                                    errorWidget: (_, _, _) =>
                                        ThumbnailErrorPlaceholder(
                                          label:
                                              (ep['name'] as String?) ??
                                              'Episode',
                                          iconSize: 24,
                                        ),
                                  ),
                                ),
                                if (_selecting)
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: _selectionBadge(
                                      _selectedEpisodeKeys.contains(_keyFor(ep)),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${ep['episode_number']}. ${ep['name']}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      _buildTmdbLogo(context),
                                      const SizedBox(width: 8),
                                      Text(
                                        voteAverage.toStringAsFixed(1),
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      if (runtime > 0)
                                        Text(
                                          runtimeText,
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.7),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    (ep['overview'] as String?) ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
