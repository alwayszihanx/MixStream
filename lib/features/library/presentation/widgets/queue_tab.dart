import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixstream/core/utils/layout_constants.dart';
import '../../../../core/services/download_service.dart';
import '../downloads_provider.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/app_icon.dart';

class QueueTab extends ConsumerStatefulWidget {
  const QueueTab({super.key});

  @override
  ConsumerState<QueueTab> createState() => _QueueTabState();
}

class _QueueTabState extends ConsumerState<QueueTab>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final downloadsAsync = ref.watch(downloadsProvider);
    final activeProgress = ref.watch(downloadProgressProvider);
    final l10n = AppLocalizations.of(context)!;

    return downloadsAsync.when(
      data: (downloads) {
        // Filter to only active/paused/queued downloads
        final queueItems = downloads.where((d) =>
            d.status == TaskStatus.running ||
            d.status == TaskStatus.enqueued ||
            d.status == TaskStatus.paused ||
            d.status == TaskStatus.waitingToRetry).toList();

        if (queueItems.isEmpty) {
          return _buildEmptyState(l10n);
        }

        // Sort by timestamp (oldest first — processing order)
        queueItems.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        return Column(
          children: [
            // Queue header
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  AppIcon('queue_rounded', size: 18,
                    color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    '${queueItems.length} in queue',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  // Pause all / Resume all
                  if (queueItems.any((d) => d.status == TaskStatus.running || d.status == TaskStatus.enqueued))
                    TextButton.icon(
                      onPressed: () {
                        for (final item in queueItems) {
                          if (item.status == TaskStatus.running || item.status == TaskStatus.enqueued) {
                            ref.read(downloadsProvider.notifier).pauseDownload(item.task.taskId);
                          }
                        }
                      },
                      icon: const AppIcon('pause_rounded', size: 16),
                      label: const Text('Pause All', style: TextStyle(fontSize: 12)),
                    ),
                  if (queueItems.every((d) => d.status == TaskStatus.paused))
                    TextButton.icon(
                      onPressed: () {
                        for (final item in queueItems) {
                          ref.read(downloadsProvider.notifier).resumeDownload(item.task.taskId);
                        }
                      },
                      icon: const AppIcon('play_arrow_rounded', size: 16),
                      label: const Text('Resume All', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
            // Queue list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                itemCount: queueItems.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final download = queueItems[index];
                  final trackingUrl = download.task.metaData;
                  final progressData = activeProgress[trackingUrl];
                  final double displayProgress =
                      progressData?.progress ?? download.progress;
                  final TaskStatus displayStatus =
                      progressData?.status ?? download.status;

                  return _QueueItemTile(
                    item: download,
                    progress: displayProgress,
                    status: displayStatus,
                    progressData: progressData,
                    position: index + 1,
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (err, stack) =>
          Center(child: Text(l10n.errorPrefix(err.toString()))),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_pulseController.value * 0.08),
                child: child,
              );
            },
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: AppIcon(
                'queue_rounded',
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Queue is empty',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Active downloads will appear here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueItemTile extends ConsumerWidget {
  final DownloadItem item;
  final double progress;
  final TaskStatus status;
  final DownloadProgressData? progressData;
  final int position;

  const _QueueItemTile({
    required this.item,
    required this.progress,
    required this.status,
    this.progressData,
    required this.position,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDone = status == TaskStatus.complete;
    final isWorking = status == TaskStatus.running || status == TaskStatus.enqueued;
    final isPaused = status == TaskStatus.paused;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Position number
            Container(
              width: 36,
              decoration: BoxDecoration(
                color: isWorking
                    ? Colors.orange.withValues(alpha: 0.15)
                    : isPaused
                        ? Colors.blue.withValues(alpha: 0.15)
                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              ),
              child: Center(
                child: Text(
                  '$position',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isWorking
                        ? Colors.orange
                        : isPaused
                            ? Colors.blue
                            : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(LayoutConstants.spacingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.item.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        AppIcon(
                          isDone
                              ? 'check_circle_rounded'
                              : isPaused
                                  ? 'pause_circle_rounded'
                                  : 'cloud_download_rounded',
                          size: 14,
                          color: isDone
                              ? Colors.green
                              : isPaused
                                  ? Colors.blue
                                  : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getStatusText(status, AppLocalizations.of(context)!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDone
                                ? Colors.green
                                : isPaused
                                    ? Colors.blue
                                    : Colors.orange,
                          ),
                        ),
                        if (progressData != null && progressData!.totalSize > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${progressData!.downloadedSizeString} / ${progressData!.totalSizeString}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress > 0 ? progress : null,
                        backgroundColor: theme.dividerColor.withValues(alpha: 0.1),
                        minHeight: 3,
                        color: isPaused ? Colors.blue : theme.colorScheme.primary,
                      ),
                    ),
                    if (progressData != null && isWorking) ...[
                      const SizedBox(height: 4),
                      Text(
                        progressData!.speedString,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Actions
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isWorking)
                  IconButton(
                    icon: const AppIcon('pause_rounded'),
                    onPressed: () => ref
                        .read(downloadsProvider.notifier)
                        .pauseDownload(item.task.taskId),
                    visualDensity: VisualDensity.compact,
                  ),
                if (isPaused)
                  IconButton(
                    icon: const AppIcon('play_arrow_rounded'),
                    onPressed: () => ref
                        .read(downloadsProvider.notifier)
                        .resumeDownload(item.task.taskId),
                    visualDensity: VisualDensity.compact,
                  ),
                IconButton(
                  icon: const AppIcon('close_rounded', size: 18),
                  onPressed: () => ref
                      .read(downloadsProvider.notifier)
                      .removeDownload(item),
                  color: theme.colorScheme.error.withValues(alpha: 0.7),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(TaskStatus status, AppLocalizations l10n) {
    switch (status) {
      case TaskStatus.enqueued:
        return l10n.statusQueued;
      case TaskStatus.running:
        return l10n.statusDownloading;
      case TaskStatus.complete:
        return l10n.statusFinished;
      case TaskStatus.failed:
        return l10n.statusFailed;
      case TaskStatus.canceled:
        return l10n.statusCanceled;
      case TaskStatus.paused:
        return l10n.statusPaused;
      default:
        return l10n.statusWaiting;
    }
  }
}
