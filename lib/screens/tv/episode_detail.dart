import 'package:flutter/material.dart';

import '../../catalog/media_item.dart';
import '../../mobile/screens/episode_screen.dart';
import '../../models/tv.dart';

/// An episode's page, opened from a link or a list of episodes. The page
/// itself is [EpisodeScreen].
class EpisodeDetailPage extends StatelessWidget {
  const EpisodeDetailPage({
    required this.episodeList,
    required this.posterPath,
    this.episodes,
    this.tvId,
    this.seriesName,
    this.backdropPath,
    super.key,
  });

  final EpisodeList episodeList;

  /// Its season's episodes, when the caller has them.
  final List<EpisodeList>? episodes;
  final int? tvId;
  final String? seriesName;
  final String? posterPath;
  final String? backdropPath;

  @override
  Widget build(BuildContext context) => EpisodeScreen(
        series: MediaItem(
          kind: MediaKind.series,
          id: tvId ?? 0,
          title: seriesName ?? '',
          overview: '',
          posterPath: posterPath,
          backdropPath: backdropPath,
          rating: null,
          releaseDate: null,
        ),
        episode: episodeList,
        seasonEpisodes: episodes,
      );
}
