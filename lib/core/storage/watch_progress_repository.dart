import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entity/multimedia_item.dart';
import 'episode_watch_repository.dart';
import 'history_repository.dart';
import 'storage_service.dart';

final watchProgressRevisionProvider =
    NotifierProvider<WatchProgressRevision, int>(WatchProgressRevision.new);

class WatchProgressRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final watchProgressRepositoryProvider = Provider<WatchProgressRepository>((ref) {
  return WatchProgressRepository(
    ref.watch(storageServiceProvider),
    ref.watch(historyRepositoryProvider),
    ref.watch(episodeWatchRepositoryProvider),
    ref.watch(watchProgressRevisionProvider.notifier).bump,
  );
});

class WatchProgressRepository {
  WatchProgressRepository(
    this._storageService,
    this._historyRepository,
    this._episodeWatchRepository,
    this._notifyChanged,
  );

  final StorageService _storageService;
  final HistoryRepository _historyRepository;
  final EpisodeWatchRepository _episodeWatchRepository;
  final void Function() _notifyChanged;

  static const String _progressKey = 'watch_progress_v2';

  Map<String, int>? _cachedProgress;

  String _videoKey(String mainUrl, int season, int episode) {
    return '$mainUrl|s$season|e$episode';
  }

  Map<String, int> _readProgress() {
    final cached = _cachedProgress;
    if (cached != null) return cached;
    final raw = _storageService.getString(_progressKey);
    if (raw == null || raw.isEmpty) return _cachedProgress = {};
    try {
      final decoded = jsonDecode(raw) as Map;
      return _cachedProgress = decoded.map<String, int>(
        (key, value) => MapEntry(key as String, value as int),
      );
    } catch (_) {
      return _cachedProgress = {};
    }
  }

  Future<void> _persist(Map<String, int> progress) async {
    _cachedProgress = progress;
    await _storageService.setString(_progressKey, jsonEncode(progress));
    _notifyChanged();
  }

  int getPosition(String mainUrl, int season, int episode) {
    return _readProgress()[_videoKey(mainUrl, season, episode)] ?? 0;
  }

  Future<void> savePosition(
    String mainUrl,
    int season,
    int episode,
    int position,
  ) async {
    final progress = Map<String, int>.from(_readProgress());
    final key = _videoKey(mainUrl, season, episode);
    final existing = progress[key] ?? 0;
    if (position > existing) {
      progress[key] = position;
      await _persist(progress);
    }
  }

  bool isWatched(String mainUrl, int season, int episode) {
    final position = getPosition(mainUrl, season, episode);
    final duration = _historyRepository.getEpisodeDuration(
      '',
      mainUrl: mainUrl,
      season: season,
      episode: episode,
    );
    if (duration > 0 && position > 0) {
      return position / duration >= 0.90;
    }
    return _episodeWatchRepository.isWatched(mainUrl, Episode(
      name: '',
      url: '',
      season: season,
      episode: episode,
    ));
  }

  Future<void> markWatched(
    String mainUrl,
    int season,
    int episode, {
    int position = 0,
  }) async {
    final progress = Map<String, int>.from(_readProgress());
    progress[_videoKey(mainUrl, season, episode)] = position;
    await _persist(progress);
    await _episodeWatchRepository.setWatched(mainUrl, Episode(
      name: '',
      url: '',
      season: season,
      episode: episode,
    ), true);
  }

  Future<void> markUnwatched(
    String mainUrl,
    int season,
    int episode,
  ) async {
    final progress = Map<String, int>.from(_readProgress());
    progress.remove(_videoKey(mainUrl, season, episode));
    await _persist(progress);
    await _episodeWatchRepository.setWatched(mainUrl, Episode(
      name: '',
      url: '',
      season: season,
      episode: episode,
    ), false);
  }
}
