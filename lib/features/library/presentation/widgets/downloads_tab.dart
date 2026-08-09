import 'dart:async';
import 'dart:io';
import 'package:background_downloader/background_downloader.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mixstream/core/utils/image_fallbacks.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/services/download_service.dart';
import '../../../../core/utils/layout_constants.dart';
import '../../../details/presentation/playback_launcher.dart';
import '../downloads_provider.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/app_icon.dart';

enum _SortMode { newest, name, size }

class DownloadsTab extends ConsumerStatefulWidget {
  const DownloadsTab({super.key});

  @override
  ConsumerState<DownloadsTab> createState() => _DownloadsTabState();
}

class _DownloadsTabState extends ConsumerState<DownloadsTab>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  _SortMode _sortMode = _SortMode.newest;

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
        if (downloads.isEmpty) {
          return _buildEmptyState(l10n);
        }

        // Compute storage info
        final totalFiles = downloads.length;
        final completedFiles =
            downloads.where((d) => d.status == TaskStatus.complete).length;
        final activeFiles = downloads
            .where(
                (d) => d.status == TaskStatus.running || d.status == TaskStatus.enqueued)
            .length;

        // Compute total downloaded bytes from progress data
        int totalDownloadedBytes = 0;
        for (final d in downloads) {
          if (d.status == TaskStatus.complete) {
            final pd = activeProgress[d.task.metaData];
            if (pd != null && pd.totalSize > 0) {
              totalDownloadedBytes += pd.totalSize;
            }
          }
        }

        // Sort
        List<DownloadItem> sorted = List.of(downloads);
        switch (_sortMode) {
          case _SortMode.newest:
            sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            break;
          case _SortMode.name:
            sorted.sort(
                (a, b) => a.item.title.compareTo(b.item.title));
            break;
          case _SortMode.size:
            sorted.sort((a, b) {
              // Active first, then paused, then completed
              int _statusRank(TaskStatus s) {
                if (s == TaskStatus.running || s == TaskStatus.enqueued) return 0;
                if (s == TaskStatus.paused) return 1;
                return 2;
              }
              return _statusRank(a.status).compareTo(_statusRank(b.status));
            });
            break;
        }

        // Grouping logic
        final Map<String, List<DownloadItem>> grouped = {};
        final List<String> keys = [];

        for (final item in sorted) {
          final String key = item.item.tmdbId?.toString() ?? item.item.title;
          if (!grouped.containsKey(key)) {
            keys.add(key);
            grouped[key] = [];
          }
          grouped[key]!.add(item);
        }

        return Column(
          children: [
            // ── Storage Info Header ──────────────────────────────
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
                  // File count
                  _StorageInfoChip(
                    icon: 'folder_open_rounded',
                    label: '$totalFiles files',
                    sublabel: '$completedFiles done',
                  ),
                  const SizedBox(width: 12),
                  // Active downloads
                  if (activeFiles > 0)
                    _StorageInfoChip(
                      icon: 'cloud_download_rounded',
                      label: '$activeFiles active',
                      sublabel: null,
                      color: Colors.orange,
                    ),
                  if (totalDownloadedBytes > 0) ...[
                    const SizedBox(width: 12),
                    _StorageInfoChip(
                      icon: 'storage_rounded',
                      label: _formatBytes(totalDownloadedBytes),
                      sublabel: 'downloaded',
                      color: Colors.green,
                    ),
                  ],
                  const Spacer(),
                  // Sort button
                  PopupMenuButton<_SortMode>(
                    icon: AppIcon(
                      'sort_rounded',
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    tooltip: 'Sort',
                    onSelected: (mode) => setState(() => _sortMode = mode),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    itemBuilder: (context) => [
                      _sortMenuItem(
                        _SortMode.newest,
                        'Newest First',
                        'schedule_rounded',
                        _sortMode,
                      ),
                      _sortMenuItem(
                        _SortMode.name,
                        'By Name',
                        'sort_by_alpha_rounded',
                        _sortMode,
                      ),
                      _sortMenuItem(
                        _SortMode.size,
                        'By Status',
                        'pending_actions_rounded',
                        _sortMode,
                      ),
                    ],
                  ),
                  // Clear all button
                  if (downloads.isNotEmpty)
                    IconButton(
                      icon: const AppIcon('delete_sweep_rounded', size: 20),
                      tooltip: 'Clear all downloads',
                      onPressed: () => _confirmClearAll(context, ref, l10n),
                      color: Theme.of(context).colorScheme.error.withValues(alpha: 0.7),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
            // ── Download List ────────────────────────────────────
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                itemCount: keys.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final key = keys[index];
                  final groupItems = grouped[key]!;

                  if (groupItems.length == 1) {
                    final download = groupItems.first;
                    final trackingUrl = download.task.metaData;
                    final progressData = activeProgress[trackingUrl];
                    final double displayProgress =
                        progressData?.progress ?? download.progress;
                    final TaskStatus displayStatus =
                        progressData?.status ?? download.status;

                    return _DownloadItemTile(
                      item: download,
                      progress: displayProgress,
                      status: displayStatus,
                      progressData: progressData,
                    );
                  } else {
                    return _GroupedDownloadTile(
                      items: groupItems,
                      activeProgress: activeProgress,
                    );
                  }
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
                'download_for_offline_outlined',
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.noDownloadsYet,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Download content to watch offline',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<_SortMode> _sortMenuItem(
    _SortMode value,
    String label,
    String icon,
    _SortMode current,
  ) {
    return PopupMenuItem<_SortMode>(
      value: value,
      child: Row(
        children: [
          AppIcon(icon, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          if (value == current)
            const AppIcon('check_rounded', size: 16, color: Colors.green),
        ],
      ),
    );
  }

  void _confirmClearAll(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final downloads = ref.read(downloadsProvider).value ?? [];
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Clear all downloads'),
        content: Text('Delete all ${downloads.length} downloads? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(downloadsProvider.notifier).removeDownloads(downloads);
            },
            child: const Text('Delete All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _StorageInfoChip extends StatelessWidget {
  final String icon;
  final String label;
  final String? sublabel;
  final Color? color;

  const _StorageInfoChip({
    required this.icon,
    required this.label,
    this.sublabel,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(icon, size: 16, color: effectiveColor),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: effectiveColor,
          ),
        ),
        if (sublabel != null) ...[
          const SizedBox(width: 4),
          Text(
            '· $sublabel',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _GroupedDownloadTile extends ConsumerWidget {
  final List<DownloadItem> items;
  final Map<String, DownloadProgressData> activeProgress;

  const _GroupedDownloadTile({
    required this.items,
    required this.activeProgress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final firstItem = items.first;

    final completedCount = items.where((i) {
      final status = activeProgress[i.task.metaData]?.status ?? i.status;
      return status == TaskStatus.complete;
    }).length;

    // Calculate total size for the group from active progress data
    final downloadService = ref.read(downloadServiceProvider);
    int totalBytes = 0;
    for (final i in items) {
      final trackingUrl = i.task.metaData;
      final pd = activeProgress[trackingUrl];
      if (pd != null && pd.totalSize > 0) {
        totalBytes += pd.totalSize;
      }
    }

    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LayoutConstants.radiusXl),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        tilePadding: const EdgeInsets.symmetric(
          horizontal: LayoutConstants.spacingMd,
          vertical: LayoutConstants.spacingXs,
        ),
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(LayoutConstants.radiusMd),
              child: CachedNetworkImage(
                imageUrl:
                    AppImageFallbacks.poster(
                      firstItem.item.posterUrl,
                      label: firstItem.item.title,
                    ) ??
                    '',
                width: 80,
                height: 120,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  width: 80,
                  height: 120,
                  color: theme.dividerColor,
                  child: const AppIcon('movie_outlined'),
                ),
              ),
            ),
            const SizedBox(width: LayoutConstants.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    firstItem.item.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      AppIcon(
                        'library_books_rounded',
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.episodesCount(items.length, completedCount),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (totalBytes > 0) ...[
                        const SizedBox(width: 8),
                        AppIcon('storage_rounded', size: 12, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text(
                          _formatBytes(totalBytes),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: LayoutConstants.spacingSm),
            IconButton(
              icon: const AppIcon('delete_outline_rounded'),
              onPressed: () => _confirmDeleteAll(context, ref),
              color: theme.colorScheme.error.withValues(alpha: 0.8),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        children: items.asMap().entries.map((entry) {
          final download = entry.value;
          final isLast = entry.key == items.length - 1;

          final trackingUrl = download.task.metaData;
          final progressData = activeProgress[trackingUrl];
          final double displayProgress =
              progressData?.progress ?? download.progress;
          final TaskStatus displayStatus =
              progressData?.status ?? download.status;

          return Column(
            children: [
              if (entry.key == 0)
                Divider(
                  height: 1,
                  color: theme.dividerColor.withValues(alpha: 0.4),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: LayoutConstants.spacingMd,
                  vertical: LayoutConstants.spacingSm,
                ),
                child: _DownloadItemTile(
                  item: download,
                  progress: displayProgress,
                  status: displayStatus,
                  progressData: progressData,
                  isInsideGroup: true,
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: LayoutConstants.spacingMd,
                  endIndent: LayoutConstants.spacingMd,
                  color: theme.dividerColor.withValues(alpha: 0.4),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _confirmDeleteAll(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(l10n.deleteAllEpisodes),
        content: Text(
          l10n.confirmDeleteAllEpisodes(items.length, items.first.item.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(downloadsProvider.notifier).removeDownloads(items);
            },
            child: Text(
              l10n.deleteAll,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadItemTile extends ConsumerWidget {
  final DownloadItem item;
  final double progress;
  final TaskStatus status;
  final DownloadProgressData? progressData;
  final bool isInsideGroup;

  const _DownloadItemTile({
    required this.item,
    required this.progress,
    required this.status,
    this.progressData,
    this.isInsideGroup = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDone = status == TaskStatus.complete;
    final isWorking =
        status == TaskStatus.running || status == TaskStatus.enqueued;
    final isPaused = status == TaskStatus.paused;

    // File size display from progress data
    final totalSize = progressData?.totalSize ?? -1;
    final sizeStr = (totalSize > 0)
        ? _formatBytes(totalSize)
        : null;

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Poster
        ClipRRect(
          borderRadius: BorderRadius.circular(LayoutConstants.radiusMd),
          child: CachedNetworkImage(
            imageUrl:
                AppImageFallbacks.poster(
                  item.item.posterUrl,
                  label: item.item.title,
                ) ??
                '',
            width: 80,
            height: 120,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) => Container(
              width: 80,
              height: 120,
              color: theme.dividerColor,
              child: const AppIcon('movie_outlined'),
            ),
          ),
        ),
        const SizedBox(width: LayoutConstants.spacingMd),
        // Details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (isInsideGroup && item.episode != null)
                    ? 'S${item.episode!.season} E${item.episode!.episode}: ${item.episode!.name}'
                    : item.item.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (!isInsideGroup &&
                  item.episode != null &&
                  item.item.contentType == MultimediaContentType.series) ...[
                const SizedBox(height: 2),
                Text(
                  'S${item.episode!.season} E${item.episode!.episode}: ${item.episode!.name}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 4),
              // Status row with file size
              Row(
                children: [
                  AppIcon(
                    isDone
                        ? 'check_circle_rounded'
                        : 'download_rounded',
                    size: 14,
                    color: isDone
                        ? Colors.green
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isDone ? l10n.completed : _getStatusText(status, l10n),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDone
                          ? Colors.green
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (sizeStr != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        sizeStr,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: LayoutConstants.spacingSm),
              if (!isDone) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: theme.dividerColor.withValues(alpha: 0.1),
                    minHeight: 4,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                if (progressData != null && isWorking)
                  Row(
                    children: [
                      Text(
                        progressData!.speedString,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (progressData!.totalSize > 0) ...[
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
              ],
              // Actions Row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
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
                  if (isDone)
                    IconButton(
                      icon: const AppIcon('play_circle_fill_rounded', color: Colors.green),
                      onPressed: () => _playLocalFile(context, ref, l10n),
                      iconSize: 28,
                    ),
                  IconButton(
                    icon: const AppIcon('share_rounded', size: 20),
                    onPressed: () => Share.share('${item.item.title}\n${item.item.url}'),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const AppIcon('delete_outline_rounded'),
                    onPressed: () => _confirmDelete(context, ref, l10n),
                    color: theme.colorScheme.error.withValues(alpha: 0.8),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    final tile = InkWell(
      onTap: isDone ? () => _playLocalFile(context, ref, l10n) : null,
      borderRadius: BorderRadius.circular(LayoutConstants.radiusLg),
      child: content,
    );

    if (isInsideGroup) {
      return tile;
    }

    final accentColor = isDone
        ? Colors.green
        : isWorking
            ? Colors.orange
            : status == TaskStatus.failed
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant;

    return Dismissible(
      key: Key(item.task.taskId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(LayoutConstants.radiusXl),
        ),
        child: const AppIcon('delete_outline_rounded', color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Text(l10n.deleteDownload),
            content: Text(l10n.confirmDeleteDownload),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        ref.read(downloadsProvider.notifier).removeDownload(item);
      },
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(LayoutConstants.radiusXl),
                    bottomLeft: Radius.circular(LayoutConstants.radiusXl),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                  padding: const EdgeInsets.all(LayoutConstants.spacingMd),
                  child: tile,
                ),
              ),
            ],
          ),
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

  Future<void> _playLocalFile(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final downloadService = ref.read(downloadServiceProvider);
    final File? file = await downloadService.getDownloadedFile(
      item.item,
      episode: item.episode,
    );

    if (file == null || !await file.exists()) {
      if (context.mounted) {
        ref
            .read(notificationServiceProvider)
            .showError(l10n.fileNotFoundRemoving);
      }
      await ref.read(downloadsProvider.notifier).removeDownload(item);
      return;
    }

    if (context.mounted) {
      unawaited(
        ref
            .read(playbackLauncherProvider)
            .play(context, file.path, baseItem: item.item),
      );
    }
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(l10n.deleteDownload),
        content: Text(l10n.confirmDeleteDownload),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(downloadsProvider.notifier).removeDownload(item);
            },
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
  var i = 0;
  double size = bytes.toDouble();
  while (size >= 1024 && i < suffixes.length - 1) {
    size /= 1024;
    i++;
  }
  return '${size.toStringAsFixed(i == 0 ? 0 : 1)} ${suffixes[i]}';
}
