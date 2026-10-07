import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;

import '../api/endpoints.dart';
import '../constants/api_constants.dart';
import '../design/app_palette.dart';
import '../functions/network.dart';
import '../models/movie.dart';
import '../models/tv.dart';
import '../models/wellness.dart';
import '../models/wellness_insights.dart';
import '../provider/app_dependency_provider.dart';
import '../provider/bookmark_provider.dart';
import '../provider/settings_provider.dart';
import '../provider/wellness_provider.dart';
import 'home_widget_copy.dart';
import 'home_widget_deep_link.dart';

/// Fills the Android home screen widgets.
///
/// A widget is a set of `<prefix>_*` keys — eyebrow, title, subtitle, meta, progress, poster, hero,
/// deep link — and the Kotlin side is a renderer that only reads them. Every string is composed here
/// through [HomeWidgetCopy], which is what stops the same fact being authored on both sides of the
/// bridge, and the two artwork slots are always filled from two different images: the poster is the
/// thumbnail, the hero is the backdrop behind the text.
class HomeWidgetService {
  HomeWidgetService._();

  static final HomeWidgetService instance = HomeWidgetService._();

  static const _providers = <String>[
    'dev.beamlak.flixquest_v2.widgets.MovieOfDayWidgetProvider',
    'dev.beamlak.flixquest_v2.widgets.TvShowOfDayWidgetProvider',
    'dev.beamlak.flixquest_v2.widgets.WellnessWidgetProvider',
    'dev.beamlak.flixquest_v2.widgets.ContinueWatchingWidgetProvider',
    'dev.beamlak.flixquest_v2.widgets.MyListWidgetProvider',
  ];

  /// Each artwork is fetched at the size the view it fills actually needs.
  static const _posterSize = 'w342';
  static const _heroSize = 'w780';

  /// Days of picks written ahead, so the widgets keep rotating while the app is closed.
  static const _scheduleDays = 7;

  DateTime? _lastNetworkRefresh;
  String? _lastThemeSignature;
  bool _legacyCleared = false;

  Future<void> refreshAll({
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
    required WellnessProvider wellness,
    required BookmarkProvider bookmarks,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await refreshLocal(wellness: wellness, bookmarks: bookmarks);

      final lastRefresh = _lastNetworkRefresh;
      if (lastRefresh != null &&
          DateTime.now().difference(lastRefresh) < const Duration(hours: 6)) {
        return;
      }
      _lastNetworkRefresh = DateTime.now();

      final results = await Future.wait<Object?>([
        _refreshMovieSchedule(settings, dependencies),
        _refreshTvSchedule(settings, dependencies),
      ].map((future) => future.catchError((Object error, StackTrace stack) {
            debugPrint('[HomeWidget] Daily content refresh failed: $error');
            return null;
          })));

      if (results.any((result) => result != null)) {
        await _updateWidgets();
      }
    } catch (error, stack) {
      debugPrint('[HomeWidget] Refresh failed: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  /// Everything the widgets can show without the network.
  Future<void> refreshLocal({
    required WellnessProvider wellness,
    required BookmarkProvider bookmarks,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _clearLegacyKeys();
      await _saveWellness(wellness);
      await _saveContinueWatching(wellness);
      await _saveMyList(bookmarks);
      await _updateWidgets();
    } catch (error, stack) {
      debugPrint('[HomeWidget] Local refresh failed: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  /// Four separate measurements of one week: how long, how many days (written out and as the bar),
  /// what was finished, and which genre led.
  Future<void> _saveWellness(WellnessProvider wellness) async {
    final week = WellnessInsights.fromSessions(
      wellness.sessions,
      period: WellnessPeriod.forRange(WellnessRange.week, DateTime.now()),
    );
    await _writeText('wellness', <String, String>{
      'eyebrow': 'THIS WEEK',
      'title': HomeWidgetCopy.weekTotal(week.totalWatchedMs),
      'subtitle': HomeWidgetCopy.weekActivity(week.activeDays),
      'meta': HomeWidgetCopy.weekHighlights(
        completedTitles: week.completedTitles,
        topGenre: week.topGenres.firstOrNull?.label,
      ),
      'deep_link': HomeWidgetDeepLink.wellness.toString(),
    });
    await HomeWidget.saveWidgetData<int>(
      'wellness_progress',
      HomeWidgetCopy.weekProgress(week.activeDays),
    );
  }

  Future<void> _saveContinueWatching(WellnessProvider wellness) async {
    final watchable = wellness.sessions.where((session) =>
        !session.isDeleted &&
        session.qualifies &&
        session.mediaType != WellnessMediaType.live);
    // Something half-watched is the better invitation; fall back to the most recent session so the
    // widget still has a title once everything has been finished.
    final session = watchable.where((entry) => !entry.completed).firstOrNull ??
        watchable.firstOrNull;

    await _saveArtwork(
      prefix: 'continue',
      posterPath: session?.posterPath,
      heroPath: session?.backdropPath,
    );
    await _writeText('continue', <String, String>{
      'eyebrow': 'CONTINUE WATCHING',
      'title': session?.title ?? 'Nothing in progress',
      'subtitle': session == null
          ? 'Play a movie or episode to pick it up here'
          : HomeWidgetCopy.episodeFacts(
              isEpisode: session.mediaType == WellnessMediaType.episode,
              season: session.seasonNumber,
              episode: session.episodeNumber,
              episodeTitle: session.subtitle,
              releaseYear: session.releaseYear,
            ),
      'meta': session == null
          ? ''
          : HomeWidgetCopy.remaining(
              durationMs: session.durationMs,
              progressEndMs: session.progressEndMs,
              completed: session.completed,
            ),
      'deep_link': HomeWidgetDeepLink.session(session).toString(),
    });
    await HomeWidget.saveWidgetData<int>(
      'continue_progress',
      session == null ? 0 : (session.progress * 100).round(),
    );
  }

  /// The saved total lives in the eyebrow, which frees the other rows to describe the one title
  /// whose artwork is on screen.
  Future<void> _saveMyList(BookmarkProvider bookmarks) async {
    final movies = bookmarks.movies;
    final shows = bookmarks.tvShows;
    final movie = movies.firstOrNull;
    final show = shows.firstOrNull;
    // Feature whichever side was saved last, and take both images from that single entry so the
    // poster and the backdrop are never of two different titles.
    final featureMovie = movie != null &&
        (show == null ||
            !_addedAt(show.dateAdded).isAfter(_addedAt(movie.dateAdded)));
    final feature = featureMovie
        ? (
            title: movie.title,
            date: movie.releaseDate,
            poster: movie.posterPath,
            hero: movie.backdropPath,
          )
        : (
            title: show?.name,
            date: show?.firstAirDate,
            poster: show?.posterPath,
            hero: show?.backdropPath,
          );
    final saved = movies.length + shows.length;

    await _saveArtwork(
      prefix: 'my_list',
      posterPath: feature.poster,
      heroPath: feature.hero,
    );
    await _writeText('my_list', <String, String>{
      'eyebrow': HomeWidgetCopy.listEyebrow(saved),
      'title': feature.title ?? 'Your list is empty',
      'subtitle': saved == 0
          ? 'Bookmark a title to keep it here'
          : HomeWidgetCopy.listBreakdown(
              movies: movies.length,
              tvShows: shows.length,
            ),
      'meta': saved == 0
          ? ''
          : HomeWidgetCopy.titleFacts(
              isMovie: featureMovie,
              date: feature.date,
            ),
      'deep_link': HomeWidgetDeepLink.myList.toString(),
    });
  }

  Future<void> syncResolvedTheme(ThemeData theme) async {
    if (!Platform.isAndroid) return;
    try {
      await _syncResolvedTheme(theme);
    } catch (error, stack) {
      debugPrint('[HomeWidget] Theme sync failed: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  /// The single writer of the widget palette, fed the theme the app actually resolved rather than a
  /// second reconstruction of it from settings. The roles are [AppPalette]'s, so a widget without
  /// artwork looks like one of the app's own panels.
  Future<void> _syncResolvedTheme(ThemeData theme) async {
    final palette = AppPalette.fromTheme(theme);
    final surface = palette.surface;
    final primary = theme.colorScheme.primary;
    final foreground = palette.foreground;
    final muted = palette.mutedText;
    final signature = <int>[
      surface.toARGB32(),
      primary.toARGB32(),
      foreground.toARGB32(),
      muted.toARGB32(),
    ].join(':');
    if (_lastThemeSignature == signature) return;
    _lastThemeSignature = signature;
    await Future.wait([
      HomeWidget.saveWidgetData<int>('theme_surface', surface.toARGB32()),
      HomeWidget.saveWidgetData<int>('theme_primary', primary.toARGB32()),
      HomeWidget.saveWidgetData<int>('theme_foreground', foreground.toARGB32()),
      HomeWidget.saveWidgetData<int>('theme_muted', muted.toARGB32()),
    ]);
    await _updateWidgets();
  }

  Future<Object?> _refreshMovieSchedule(
    SettingsProvider settings,
    AppDependencyProvider dependencies,
  ) async {
    final movies = await fetchMovies(
      Endpoints.trendingMoviesUrl(settings.appLanguage),
      settings.enableProxy,
      dependencies.tmdbProxy,
    );
    final valid = movies
        .where((movie) =>
            movie.id != null &&
            movie.title?.trim().isNotEmpty == true &&
            movie.adult != true)
        .toList(growable: false);
    if (valid.isEmpty) return null;
    await _saveMovieSchedule(valid);
    return true;
  }

  Future<Object?> _refreshTvSchedule(
    SettingsProvider settings,
    AppDependencyProvider dependencies,
  ) async {
    final shows = await fetchTV(
      Endpoints.trendingTVUrl(settings.appLanguage),
      settings.enableProxy,
      dependencies.tmdbProxy,
    );
    final valid = shows
        .where((show) =>
            show.id != null &&
            show.name?.trim().isNotEmpty == true &&
            show.adult != true)
        .toList(growable: false);
    if (valid.isEmpty) return null;
    await _saveTvSchedule(valid);
    return true;
  }

  Future<void> _saveMovieSchedule(List<Movie> movies) async {
    final startDay = _epochDay(DateTime.now());
    final items = <Map<String, Object?>>[];
    for (var offset = 0; offset < _scheduleDays; offset++) {
      final movie = movies[(startDay + offset) % movies.length];
      final artwork = await Future.wait([
        _saveImage(
          key: 'movie_daily_$offset',
          remotePath: movie.posterPath,
          size: _posterSize,
        ),
        _saveImage(
          key: 'movie_hero_$offset',
          remotePath: movie.backdropPath,
          size: _heroSize,
        ),
      ]);
      items.add(<String, Object?>{
        'title': movie.title,
        'subtitle': HomeWidgetCopy.dailyFacts(
          date: movie.releaseDate,
          rating: movie.voteAverage,
        ),
        'meta': HomeWidgetCopy.hook(movie.overview),
        'poster': artwork.first,
        'hero': artwork.last,
        'deepLink': HomeWidgetDeepLink.movie(
          id: movie.id!,
          title: movie.title,
          posterPath: movie.posterPath,
          backdropPath: movie.backdropPath,
        ).toString(),
      });
    }
    await HomeWidget.saveWidgetData<String>(
      'movie_daily_schedule',
      jsonEncode(<String, Object?>{'startDay': startDay, 'items': items}),
    );
  }

  Future<void> _saveTvSchedule(List<TV> shows) async {
    final startDay = _epochDay(DateTime.now());
    final items = <Map<String, Object?>>[];
    for (var offset = 0; offset < _scheduleDays; offset++) {
      final show = shows[(startDay + offset) % shows.length];
      final artwork = await Future.wait([
        _saveImage(
          key: 'tv_daily_$offset',
          remotePath: show.posterPath,
          size: _posterSize,
        ),
        _saveImage(
          key: 'tv_hero_$offset',
          remotePath: show.backdropPath,
          size: _heroSize,
        ),
      ]);
      items.add(<String, Object?>{
        'title': show.name,
        'subtitle': HomeWidgetCopy.dailyFacts(
          date: show.firstAirDate,
          rating: show.voteAverage,
        ),
        'meta': HomeWidgetCopy.hook(show.overview),
        'poster': artwork.first,
        'hero': artwork.last,
        'deepLink': HomeWidgetDeepLink.tv(
          id: show.id!,
          name: show.name,
          posterPath: show.posterPath,
          backdropPath: show.backdropPath,
        ).toString(),
      });
    }
    await HomeWidget.saveWidgetData<String>(
      'tv_daily_schedule',
      jsonEncode(<String, Object?>{'startDay': startDay, 'items': items}),
    );
  }

  Future<void> _writeText(String prefix, Map<String, String> fields) =>
      Future.wait(fields.entries.map((field) =>
          HomeWidget.saveWidgetData<String>(
              '${prefix}_${field.key}', field.value)));

  Future<void> _saveArtwork({
    required String prefix,
    required String? posterPath,
    required String? heroPath,
  }) =>
      Future.wait([
        _saveImage(
          key: '${prefix}_poster',
          remotePath: posterPath,
          size: _posterSize,
        ),
        _saveImage(
          key: '${prefix}_hero',
          remotePath: heroPath,
          size: _heroSize,
        ),
      ]);

  /// Downloads one artwork and returns the file the widget should read.
  ///
  /// The remote path is remembered alongside the file so an unchanged image is never fetched twice,
  /// and an absent one clears both keys: a widget that has moved on to another title must not keep
  /// rendering the previous one's art.
  Future<String?> _saveImage({
    required String key,
    required String? remotePath,
    required String size,
  }) async {
    final sourceKey = '${key}_source';
    if (remotePath == null || remotePath.isEmpty) {
      await HomeWidget.saveWidgetData<String>(key, null);
      await HomeWidget.saveWidgetData<String>(
        sourceKey,
        null,
        deleteFile: false,
      );
      return null;
    }
    final previousSource = await HomeWidget.getWidgetData<String>(sourceKey);
    final previousFile = await HomeWidget.getWidgetData<String>(key);
    if (previousSource == remotePath && previousFile != null) {
      return previousFile;
    }
    // Sessions recorded by the offline player keep the whole image URL they displayed rather than
    // the path behind it, and that one is fetched as it stands instead of being sized again.
    final url = remotePath.startsWith('http')
        ? remotePath
        : '$TMDB_BASE_IMAGE_URL$size$remotePath';
    try {
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final saved =
          await HomeWidget.saveFile(key, response.bodyBytes, extension: 'jpg');
      await HomeWidget.saveWidgetData<String>(
        sourceKey,
        remotePath,
        deleteFile: false,
      );
      return saved;
    } catch (error) {
      debugPrint('[HomeWidget] Image download failed for $key: $error');
      return HomeWidget.getWidgetData<String>(key);
    }
  }

  /// Keys from the previous layout that nothing reads any more. `continue_image` and `my_list_image`
  /// held a copy of a poster path that is still live under another key, so they are cleared without
  /// touching the file behind them.
  Future<void> _clearLegacyKeys() async {
    if (_legacyCleared) return;
    _legacyCleared = true;
    const legacy = <String>[
      'continue_image',
      'my_list_image',
      'theme_background',
      'theme_eyebrow',
    ];
    await Future.wait(legacy.map((key) =>
        HomeWidget.saveWidgetData<String>(key, null, deleteFile: false)));
  }

  Future<void> _updateWidgets() async {
    await Future.wait(
      _providers.map(
        (provider) => HomeWidget.updateWidget(
          qualifiedAndroidName: provider,
        ).catchError((Object error) {
          debugPrint('[HomeWidget] Could not update $provider: $error');
          return false;
        }),
      ),
    );
  }

  static int _epochDay(DateTime date) {
    final utcDay = DateTime.utc(date.year, date.month, date.day);
    return utcDay.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  }

  static DateTime _addedAt(String? value) =>
      (value == null ? null : DateTime.tryParse(value)) ??
      DateTime.fromMillisecondsSinceEpoch(0);
}
