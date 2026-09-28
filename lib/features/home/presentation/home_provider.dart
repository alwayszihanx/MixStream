import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/addons/data/addon_client.dart';
import '../../../../core/config/tmdb_config.dart';
import '../../../../core/addons/data/addon_repository.dart';
import '../../../../core/addons/models/addon_manifest.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/extensions/extension_manager.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/extensions/base_provider.dart';
import '../../explore/data/explore_tmdb_provider.dart';
import '../../explore/data/explore_language_provider.dart';

import 'regional_sections.dart';
import './home_state.dart';

part 'home_provider.g.dart';

/// Address of a Stremio catalog embedded in a home section key, so the
/// section's rows and its "View all" can both reach that exact catalog.
typedef AddonCatalogTarget = ({
  String title,
  String addonUrl,
  String type,
  String catalogId,
});

/// Parses a section key back into its add-on catalog address. Returns null for
/// plain TMDB/provider sections.
AddonCatalogTarget? addonCatalogTarget(String key) {
  final marker = key.indexOf('\u0000');
  if (marker < 0) return null;
  final params = <String, String>{};
  for (final part in key.substring(marker + 1).split(';')) {
    final eq = part.indexOf('=');
    if (eq < 0) continue;
    params[part.substring(0, eq)] = Uri.decodeComponent(part.substring(eq + 1));
  }
  final addonUrl = params['addon'];
  final type = params['type'];
  final id = params['id'];
  if (addonUrl == null || type == null || id == null) return null;
  return (
    title: key.substring(0, marker),
    addonUrl: addonUrl,
    type: type,
    catalogId: id,
  );
}

@riverpod
class HomeData extends _$HomeData {
  int _fetchToken = 0;

  @override
  HomeState build() {
    // Bumped here as well as in fetch(): a provider change must cancel the
    // previous provider's in-flight load, not just its next one.
    _fetchToken++;
    final activeProvider = ref.watch(activeProviderProvider);
    if (activeProvider == null) {
      // No MixStream provider installed — fall back to the TMDB catalog so
      // Nuvio plugin sources remain usable on their own.
      Future.microtask(() => fetch());
      return const HomeLoading();
    }

    // Start initial fetch
    Future.microtask(() => fetch());
    return const HomeLoading();
  }

  /// Whether to trust an in-flight fetch's result.
  ///
  /// The notifier outlives a rebuild, so without this a fetch that is still
  /// running for the provider the user just switched away from lands on top of
  /// the grid they are now looking at. Bumped in `build` as well, so a
  /// provider change cancels the previous provider's in-flight load.
  bool _isCurrent(int token) => token == _fetchToken && ref.mounted;

  Future<void> fetch() async {
    final token = ++_fetchToken;
    final activeProvider = ref.read(activeProviderProvider);

    // Only skip the work when the network is genuinely unreachable. See
    // _isOnline: the previous dns.google probe reported "offline" on networks
    // that simply block it.
    if (!await _isOnline()) {
      if (_isCurrent(token)) state = const HomeOffline();
      return;
    }

    try {
      // 1. Get the provider (or TMDB fallback) catalog first so the hero and
      //    familiar rows appear immediately.
      final providerItems = activeProvider == null
          ? await _fetchFallbackCatalog()
          : await activeProvider.getHome().catchError(
              (_) => <String, List<MultimediaItem>>{},
            );

      final shelves = <String, List<MultimediaItem>>{};

      void publish() {
        if (!_isCurrent(token)) return;
        // Regional shelves sit directly under the hero; provider rows follow.
        final merged = <String, List<MultimediaItem>>{};
        for (final entry in shelves.entries) {
          if (entry.value.isNotEmpty) merged[entry.key] = entry.value;
        }
        for (final entry in providerItems.entries) {
          if (!kRegionalSectionKeys.contains(entry.key) &&
              !merged.containsKey(entry.key)) {
            merged[entry.key] = entry.value;
          }
        }
        // Keep the loading shimmer up rather than flashing an empty page when
        // the provider catalog is empty and shelves are still in flight.
        if (merged.isNotEmpty) state = HomeSuccess(merged);
      }

      publish();

      // 2. Stream the regional shelves in as each one resolves, so a slow
      //    region never blocks the rest of the page.
      await _fetchRegionalShelves(onShelf: (key, items) {
        if (!_isCurrent(token)) return;
        shelves[key] = items;
        publish();
      });
    } catch (e) {
      if (state is! HomeSuccess && _isCurrent(token)) {
        state = HomeError(e.toString());
      }
    }
  }

  /// Loads the "Latest" plus every per-industry regional shelf.
  ///
  /// Each shelf merges 2 pages of movies (40) with 1 page of series (20) for
  /// ~60 entries, sorted newest-first by the API so a new release lands at the
  /// top of its section automatically. Failures and empty shelves are skipped.
  Future<void> _fetchRegionalShelves({
    required void Function(String key, List<MultimediaItem> items) onShelf,
  }) async {
    final service = ref.read(tmdbServiceProvider);

    Future<void> load(
      String key,
      String? originCountries,
      String? originalLanguages,
      int minVotes, {
      Map<String, dynamic>? movieExtra,
      Map<String, dynamic>? tvExtra,
      String movieSort = 'primary_release_date.desc',
      String tvSort = 'first_air_date.desc',
    }) async {
      try {
        final results = await Future.wait([
          service.getRegionMovies(
            originCountries ?? '',
            originalLanguages: originalLanguages,
            minVotes: minVotes,
            sortBy: movieSort,
            page: 1,
            additionalParams: movieExtra,
          ),
          service.getRegionMovies(
            originCountries ?? '',
            originalLanguages: originalLanguages,
            minVotes: minVotes,
            sortBy: movieSort,
            page: 2,
            additionalParams: movieExtra,
          ),
          service.getRegionTV(
            originCountries ?? '',
            originalLanguages: originalLanguages,
            minVotes: minVotes,
            sortBy: tvSort,
            page: 1,
            additionalParams: tvExtra,
          ),
        ]);

        final seen = <int>{};
        final merged = <MultimediaItem>[];
        for (final list in results) {
          for (final item in list) {
            if (seen.add(item.tmdbId ?? item.url.hashCode)) merged.add(item);
          }
        }
        if (merged.length >= 40) onShelf(key, merged);
      } catch (e) {
        if (kDebugMode) debugPrint('[HomeData] shelf $key failed: $e');
      }
    }

    // Small concurrency cap so we don't burst ~40 requests at once on mobile.
    const chunkSize = 4;

    // "Latest" = anything released in the recent past, ranked by popularity.
    // Using a date *window* (rather than sorting all-time by date) is what
    // keeps freshly-released titles at the top instead of the newest-indexed
    // unrated placeholder entries.
    final recentFrom = DateTime.now()
        .subtract(const Duration(days: LatestSection.windowDays))
        .toIso8601String()
        .split('T')
        .first;

    final jobs = <Future<void>>[
      load(
        LatestSection.key,
        null,
        null,
        LatestSection.minVotes,
        movieSort: 'popularity.desc',
        tvSort: 'popularity.desc',
        movieExtra: {'primary_release_date.gte': recentFrom},
        tvExtra: {'first_air_date.gte': recentFrom},
      ),
      for (final s in kRegionalSections)
        load(s.key, s.originCountries, s.originalLanguages, s.minVotes),
    ];

    for (var i = 0; i < jobs.length; i += chunkSize) {
      await Future.wait(jobs.sublist(i, (i + chunkSize).clamp(0, jobs.length)));
    }
  }

  /// Whether the app can reach the network at all.
  ///
  /// This used to be `InternetAddress.lookup('dns.google')`, which is not a
  /// connectivity test: dns.google is unreachable on any network that blocks
  /// it, and on plenty that only allow port 53 to the local resolver, so the
  /// home screen showed "no internet" while the internet was fine. It now
  /// asks the host the app actually needs, and treats ANY HTTP answer as
  /// reachable — a 401 or a 404 still proves the network path works, which is
  /// the only thing being asked here.
  Future<bool> _isOnline() async {
    final client = HttpClient();
    try {
      client.connectionTimeout = const Duration(seconds: 3);
      final request = await client
          .getUrl(Uri.parse('${TmdbConfig.baseUrl}/configuration'))
          .timeout(const Duration(seconds: 4));
      final response = await request
          .close()
          .timeout(const Duration(seconds: 4));
      return response.statusCode > 0;
    } catch (_) {
      return false;
    } finally {
      try {
        client.close(force: true);
      } catch (_) {}
    }
  }

  Future<Map<String, List<MultimediaItem>>> _fetchTmdbCatalog() async {
    final service = ref.read(tmdbServiceProvider);
    final lang = ref.read(languageProvider);

    final futures = await Future.wait([
      service.getTrendingAllDay(language: lang),
      service.getPopularMovies(language: lang),
      service.getTopRated(language: lang),
      service.getPopularTV(language: lang),
      service.getOnTheAirTV(language: lang),
    ]);

    return {
      'Trending': futures[0],
      'Popular Movies': futures[1],
      'Top Rated': futures[2],
      'Popular TV Shows': futures[3],
      'On The Air': futures[4],
    };
  }

  /// TMDB rows plus the enabled Stremio add-on catalogs. The add-on sections
  /// are appended after the TMDB ones; `Trending` stays first so the hero
  /// carousel is a guaranteed present, well-known row.
  Future<Map<String, List<MultimediaItem>>> _fetchFallbackCatalog() async {
    final catalog = await _fetchTmdbCatalog();
    final addonCatalogs = await _fetchAddonCatalogs();
    if (addonCatalogs.isEmpty) return catalog;
    return {...catalog, ...addonCatalogs};
  }

  /// First page of each enabled add-on catalog, capped so a slow or broken
  /// add-on can't stall the whole home screen. Section keys carry the catalog
  /// address (`\u0000`-prefixed) so the home screen can open "View all" on
  /// that exact catalog.
  static const int _maxAddonCatalogSections = 6;
  static const int _addonCatalogPageLimit = 12;

  Future<Map<String, List<MultimediaItem>>> _fetchAddonCatalogs() async {
    final repository = ref.read(addonRepositoryProvider);
    if (repository.isLoading) {
      await ref.read(addonRepositoryProvider.notifier).load();
    }
    final targets = <(ManagedAddon, AddonCatalog)>[];
    for (final addon in ref.read(addonRepositoryProvider).enabled) {
      final manifest = addon.manifest;
      if (manifest == null || manifest.catalogs.isEmpty) continue;
      for (final catalog in manifest.catalogs.take(2)) {
        targets.add((addon, catalog));
        if (targets.length >= _maxAddonCatalogSections) break;
      }
      if (targets.length >= _maxAddonCatalogSections) break;
    }
    if (targets.isEmpty) return const {};

    final client = ref.read(addonClientProvider);
    final results = await Future.wait([
      for (final (addon, catalog) in targets)
        client
            .catalog(addon, type: catalog.type, id: catalog.id)
            .then<List<MultimediaItem>>(
              (rows) => [
                for (final row in rows.take(_addonCatalogPageLimit))
                  row.toMultimediaItem(addonUrl: addon.manifestUrl),
              ],
            )
            .timeout(const Duration(seconds: 12))
            .catchError((_) {
          return const <MultimediaItem>[];
        }),
    ]);

    final sections = <String, List<MultimediaItem>>{};
    for (var i = 0; i < targets.length; i++) {
      final (addon, catalog) = targets[i];
      if (results[i].isEmpty) continue;
      sections[
          '${addon.displayName} · ${catalog.name}\u0000addon=${Uri.encodeComponent(addon.manifestUrl)};type=${catalog.type};id=${Uri.encodeComponent(catalog.id)}'] =
          results[i];
    }
    return sections;
  }
}

@riverpod
class HomeFilter extends _$HomeFilter {
  @override
  ProviderType? build() {
    final storage = ref.read(storageServiceProvider);
    final saved = storage.getHomeCategory();
    if (saved != null) {
      try {
        return ProviderType.values.firstWhere((e) => e.name == saved);
      } catch (_) {}
    }
    return null;
  }

  Future<void> setFilter(ProviderType? type) async {
    state = type;
    final storage = ref.read(storageServiceProvider);
    await storage.setHomeCategory(type?.name);
  }
}
