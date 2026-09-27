import 'dart:async';
import 'dart:math' show min;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/domain/entity/multimedia_item.dart';
import '../../../core/extensions/extension_manager.dart';
import '../../../core/extensions/base_provider.dart';
import '../../../core/services/download_service.dart';
import '../../../core/nuvio/data/nuvio_repository.dart';
import '../../../core/nuvio/data/nuvio_stream_service.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/loading_dialog.dart';
import '../../../shared/widgets/custom_widgets.dart';
import '../../../shared/widgets/loading_indicator.dart';
import 'package:mixstream/l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_icon.dart';

part 'download_launcher.g.dart';

@Riverpod(keepAlive: true)
DownloadLauncher downloadLauncher(Ref ref) {
  return DownloadLauncher(ref);
}

class DownloadLauncher {
  final Ref _ref;

  DownloadLauncher(this._ref);

  Future<void> launch(
    BuildContext context,
    MultimediaItem item, {
    String? episodeUrl,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final resolveUrl = episodeUrl ?? item.url;
    if (resolveUrl.isEmpty) return;

    bool isCanceled = false;
    unawaited(
      LoadingDialog.show(
        context,
        message: l10n.resolving,
        onCancel: () => isCanceled = true,
      ),
    );

    try {
      // 2. Resolve streams
      final manager = _ref.read(extensionManagerProvider.notifier);
      MixStreamProvider? provider;
      if (item.provider != null) {
        try {
          final val = item.provider!;
          provider = manager.getAllProviders().firstWhere(
            (p) => p.packageName == val || p.name == val,
          );
        } catch (e) {
          if (kDebugMode) debugPrint('DownloadLauncher.launch: $e');
        }
      }
      provider ??= _ref.read(activeProviderProvider);
      if (provider == null) throw Exception('No active provider');

      final streams = await provider.loadStreams(resolveUrl);
      if (isCanceled || !context.mounted) return;

      Navigator.of(context).pop(); // Dismiss loading dialog

      if (streams.isEmpty) {
        throw Exception('No download sources found for this item.');
      }

      // 3. Show Source Picker
      _showSourcePicker(context, streams, item, resolveUrl);
    } catch (e) {
      if (!context.mounted) return;
      if (!isCanceled) Navigator.of(context).pop(); // Dismiss if still there
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorPrefix(e.toString()))));
    }
  }

  /// Downloads several episodes in one go without per-episode dialogs.
  ///
  /// Each episode's streams are resolved with the item's provider, the best
  /// candidate is picked automatically, and the download is queued straight
  /// away. Failures are collected and reported as a single summary at the end.
  Future<void> downloadEpisodes(
    BuildContext context,
    MultimediaItem item,
    List<Episode> episodes, {
    /// Drop episodes that already have a file, so re-running a batch doesn't
    /// re-download (and re-remux) the same data.
    bool skipExisting = false,
  }) async {
    if (episodes.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;

    final targets = skipExisting
        ? await _withoutAlreadyDownloaded(item, episodes)
        : episodes;
    if (targets.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.batchDownloadNoneStarted)),
        );
      }
      return;
    }

    // A MixStream provider is the preferred resolver, but it is optional:
    // TMDB/Nuvio items have no provider and their episodes carry no URL, so
    // the Nuvio scrapers are used instead (see [_resolveEpisodeStreams]).
    final manager = _ref.read(extensionManagerProvider.notifier);
    MixStreamProvider? provider;
    if (item.provider != null) {
      try {
        final val = item.provider!;
        provider = manager.getAllProviders().firstWhere(
          (p) => p.packageName == val || p.name == val,
        );
      } catch (e) {
        if (kDebugMode) debugPrint('DownloadLauncher.downloadEpisodes: $e');
      }
    }
    provider ??= _ref.read(activeProviderProvider);

    if (provider == null && !_hasNuvioScrapers()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorPrefix('No active provider'))),
      );
      return;
    }

    final downloadService = _ref.read(downloadServiceProvider);
    bool canceled = false;
    var processed = 0;

    unawaited(
      LoadingDialog.show(
        context,
        message: l10n.preparingDownloads,
        onCancel: () => canceled = true,
      ),
    );

    var started = 0;
    final failures = <String>[];

    // Ask for storage/battery permission once up front. [startDownload] also
    // checks, but three workers hitting it simultaneously could stack three
    // system dialogs.
    try {
      await downloadService.requestIgnoreBatteryOptimizations();
    } catch (_) {}

    // Episodes are resolved concurrently: a batch of 20 used to be 20 serial
    // scraper round-trips, which dominated the wait. A small pool keeps the
    // device and the scrapers from being hammered while still cutting the
    // elapsed time several-fold.
    const int maxParallel = 3;
    final queue = List<Episode>.from(targets);
    var cursor = 0;

    Future<void> worker() async {
      while (true) {
        if (canceled || !context.mounted) return;
        final index = cursor++;
        if (index >= queue.length) return;
        final episode = queue[index];
        processed++;

        try {
          final streams = await _resolveEpisodeStreams(
            item: item,
            episode: episode,
            provider: provider,
          );
          if (canceled || !context.mounted) return;

          // Nuvio scrapers frequently hand back extension-less direct links
          // (`.../stream/9f2c1`), so candidates are probed and accepted on
          // their content type rather than their file name. The first link that
          // is a real, sized video file wins; the rest are discarded.
          final candidates = _rankStreams(streams);
          StreamResult? stream;
          DownloadMetadata? metadata;

          for (final candidate in candidates) {
            if (canceled || !context.mounted) return;
            final probe = await downloadService
                .getMetadata(candidate.url, headers: candidate.headers)
                .timeout(const Duration(seconds: 15), onTimeout: () => null);
            if (probe != null &&
                probe.size != null &&
                _isDirectVideo(probe.mimeType, candidate.url)) {
              stream = candidate;
              metadata = probe;
              break;
            }
          }

          if (canceled || !context.mounted) return;
          if (stream == null || metadata == null) {
            failures.add(_labelFor(episode));
            continue;
          }

          final saveDir = await downloadService.getDownloadPath(
            item,
            episode: episode,
          );
          final extension = _getFileExtension(stream.url, metadata.mimeType);
          final sanitized = episode.name
              .replaceAll(RegExp(r'[^\w\s-]'), '')
              .trim();
          final filename =
              'S${episode.season}-E${episode.episode} $sanitized$extension';

          final ok = await downloadService.startDownload(
            url: stream.url,
            filename: filename,
            directory: saveDir,
            item: item,
            episode: episode,
            trackingUrl: _trackingIdFor(item, episode),
            headers: stream.headers,
          );
          if (ok) {
            started++;
          } else {
            failures.add(_labelFor(episode));
          }
        } catch (e) {
          if (kDebugMode) debugPrint('DownloadLauncher.downloadEpisodes: $e');
          failures.add(_labelFor(episode));
        }
      }
    }

    final workers = min(maxParallel, queue.length);
    await Future.wait([for (var i = 0; i < workers; i++) worker()]);

    if (!context.mounted) return;
    Navigator.of(context).pop(); // Dismiss loading dialog

    if (canceled) return;

    final messenger = ScaffoldMessenger.of(context);
    if (started == 0) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.batchDownloadNoneStarted)),
      );
    } else {
      final summary = l10n.batchDownloadSummary(started, targets.length);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            failures.isEmpty
                ? summary
                : '$summary\n${failures.join(', ')}',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
    if (kDebugMode && processed < episodes.length) {
      debugPrint(
        '[DownloadLauncher] downloadEpisodes stopped early: $processed/${episodes.length}',
      );
    }
  }

  /// Whether any Nuvio scraper is installed, enabled and usable on this
  /// platform. Nuvio is not a [MixStreamProvider], so it is detected through
  /// its own repository state.
  bool _hasNuvioScrapers() {
    try {
      return _ref.read(nuvioRepositoryProvider).activeScrapers.isNotEmpty;
    } catch (e) {
      if (kDebugMode) debugPrint('DownloadLauncher._hasNuvioScrapers: $e');
      return false;
    }
  }

  /// Resolves playable sources for one episode.
  ///
  /// Order of preference:
  ///  1. The item's MixStream provider, when the episode actually has a URL.
  ///  2. The Nuvio scrapers, which key off the parent TMDB id plus the
  ///     season/episode numbers — this is the only path for TMDB/Nuvio items,
  ///     whose episodes typically carry an empty URL.
  Future<List<StreamResult>> _resolveEpisodeStreams({
    required MultimediaItem item,
    required Episode episode,
    required MixStreamProvider? provider,
  }) async {
    final episodeUrl = episode.url.trim();

    if (provider != null && episodeUrl.isNotEmpty) {
      try {
        final streams = await provider.loadStreams(episodeUrl);
        if (streams.isNotEmpty) return streams;
      } catch (e) {
        if (kDebugMode) debugPrint('DownloadLauncher provider resolve: $e');
      }
    }

    // Nuvio path.
    final tmdbId = (item.tmdbId ?? 0).toString().trim();
    if (tmdbId.isEmpty || tmdbId == '0') return const [];
    if (!_hasNuvioScrapers()) return const [];

    final collected = <StreamResult>[];
    final sub = _ref
        .read(nuvioStreamServiceProvider)
        .resolve(
          tmdbId: tmdbId,
          mediaType: 'tv',
          season: episode.season,
          episode: episode.episode,
        )
        .listen((progress) {
          for (final s in progress.streams) {
            collected
              ..removeWhere((existing) => existing.url == s.url)
              ..add(s.toStreamResult());
          }
        });

    // Wait until the resolver reports it has no more scrapers to run, but
    // never block a batch forever on one slow scraper.
    await sub.asFuture<void>().timeout(
      const Duration(seconds: 45),
      onTimeout: () {},
    ).catchError((_) {});
    await sub.cancel();

    if (kDebugMode) {
      debugPrint(
        '[DownloadLauncher] Nuvio S${episode.season}E${episode.episode}: '
        '${collected.length} links',
      );
    }
    return collected;
  }

  /// Filters out episodes that already have a file, using one directory read
  /// for the whole season instead of a probe per episode.
  Future<List<Episode>> _withoutAlreadyDownloaded(
    MultimediaItem item,
    List<Episode> episodes,
  ) async {
    try {
      final existing = await _ref
          .read(downloadServiceProvider)
          .existingEpisodeKeys(item, episodes);
      if (existing.isEmpty) return episodes;
      return episodes
          .where((e) => !existing.contains(_trackingKeyOf(e)))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('DownloadLauncher skipExisting: $e');
      return episodes;
    }
  }

  static String _trackingKeyOf(Episode episode) =>
      DownloadService.episodeDownloadKey(episode);

  /// Short `S1-E2` label used in the failure summary.
  static String _labelFor(Episode episode) =>
      'S${episode.season}E${episode.episode}';

  /// Stable, non-empty identity for a download.
  ///
  /// Download progress and metadata are keyed off this. TMDB/Nuvio episodes
  /// carry an empty [Episode.url], so falling back to it would make every
  /// episode in a batch share one key and clobber each other's progress.
  String _trackingIdFor(MultimediaItem item, Episode episode) {
    final url = episode.url.trim();
    if (url.isNotEmpty) return url;
    return 'tmdb:${item.tmdbId}:S${episode.season}E${episode.episode}';
  }

  /// Orders downloadable candidates, best first.
  ///
  /// Nuvio scraper links are frequently protocol-relative (`//host/x.mp4`) or
  /// extension-less, so protocol-relative URLs are upgraded to HTTPS and
  /// magnet/torrent/HLS links are dropped — [startDownload] can only queue a
  /// plain HTTP file, so accepting one of those would silently save a
  /// manifest instead of the video. Extension hints only affect ordering;
  /// acceptance is decided later by content type.
  List<StreamResult> _rankStreams(List<StreamResult> streams) {
    const videoExts = ['.mp4', '.mkv', '.webm', '.avi', '.m4v', '.mov'];
    const rejectExts = ['.m3u8', '.mpd', '.ts', '.torrent'];

    final withVideoExt = <StreamResult>[];
    final others = <StreamResult>[];

    for (final s in streams) {
      final url = s.url.startsWith('//') ? 'https:${s.url}' : s.url;
      if (!url.startsWith('http')) continue;

      final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
      if (rejectExts.any(path.endsWith)) continue;

      final normalized = url == s.url
          ? s
          : StreamResult(
              url: url,
              source: s.source,
              providerName: s.providerName,
              headers: s.headers,
              subtitles: s.subtitles,
              drmKid: s.drmKid,
              drmKey: s.drmKey,
              licenseUrl: s.licenseUrl,
            );

      if (videoExts.any(path.endsWith)) {
        withVideoExt.add(normalized);
      } else {
        others.add(normalized);
      }
    }

    return [...withVideoExt, ...others];
  }

  /// Whether a probed link is a single downloadable video file.
  ///
  /// HLS/DASH manifests report `application/vnd.apple.mpegurl` /
  /// `application/dash+xml` and are rejected; genuine `video/*` types are
  /// accepted so extension-less scraper links still work. When the server
  /// sends no useful type, fall back to the file extension.
  bool _isDirectVideo(String? mimeType, String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    const rejectExts = ['.m3u8', '.mpd', '.ts', '.torrent'];
    if (rejectExts.any(path.endsWith)) return false;

    final mime = mimeType?.toLowerCase().trim() ?? '';
    if (mime.isNotEmpty) {
      if (mime.contains('mpegurl') || mime.contains('dash+xml')) return false;
      if (mime.startsWith('video/')) return true;
    }

    const videoExts = ['.mp4', '.mkv', '.webm', '.avi', '.m4v', '.mov'];
    return videoExts.any(path.endsWith);
  }

  void _showSourcePicker(
    BuildContext context,
    List<StreamResult> streams,
    MultimediaItem item,
    String resolveUrl,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  l10n.selectSource,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: streams.length,
                  itemBuilder: (context, index) {
                    final stream = streams[index];
                    final label = stream.source != 'Auto'
                        ? stream.source
                        : 'Source ${index + 1}';
                    final host = Uri.tryParse(stream.url)?.host ?? '';

                    return ListTile(
                      leading: const AppIcon('file_download_outlined'),
                      title: Text(label),
                      subtitle: host.isNotEmpty ? Text(host) : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        _verifyAndDownload(context, stream, item, resolveUrl);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _verifyAndDownload(
    BuildContext context,
    StreamResult stream,
    MultimediaItem item,
    String resolveUrl,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final downloadService = _ref.read(downloadServiceProvider);

    // 1. Show verification dialog
    // Use root navigator context if current context is unmounted
    final navContext = rootNavigatorKey.currentContext ?? context;

    bool isCanceled = false;
    unawaited(
      showDialog<void>(
        context: navContext,
        barrierDismissible: false, // Block UI interaction
        builder: (ctx) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLoadingIndicator(),
                  const SizedBox(height: 16),
                  Text(l10n.verifyingSourceSize),
                ],
              ),
              actions: [
                CustomButton(
                  isPrimary: false,
                  onPressed: () {
                    isCanceled = true;
                    Navigator.of(ctx).pop();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(l10n.cancel),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    final metadata = await downloadService
        .getMetadata(stream.url, headers: stream.headers)
        .timeout(const Duration(seconds: 15), onTimeout: () => null);

    if (!navContext.mounted) return;
    if (!isCanceled) {
      Navigator.of(navContext, rootNavigator: true).pop();
    } else {
      return; // Canceled, don't proceed
    }

    final finalContext = rootNavigatorKey.currentContext ?? navContext;

    if (metadata == null || metadata.size == null) {
      if (finalContext.mounted) {
        _showErrorDialog(
          finalContext,
          'This source doesn\'t support direct downloading or is currently unavailable. Please try another source.',
          stream,
          item,
          resolveUrl,
        );
      }
      return;
    }

    // 2. Show Confirmation Dialog
    if (finalContext.mounted) {
      unawaited(
        showDialog<void>(
          context: finalContext,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.confirmDownload),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.titleWithParam(item.title)),
                const SizedBox(height: 8),
                Text(l10n.sourceWithParam(stream.source)),
                const SizedBox(height: 8),
                Text(l10n.sizeWithParam(metadata.sizeString)),
                const SizedBox(height: 16),
                Text(l10n.fileSaveLocationNotification),
              ],
            ),
            actions: [
              CustomButton(
                onPressed: () => Navigator.pop(ctx),
                label: l10n.cancel,
              ),
              CustomButton(
                isPrimary: true,
                onPressed: () async {
                  Navigator.pop(ctx);

                  final episodeData = item.episodes?.firstWhereOrNull(
                    (e) => e.url == resolveUrl,
                  );
                  final saveDir = await downloadService.getDownloadPath(
                    item,
                    episode: episodeData,
                  );

                  final extension = _getFileExtension(
                    stream.url,
                    metadata.mimeType,
                  );
                  String filename;
                  if (episodeData != null &&
                      item.contentType != MultimediaContentType.movie) {
                    final sanitizedEpName = episodeData.name
                        .replaceAll(RegExp(r'[^\w\s-]'), '')
                        .trim();
                    filename =
                        "S${episodeData.season}-E${episodeData.episode} $sanitizedEpName$extension";
                  } else {
                    final sanitizedTitle = item.title
                        .replaceAll(RegExp(r'[^\w\s-]'), '')
                        .trim();
                    filename = "$sanitizedTitle$extension";
                  }

                  if (kDebugMode) {
                    debugPrint(
                      '[DownloadLauncher] Final Path: $saveDir/$filename',
                    );
                  }

                  final started = await downloadService.startDownload(
                    url: stream.url,
                    filename: filename,
                    directory: saveDir,
                    item: item,
                    episode: episodeData,
                    trackingUrl: resolveUrl,
                    headers: stream.headers,
                  );

                  if (!started && finalContext.mounted) {
                    ScaffoldMessenger.of(finalContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Failed to start download. Check storage permissions.',
                        ),
                      ),
                    );
                  }
                },
                child: Text(l10n.downloadNow),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _showErrorDialog(
    BuildContext context,
    String message,
    StreamResult stream,
    MultimediaItem item,
    String resolveUrl,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.downloadUnavailable),
        content: Text(message),
        actions: [
          CustomButton(
            onPressed: () => Navigator.pop(ctx),
            label: l10n.cancel,
          ),
          CustomButton(
            isPrimary: true,
            onPressed: () {
              Navigator.pop(ctx);
              launch(
                context,
                item,
                episodeUrl: resolveUrl,
              );
            },
            label: l10n.selectAnotherSource,
          ),
        ],
      ),
    );
  }

  String _getFileExtension(String url, String? mimeType) {
    if (mimeType != null) {
      if (mimeType.contains('video/mp4')) return '.mp4';
      if (mimeType.contains('video/x-matroska')) return '.mkv';
      if (mimeType.contains('video/webm')) return '.webm';
    }

    final uri = Uri.tryParse(url);
    if (uri != null) {
      final path = uri.path.toLowerCase();
      if (path.endsWith('.mp4')) return '.mp4';
      if (path.endsWith('.mkv')) return '.mkv';
      if (path.endsWith('.webm')) return '.webm';
      if (path.endsWith('.avi')) return '.avi';
    }

    return '.mp4'; // Default
  }
}
