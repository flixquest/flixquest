import 'dart:math' as math;

import 'wellness.dart';

enum WellnessRange { week, month, year, allTime }

class WellnessPeriod {
  const WellnessPeriod({
    required this.startUtc,
    required this.endUtc,
    this.unbounded = false,
  });

  final DateTime startUtc;
  final DateTime endUtc;

  /// True for "all time", whose start is a sentinel rather than a real
  /// boundary. Day-count metrics measure from the first recorded day instead.
  final bool unbounded;

  factory WellnessPeriod.forRange(WellnessRange range, DateTime now) {
    final localNow = now.toLocal();
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final localStart = switch (range) {
      WellnessRange.week => today.subtract(Duration(days: today.weekday - 1)),
      WellnessRange.month => DateTime(today.year, today.month),
      WellnessRange.year => DateTime(today.year),
      WellnessRange.allTime => DateTime(2000),
    };
    final localEnd = switch (range) {
      WellnessRange.week => localStart.add(const Duration(days: 7)),
      WellnessRange.month => DateTime(localStart.year, localStart.month + 1),
      WellnessRange.year => DateTime(localStart.year + 1),
      WellnessRange.allTime => today.add(const Duration(days: 1)),
    };
    return WellnessPeriod(
      startUtc: localStart.toUtc(),
      endUtc: localEnd.toUtc(),
      unbounded: range == WellnessRange.allTime,
    );
  }

  WellnessPeriod previous() {
    final duration = endUtc.difference(startUtc);
    return WellnessPeriod(
      startUtc: startUtc.subtract(duration),
      endUtc: startUtc,
    );
  }

  bool overlaps(WellnessViewingSession session) =>
      session.endedAtUtc.isAfter(startUtc) &&
      session.startedAtUtc.isBefore(endUtc);
}

/// Watch time broken down by media type. Used for per-day splits so a chart
/// selection can explain *what* was watched, not just how much.
class WellnessMediaSplit {
  const WellnessMediaSplit({
    this.movieMs = 0,
    this.episodeMs = 0,
    this.liveMs = 0,
  });

  static const WellnessMediaSplit empty = WellnessMediaSplit();

  final int movieMs;
  final int episodeMs;
  final int liveMs;

  int get totalMs => movieMs + episodeMs + liveMs;
  bool get isEmpty => totalMs == 0;

  WellnessMediaSplit operator +(WellnessMediaSplit other) => WellnessMediaSplit(
        movieMs: movieMs + other.movieMs,
        episodeMs: episodeMs + other.episodeMs,
        liveMs: liveMs + other.liveMs,
      );

  WellnessMediaSplit addMs(WellnessMediaType type, int ms) => switch (type) {
        WellnessMediaType.movie => WellnessMediaSplit(
            movieMs: movieMs + ms,
            episodeMs: episodeMs,
            liveMs: liveMs,
          ),
        WellnessMediaType.episode => WellnessMediaSplit(
            movieMs: movieMs,
            episodeMs: episodeMs + ms,
            liveMs: liveMs,
          ),
        WellnessMediaType.live => WellnessMediaSplit(
            movieMs: movieMs,
            episodeMs: episodeMs,
            liveMs: liveMs + ms,
          ),
      };
}

class WellnessRankedValue {
  const WellnessRankedValue(this.label, this.value);

  final String label;
  final int value;
}

class WellnessInsights {
  const WellnessInsights({
    required this.sessions,
    required this.totalWatchedMs,
    required this.sumPlaybackMs,
    required this.movieMs,
    required this.episodeMs,
    required this.liveMs,
    required this.completedMovies,
    required this.completedEpisodes,
    required this.uniqueSeries,
    required this.rewatches,
    required this.activeDays,
    required this.dailyWatchedMs,
    required this.hourOfWeekMs,
    required this.topTitles,
    required this.topGenres,
    required this.topLanguages,
    required this.topCountries,
    required this.topDecades,
    required this.topProviders,
    required this.viewingSessionCount,
    required this.longestSessionMs,
    required this.dailyMediaMs,
    required this.topSeriesEpisodes,
    required this.titlesStarted,
    required this.sampledTitles,
    required this.periodDays,
    this.networkBytes = 0,
    this.networkMeasuredSessions = 0,
    this.networkMeasuredMs = 0,
  });

  final List<WellnessViewingSession> sessions;

  /// Headline viewing time. Rewatches count independently while simultaneous
  /// playback of different titles is counted once per real-world time slice.
  final int totalWatchedMs;

  /// Sum of every playback stream, including simultaneous playback.
  final int sumPlaybackMs;
  final int movieMs;
  final int episodeMs;
  final int liveMs;
  final int completedMovies;
  final int completedEpisodes;
  final int uniqueSeries;
  final int rewatches;
  final int activeDays;
  final Map<DateTime, int> dailyWatchedMs;
  final List<List<int>> hourOfWeekMs;
  final List<WellnessRankedValue> topTitles;
  final List<WellnessRankedValue> topGenres;
  final List<WellnessRankedValue> topLanguages;
  final List<WellnessRankedValue> topCountries;
  final List<WellnessRankedValue> topDecades;
  final List<WellnessRankedValue> topProviders;
  final int viewingSessionCount;
  final int longestSessionMs;

  /// Per-local-day watch time split by media type, same keys as
  /// [dailyWatchedMs].
  final Map<DateTime, WellnessMediaSplit> dailyMediaMs;

  /// Series ranked by how many distinct episodes were watched, not by time.
  final List<WellnessRankedValue> topSeriesEpisodes;

  /// Distinct non-live titles with qualifying watch time in the period.
  final int titlesStarted;

  /// Titles that were started but never finished.
  final int sampledTitles;

  /// Calendar days the period covers, clamped to at least one.
  final int periodDays;

  /// Network data used by the sessions that measured it, with a session that
  /// straddles the period's edge counted in proportion to its watch time
  /// inside the period.
  final int networkBytes;

  /// Sessions that measured their network data. Older sessions and some
  /// platforms do not, so [networkBytes] can cover only part of the period.
  final int networkMeasuredSessions;

  /// Watch time of the sessions behind [networkBytes].
  final int networkMeasuredMs;

  bool get isEmpty => sessions.isEmpty;
  bool get hasNetworkUsage => networkMeasuredSessions > 0;

  /// Network data per hour watched, over the sessions that measured it.
  int get networkBytesPerHour => networkMeasuredMs <= 0
      ? 0
      : (networkBytes * const Duration(hours: 1).inMilliseconds /
              networkMeasuredMs)
          .round();
  int get sessionCount => viewingSessionCount;
  int get completedTitles => completedMovies + completedEpisodes;
  int get averageActiveDayMs =>
      activeDays == 0 ? 0 : totalWatchedMs ~/ activeDays;

  /// Watch time by hour of day, summed across the week.
  List<int> get hourlyMs {
    final hours = List<int>.filled(24, 0);
    for (final day in hourOfWeekMs) {
      for (var hour = 0; hour < day.length && hour < 24; hour++) {
        hours[hour] += day[hour];
      }
    }
    return List<int>.unmodifiable(hours);
  }

  /// Watch time per weekday, Monday first.
  List<int> get weekdayTotalsMs => List<int>.unmodifiable(
        hourOfWeekMs.map((day) => day.fold<int>(0, (a, b) => a + b)),
      );

  int get weekendWatchedMs {
    final totals = weekdayTotalsMs;
    if (totals.length < 7) return 0;
    return totals[5] + totals[6];
  }

  int get weekdayWatchedMs {
    final totals = weekdayTotalsMs;
    if (totals.length < 7) return 0;
    return totals.take(5).fold<int>(0, (a, b) => a + b);
  }

  /// 22:00–04:59 watch time.
  int get lateNightMs {
    final hours = hourlyMs;
    var total = hours[22] + hours[23];
    for (var hour = 0; hour < 5; hour++) {
      total += hours[hour];
    }
    return total;
  }

  /// Watch time in four ordered parts of the day: morning (05–11), afternoon
  /// (12–16), evening (17–21), late night (22–04).
  List<int> get partOfDayMs {
    final hours = hourlyMs;
    var morning = 0;
    var afternoon = 0;
    var evening = 0;
    for (var hour = 5; hour <= 11; hour++) {
      morning += hours[hour];
    }
    for (var hour = 12; hour <= 16; hour++) {
      afternoon += hours[hour];
    }
    for (var hour = 17; hour <= 21; hour++) {
      evening += hours[hour];
    }
    return List<int>.unmodifiable([morning, afternoon, evening, lateNightMs]);
  }

  /// The busiest weekday/hour cell of the week, or null when nothing is
  /// recorded.
  (int weekday, int hour, int ms)? get peakHourOfWeek {
    var best = 0;
    (int, int, int)? peak;
    for (var day = 0; day < hourOfWeekMs.length; day++) {
      for (var hour = 0; hour < hourOfWeekMs[day].length; hour++) {
        final value = hourOfWeekMs[day][hour];
        if (value > best) {
          best = value;
          peak = (day, hour, value);
        }
      }
    }
    return peak;
  }

  /// The single heaviest day in the period.
  (DateTime day, int ms)? get busiestDay {
    (DateTime, int)? best;
    for (final entry in dailyWatchedMs.entries) {
      if (entry.value <= 0) continue;
      if (best == null || entry.value > best.$2) best = (entry.key, entry.value);
    }
    return best;
  }

  int get averageSessionMs =>
      viewingSessionCount == 0 ? 0 : totalWatchedMs ~/ viewingSessionCount;

  /// Share of started titles that were finished, 0–1.
  double get completionRate =>
      titlesStarted == 0 ? 0 : completedTitles / titlesStarted;

  /// Share of the period's days with any viewing, 0–1.
  double get activeDayShare =>
      periodDays == 0 ? 0 : (activeDays / periodDays).clamp(0.0, 1.0);

  /// Typical day, robust to one binge skewing the mean.
  int get medianActiveDayMs {
    final values = dailyWatchedMs.values.where((value) => value > 0).toList()
      ..sort();
    if (values.isEmpty) return 0;
    final middle = values.length ~/ 2;
    return values.length.isOdd
        ? values[middle]
        : (values[middle - 1] + values[middle]) ~/ 2;
  }

  /// Longest run of consecutive days with any viewing.
  int get longestStreakDays {
    final days = _activeDaysSorted();
    if (days.isEmpty) return 0;
    var longest = 1;
    var run = 1;
    for (var i = 1; i < days.length; i++) {
      if (days[i].difference(days[i - 1]).inDays == 1) {
        run++;
        longest = math.max(longest, run);
      } else {
        run = 1;
      }
    }
    return longest;
  }

  /// Run of consecutive days with viewing ending today (or yesterday, so the
  /// streak survives until the day is actually missed).
  int currentStreakDays([DateTime? now]) {
    final days = _activeDaysSorted();
    if (days.isEmpty) return 0;
    final localNow = (now ?? DateTime.now()).toLocal();
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final last = days.last;
    final gap = today.difference(last).inDays;
    if (gap > 1) return 0;
    var streak = 1;
    for (var i = days.length - 1; i > 0; i--) {
      if (days[i].difference(days[i - 1]).inDays == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  List<DateTime> _activeDaysSorted() {
    final days = dailyWatchedMs.entries
        .where((entry) => entry.value > 0)
        .map((entry) => DateTime(entry.key.year, entry.key.month, entry.key.day))
        .toSet()
        .toList()
      ..sort();
    return days;
  }

  factory WellnessInsights.fromSessions(
    Iterable<WellnessViewingSession> allSessions, {
    required WellnessPeriod period,
  }) {
    final sessions = allSessions
        .where((session) =>
            !session.isDeleted && session.qualifies && period.overlaps(session))
        .toList(growable: false)
      ..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));

    final intervals = <_PlaybackInterval>[];
    var fallbackWatchedMs = 0;
    var movieMs = 0;
    var episodeMs = 0;
    var liveMs = 0;
    final daily = <DateTime, int>{};
    final dailyByType = <DateTime, WellnessMediaSplit>{};
    final hourGrid = List<List<int>>.generate(
      7,
      (_) => List<int>.filled(24, 0),
    );
    final seriesEpisodeKeys = <String, Set<String>>{};
    final seriesLabels = <String, String>{};
    final startedTitleKeys = <String>{};
    final completedMovieKeys = <String>{};
    final completedEpisodeKeys = <String>{};
    final seriesKeys = <String>{};
    final completionCounts = <String, int>{};
    final titleMs = <String, int>{};
    final genreMs = <String, int>{};
    final languageMs = <String, int>{};
    final countryMs = <String, int>{};
    final decadeMs = <String, int>{};
    final providerMs = <String, int>{};
    var networkBytes = 0;
    var networkMeasuredSessions = 0;
    var networkMeasuredMs = 0;

    for (final session in sessions) {
      final clippedMs = _clippedSessionWatchedMs(session, period);
      if (clippedMs <= 0) continue;
      final sessionBytes = session.networkBytes;
      if (sessionBytes != null) {
        networkMeasuredSessions++;
        networkMeasuredMs += clippedMs;
        networkBytes += session.watchedMs <= clippedMs
            ? sessionBytes
            : (sessionBytes * clippedMs / session.watchedMs).round();
      }
      switch (session.mediaType) {
        case WellnessMediaType.movie:
          movieMs += clippedMs;
          if (session.completed) completedMovieKeys.add(session.uniqueTitleKey);
        case WellnessMediaType.episode:
          episodeMs += clippedMs;
          seriesKeys.add(session.uniqueSeriesKey);
          seriesEpisodeKeys
              .putIfAbsent(session.uniqueSeriesKey, () => <String>{})
              .add(session.uniqueTitleKey);
          seriesLabels.putIfAbsent(session.uniqueSeriesKey, () => session.title);
          if (session.completed) {
            completedEpisodeKeys.add(session.uniqueTitleKey);
          }
        case WellnessMediaType.live:
          liveMs += clippedMs;
      }
      if (session.completed) {
        completionCounts.update(
          session.uniqueTitleKey,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
      if (session.mediaType != WellnessMediaType.live) {
        startedTitleKeys.add(session.uniqueTitleKey);
        titleMs.update(session.title, (value) => value + clippedMs,
            ifAbsent: () => clippedMs);
        for (final genre in session.genres) {
          genreMs.update(genre, (value) => value + clippedMs,
              ifAbsent: () => clippedMs);
        }
        for (final language in session.languages) {
          languageMs.update(language, (value) => value + clippedMs,
              ifAbsent: () => clippedMs);
        }
        for (final country in session.countries) {
          countryMs.update(country, (value) => value + clippedMs,
              ifAbsent: () => clippedMs);
        }
        final year = session.releaseYear;
        if (year != null && year > 1800) {
          final decade = '${year ~/ 10 * 10}s';
          decadeMs.update(decade, (value) => value + clippedMs,
              ifAbsent: () => clippedMs);
        }
        final provider = session.provider?.trim();
        if (provider != null && provider.isNotEmpty) {
          providerMs.update(provider, (value) => value + clippedMs,
              ifAbsent: () => clippedMs);
        }
      }

      if (session.segments.isEmpty) {
        fallbackWatchedMs += clippedMs;
        _addFallbackToCalendar(
          session,
          clippedMs,
          daily,
          hourGrid,
          dailyByType,
        );
        continue;
      }
      for (final segment in session.segments) {
        final start = segment.startedAtUtc.isBefore(period.startUtc)
            ? period.startUtc
            : segment.startedAtUtc;
        final end = segment.endedAtUtc.isAfter(period.endUtc)
            ? period.endUtc
            : segment.endedAtUtc;
        if (!end.isAfter(start)) continue;
        intervals.add(_PlaybackInterval(start, end, session.uniqueTitleKey));
        _splitSegmentByLocalHour(
          start,
          end,
          session.timezoneOffsetMinutes,
          daily,
          hourGrid,
          dailyByType,
          session.mediaType,
        );
      }
    }

    final unionMs =
        _titleAwarePlaybackDurationMs(intervals) + fallbackWatchedMs;
    final sumMs = movieMs + episodeMs + liveMs;
    final activeDays = daily.values.where((value) => value > 0).length;
    final rewatches = completionCounts.values.fold<int>(
      0,
      (total, count) => total + math.max(0, count - 1),
    );
    final grouped = _groupedViewingSessions(sessions, period);
    final completedTitleKeys = <String>{
      ...completedMovieKeys,
      ...completedEpisodeKeys,
    };
    final seriesEpisodeCounts = <String, int>{
      for (final entry in seriesEpisodeKeys.entries)
        seriesLabels[entry.key] ?? entry.key: entry.value.length,
    };
    final periodDays = _periodDayCount(period, daily.keys);
    return WellnessInsights(
      sessions: sessions,
      totalWatchedMs: math.min(unionMs, sumMs),
      sumPlaybackMs: sumMs,
      movieMs: movieMs,
      episodeMs: episodeMs,
      liveMs: liveMs,
      completedMovies: completedMovieKeys.length,
      completedEpisodes: completedEpisodeKeys.length,
      uniqueSeries: seriesKeys.length,
      rewatches: rewatches,
      activeDays: activeDays,
      dailyWatchedMs: Map<DateTime, int>.unmodifiable(daily),
      hourOfWeekMs: List<List<int>>.unmodifiable(
        hourGrid.map(List<int>.unmodifiable),
      ),
      topTitles: _ranked(titleMs),
      topGenres: _ranked(genreMs),
      topLanguages: _ranked(languageMs),
      topCountries: _ranked(countryMs),
      topDecades: _ranked(decadeMs),
      topProviders: _ranked(providerMs),
      viewingSessionCount: grouped.$1,
      longestSessionMs: grouped.$2,
      dailyMediaMs: Map<DateTime, WellnessMediaSplit>.unmodifiable(dailyByType),
      topSeriesEpisodes: _ranked(seriesEpisodeCounts),
      titlesStarted: startedTitleKeys.length,
      sampledTitles: startedTitleKeys.difference(completedTitleKeys).length,
      periodDays: periodDays,
      networkBytes: networkBytes,
      networkMeasuredSessions: networkMeasuredSessions,
      networkMeasuredMs: networkMeasuredMs,
    );
  }

  static WellnessInsights empty() => WellnessInsights.fromSessions(
        const <WellnessViewingSession>[],
        period: WellnessPeriod(
          startUtc: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          endUtc: DateTime.fromMillisecondsSinceEpoch(1, isUtc: true),
        ),
      );
}

/// Days the period covers for consistency metrics: the calendar span, cut off
/// at the last recorded day so days that have not happened yet cannot count
/// against a streak, and measured from the first recorded day when the period
/// is unbounded.
int _periodDayCount(WellnessPeriod period, Iterable<DateTime> activeDays) {
  final days = activeDays.toList(growable: false)..sort();
  final startLocal = period.startUtc.toLocal();
  var start = DateTime(startLocal.year, startLocal.month, startLocal.day);
  if (period.unbounded && days.isNotEmpty) start = days.first;
  final endLocal = period.endUtc.toLocal();
  var end = DateTime(endLocal.year, endLocal.month, endLocal.day);
  if (days.isNotEmpty) {
    final afterLast = days.last.add(const Duration(days: 1));
    if (afterLast.isBefore(end)) end = afterLast;
  }
  // Hours, not days: a DST shift inside the span would otherwise round down.
  return math.max(1, (end.difference(start).inHours + 12) ~/ 24);
}

int _clippedSessionWatchedMs(
  WellnessViewingSession session,
  WellnessPeriod period,
) {
  if (session.segments.isNotEmpty) {
    return session.segments.fold<int>(0, (total, segment) {
      final start = segment.startedAtUtc.isBefore(period.startUtc)
          ? period.startUtc
          : segment.startedAtUtc;
      final end = segment.endedAtUtc.isAfter(period.endUtc)
          ? period.endUtc
          : segment.endedAtUtc;
      return total +
          (end.isAfter(start) ? end.difference(start).inMilliseconds : 0);
    });
  }
  final sessionSpan = math.max(
    1,
    session.endedAtUtc.difference(session.startedAtUtc).inMilliseconds,
  );
  final start = session.startedAtUtc.isBefore(period.startUtc)
      ? period.startUtc
      : session.startedAtUtc;
  final end = session.endedAtUtc.isAfter(period.endUtc)
      ? period.endUtc
      : session.endedAtUtc;
  final overlap = math.max(0, end.difference(start).inMilliseconds);
  return (session.watchedMs * overlap / sessionSpan).round();
}

void _addFallbackToCalendar(
  WellnessViewingSession session,
  int watchedMs,
  Map<DateTime, int> daily,
  List<List<int>> hourGrid,
  Map<DateTime, WellnessMediaSplit> dailyByType,
) {
  final local = session.startedAtUtc
      .add(Duration(minutes: session.timezoneOffsetMinutes));
  final day = DateTime(local.year, local.month, local.day);
  daily.update(day, (value) => value + watchedMs, ifAbsent: () => watchedMs);
  hourGrid[local.weekday - 1][local.hour] += watchedMs;
  dailyByType.update(
    day,
    (split) => split.addMs(session.mediaType, watchedMs),
    ifAbsent: () => WellnessMediaSplit.empty.addMs(session.mediaType, watchedMs),
  );
}

void _splitSegmentByLocalHour(
  DateTime startUtc,
  DateTime endUtc,
  int offsetMinutes,
  Map<DateTime, int> daily,
  List<List<int>> hourGrid,
  Map<DateTime, WellnessMediaSplit> dailyByType,
  WellnessMediaType mediaType,
) {
  var cursor = startUtc.add(Duration(minutes: offsetMinutes));
  final localEnd = endUtc.add(Duration(minutes: offsetMinutes));
  while (cursor.isBefore(localEnd)) {
    final nextHour = DateTime.utc(
      cursor.year,
      cursor.month,
      cursor.day,
      cursor.hour + 1,
    );
    final sliceEnd = nextHour.isBefore(localEnd) ? nextHour : localEnd;
    final watchedMs = sliceEnd.difference(cursor).inMilliseconds;
    final day = DateTime(cursor.year, cursor.month, cursor.day);
    daily.update(day, (value) => value + watchedMs, ifAbsent: () => watchedMs);
    hourGrid[cursor.weekday - 1][cursor.hour] += watchedMs;
    dailyByType.update(
      day,
      (split) => split.addMs(mediaType, watchedMs),
      ifAbsent: () => WellnessMediaSplit.empty.addMs(mediaType, watchedMs),
    );
    cursor = sliceEnd;
  }
}

int _unionDurationMs(List<_Interval> intervals) {
  if (intervals.isEmpty) return 0;
  intervals.sort((a, b) => a.start.compareTo(b.start));
  var start = intervals.first.start;
  var end = intervals.first.end;
  var total = 0;
  for (final interval in intervals.skip(1)) {
    if (!interval.start.isAfter(end)) {
      if (interval.end.isAfter(end)) end = interval.end;
      continue;
    }
    total += end.difference(start).inMilliseconds;
    start = interval.start;
    end = interval.end;
  }
  return total + end.difference(start).inMilliseconds;
}

List<WellnessRankedValue> _ranked(Map<String, int> values) {
  final ranked = values.entries
      .map((entry) => WellnessRankedValue(entry.key, entry.value))
      .toList(growable: false)
    ..sort((a, b) => b.value.compareTo(a.value));
  return List<WellnessRankedValue>.unmodifiable(ranked);
}

class _Interval {
  const _Interval(this.start, this.end);

  final DateTime start;
  final DateTime end;
}

class _PlaybackInterval extends _Interval {
  const _PlaybackInterval(super.start, super.end, this.titleKey);

  final String titleKey;
}

/// Counts overlapping rewatches of one title independently while collapsing
/// overlapping playback of different titles to one real-world time slice.
int _titleAwarePlaybackDurationMs(List<_PlaybackInterval> intervals) {
  if (intervals.isEmpty) return 0;
  final events = <DateTime, List<_PlaybackEvent>>{};
  for (final interval in intervals) {
    events.putIfAbsent(interval.start, () => <_PlaybackEvent>[]).add(
          _PlaybackEvent(interval.titleKey, 1),
        );
    events.putIfAbsent(interval.end, () => <_PlaybackEvent>[]).add(
          _PlaybackEvent(interval.titleKey, -1),
        );
  }
  final points = events.keys.toList()..sort();
  final active = <String, int>{};
  var total = 0;
  for (var index = 0; index < points.length - 1; index++) {
    final point = points[index];
    for (final event in events[point]!) {
      final next = (active[event.titleKey] ?? 0) + event.delta;
      if (next <= 0) {
        active.remove(event.titleKey);
      } else {
        active[event.titleKey] = next;
      }
    }
    final nextPoint = points[index + 1];
    if (active.isNotEmpty && nextPoint.isAfter(point)) {
      final playbackCount = active.values.fold<int>(
        0,
        (maximum, count) => count > maximum ? count : maximum,
      );
      total += nextPoint.difference(point).inMilliseconds * playbackCount;
    }
  }
  return total;
}

class _PlaybackEvent {
  const _PlaybackEvent(this.titleKey, this.delta);

  final String titleKey;
  final int delta;
}

(int, int) _groupedViewingSessions(
  List<WellnessViewingSession> sessions,
  WellnessPeriod period,
) {
  if (sessions.isEmpty) return (0, 0);
  final ordered = sessions.toList()
    ..sort((a, b) => a.startedAtUtc.compareTo(b.startedAtUtc));
  var count = 0;
  var longestMs = 0;
  var groupEnd = period.startUtc;
  var groupIntervals = <_Interval>[];
  var groupFallbackMs = 0;

  void closeGroup() {
    if (groupIntervals.isEmpty && groupFallbackMs == 0) return;
    count++;
    longestMs = math.max(
      longestMs,
      _unionDurationMs(groupIntervals) + groupFallbackMs,
    );
    groupIntervals = <_Interval>[];
    groupFallbackMs = 0;
  }

  for (final session in ordered) {
    if (session.startedAtUtc.difference(groupEnd) >
        const Duration(minutes: 30)) {
      closeGroup();
    }
    if (session.endedAtUtc.isAfter(groupEnd)) groupEnd = session.endedAtUtc;
    if (session.segments.isEmpty) {
      groupFallbackMs += _clippedSessionWatchedMs(session, period);
      continue;
    }
    for (final segment in session.segments) {
      final start = segment.startedAtUtc.isBefore(period.startUtc)
          ? period.startUtc
          : segment.startedAtUtc;
      final end = segment.endedAtUtc.isAfter(period.endUtc)
          ? period.endUtc
          : segment.endedAtUtc;
      if (end.isAfter(start)) groupIntervals.add(_Interval(start, end));
    }
  }
  closeGroup();
  return (count, longestMs);
}
