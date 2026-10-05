import 'package:flixquest/services/adsterra_playback_ads_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../catalog/details_play.dart';
import '../catalog/media_item.dart';
import '../functions/function.dart';
import '../models/tv.dart';
import '../models/tv_stream_metadata.dart';
import '../screens/tv/tv_video_loader.dart';

/// Plays, or downloads, [episode] of [series] from a series', season's or
/// episode's page, the same way from each: with its season's episodes and
/// the series' seasons, so the player can list them and offer the next one.
///
/// Resolves to whether a download was queued; says so when it was.
Future<bool> playEpisode(
  BuildContext context, {
  required MediaItem series,
  required EpisodeList episode,
  required List<EpisodeList> seasonEpisodes,
  List<Seasons>? allSeasons,
  InsightsMetadata? insights,
  int? elapsed,
  bool download = false,
}) async {
  if (!await checkConnection()) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('check_connection'))),
      );
    }
    return false;
  }
  if (!context.mounted) return false;
  if (!await AdsterraPlaybackAdsService.instance
          .beforeLoader(context, download: download) ||
      !context.mounted) {
    return false;
  }
  final queued = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => TVVideoLoader(
        download: download,
        metadata: TVStreamMetadata(
          elapsed: elapsed,
          episodeId: episode.episodeId,
          episodeName: episode.name,
          episodeNumber: episode.episodeNumber,
          posterPath: series.posterPath,
          backdropPath: episode.stillPath ?? series.backdropPath,
          seasonNumber: episode.seasonNumber,
          seriesName: series.title,
          tvId: series.id,
          airDate: episode.airDate,
          genres: insights?.genres ?? const <String>[],
          languages: insights?.languages ?? const <String>[],
          countries: insights?.countries ?? const <String>[],
          seasonEpisodes: seasonEpisodes
              .where((episode) => episode.episodeId != null)
              .map(EpisodeMetadata.fromEpisodeList)
              .toList(growable: false),
          allSeasons: allSeasons
              ?.where((season) => season.seasonNumber != null)
              .map(SeasonMetadata.fromSeason)
              .toList(growable: false),
        ),
      ),
    ),
  );
  final added = download && queued == true;
  if (added && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('added_to_downloads'))),
    );
  }
  return added;
}
