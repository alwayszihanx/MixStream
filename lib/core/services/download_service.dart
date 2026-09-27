import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:background_downloader/background_downloader.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:collection/collection.dart';
import 'package:permission_handler/permission_handler.dart'
    hide PermissionStatus;
import 'package:device_info_plus/device_info_plus.dart';

import '../domain/entity/multimedia_item.dart';
import '../router/app_router.dart';
import '../storage/storage_service.dart';
import '../network/dio_client_provider.dart';
import 'hls_downloader.dart';
import 'mkv_remuxer.dart';
import 'notification_service.dart';

part 'download_service.g.dart';

@Riverpod(keepAlive: true)
DownloadService downloadService(Ref ref) {
  final service = DownloadService(ref);
  // Cancel the FileDownloader stream subscription when the ProviderScope is
  // disposed (e.g. on app restart). Without this the subscription outlives the
  // scope and the next DownloadService.init() throws "Stream already listened".
  ref.onDispose(service.dispose);
  return service;
}

class DownloadProgressData {
  final String taskId;
  final double progress;
  final double networkSpeed; // MB/s
  final Duration timeRemaining;
  final int totalSize; // Bytes
  final TaskStatus status;

  /// True while a finished download is being remuxed into MKV.
  final bool converting;

  /// 0..1 progress of the MKV conversion, when [converting] is set.
  final double conversionProgress;

  /// The download finished but the MP4→MKV remux failed, so the original file
  /// was kept as-is. Surfaced in the Downloads row instead of failing silently.
  final bool conversionFailed;

  DownloadProgressData({
    required this.taskId,
    required double progress,
    required this.networkSpeed,
    required this.timeRemaining,
    required this.status,
    this.totalSize = -1,
    this.converting = false,
    this.conversionProgress = 0.0,
    this.conversionFailed = false,
  }) : progress = progress.clamp(0.0, 1.0);

  String get downloadedSizeString {
    if (totalSize <= 0) return "Calculating...";
    if (progress <= 0) return "0 MB";
    final double downloaded = (totalSize * progress) / (1024 * 1024);
    if (downloaded > 1024) {
      return "${(downloaded / 1024).toStringAsFixed(2)} GB";
    }
    return "${downloaded.toStringAsFixed(2)} MB";
  }

  String get totalSizeString {
    if (totalSize <= 0) return "Unknown";
    final double total = totalSize / (1024 * 1024);
    if (total > 1024) return "${(total / 1024).toStringAsFixed(2)} GB";
    return "${total.toStringAsFixed(2)} MB";
  }

  String get speedString {
    if (status == TaskStatus.paused) return "Paused";
    if (progress >= 1.0) return "Done";
    if (networkSpeed < 0) return "Calculating...";
    if (networkSpeed == 0) return "0 MB/s";

    if (networkSpeed < 1.0) {
      return "${(networkSpeed * 1024).toStringAsFixed(2)} KB/s";
    }
    return "${networkSpeed.toStringAsFixed(2)} MB/s";
  }

  String get timeRemainingString {
    if (status == TaskStatus.paused) return "---";
    if (progress >= 1.0) return "Finished";
    if (timeRemaining.inSeconds <= 0) return "Calculating...";
    if (timeRemaining.inHours > 0) {
      return "${timeRemaining.inHours}h ${timeRemaining.inMinutes % 60}m remaining";
    }
    if (timeRemaining.inMinutes > 0) {
      return "${timeRemaining.inMinutes}m ${timeRemaining.inSeconds % 60}s remaining";
    }
    return "${timeRemaining.inSeconds}s remaining";
  }
}

@Riverpod(keepAlive: true)
class DownloadProgressNotifier extends _$DownloadProgressNotifier {
  @override
  Map<String, DownloadProgressData> build() => {};

  void update(String url, DownloadProgressData data) {
    state = {...state, url: data};
  }

  void remove(String url) {
    state = {...state}..remove(url);
  }
}

@Riverpod(keepAlive: true)
class ActiveDownloadsNotifier extends _$ActiveDownloadsNotifier {
  @override
  Set<String> build() => {};

  void add(String url) => state = {...state, url};
  void remove(String url) => state = {...state}..remove(url);
}

class DownloadService {
  // FileDownloader().updates is a single-subscription stream that rejects
  // re-subscription even after cancel. Subscribe once as a static bridge so
  // each DownloadService instance can listen via the broadcast proxy instead.
  static StreamSubscription<TaskUpdate>? _fdSubscription;
  static final _sharedEvents = StreamController<TaskUpdate>.broadcast();

  final Ref _ref;
  final Dio _dio;
  final Set<String> _cancellingUrls = {};
  final _updatesController = StreamController<TaskUpdate>.broadcast();
  StreamSubscription<TaskUpdate>? _updatesSubscription;
  bool _isInitialized = false;

  DownloadService(this._ref) : _dio = _ref.read(dioClientProvider);

  Stream<TaskUpdate> get updates => _updatesController.stream;

  void dispose() {
    _updatesSubscription?.cancel();
    _updatesController.close();
    // Do NOT cancel _fdSubscription — it matches FileDownloader()'s singleton
    // lifetime and cannot be re-subscribed after cancellation.
  }

  Future<void> init() async {
    if (_isInitialized) {
      if (kDebugMode) debugPrint('[DownloadService] Already initialized.');
      return;
    }
    // 1. Configure the downloader (chainable API)
    await FileDownloader()
        .configure(
          globalConfig: [(Config.requestTimeout, const Duration(seconds: 100))],
          androidConfig: [(Config.runInForeground, Config.always)],
          iOSConfig: [(Config.excludeFromCloudBackup, Config.always)],
        )
        .then((result) => debugPrint('Configuration result = $result'));

    // 2. Register callbacks and configure notifications
    final notificationConfig = TaskNotification(
      '{displayName}',
      Platform.isIOS
          ? 'Downloading...'
          : '{progress} • {networkSpeed} • {timeRemaining}',
    );

    FileDownloader()
        .registerCallbacks(
          taskNotificationTapCallback: _myNotificationTapCallback,
        )
        .configureNotification(
          running: notificationConfig,
          complete: const TaskNotification(
            '{displayName}',
            'Download finished',
          ),
          error: const TaskNotification('{displayName}', 'Download failed'),
          paused: const TaskNotification('{displayName}', 'Download paused'),
          progressBar: !Platform.isIOS,
        )
        .configureNotificationForGroup(
          'downloads',
          running: notificationConfig,
          complete: const TaskNotification(
            '{displayName}',
            'Download finished',
          ),
          error: const TaskNotification('{displayName}', 'Download failed'),
          paused: const TaskNotification('{displayName}', 'Download paused'),
          progressBar: !Platform.isIOS,
        );

    // 3. Re-check Permission status (native API)
    final status = await FileDownloader().permissions.status(
      PermissionType.notifications,
    );
    if (status != PermissionStatus.granted) {
      await FileDownloader().permissions.request(PermissionType.notifications);
    }

    // 4. Bridge FileDownloader updates into a shared broadcast stream (once),
    //    then let this instance listen to that broadcast proxy.
    _fdSubscription ??= FileDownloader().updates.listen(_sharedEvents.add);
    _updatesSubscription = _sharedEvents.stream.listen((update) {
      _updatesController.add(update);
      final trackingUrl = update.task.metaData.isNotEmpty
          ? update.task.metaData
          : update.task.url;

      if (_cancellingUrls.contains(trackingUrl)) return;

      switch (update) {
        case TaskProgressUpdate():
          final current = _ref.read(downloadProgressProvider)[trackingUrl];

          // If we already marked it as complete/failed, ignore lingering progress updates
          if (current != null &&
              (current.status == TaskStatus.complete ||
                  current.status == TaskStatus.failed)) {
            return;
          }

          final progressData = DownloadProgressData(
            taskId: update.task.taskId,
            progress: update.progress >= 0
                ? update.progress
                : (current?.progress ?? 0),
            networkSpeed: update.networkSpeed,
            timeRemaining: update.timeRemaining,
            totalSize: update.expectedFileSize > 0
                ? update.expectedFileSize
                : (current?.totalSize ?? -1),
            status: TaskStatus.running,
          );

          // Only add to active downloads if it's not finished
          if (update.progress < 1.0) {
            _ref.read(activeDownloadsProvider.notifier).add(trackingUrl);
          } else {
            // Force removal from active downloads if it's hitting 100%
            _ref.read(activeDownloadsProvider.notifier).remove(trackingUrl);
          }

          _ref
              .read(downloadProgressProvider.notifier)
              .update(trackingUrl, progressData);

        case TaskStatusUpdate():
          if (kDebugMode) {
            debugPrint(
              '[DownloadService] Status: ${update.status} for $trackingUrl',
            );
          }
          // Update status in progress map
          final current = _ref.read(downloadProgressProvider)[trackingUrl];
          if (current != null) {
            _ref
                .read(downloadProgressProvider.notifier)
                .update(
                  trackingUrl,
                  DownloadProgressData(
                    taskId: current.taskId,
                    progress: current.progress,
                    networkSpeed: update.status == TaskStatus.running
                        ? current.networkSpeed
                        : 0,
                    timeRemaining: update.status == TaskStatus.running
                        ? current.timeRemaining
                        : Duration.zero,
                    totalSize: current.totalSize,
                    status: update.status,
                  ),
                );
          }
          unawaited(_handleStatusUpdate(update, trackingUrl));
      }
    });

    // 5. Catch up on any running tasks and database tracking
    await FileDownloader().trackTasks();
    await FileDownloader().start();

    // 6. Bridge Database Records to Riverpod (Persistence after restart)
    final records = await FileDownloader().database.allRecords();
    for (final record in records) {
      // Only recover paused tasks here.
      // Active/Enqueued tasks will be automatically picked up by FileDownloader().updates
      // if they are still running or re-started by trackTasks().
      if (record.status == TaskStatus.paused) {
        final trackingUrl = record.task.metaData.isNotEmpty
            ? record.task.metaData
            : record.task.url;

        _ref.read(activeDownloadsProvider.notifier).add(trackingUrl);
        _ref
            .read(downloadProgressProvider.notifier)
            .update(
              trackingUrl,
              DownloadProgressData(
                taskId: record.task.taskId,
                progress: record.progress,
                networkSpeed: 0,
                timeRemaining: Duration.zero,
                status: record.status,
                totalSize: record.expectedFileSize,
              ),
            );
      }
    }

    if (Platform.isIOS) {
      await FileDownloader().resumeFromBackground();
    }

    _isInitialized = true;
  }

  /// Process tapping on a notification
  void _myNotificationTapCallback(
    Task task,
    NotificationType notificationType,
  ) {
    if (kDebugMode) {
      debugPrint(
        '[DownloadService] Tapped $notificationType for ${task.taskId}',
      );
    }
    // Navigate to the Downloads tab (LibraryScreen)
    _ref.read(appRouterProvider).go('/library');
  }

  Future<void> _handleStatusUpdate(
    TaskStatusUpdate update,
    String trackingUrl,
  ) async {
    if (update.status == TaskStatus.complete) {
      await _finalizeCompletedDownload(update.task, trackingUrl);
    } else if (update.status == TaskStatus.failed ||
        update.status == TaskStatus.canceled) {
      _ref.read(activeDownloadsProvider.notifier).remove(trackingUrl);
      _ref.read(downloadProgressProvider.notifier).remove(trackingUrl);

      if (update.status == TaskStatus.failed) {
        // Show system notification for download failure
        _sendDownloadErrorNotification(update.task);
      }

      if (update.status == TaskStatus.canceled) {
        // Cleanup database and metadata for cancelled tasks
        FileDownloader().database.deleteRecordWithId(update.task.taskId);
        _ref
            .read(storageServiceProvider)
            .removeDownloadMetadata(update.task.taskId);
      }
    }
  }

  /// A finished download is remuxed into a genuine MKV before the "finished"
  /// notification is fired, so the user never gets a file that is about to be
  /// replaced. Conversion failure keeps the original file and is non-fatal.
  Future<void> _finalizeCompletedDownload(Task task, String trackingUrl) async {
    // Keep the row visible while the file is being converted.
    final current = _ref.read(downloadProgressProvider)[trackingUrl];
    if (current != null) {
      _setConverting(trackingUrl, current, 0);
    }

    // Convert MP4 → MKV in a background isolate (pure Dart, no FFmpeg), behind
    // a small queue. A batch can finish many files at once, and one isolate per
    // completion spikes memory and competes with the remaining downloads for
    // disk I/O.
    var failed = false;
    try {
      final filePath = await _taskFilePath(task);
      if (filePath != null && await File(filePath).exists()) {
        final result = await _enqueueRemux(
          filePath,
          onProgress: current == null
              ? null
              : (p) => _setConverting(trackingUrl, current, p),
        );
        if (!result.success) {
          failed = true;
          if (kDebugMode) {
            debugPrint('[DownloadService] MKV conversion failed: ${result.error}');
          }
        }
      }
    } catch (e) {
      failed = true;
      if (kDebugMode) {
        debugPrint('[DownloadService] MKV conversion error: $e');
      }
    }

    _ref.read(activeDownloadsProvider.notifier).remove(trackingUrl);
    if (failed) {
      // Keep the row so the user can see why the file is still an MP4.
      _ref.read(downloadProgressProvider.notifier).update(
        trackingUrl,
        DownloadProgressData(
          taskId: task.taskId,
          progress: 1.0,
          networkSpeed: 0,
          timeRemaining: Duration.zero,
          totalSize: current?.totalSize ?? 0,
          status: TaskStatus.complete,
          converting: false,
          conversionFailed: true,
        ),
      );
    } else {
      _ref.read(downloadProgressProvider.notifier).remove(trackingUrl);
    }
    // The remux may have replaced the .mp4 with a .mkv, so cached paths for
    // this item/episode (and any sibling that shared the scan) are stale.
    invalidateDownloadedFiles();

    // Show system notification for download complete
    _sendDownloadCompleteNotification(task);
  }

  void _setConverting(
    String trackingUrl,
    DownloadProgressData current,
    double fraction,
  ) {
    _ref
        .read(downloadProgressProvider.notifier)
        .update(
          trackingUrl,
          DownloadProgressData(
            taskId: current.taskId,
            progress: 1.0,
            networkSpeed: 0,
            timeRemaining: Duration.zero,
            totalSize: current.totalSize,
            status: TaskStatus.running,
            converting: true,
            conversionProgress: fraction.clamp(0.0, 1.0),
          ),
        );
  }

  /// Bounded queue for MKV conversions. Two at a time is enough to keep a
  /// second core busy while leaving headroom for active downloads.
  final List<_RemuxJob> _remuxQueue = [];
  int _remuxActive = 0;
  static const int _maxConcurrentRemuxes = 2;

  Future<RemuxResult> _enqueueRemux(
    String filePath, {
    void Function(double)? onProgress,
  }) {
    final job = _RemuxJob(filePath, onProgress);
    _remuxQueue.add(job);
    _drainRemuxQueue();
    return job.completer.future;
  }

  void _drainRemuxQueue() {
    while (_remuxActive < _maxConcurrentRemuxes && _remuxQueue.isNotEmpty) {
      final job = _remuxQueue.removeAt(0);
      _remuxActive++;
      unawaited(
        _runRemuxJob(job).whenComplete(() {
          _remuxActive--;
          _drainRemuxQueue();
        }),
      );
    }
  }

  Future<void> _runRemuxJob(_RemuxJob job) async {
    try {
      if (job.onProgress == null) {
        // No progress UI attached: `compute` is cheaper than a manual isolate.
        job.completer.complete(
          await compute(remuxDownloadedVideoToMkv, job.path),
        );
        return;
      }

      // `compute` cannot forward a progress callback, so run the remux in a
      // hand-spawned isolate and stream progress back over a port.
      final progressPort = ReceivePort();
      final replyPort = ReceivePort();
      final progressSub = progressPort.listen((msg) {
        if (msg is double) job.onProgress!(msg);
      });

      await Isolate.spawn(
        _remuxIsolateEntry,
        _RemuxRequest(job.path, progressPort.sendPort, replyPort.sendPort),
      );

      final result = await replyPort.first as RemuxResult;
      await progressSub.cancel();
      progressPort.close();
      replyPort.close();
      job.completer.complete(result);
    } catch (e, st) {
      job.completer.completeError(e, st);
    }
  }

  /// Whether [url] points at an HLS playlist.
  static bool _isHlsUrl(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    return path.endsWith('.m3u8') || path.endsWith('.m3u');
  }

  /// Downloads an HLS stream and writes it as a genuine `.mkv`.
  ///
  /// Runs on a background isolate (the demux/mux is CPU bound), reports
  /// progress through the same map the UI already watches, and is a no-op if a
  /// file already exists at the target.
  Future<bool> _startHlsDownload({
    required String url,
    required String filename,
    required String directory,
    required MultimediaItem item,
    Episode? episode,
    String? trackingUrl,
    Map<String, String>? headers,
  }) async {
    final key = trackingUrl ?? url;
    final saveDir = await getDownloadPath(item, episode: episode);
    final targetPath = p.join(saveDir, '$filename.mkv');
    if (await File(targetPath).exists()) {
      if (kDebugMode) debugPrint('[DownloadService] HLS already downloaded');
      return false;
    }
    final taskId = 'hls:${key.hashCode.abs()}';

    _ref.read(activeDownloadsProvider.notifier).add(key);
    _ref
        .read(downloadProgressProvider.notifier)
        .update(
          key,
          DownloadProgressData(
            taskId: taskId,
            progress: 0,
            networkSpeed: 0,
            timeRemaining: Duration.zero,
            status: TaskStatus.running,
          ),
        );

    try {
      await requestIgnoreBatteryOptimizations();
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        if (info.version.sdkInt >= 30) {
          if (!await Permission.manageExternalStorage.isGranted) {
            await Permission.manageExternalStorage.request();
          }
        } else if (!await Permission.storage.isGranted) {
          await Permission.storage.request();
        }
      }
      await Directory(saveDir).create(recursive: true);

      final outPath = await compute(_hlsToMkvEntry, _HlsRequest(
        url: url,
        outputPath: targetPath,
        headers: headers,
      ));

      final file = File(outPath);
      if (!await file.exists()) {
        throw StateError('HLS download produced no file');
      }

      // Persist metadata exactly like a normal download so the item shows up
      // in the Downloads tab and can be played offline.
      await _ref
          .read(storageServiceProvider)
          .saveDownloadMetadata(taskId, item, episode: episode);

      _ref.read(downloadProgressProvider.notifier).update(
        key,
        DownloadProgressData(
          taskId: taskId,
          progress: 1.0,
          networkSpeed: 0,
          timeRemaining: Duration.zero,
          totalSize: await file.length(),
          status: TaskStatus.complete,
        ),
      );
      _ref.read(activeDownloadsProvider.notifier).remove(key);
      invalidateDownloadedFiles();

      if (kDebugMode) {
        debugPrint('[DownloadService] HLS saved to $outPath');
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[DownloadService] HLS download failed: $e');
      _ref.read(activeDownloadsProvider.notifier).remove(key);
      _ref.read(downloadProgressProvider.notifier).remove(key);
      return false;
    }
  }

  Future<String?> _taskFilePath(Task task) async {
    try {
      final filename = task.filename;
      final directory = task.directory;
      if (Platform.isIOS) {
        final docs = await getApplicationDocumentsDirectory();
        return p.join(docs.path, directory, filename);
      }
      // Android / desktop: BaseDirectory.root + absolute directory.
      return p.join(directory, filename);
    } catch (_) {
      return null;
    }
  }

  Future<void> _sendDownloadCompleteNotification(Task task) async {
    try {
      final storage = _ref.read(storageServiceProvider);
      final metadata = await storage.getDownloadMetadata(task.taskId);
      final title = metadata?['item'] != null
          ? (metadata!['item'] as Map)['title']?.toString() ?? 'Download'
          : task.displayName;
      final filePath = task.filename;
      await _ref.read(notificationServiceProvider).showDownloadComplete(
            title,
            filePath,
          );
    } catch (_) {
      // Non-critical — don't crash if notification fails
    }
  }

  Future<void> _sendDownloadErrorNotification(Task task) async {
    try {
      final storage = _ref.read(storageServiceProvider);
      final metadata = await storage.getDownloadMetadata(task.taskId);
      final title = metadata?['item'] != null
          ? (metadata!['item'] as Map)['title']?.toString() ?? 'Download'
          : task.displayName;
      await _ref.read(notificationServiceProvider).showDownloadError(
            title,
            'The download encountered an error. Tap to retry.',
          );
    } catch (_) {
      // Non-critical
    }
  }

  Future<void> cancelDownload(String taskId, String trackingUrl) async {
    _cancellingUrls.add(trackingUrl);
    try {
      await FileDownloader().cancelTasksWithIds([taskId]);
      _ref.read(activeDownloadsProvider.notifier).remove(trackingUrl);
      _ref.read(downloadProgressProvider.notifier).remove(trackingUrl);

      // Proactive cleanup
      await FileDownloader().database.deleteRecordWithId(taskId);
      await _ref.read(storageServiceProvider).removeDownloadMetadata(taskId);
    } finally {
      // Small delay to let final updates clear
      Future.delayed(const Duration(milliseconds: 500), () {
        _cancellingUrls.remove(trackingUrl);
      });
    }
  }

  Future<void> pauseDownload(String taskId) async {
    final task = await FileDownloader().taskForId(taskId);
    if (task is DownloadTask) {
      await FileDownloader().pause(task);
    }
  }

  Future<void> resumeDownload(String taskId) async {
    final task = await FileDownloader().taskForId(taskId);
    if (task is DownloadTask) {
      await FileDownloader().resume(task);
    }
  }

  Future<DownloadMetadata?> getMetadata(
    String url, {
    Map<String, String>? headers,
  }) async {
    try {
      // 1. Try HEAD request first
      int? size;
      String? mimeType;

      try {
        final response = await _dio
            .head<dynamic>(
              url,
              options: Options(headers: headers, followRedirects: true),
            )
            .timeout(const Duration(seconds: 10));

        final contentLength = response.headers.value('content-length');
        if (contentLength != null) {
          size = int.tryParse(contentLength);
        }
        mimeType = response.headers.value('content-type');
      } catch (e) {
        // HEAD failed, will try GET fallback
      }

      // 2. Fallback to GET with Range if size unknown
      if (size == null) {
        try {
          final getResponse = await _dio
              .get<dynamic>(
                url,
                options: Options(
                  headers: {...?headers, 'Range': 'bytes=0-0'},
                  followRedirects: true,
                ),
              )
              .timeout(const Duration(seconds: 10));

          final rangeContentLength = getResponse.headers.value('content-range');
          if (rangeContentLength != null) {
            final totalSize = rangeContentLength.split('/').last;
            size = int.tryParse(totalSize);
          }
          mimeType ??= getResponse.headers.value('content-type');
        } catch (e) {
          // GET fallback failed
        }
      }

      return DownloadMetadata(size: size, mimeType: mimeType);
    } catch (e) {
      return null;
    }
  }

  Future<bool> startDownload({
    required String url,
    required String filename,
    required String directory, // Relative for mobile/mac, absolute for others
    required MultimediaItem item,
    Episode? episode,
    String? trackingUrl,
    Map<String, String>? headers,
  }) async {
    if (kDebugMode) {
      debugPrint('[DownloadService] startDownload called');
      debugPrint('[DownloadService] - URL: $url');
      debugPrint('[DownloadService] - Tracking URL: $trackingUrl');
      debugPrint('[DownloadService] - Filename: $filename');
      debugPrint('[DownloadService] - Directory: $directory');
    }

    // HLS is a playlist, not a file, so background_downloader cannot queue it.
    // Fetch the segments and build a real MKV instead.
    if (_isHlsUrl(url)) {
      return _startHlsDownload(
        url: url,
        filename: filename,
        directory: directory,
        item: item,
        episode: episode,
        trackingUrl: trackingUrl,
        headers: headers,
      );
    }

    // Industry Standard: Ask for battery optimization when a real download starts
    await requestIgnoreBatteryOptimizations();

    // Request permission on Android (Version Aware)
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 30) {
        // For Android 11+, request MANAGE_EXTERNAL_STORAGE to allow native C++ players (media_kit)
        // to bypass FUSE directory depth limits for deeply nested series folders
        final status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
          await Permission.manageExternalStorage.request();
        }
      } else {
        // For Android 10 and below, request standard storage permission
        await Permission.storage.request();
      }
    }

    final isAndroid = Platform.isAndroid;
    final isIOS = Platform.isIOS;

    // Prevention: Check if task is ALREADY running (using database for robustness)
    final records = await FileDownloader().database.allRecords();
    final existingRecord = records.firstWhereOrNull(
      (r) =>
          (r.status == TaskStatus.enqueued ||
              r.status == TaskStatus.running ||
              r.status == TaskStatus.paused) &&
          (r.task.metaData.isNotEmpty ? r.task.metaData : r.task.url) ==
              (trackingUrl ?? url),
    );

    if (existingRecord != null) {
      if (kDebugMode) {
        debugPrint(
          '[DownloadService] Task already exists in database with status: ${existingRecord.status}',
        );
      }

      // If it was paused, resume it!
      if (existingRecord.status == TaskStatus.paused) {
        if (kDebugMode) {
          debugPrint('[DownloadService] Auto-resuming paused task.');
        }
        if (existingRecord.task is DownloadTask) {
          await FileDownloader().resume(existingRecord.task as DownloadTask);
        }
      }

      _ref.read(activeDownloadsProvider.notifier).add(trackingUrl ?? url);
      return true;
    }

    // Path Logic:
    // Android/Desktop: use BaseDirectory.root with absolute path.
    // iOS: use BaseDirectory.applicationDocuments with relative path for sandbox safety.
    BaseDirectory baseDir;
    String taskDirectory;

    if (isIOS) {
      baseDir = BaseDirectory.applicationDocuments;
      // On iOS, 'directory' (from getDownloadPath(absolute: false)) is relative: "MixStream/Title"
      taskDirectory = directory;
    } else {
      // Android, Windows, macOS, Linux: use absolute paths with BaseDirectory.root
      baseDir = BaseDirectory.root;
      if (isAndroid) {
        taskDirectory = p.join(await _getPublicDownloadsPath(), directory);
      } else {
        // Desktop: directory is already absolute (e.g. /Users/akash/Downloads/MixStream/Title)
        taskDirectory = directory;
      }
    }

    final task = DownloadTask(
      url: url,
      filename: filename,
      displayName: filename,
      baseDirectory: baseDir,
      directory: taskDirectory,
      headers: headers ?? {},
      updates: Updates.statusAndProgress,
      retries: 3, // Align with example
      allowPause: true,
      metaData: trackingUrl ?? url,
    );

    if (kDebugMode) debugPrint('[DownloadService] Enqueuing task...');

    // Create the directory if it doesn't exist
    final String fullDirPath;
    if (isIOS) {
      final docsDir = await getApplicationDocumentsDirectory();
      fullDirPath = p.join(docsDir.path, taskDirectory);
    } else {
      // Android/Desktop: taskDirectory is already absolute
      fullDirPath = taskDirectory;
    }

    final dir = Directory(fullDirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final success = await FileDownloader().enqueue(task);
    if (kDebugMode) debugPrint('[DownloadService] Enqueue result: $success');

    if (success) {
      _ref.read(activeDownloadsProvider.notifier).add(trackingUrl ?? url);
      // Save metadata for offline support
      await _ref
          .read(storageServiceProvider)
          .saveDownloadMetadata(task.taskId, item, episode: episode);
    }
    return success;
  }

  Future<String> getDownloadPath(
    MultimediaItem? item, {
    Episode? episode,
    bool absolute = false,
  }) async {
    final dir =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final sanitizedTitle =
        item?.title.replaceAll(RegExp(r'[^\w\s-]'), '').trim() ?? "Unknown";

    String path;
    final publicDir = await _getPublicDownloadsPath();

    if (Platform.isAndroid || Platform.isIOS) {
      path = p.join("MixStream", sanitizedTitle);
      if (absolute) {
        path = p.join(publicDir, path);
      }
    } else {
      path = p.join(dir.path, "MixStream", sanitizedTitle);
    }

    // Add Season subdirectory if it's a series and we have an episode
    if (item != null &&
        episode != null &&
        item.contentType != MultimediaContentType.movie) {
      // Logic: If there's more than one season in the details, use subdirectories
      final seasonCount =
          item.episodes?.map((e) => e.season).toSet().length ?? 0;
      if (seasonCount > 1) {
        path = p.join(path, "Season ${episode.season}");
      }
    }

    return path;
  }

  /// Resolved download paths, keyed by `directory\0baseName`.
  ///
  /// [getDownloadedFile] runs for every visible download row and every episode
  /// card, and each call used to cost up to four `exists()` syscalls. Results
  /// are cached and invalidated whenever a file is written, remuxed or
  /// deleted. Negative results are cached too, so a missing file is not
  /// re-probed on every rebuild.
  final Map<String, File?> _downloadedFileCache = {};
  static const int _maxDownloadedFileCacheEntries = 600;

  static String _downloadedFileCacheKey(String directory, String baseName) =>
      '$directory\u0000$baseName';

  void _cacheDownloadedFile(String key, File? file) {
    if (_downloadedFileCache.length >= _maxDownloadedFileCacheEntries) {
      _downloadedFileCache.clear();
    }
    _downloadedFileCache[key] = file;
  }

  /// Drops every cached lookup. Called after any write/remux/delete so the
  /// next check hits the disk.
  void invalidateDownloadedFiles() => _downloadedFileCache.clear();

  /// The `S<season>-E<episode>` prefix an episode is saved under.
  static String episodeBaseName(Episode episode) {
    final name = episode.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    return 'S${episode.season}-E${episode.episode} $name';
  }

  /// Stable per-episode key. TMDB/Nuvio episodes have an empty [Episode.url],
  /// so the season/episode numbers are the only dependable identity.
  static String episodeDownloadKey(Episode episode) =>
      'S${episode.season}-E${episode.episode}';

  Future<File?> getDownloadedFile(
    MultimediaItem item, {
    Episode? episode,
  }) async {
    final directoryPath = await getDownloadPath(
      item,
      episode: episode,
      absolute: true,
    );
    final directory = Directory(directoryPath);
    if (!await directory.exists()) return null;

    final sanitizedTitle = item.title
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim();
    final String baseName;
    if (episode != null && item.contentType != MultimediaContentType.movie) {
      baseName = episodeBaseName(episode);
    } else {
      baseName = sanitizedTitle;
    }

    final key = _downloadedFileCacheKey(directoryPath, baseName);
    if (_downloadedFileCache.containsKey(key)) {
      return _downloadedFileCache[key];
    }

    // MKV first: a completed download is remuxed, so the converted file is the
    // one we want to hand back.
    const extensions = ['.mkv', '.mp4', '.webm', '.avi'];
    for (final ext in extensions) {
      final file = File(p.join(directoryPath, '$baseName$ext'));
      if (await file.exists()) {
        _cacheDownloadedFile(key, file);
        return file;
      }
    }

    _cacheDownloadedFile(key, null);
    return null;
  }

  /// Which of [episodes] already have a file on disk.
  ///
  /// Lists the season directory once and matches the `S<season>-E<episode>`
  /// prefix, so this costs one directory read instead of four `exists()` calls
  /// per episode. Returns keys in [episodeDownloadKey] form (`S1-E2`).
  Future<Set<String>> existingEpisodeKeys(
    MultimediaItem item,
    List<Episode> episodes,
  ) async {
    final found = <String>{};
    if (episodes.isEmpty) return found;

    final directoryPath = await getDownloadPath(
      item,
      episode: episodes.first,
      absolute: true,
    );

    final List<String> names;
    try {
      final dir = Directory(directoryPath);
      if (!await dir.exists()) return found;
      names = await dir
          .list(followLinks: false)
          .where((e) => e is File)
          .map((e) => e.uri.pathSegments.isEmpty ? '' : e.uri.pathSegments.last)
          .toList();
    } catch (_) {
      return found;
    }

    final pattern = RegExp(r'^S(\d+)-E(\d+)(?:\s|$)');
    final byKey = <String, String>{};
    for (final n in names) {
      final m = pattern.firstMatch(n);
      if (m != null) byKey['S${m.group(1)}-E${m.group(2)}'] = n;
    }

    for (final ep in episodes) {
      final key = episodeDownloadKey(ep);
      final name = byKey[key];
      if (name == null) continue;
      found.add(key);
      _cacheDownloadedFile(
        _downloadedFileCacheKey(directoryPath, episodeBaseName(ep)),
        File(p.join(directoryPath, name)),
      );
    }
    return found;
  }

  // Check if battery optimizations are ignored
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    return await Permission.ignoreBatteryOptimizations.isGranted;
  }

  // Request user to disable battery optimizations for persistent downloads
  Future<void> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return;

    final status = await Permission.ignoreBatteryOptimizations.status;
    if (!status.isGranted) {
      if (kDebugMode) {
        debugPrint('[DownloadService] Requesting ignore battery optimizations');
      }
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  Future<bool> deleteDownloadedFile(File file) async {
    invalidateDownloadedFiles();
    try {
      if (await file.exists()) {
        final parentDir = file.parent;
        await file.delete();
        // Recursively cleanup empty parent folders
        await _deleteEmptyParentDirectories(parentDir);
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DownloadService] Error deleting file: $e');
      }
    }
    return false;
  }

  Future<void> _deleteEmptyParentDirectories(Directory directory) async {
    try {
      // 1. Safety check: Only delete if it's within a 'MixStream' folder
      if (!directory.path.contains('MixStream')) return;

      // 2. Stop at the main 'MixStream' root to avoid deleting the base app directory
      if (directory.path.endsWith('MixStream') ||
          directory.path.endsWith('MixStream/')) {
        return;
      }

      if (await directory.exists()) {
        // 3. Get non-hidden entities
        final List<FileSystemEntity> entities = await directory
            .list()
            .where(
              (entity) => !entity.path
                  .split(Platform.pathSeparator)
                  .last
                  .startsWith('.'),
            )
            .toList();

        if (entities.isEmpty) {
          await directory.delete();
          // 4. Recurse to parent
          await _deleteEmptyParentDirectories(directory.parent);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DownloadService] Error deleting empty folder: $e');
      }
    }
  }

  Future<String> _getPublicDownloadsPath() async {
    if (Platform.isAndroid) {
      return "/storage/emulated/0/Download";
    }
    if (Platform.isIOS) {
      final dir = await getApplicationDocumentsDirectory();
      return dir.path;
    }
    final dir =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    return dir.path;
  }
}

class DownloadMetadata {
  final int? size;
  final String? mimeType;

  DownloadMetadata({this.size, this.mimeType});

  String get sizeString {
    if (size == null) return "Unknown size";
    final double mb = size! / (1024 * 1024);
    if (mb > 1024) {
      return "${(mb / 1024).toStringAsFixed(2)} GB";
    }
    return "${mb.toStringAsFixed(2)} MB";
  }
}

/// One queued MP4→MKV conversion.
class _RemuxJob {
  final String path;
  final void Function(double)? onProgress;
  final Completer<RemuxResult> completer = Completer<RemuxResult>();

  _RemuxJob(this.path, this.onProgress);
}

/// Message handed to the remux isolate so it can report progress and return a
/// result. Kept to primitives so it is safely sendable.
class _RemuxRequest {
  final String path;
  final SendPort progressPort;
  final SendPort replyPort;

  const _RemuxRequest(this.path, this.progressPort, this.replyPort);
}

/// Isolate entry point for a progress-reporting remux.
void _remuxIsolateEntry(_RemuxRequest request) {
  remuxDownloadedVideoToMkv(
    request.path,
    onProgress: request.progressPort.send,
  ).then(
    request.replyPort.send,
    onError: (Object e) => request.replyPort.send(RemuxResult.fail('$e')),
  );
}

/// Sendable parameters for the HLS→MKV isolate.
class _HlsRequest {
  final String url;
  final String outputPath;
  final Map<String, String>? headers;
  const _HlsRequest({
    required this.url,
    required this.outputPath,
    this.headers,
  });
}

/// Isolate entry point: builds the MKV and returns its path.
Future<String> _hlsToMkvEntry(_HlsRequest request) async {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 60),
      followRedirects: true,
    ),
  );
  final file = await HlsDownloader(dio).downloadToMkv(
    request.url,
    request.outputPath,
    headers: request.headers,
  );
  return file.path;
}
