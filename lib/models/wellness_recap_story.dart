import 'dart:math' as math;

import 'wellness_insights.dart';
import 'wellness_recap.dart';
import 'wellness_time_series.dart';

/// `42h 10m`, or `42h` and `10m` when the other part is zero.
String formatWatchedTime(int milliseconds) {
  final duration = Duration(milliseconds: milliseconds.abs());
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

/// The one-line identity a recap leads with.
enum WellnessViewerType {
  nightOwl,
  earlyBird,
  weekendBinger,
  streakKeeper,
  marathoner,
  completionist,
  seriesDevotee,
  movieLover,
  worldExplorer,
  timeTraveller,
  comfortRewatcher,
  sampler,
  liveRegular,

  /// Enough viewing to describe, with no habit that stands out.
  storyChaser,
}

/// A viewer type and the fact that earned it. [value] means what its type
/// needs: a percent, a count, or milliseconds of watch time.
class WellnessViewerProfile {
  const WellnessViewerProfile(
    this.type, {
    this.value = 0,
    this.secondValue = 0,
    this.label,
  });

  final WellnessViewerType type;
  final int value;
  final int secondValue;
  final String? label;

  /// How far past its threshold the habit is, so the most distinctive one
  /// wins rather than whichever is checked first.
  static WellnessViewerProfile? of(
    WellnessInsights insights,
    WellnessRecapPeriod period,
  ) {
    if (period.kind == WellnessRecapPeriodKind.day ||
        insights.sessionCount < _minSessions ||
        insights.totalWatchedMs < _minWatchedMs) {
      return null;
    }

    final candidates = <(double, WellnessViewerProfile)>[];
    void consider(double strength, WellnessViewerProfile profile) {
      if (strength >= 1) candidates.add((strength, profile));
    }

    final total = insights.sumPlaybackMs;
    final clockTotal = insights.hourlyMs.fold<int>(0, (a, b) => a + b);
    if (clockTotal > 0) {
      final parts = insights.partOfDayMs;
      final late = parts[3] / clockTotal;
      consider(
        late / .4,
        WellnessViewerProfile(WellnessViewerType.nightOwl,
            value: _percent(late)),
      );
      final morning = parts[0] / clockTotal;
      consider(
        morning / .35,
        WellnessViewerProfile(WellnessViewerType.earlyBird,
            value: _percent(morning)),
      );
      if (insights.periodDays >= 7 && insights.activeDays >= 3) {
        final weekend = insights.weekendWatchedMs / clockTotal;
        consider(
          weekend / .55,
          WellnessViewerProfile(WellnessViewerType.weekendBinger,
              value: _percent(weekend)),
        );
      }
    }

    final streak = insights.longestStreakDays;
    final streakBar = switch (period.kind) {
      WellnessRecapPeriodKind.week => 5,
      WellnessRecapPeriodKind.month => 7,
      _ => 14,
    };
    consider(
      streak / streakBar,
      WellnessViewerProfile(WellnessViewerType.streakKeeper, value: streak),
    );

    consider(
      insights.longestSessionMs / const Duration(hours: 4).inMilliseconds,
      WellnessViewerProfile(WellnessViewerType.marathoner,
          value: insights.longestSessionMs),
    );

    final completion = insights.completionRate;
    if (insights.titlesStarted >= 5) {
      consider(
        completion / .8,
        WellnessViewerProfile(WellnessViewerType.completionist,
            value: _percent(completion)),
      );
    }
    if (insights.sampledTitles >= 6 && completion < .35) {
      consider(
        (1 - completion) / .65,
        WellnessViewerProfile(
          WellnessViewerType.sampler,
          value: insights.titlesStarted,
          secondValue: insights.completedTitles,
        ),
      );
    }

    if (total > 0) {
      final topSeries = insights.topSeriesEpisodes.firstOrNull?.value ?? 0;
      if (topSeries >= 6) {
        consider(
          insights.episodeMs / total / .75,
          WellnessViewerProfile(WellnessViewerType.seriesDevotee,
              value: topSeries),
        );
      }
      if (insights.completedMovies >= 3) {
        consider(
          insights.movieMs / total / .75,
          WellnessViewerProfile(WellnessViewerType.movieLover,
              value: insights.completedMovies),
        );
      }
      final live = insights.liveMs / total;
      consider(
        live / .5,
        WellnessViewerProfile(WellnessViewerType.liveRegular,
            value: _percent(live)),
      );
    }

    consider(
      insights.topCountries.length / 5,
      WellnessViewerProfile(WellnessViewerType.worldExplorer,
          value: insights.topCountries.length),
    );

    final decades = insights.topDecades;
    if (decades.isNotEmpty) {
      final decadeYear = int.tryParse(decades.first.label.replaceAll('s', ''));
      final decadeTotal = decades.fold<int>(0, (a, b) => a + b.value);
      if (decadeYear != null &&
          decadeTotal > 0 &&
          period.startLocal.year - decadeYear >= 30) {
        consider(
          decades.first.value / decadeTotal / .5,
          WellnessViewerProfile(WellnessViewerType.timeTraveller,
              label: decades.first.label),
        );
      }
    }

    consider(
      insights.rewatches / 3,
      WellnessViewerProfile(WellnessViewerType.comfortRewatcher,
          value: insights.rewatches),
    );

    if (candidates.isEmpty) {
      return WellnessViewerProfile(
        WellnessViewerType.storyChaser,
        value: insights.medianActiveDayMs,
      );
    }
    // A long streak or sitting can run far past its bar; capping keeps one big
    // number from always beating a habit that defines the whole period.
    var best = candidates.first;
    for (final candidate in candidates.skip(1)) {
      if (math.min(candidate.$1, _maxStrength) >
          math.min(best.$1, _maxStrength)) {
        best = candidate;
      }
    }
    return best.$2;
  }

  static const _minSessions = 3;
  static const _minWatchedMs = 2 * 60 * 60 * 1000;
  static const _maxStrength = 2.0;
}

int _percent(double ratio) => (ratio.clamp(0.0, 1.0) * 100).round();

/// A ranked title with the artwork its sessions recorded.
class WellnessRecapTitle {
  const WellnessRecapTitle({
    required this.title,
    required this.watchedMs,
    this.posterPath,
    this.backdropPath,
  });

  final String title;
  final int watchedMs;
  final String? posterPath;
  final String? backdropPath;

  bool get hasPoster => posterPath != null;
}

enum WellnessRecapStatKind {
  finished,
  streak,
  activeDays,
  titles,
  newTitles,
  longestSitting,
  sessions,
}

class WellnessRecapStat {
  const WellnessRecapStat(this.kind, this.value);

  final WellnessRecapStatKind kind;

  /// A count, or milliseconds for [WellnessRecapStatKind.longestSitting].
  final int value;
}

/// One bar of the recap's rhythm chart. An empty [label] draws no tick text.
class WellnessRecapBar {
  const WellnessRecapBar(this.label, this.watchedMs);

  final String label;
  final int watchedMs;
}

/// What a shareable recap says about a period: every choice about which facts
/// are worth showing, kept apart from how they are drawn.
class WellnessRecapStory {
  WellnessRecapStory._({
    required this.insights,
    required this.period,
    required this.profile,
    required this.titles,
    required this.genres,
    required this.bars,
  });

  factory WellnessRecapStory.of(
    WellnessInsights insights,
    WellnessRecapPeriod period,
  ) {
    return WellnessRecapStory._(
      insights: insights,
      period: period,
      profile: WellnessViewerProfile.of(insights, period),
      titles: _rankedTitles(insights),
      genres: insights.topGenres
          .take(3)
          .map((genre) => genre.label)
          .toList(growable: false),
      bars: _bars(insights, period),
    );
  }

  final WellnessInsights insights;
  final WellnessRecapPeriod period;
  final WellnessViewerProfile? profile;

  /// Most watched first, up to [_maxTitles].
  final List<WellnessRecapTitle> titles;
  final List<String> genres;
  final List<WellnessRecapBar> bars;

  static const _maxTitles = 8;

  int get totalWatchedMs => insights.totalWatchedMs;

  /// The busiest titles that have a poster, in rank order.
  List<WellnessRecapTitle> postersUpTo(int count) => titles
      .where((title) => title.hasPoster)
      .take(count)
      .toList(growable: false);

  /// The picture behind the card: the top title's wide art when it has some.
  String? get backgroundPath {
    for (final title in titles) {
      final path = title.backdropPath ?? title.posterPath;
      if (path != null) return path;
    }
    return null;
  }

  /// Facts for the stat row, most interesting first. Nothing with a zero, and
  /// nothing the viewer type's own line already says.
  ///
  /// With [includeHabits] off, facts about when and how long someone watches
  /// are left out.
  List<WellnessRecapStat> stats({required bool includeHabits}) {
    final said = includeHabits ? profile?.type : null;
    final isDay = period.kind == WellnessRecapPeriodKind.day;
    final streak = insights.longestStreakDays;
    final finished = insights.completedTitles;
    final started = insights.titlesStarted;
    final longest = insights.longestSessionMs;
    final stats = <WellnessRecapStat>[
      if (finished > 0)
        WellnessRecapStat(WellnessRecapStatKind.finished, finished),
      if (includeHabits &&
          !isDay &&
          streak >= 2 &&
          said != WellnessViewerType.streakKeeper)
        WellnessRecapStat(WellnessRecapStatKind.streak, streak),
      // Every active day in one unbroken run is the streak over again.
      if (!isDay && insights.activeDays >= 2 && insights.activeDays != streak)
        WellnessRecapStat(
          WellnessRecapStatKind.activeDays,
          insights.activeDays,
        ),
      // The labels are plural, and "5 finished, 5 titles" says one thing twice.
      if (started >= 2 && started != finished)
        WellnessRecapStat(WellnessRecapStatKind.titles, started),
      // One long sitting that is the whole total adds nothing to the total.
      if (includeHabits &&
          longest > 0 &&
          longest < totalWatchedMs &&
          said != WellnessViewerType.marathoner)
        WellnessRecapStat(WellnessRecapStatKind.longestSitting, longest),
      if (insights.firstTimeTitles >= 2 && insights.firstTimeTitles != started)
        WellnessRecapStat(
          WellnessRecapStatKind.newTitles,
          insights.firstTimeTitles,
        ),
    ];
    if (stats.length < 2 && insights.sessionCount >= 2) {
      stats.add(WellnessRecapStat(
        WellnessRecapStatKind.sessions,
        insights.sessionCount,
      ));
    }
    return stats;
  }

  static List<WellnessRecapTitle> _rankedTitles(WellnessInsights insights) {
    final posters = <String, String>{};
    final backdrops = <String, String>{};
    // Sessions arrive newest first, so a title keeps its most recent artwork
    // even when an older session (or a download) recorded none.
    for (final session in insights.sessions) {
      final poster = session.posterPath;
      if (poster != null && poster.trim().isNotEmpty) {
        posters.putIfAbsent(session.title, () => poster);
      }
      final backdrop = session.backdropPath;
      if (backdrop != null && backdrop.trim().isNotEmpty) {
        backdrops.putIfAbsent(session.title, () => backdrop);
      }
    }
    return insights.topTitles
        .take(_maxTitles)
        .map((title) => WellnessRecapTitle(
              title: title.label,
              watchedMs: title.value,
              posterPath: posters[title.label],
              backdropPath: backdrops[title.label],
            ))
        .toList(growable: false);
  }

  static List<WellnessRecapBar> _bars(
    WellnessInsights insights,
    WellnessRecapPeriod period,
  ) {
    if (period.kind == WellnessRecapPeriodKind.month) {
      // One bar per day: the live chart's weekly buckets leave a month with
      // only four or five bars, too little to read as a rhythm. The values are
      // the same daily totals those buckets add up.
      final days = DateTime(
        period.startLocal.year,
        period.startLocal.month + 1,
        0,
      ).day;
      return List<WellnessRecapBar>.generate(days, (index) {
        final day = DateTime(
          period.startLocal.year,
          period.startLocal.month,
          index + 1,
        );
        return WellnessRecapBar(
          index % 7 == 0 ? '${index + 1}' : '',
          insights.dailyWatchedMs[day] ?? 0,
        );
      }, growable: false);
    }
    return WellnessTimeSeries.forRecap(insights, period)
        .buckets
        .map((bucket) => WellnessRecapBar(bucket.label, bucket.totalMs))
        .toList(growable: false);
  }
}
