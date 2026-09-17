import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/addons/data/addon_client.dart';
import '../../../../core/addons/data/addon_repository.dart';
import '../../../../core/addons/models/addon_manifest.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/extensions/extension_manager.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/extensions/base_provider.dart';
import '../../explore/data/explore_tmdb_provider.dart';
import '../../explore/data/explore_language_provider.dart';

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
  @override
  HomeState build() {
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

  Future<void> fetch() async {
    final activeProvider = ref.read(activeProviderProvider);

    // Fast connectivity check
    final online = await _isOnline();
    if (!online) {
      state = const HomeOffline();
      return;
    }

    try {
      final items = activeProvider == null
          ? await _fetchFallbackCatalog()
          : await activeProvider.getHome();

      if (items.isEmpty) {
        state = const HomeSuccess({});
      } else {
        state = HomeSuccess(items);
      }
    } catch (e) {
      state = HomeError(e.toString());
    }
  }

  Future<bool> _isOnline() async {
    try {
      final result = await InternetAddress.lookup(
        'dns.google',
      ).timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
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
