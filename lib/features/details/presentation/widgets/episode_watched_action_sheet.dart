import 'package:flutter/material.dart';
import 'package:mixstream/core/domain/entity/multimedia_item.dart';

class EpisodeWatchedActionSheet extends StatelessWidget {
  final String mainUrl;
  final Episode episode;
  final bool isWatched;

  const EpisodeWatchedActionSheet({
    super.key,
    required this.mainUrl,
    required this.episode,
    required this.isWatched,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: [
        ListTile(
          leading: Icon(isWatched ? Icons.check_circle : Icons.radio_button_unchecked, color: isWatched ? Colors.green : Colors.grey),
          title: Text(isWatched ? 'Mark Unwatched' : 'Mark Watched'),
          onTap: () => Navigator.pop(context, !isWatched),
        ),
        if (isWatched)
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: Text('Reset Progress', style: TextStyle(color: Colors.red.shade400)),
            onTap: () => Navigator.pop(context, 'reset'),
          ),
      ],
    );
  }
}

class SeasonWatchedActionSheet extends StatelessWidget {
  final String mainUrl;
  final int season;
  final int totalEpisodes;
  final int watchedCount;

  const SeasonWatchedActionSheet({
    super.key,
    required this.mainUrl,
    required this.season,
    required this.totalEpisodes,
    required this.watchedCount,
  });

  @override
  Widget build(BuildContext context) {
    final allWatched = watchedCount >= totalEpisodes;
    return Wrap(
      children: [
        ListTile(
          leading: Icon(allWatched ? Icons.check_circle : Icons.radio_button_unchecked, color: allWatched ? Colors.green : Colors.grey),
          title: Text(allWatched ? 'Unwatch All Episodes' : 'Watch All Episodes'),
          subtitle: Text('$watchedCount/$totalEpisodes'),
          onTap: () => Navigator.pop(context, !allWatched),
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline, color: Colors.red),
          title: Text('Reset Season Progress', style: TextStyle(color: Colors.red.shade400)),
          onTap: () => Navigator.pop(context, 'reset'),
        ),
      ],
    );
  }
}
