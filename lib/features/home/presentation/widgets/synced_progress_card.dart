import 'package:flutter/material.dart';
import 'package:mixstream/features/tracking/domain/sync_progress_item.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mixstream/core/domain/entity/multimedia_item.dart';
import 'package:mixstream/shared/widgets/cards_wrapper.dart';
import 'package:mixstream/shared/widgets/thumbnail_error_placeholder.dart';
import 'package:mixstream/core/utils/image_fallbacks.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixstream/features/tracking/data/sync_manager.dart';
import 'package:mixstream/l10n/generated/app_localizations.dart';
import 'package:mixstream/core/services/notification_service.dart';
import '../../../../shared/widgets/app_icon.dart';

class SyncedProgressCard extends ConsumerWidget {
  final SyncProgressItem item;
  final double width;
  final bool isLarge;
  final VoidCallback onTap;

  const SyncedProgressCard({
    super.key,
    required this.item,
    required this.width,
    required this.isLarge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final progress = (item.progressPercentage / 100.0).clamp(0.0, 1.0);

    return CardsWrapper(
      onTap: onTap,
      onLongPress: () {
        showModalBottomSheet<void>(
          context: context,
          builder: (context) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                ListTile(
                  leading: AppIcon('delete_outline', color: cs.error),
                  title: Text(
                    AppLocalizations.of(context)!.removeFromHistory,
                    style: TextStyle(color: cs.error),
                  ),
                  onTap: () async {
                    final manager = ref.read(syncManagerProvider);
                    final success = await manager.removePlaybackProgress(item);
                    if (success && context.mounted) {
                      ref.invalidate(syncedProgressProvider);
                      ref
                          .read(notificationServiceProvider)
                          .showSuccess(
                            AppLocalizations.of(
                              context,
                            )!.removedFromHistory(item.title),
                          );
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const AppIcon('close'),
                  title: Text(AppLocalizations.of(context)!.cancel),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(4),
              ),
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: CachedNetworkImage(
                  imageUrl:
                      AppImageFallbacks.tmdbPoster(
                        item.posterUrl,
                        label: item.title,
                      ) ??
                      '',
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: cs.surfaceContainerHighest),
                  errorWidget: (_, _, _) =>
                      ThumbnailErrorPlaceholder(label: item.title),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (item.type == MultimediaContentType.series &&
                        item.season != null &&
                        item.episode != null &&
                        (item.season! > 0 || item.episode! > 0))
                      Text(
                        "S${item.season} E${item.episode}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: cs.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        AppIcon('cloud_sync', size: 10, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          '${item.progressPercentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
