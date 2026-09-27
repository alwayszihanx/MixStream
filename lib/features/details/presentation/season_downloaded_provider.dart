import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/domain/entity/multimedia_item.dart';
import '../../../core/services/download_service.dart';
import 'details_controller.dart';

part 'season_downloaded_provider.g.dart';

/// How many of a season's episodes already have a file on disk.
class SeasonDownloadedCount {
  const SeasonDownloadedCount({
    required this.count,
    required this.total,
    required this.keys,
  });

  final int count;
  final int total;

  /// `S1-E2` keys, so callers can skip already-downloaded episodes.
  final Set<String> keys;

  double get fraction => total == 0 ? 0 : count / total;
}

/// Downloads the season's file listing once per season/filter change and
/// exposes the result to the details header and the batch downloader.
///
/// This deliberately replaces N × 4 `exists()` probes with a single directory
/// read, which is what makes it affordable to re-check as the user pages
/// through a long show.
@riverpod
class SeasonDownloadedCountNotifier extends _$SeasonDownloadedCountNotifier {
  @override
  Future<SeasonDownloadedCount> build({
    required String itemUrl,
    required MultimediaItem item,
  }) async {
    // Re-run whenever the season, dub filter or range changes, because each
    // represents a different slice of the library folder.
    final controller = ref.watch(detailsControllerProvider(itemUrl));
    final season = controller.selectedSeason;
    final dub = controller.selectedDubStatus;

    // Also re-run as the active-download set changes, so the "3 of 12
    // downloaded" badge fills in as a batch actually lands on disk.
    ref.watch(activeDownloadsProvider);

    final all = controller.seasonMap[season] ?? const <Episode>[];
    var episodes = all;
    if (dub != DubStatus.none) {
      episodes = all.where((e) => e.dubStatus == dub).toList();
    }

    if (episodes.isEmpty) {
      return SeasonDownloadedCount(count: 0, total: 0, keys: const {});
    }

    final service = ref.read(downloadServiceProvider);
    final found = await service.existingEpisodeKeys(item, episodes);
    if (!ref.mounted) {
      return SeasonDownloadedCount(
        count: found.length,
        total: episodes.length,
        keys: found,
      );
    }
    return SeasonDownloadedCount(
      count: found.length,
      total: episodes.length,
      keys: found,
    );
  }

  /// Re-checks after a batch finishes so the badge updates.
  Future<void> refresh({required String itemUrl, required MultimediaItem item}) async {
    state = AsyncData(await build(itemUrl: itemUrl, item: item));
  }
}

/// Convenience view used by the episode card to decide whether an episode is
/// already on disk without probing the filesystem per card.
@riverpod
File? episodeDownloadedFile(Ref ref, String itemUrl, Episode episode) {
  final map = ref.watch(downloadedFileIndexProvider(itemUrl));
  return map[DownloadService.episodeDownloadKey(episode)];
}

/// Per-episode downloaded files for an item, keyed by `S1-E2`.
@Riverpod(keepAlive: true)
class DownloadedFileIndex extends _$DownloadedFileIndex {
  @override
  Map<String, File> build(String itemUrl) => const {};

  Future<void> refresh(MultimediaItem item) async {
    final controller = ref.read(detailsControllerProvider(itemUrl));
    final all = controller.seasonMap.values.expand((e) => e).toList();
    if (all.isEmpty) return;

    final service = ref.read(downloadServiceProvider);
    final keys = await service.existingEpisodeKeys(item, all);
    if (!ref.mounted) return;

    final next = <String, File>{};
    final byKey = <String, Episode>{
      for (final e in all) DownloadService.episodeDownloadKey(e): e,
    };
    for (final key in keys) {
      final ep = byKey[key];
      if (ep == null) continue;
      final file = await service.getDownloadedFile(item, episode: ep);
      if (file != null) next[key] = file;
    }
    state = next;
  }

  void remove(String key) {
    if (!state.containsKey(key)) return;
    state = {...state}..remove(key);
  }
}
