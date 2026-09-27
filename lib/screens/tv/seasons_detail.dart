import 'package:flutter/material.dart';

import '../../catalog/details_controller.dart';
import '../../catalog/media_item.dart';
import '../../mobile/screens/season_screen.dart';
import '../../models/tv.dart';

/// A season's page, opened from a link or anywhere that has the series'
/// details at hand. The page itself is [SeasonScreen].
class SeasonsDetail extends StatelessWidget {
  const SeasonsDetail({
    required this.seasons,
    required this.tvDetails,
    required this.heroId,
    this.tvId,
    this.seriesName,
    this.posterPath,
    super.key,
  });

  /// The season to show.
  final Seasons seasons;
  final String heroId;
  final int? tvId;
  final String? seriesName;
  final String? posterPath;
  final TVDetails tvDetails;

  @override
  Widget build(BuildContext context) {
    final id = tvId ?? tvDetails.id ?? 0;
    final series = MediaItem(
      kind: MediaKind.series,
      id: id,
      title: seriesName ?? tvDetails.originalTitle ?? '',
      overview: '',
      posterPath: posterPath ?? seasons.posterPath,
      backdropPath: tvDetails.backdropPath,
      rating: null,
      releaseDate: null,
    );
    final ordered = MediaDetailsData(
      item: series,
      seriesDetails: tvDetails,
      recommendations: const <MediaItem>[],
    ).seasons;
    return SeasonScreen(
      series: series,
      seasons: ordered.isEmpty ? <Seasons>[seasons] : ordered,
      seasonNumber: seasons.seasonNumber ?? 1,
    );
  }
}
