import '../api/endpoints.dart';
import '../models/genres.dart';
import '../provider/app_dependency_provider.dart';
import '../provider/settings_provider.dart';
import 'catalog_controller.dart';
import 'home_feed_controller.dart' show interleave;
import 'media_item.dart';

enum HotSegment { comingSoon, everyoneWatching, topMovies, topSeries }

abstract class NewAndHotSource {
  Future<List<MediaItem>> upcomingMovies();
  Future<List<MediaItem>> seriesPremieres(DateTime today);
  Future<List<MediaItem>> trending(MediaKind kind);
  Future<List<Genres>> genres(MediaKind kind);
}

class CatalogNewAndHotSource implements NewAndHotSource {
  const CatalogNewAndHotSource({
    required this.settings,
    required this.dependencies,
    this.catalog = const CatalogController(),
  });

  final SettingsProvider settings;
  final AppDependencyProvider dependencies;
  final CatalogController catalog;

  Future<List<MediaItem>> _row(MediaKind kind, String url) => catalog.loadRow(
        kind: kind,
        url: url,
        settings: settings,
        dependencies: dependencies,
        strict: true,
      );

  @override
  Future<List<MediaItem>> upcomingMovies() =>
      _row(MediaKind.movie, Endpoints.upcomingMoviesUrl(settings.appLanguage));

  @override
  Future<List<MediaItem>> seriesPremieres(DateTime today) => _row(
        MediaKind.series,
        Endpoints.upcomingSeriesPremieresUrl(
          settings.appLanguage,
          today,
          includeAdult: settings.isAdult,
        ),
      );

  @override
  Future<List<MediaItem>> trending(MediaKind kind) => _row(
        kind,
        kind == MediaKind.movie
            ? Endpoints.trendingMoviesTodayUrl(settings.appLanguage)
            : Endpoints.trendingTVTodayUrl(settings.appLanguage),
      );

  @override
  Future<List<Genres>> genres(MediaKind kind) => catalog.loadGenres(
        kind: kind,
        settings: settings,
        dependencies: dependencies,
      );
}

class PremiereGroup {
  const PremiereGroup(this.date, this.items);

  final DateTime date;
  final List<MediaItem> items;
}

/// Today is included. TMDB sometimes returns released titles and undated
/// ones in its upcoming response; neither belongs on this calendar.
List<PremiereGroup> groupPremieres(
  List<MediaItem> movies,
  List<MediaItem> series,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final dated = <(DateTime, MediaItem)>[];
  final seen = <String>{};
  for (final item in <MediaItem>[...movies, ...series]) {
    if (item.id < 0) continue;
    if ((item.backdropPath ?? '').isEmpty && (item.posterPath ?? '').isEmpty) {
      continue;
    }
    final parsed = DateTime.tryParse(item.releaseDate ?? '');
    if (parsed == null) continue;
    final day = DateTime(parsed.year, parsed.month, parsed.day);
    if (day.isBefore(today)) continue;
    if (!seen.add(item.stableId)) continue;
    dated.add((day, item));
  }
  dated.sort((a, b) {
    final byDate = a.$1.compareTo(b.$1);
    if (byDate != 0) return byDate;
    return (b.$2.popularity ?? 0).compareTo(a.$2.popularity ?? 0);
  });
  final groups = <PremiereGroup>[];
  for (final entry in dated) {
    if (groups.isEmpty || groups.last.date != entry.$1) {
      groups.add(PremiereGroup(entry.$1, <MediaItem>[]));
    }
    groups.last.items.add(entry.$2);
  }
  return groups;
}

List<MediaItem> topTen(List<MediaItem> items) {
  final seen = <String>{};
  return items
      .where((item) => item.id >= 0 && seen.add(item.stableId))
      .take(10)
      .toList(growable: false);
}

List<MediaItem> everyoneWatching(
  List<MediaItem> movies,
  List<MediaItem> series,
) =>
    interleave(<List<MediaItem>>[movies, series])
        .take(20)
        .toList(growable: false);

class NewAndHotFeed {
  const NewAndHotFeed({
    this.groups = const <PremiereGroup>[],
    this.items = const <MediaItem>[],
    this.movieGenres = const <Genres>[],
    this.seriesGenres = const <Genres>[],
  });

  final List<PremiereGroup> groups;
  final List<MediaItem> items;
  final List<Genres> movieGenres;
  final List<Genres> seriesGenres;
  bool get isEmpty => groups.isEmpty && items.isEmpty;
}

/// All of New & Hot at once, as the TV lays it out.
class NewAndHotPage {
  const NewAndHotPage({
    this.comingSoon = const <PremiereGroup>[],
    this.everyoneWatching = const <MediaItem>[],
    this.topMovies = const <MediaItem>[],
    this.topSeries = const <MediaItem>[],
    this.movieGenres = const <Genres>[],
    this.seriesGenres = const <Genres>[],
  });

  final List<PremiereGroup> comingSoon;
  final List<MediaItem> everyoneWatching;
  final List<MediaItem> topMovies;
  final List<MediaItem> topSeries;
  final List<Genres> movieGenres;
  final List<Genres> seriesGenres;

  bool get isEmpty =>
      comingSoon.isEmpty &&
      everyoneWatching.isEmpty &&
      topMovies.isEmpty &&
      topSeries.isEmpty;

  /// The coming titles soonest first, each with the day it arrives.
  List<(DateTime, MediaItem)> get premieres => <(DateTime, MediaItem)>[
        for (final group in comingSoon)
          for (final item in group.items) (group.date, item),
      ];

  /// The genre names of [item], in TMDB's order.
  List<String> genreNames(MediaItem item) {
    final genres = item.kind == MediaKind.movie ? movieGenres : seriesGenres;
    return <String>[
      for (final id in item.genreIds)
        for (final genre in genres)
          if (genre.genreID == id && genre.genreName != null) genre.genreName!,
    ];
  }
}

/// Independent segment loads let the screen cache each one for this visit.
class NewAndHotCatalog {
  const NewAndHotCatalog(this.source, {this.now = DateTime.now});

  final NewAndHotSource source;
  final DateTime Function() now;

  Future<NewAndHotFeed> load(HotSegment segment) async {
    switch (segment) {
      case HotSegment.comingSoon:
        final today = now();
        final rows = await _eitherKind(
          source.upcomingMovies(),
          source.seriesPremieres(today),
        );
        final genres = await Future.wait(<Future<List<Genres>>>[
          source.genres(MediaKind.movie),
          source.genres(MediaKind.series),
        ]);
        return NewAndHotFeed(
          groups: groupPremieres(rows[0], rows[1], today),
          movieGenres: genres[0],
          seriesGenres: genres[1],
        );
      case HotSegment.everyoneWatching:
        final rows = await _eitherKind(
          source.trending(MediaKind.movie),
          source.trending(MediaKind.series),
        );
        return NewAndHotFeed(items: everyoneWatching(rows[0], rows[1]));
      case HotSegment.topMovies:
        return NewAndHotFeed(
            items: topTen(await source.trending(MediaKind.movie)));
      case HotSegment.topSeries:
        return NewAndHotFeed(
            items: topTen(await source.trending(MediaKind.series)));
    }
  }

  /// Every segment at once, for the TV, which shows them as rows of one
  /// page. Each list is asked for once: Everyone's Watching and the two
  /// Top 10s share the day's trending lists.
  ///
  /// A list that fails leaves its rows empty and the rest showing; the page
  /// fails only when none of them loads. Genres are only labels, so they
  /// never fail it.
  Future<NewAndHotPage> loadPage() async {
    final today = now();
    Object? error;
    Future<List<T>?> settle<T>(Future<List<T>> load) async {
      try {
        return await load;
      } catch (caught) {
        error = caught;
        return null;
      }
    }

    final upcoming = settle(source.upcomingMovies());
    final premieres = settle(source.seriesPremieres(today));
    final movies = settle(source.trending(MediaKind.movie));
    final series = settle(source.trending(MediaKind.series));
    final movieGenres = settle(source.genres(MediaKind.movie));
    final seriesGenres = settle(source.genres(MediaKind.series));
    final rows = <List<MediaItem>?>[
      await upcoming,
      await premieres,
      await movies,
      await series,
    ];
    if (rows.every((row) => row == null)) throw error!;
    List<MediaItem> row(int index) => rows[index] ?? const <MediaItem>[];
    return NewAndHotPage(
      comingSoon: groupPremieres(row(0), row(1), today),
      everyoneWatching: everyoneWatching(row(2), row(3)),
      topMovies: topTen(row(2)),
      topSeries: topTen(row(3)),
      movieGenres: await movieGenres ?? const <Genres>[],
      seriesGenres: await seriesGenres ?? const <Genres>[],
    );
  }

  /// Both kinds' lists; one failing leaves the other showing, and the
  /// segment fails only when neither loads.
  static Future<List<List<MediaItem>>> _eitherKind(
    Future<List<MediaItem>> movies,
    Future<List<MediaItem>> series,
  ) async {
    Object? error;
    Future<List<MediaItem>?> settle(Future<List<MediaItem>> load) async {
      try {
        return await load;
      } catch (caught) {
        error = caught;
        return null;
      }
    }

    final rows = await Future.wait(<Future<List<MediaItem>?>>[
      settle(movies),
      settle(series),
    ]);
    if (rows.every((row) => row == null)) throw error!;
    return <List<MediaItem>>[
      for (final row in rows) row ?? const <MediaItem>[],
    ];
  }
}
