import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../shared/widgets/thumbnail_error_placeholder.dart';
import '../../../../core/models/tmdb_details.dart';
import '../../../../core/storage/history_repository.dart';
import 'provider_search_section.dart';
import '../../../../shared/widgets/app_icon.dart';

class TmdbDetailsDesktopHero extends ConsumerWidget {
  const TmdbDetailsDesktopHero({
    super.key,
    required this.data,
    required this.isMovie,
    required this.child,
    this.source,
  });

  final TmdbDetails data;
  final bool isMovie;
  final Widget child;
  final String? source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final title = data.title;
    final overview = data.overview;
    final logoUrl = data.logoUrl;
    final runtime = data.runtime;
    final hours = runtime ~/ 60;
    final minutes = runtime % 60;
    final durationText = hours > 0 ? '${hours}H ${minutes}M' : '${minutes}M';
    final releaseDate = data.releaseDateFull;
    final year = releaseDate.isNotEmpty ? releaseDate.split('-')[0] : '';
    final rating = data.voteAverage.toStringAsFixed(1);
    final genreText = data.genresStr;
    final certification = data.certification;
    final director = data.director;
    final backdropImageUrl = data.backdropImageUrl;
    final posterUrl = data.posterImageUrl;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final heroHeight = screenWidth * 0.45;

    return Column(
      children: [
        // ── Hero backdrop ──
        SizedBox(
          height: heroHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: backdropImageUrl,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                memCacheWidth: (screenWidth * MediaQuery.devicePixelRatioOf(context)).round(),
                errorWidget: (_, _, _) => ThumbnailErrorPlaceholder(label: title, isBackdrop: true),
              ),
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

        // ── Poster + info row ──
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
                        errorWidget: (_, _, _) => ThumbnailErrorPlaceholder(label: title),
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
                      // Progress bar
                      Consumer(
                        builder: (context, ref, _) {
                          final historyRepo = ref.watch(historyRepositoryProvider);
                          final pos = historyRepo.getPosition(data.id.toString());
                          final dur = historyRepo.getDuration(data.id.toString());
                          if (pos > 0 && dur > 0) {
                            final progress = (pos / dur).clamp(0.0, 1.0);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 4,
                                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                      valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "${(progress * 100).toInt()}% watched",
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      // Title
                      if (logoUrl != null)
                        CachedNetworkImage(
                          imageUrl: logoUrl,
                          height: 80,
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.contain,
                          placeholder: (_, _) => _buildTitle(theme, title),
                          errorWidget: (_, _, _) => _buildTitle(theme, title),
                        )
                      else
                        _buildTitle(theme, title),
                      const SizedBox(height: 10),
                      // Metadata
                      Wrap(
                        spacing: 16,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildTmdbLogo(),
                          _buildTopBadge(context,
                            source == 'anilist'
                                ? (isMovie ? "ANIME" : "ANIME")
                                : (isMovie ? "MOVIE" : "SERIES"),
                          ),
                          if (year.isNotEmpty)
                            _metaText(context, year),
                          Text('•', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.3))),
                          Icon(Icons.star_rounded, size: 16, color: const Color(0xFF01B4E4)),
                          const SizedBox(width: 2),
                          Text(rating, style: TextStyle(color: const Color(0xFF01B4E4), fontWeight: FontWeight.bold, fontSize: 13)),
                          if (durationText.isNotEmpty) ...[
                            Text('•', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.3))),
                            _metaText(context, durationText),
                          ],
                          if (certification.isNotEmpty) ...[
                            Text('•', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.3))),
                            _metaText(context, certification),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Overview
                      Text(
                        overview,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        genreText,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Sources header
                      Row(
                        children: [
                          AppIcon('extension', color: theme.colorScheme.primary, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            "Available Sources",
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              "BETA",
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 220),
                        child: ProviderSearchSection(
                          query: title,
                          compact: true,
                          parentMediaType: isMovie ? 'movie' : 'tv',
                          tmdbId: data.tmdbId,
                          imdbId: data.imdbId,
                        ),
                      ),
                      if (director != "Unknown") ...[
                        const SizedBox(height: 12),
                        Text(
                          isMovie ? "Director: $director" : "Creator: $director",
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 13,
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

        const SizedBox(height: 32),

        // ── Content below ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: child,
        ),

        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _metaText(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildTmdbLogo() {
    if (source == 'anilist') {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFF02A9FF).withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(5),
        child: SvgPicture.asset('assets/images/anilist_icon.svg', fit: BoxFit.contain),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF01B4E4),
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Text("TMDB", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 9)),
    );
  }

  Widget _buildTopBadge(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
