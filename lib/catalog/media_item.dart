import '../models/movie.dart';
import '../models/recently_watched.dart';
import '../models/tv.dart';

enum MediaKind { movie, series }

class MediaItem {
  const MediaItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.rating,
    required this.releaseDate,
    this.progress,
    this.progressLabel,
    this.stableKey,
    this.movie,
    this.series,
    this.recentMovie,
    this.recentEpisode,
  });

  factory MediaItem.fromMovie(Movie movie) {
    return MediaItem(
      kind: MediaKind.movie,
      id: movie.id ?? -1,
      title: movie.title ?? movie.originalTitle ?? 'Untitled movie',
      overview: movie.overview ?? '',
      posterPath: movie.posterPath,
      backdropPath: movie.backdropPath,
      rating: movie.voteAverage,
      releaseDate: movie.releaseDate,
      movie: movie,
    );
  }

  factory MediaItem.fromSeries(TV series) {
    return MediaItem(
      kind: MediaKind.series,
      id: series.id ?? -1,
      title: series.name ?? series.originalName ?? 'Untitled series',
      overview: series.overview ?? '',
      posterPath: series.posterPath,
      backdropPath: series.backdropPath,
      rating: series.voteAverage,
      releaseDate: series.firstAirDate,
      series: series,
    );
  }

  factory MediaItem.fromRecentMovie(RecentMovie recent) {
    final movie = Movie(
      id: recent.id,
      title: recent.title,
      originalTitle: recent.title,
      posterPath: recent.posterPath,
      backdropPath: recent.backdropPath,
      releaseDate: recent.releaseYear?.toString(),
    );
    return MediaItem(
      kind: MediaKind.movie,
      id: recent.id ?? -1,
      title: recent.title ?? 'Untitled movie',
      overview: '',
      posterPath: recent.posterPath,
      backdropPath: recent.backdropPath,
      rating: null,
      releaseDate: recent.releaseYear?.toString(),
      progress: _watchProgress(recent.elapsed, recent.remaining),
      progressLabel: 'Continue movie',
      stableKey: 'recent-movie:${recent.id}',
      movie: movie,
      recentMovie: recent,
    );
  }

  factory MediaItem.fromRecentEpisode(RecentEpisode recent) {
    final series = TV(
      id: recent.seriesId,
      name: recent.seriesName,
      originalName: recent.seriesName,
      posterPath: recent.posterPath,
      backdropPath: recent.backdropPath,
    );
    final season = recent.seasonNum?.toString().padLeft(2, '0') ?? '--';
    final episode = recent.episodeNum?.toString().padLeft(2, '0') ?? '--';
    return MediaItem(
      kind: MediaKind.series,
      id: recent.seriesId ?? -1,
      title: recent.seriesName ?? 'Untitled series',
      overview: '',
      posterPath: recent.posterPath,
      backdropPath: recent.backdropPath,
      rating: null,
      releaseDate: null,
      progress: _watchProgress(recent.elapsed, recent.remaining),
      progressLabel: 'S$season  •  E$episode',
      stableKey:
          'recent-series:${recent.seriesId}:${recent.seasonNum}:${recent.episodeNum}',
      series: series,
      recentEpisode: recent,
    );
  }

  final MediaKind kind;
  final int id;
  final String title;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final num? rating;
  final String? releaseDate;
  final double? progress;
  final String? progressLabel;
  final String? stableKey;
  final Movie? movie;
  final TV? series;
  final RecentMovie? recentMovie;
  final RecentEpisode? recentEpisode;

  String get stableId => stableKey ?? '${kind.name}:$id';

  String? get year {
    final value = releaseDate;
    return value != null && value.length >= 4 ? value.substring(0, 4) : null;
  }

  static double? _watchProgress(int? elapsed, int? remaining) {
    if (elapsed == null || remaining == null || elapsed + remaining <= 0) {
      return null;
    }
    return (elapsed / (elapsed + remaining)).clamp(0, 1);
  }
}
