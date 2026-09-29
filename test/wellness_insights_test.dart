import 'package:flixquest/models/wellness.dart';
import 'package:flixquest/models/wellness_insights.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WellnessPlaybackTracker', () {
    test('counts active playback and excludes pauses', () {
      final tracker = WellnessPlaybackTracker(
        id: 'session',
        createdAt: DateTime.utc(2026, 8, 20, 18),
      );
      tracker.play(DateTime.utc(2026, 8, 20, 18));
      tracker.pause(DateTime.utc(2026, 8, 20, 18, 10));
      tracker.play(DateTime.utc(2026, 8, 20, 18, 30));
      tracker.pause(DateTime.utc(2026, 8, 20, 18, 35));

      expect(tracker.watchedMs(), const Duration(minutes: 15).inMilliseconds);
      expect(tracker.snapshot(), hasLength(2));
    });
  });

  group('WellnessInsights', () {
    final period = WellnessPeriod(
      startUtc: DateTime.utc(2026, 8, 17),
      endUtc: DateTime.utc(2026, 8, 24),
    );

    test('unions simultaneous playback for the headline total', () {
      final first = _session(
        id: 'one',
        contentId: '1',
        title: 'First',
        start: DateTime.utc(2026, 8, 20, 18),
        end: DateTime.utc(2026, 8, 20, 19),
      );
      final second = _session(
        id: 'two',
        contentId: '2',
        title: 'Second',
        start: DateTime.utc(2026, 8, 20, 18, 30),
        end: DateTime.utc(2026, 8, 20, 19, 30),
      );

      final insights = WellnessInsights.fromSessions(
        <WellnessViewingSession>[first, second],
        period: period,
      );

      expect(insights.sumPlaybackMs, const Duration(hours: 2).inMilliseconds);
      expect(
        insights.totalWatchedMs,
        const Duration(minutes: 90).inMilliseconds,
      );
    });

    test('adds repeated playback of the same title to the headline total', () {
      final first = _session(
        id: 'rewatch-1',
        contentId: 'same-title',
        title: 'Arrival',
        start: DateTime.utc(2026, 8, 20, 18),
        end: DateTime.utc(2026, 8, 20, 19),
      );
      final second = _session(
        id: 'rewatch-2',
        contentId: 'same-title',
        title: 'Arrival',
        start: DateTime.utc(2026, 8, 20, 18),
        end: DateTime.utc(2026, 8, 20, 19),
      );

      final insights = WellnessInsights.fromSessions(
        <WellnessViewingSession>[first, second],
        period: period,
      );

      expect(
        insights.totalWatchedMs,
        const Duration(hours: 2).inMilliseconds,
      );
    });

    test('tracks unique completions, series, and rewatches separately', () {
      final sessions = <WellnessViewingSession>[
        _session(
          id: 'movie-1',
          contentId: '10',
          title: 'Arrival',
          start: DateTime.utc(2026, 8, 18, 18),
          end: DateTime.utc(2026, 8, 18, 20),
          completed: true,
        ),
        _session(
          id: 'movie-2',
          contentId: '10',
          title: 'Arrival',
          start: DateTime.utc(2026, 8, 19, 18),
          end: DateTime.utc(2026, 8, 19, 20),
          completed: true,
        ),
        _session(
          id: 'episode-1',
          contentId: 'episode-1',
          seriesId: 'show-1',
          title: 'Severance',
          start: DateTime.utc(2026, 8, 20, 18),
          end: DateTime.utc(2026, 8, 20, 19),
          mediaType: WellnessMediaType.episode,
          completed: true,
        ),
      ];

      final insights = WellnessInsights.fromSessions(sessions, period: period);

      expect(insights.completedMovies, 1);
      expect(insights.completedEpisodes, 1);
      expect(insights.uniqueSeries, 1);
      expect(insights.rewatches, 1);
    });

    test('groups nearby titles into one viewing session', () {
      final sessions = <WellnessViewingSession>[
        _session(
          id: 'episode-1',
          contentId: 'episode-1',
          title: 'Show',
          start: DateTime.utc(2026, 8, 20, 18),
          end: DateTime.utc(2026, 8, 20, 18, 30),
          mediaType: WellnessMediaType.episode,
        ),
        _session(
          id: 'episode-2',
          contentId: 'episode-2',
          title: 'Show',
          start: DateTime.utc(2026, 8, 20, 18, 45),
          end: DateTime.utc(2026, 8, 20, 19, 15),
          mediaType: WellnessMediaType.episode,
        ),
        _session(
          id: 'movie',
          contentId: 'movie',
          title: 'Later',
          start: DateTime.utc(2026, 8, 20, 21),
          end: DateTime.utc(2026, 8, 20, 22),
        ),
      ];

      final insights = WellnessInsights.fromSessions(sessions, period: period);

      expect(insights.sessionCount, 2);
      expect(
        insights.longestSessionMs,
        const Duration(hours: 1).inMilliseconds,
      );
    });

    test('ignores playback shorter than thirty seconds', () {
      final tiny = _session(
        id: 'tiny',
        contentId: '1',
        title: 'Preview',
        start: DateTime.utc(2026, 8, 20, 18),
        end: DateTime.utc(2026, 8, 20, 18, 0, 29),
      );

      final insights = WellnessInsights.fromSessions(<WellnessViewingSession>[
        tiny,
      ], period: period);

      expect(insights.isEmpty, isTrue);
    });

    test('splits active time across local midnight', () {
      final session = _session(
        id: 'midnight',
        contentId: '1',
        title: 'Late movie',
        start: DateTime.utc(2026, 8, 20, 20, 30),
        end: DateTime.utc(2026, 8, 20, 21, 30),
        timezoneOffsetMinutes: 180,
      );

      final insights = WellnessInsights.fromSessions(
        <WellnessViewingSession>[session],
        period: period,
      );

      expect(
        insights.dailyWatchedMs[DateTime(2026, 8, 20)],
        const Duration(minutes: 30).inMilliseconds,
      );
      expect(
        insights.dailyWatchedMs[DateTime(2026, 8, 21)],
        const Duration(minutes: 30).inMilliseconds,
      );
    });
  });

  group('WellnessInsights derived patterns', () {
    final period = WellnessPeriod(
      startUtc: DateTime.utc(2026, 8, 17),
      endUtc: DateTime.utc(2026, 8, 24),
    );

    test('indexes the hour grid from Monday', () {
      // 2026-08-17 is a Monday; 2026-08-23 is the Sunday that closes the week.
      final insights = WellnessInsights.fromSessions(
        [
          _session(
            id: 'monday',
            contentId: 'a',
            title: 'Monday night',
            start: DateTime.utc(2026, 8, 17, 21),
            end: DateTime.utc(2026, 8, 17, 22),
          ),
          _session(
            id: 'sunday',
            contentId: 'b',
            title: 'Sunday morning',
            start: DateTime.utc(2026, 8, 23, 9),
            end: DateTime.utc(2026, 8, 23, 9, 30),
          ),
        ],
        period: period,
      );

      expect(insights.hourOfWeekMs, hasLength(7));
      expect(insights.hourOfWeekMs.first, hasLength(24));
      expect(
        insights.hourOfWeekMs[0][21],
        const Duration(hours: 1).inMilliseconds,
      );
      expect(
        insights.hourOfWeekMs[6][9],
        const Duration(minutes: 30).inMilliseconds,
      );
      expect(insights.peakHourOfWeek, (0, 21, const Duration(hours: 1).inMilliseconds));
    });

    test('splits the day into morning, afternoon, evening and late night', () {
      final insights = WellnessInsights.fromSessions(
        [
          _session(
            id: 'morning',
            contentId: 'a',
            title: 'Morning',
            start: DateTime.utc(2026, 8, 18, 7),
            end: DateTime.utc(2026, 8, 18, 8),
          ),
          _session(
            id: 'afternoon',
            contentId: 'b',
            title: 'Afternoon',
            start: DateTime.utc(2026, 8, 18, 14),
            end: DateTime.utc(2026, 8, 18, 14, 30),
          ),
          _session(
            id: 'evening',
            contentId: 'c',
            title: 'Evening',
            start: DateTime.utc(2026, 8, 18, 19),
            end: DateTime.utc(2026, 8, 18, 21),
          ),
          _session(
            id: 'late',
            contentId: 'd',
            title: 'Late',
            start: DateTime.utc(2026, 8, 18, 23),
            end: DateTime.utc(2026, 8, 18, 23, 45),
          ),
        ],
        period: period,
      );

      expect(insights.partOfDayMs, hasLength(4));
      expect(insights.partOfDayMs[0], const Duration(hours: 1).inMilliseconds);
      expect(
        insights.partOfDayMs[1],
        const Duration(minutes: 30).inMilliseconds,
      );
      expect(insights.partOfDayMs[2], const Duration(hours: 2).inMilliseconds);
      expect(
        insights.partOfDayMs[3],
        const Duration(minutes: 45).inMilliseconds,
      );
      // Late night is the same 22:00–05:00 window the meter reports.
      expect(
        insights.lateNightMs,
        const Duration(minutes: 45).inMilliseconds,
      );
    });

    test('separates weekday from weekend viewing', () {
      final insights = WellnessInsights.fromSessions(
        [
          _session(
            id: 'friday',
            contentId: 'a',
            title: 'Friday',
            start: DateTime.utc(2026, 8, 21, 20),
            end: DateTime.utc(2026, 8, 21, 21),
          ),
          _session(
            id: 'saturday',
            contentId: 'b',
            title: 'Saturday',
            start: DateTime.utc(2026, 8, 22, 20),
            end: DateTime.utc(2026, 8, 22, 23),
          ),
        ],
        period: period,
      );

      expect(insights.weekdayWatchedMs, const Duration(hours: 1).inMilliseconds);
      expect(insights.weekendWatchedMs, const Duration(hours: 3).inMilliseconds);
      expect(insights.busiestDay?.$1, DateTime(2026, 8, 22));
      expect(insights.busiestDay?.$2, const Duration(hours: 3).inMilliseconds);
    });

    test('measures streaks over consecutive days', () {
      final insights = WellnessInsights.fromSessions(
        [
          for (final day in [17, 18, 19, 22, 23])
            _session(
              id: 'day-$day',
              contentId: 'c-$day',
              title: 'Day $day',
              start: DateTime.utc(2026, 8, day, 20),
              end: DateTime.utc(2026, 8, day, 21),
            ),
        ],
        period: period,
      );

      expect(insights.longestStreakDays, 3);
      expect(insights.activeDays, 5);
      expect(insights.periodDays, 7);
      // Counted from the day given, so a broken run reads as zero.
      expect(insights.currentStreakDays(DateTime(2026, 8, 23)), 2);
      expect(insights.currentStreakDays(DateTime(2026, 8, 24)), 2);
      expect(insights.currentStreakDays(DateTime(2026, 8, 26)), 0);
    });

    test('reports typical days and sessions rather than only totals', () {
      final insights = WellnessInsights.fromSessions(
        [
          _session(
            id: 'short',
            contentId: 'a',
            title: 'Short',
            start: DateTime.utc(2026, 8, 17, 20),
            end: DateTime.utc(2026, 8, 17, 21),
          ),
          _session(
            id: 'medium',
            contentId: 'b',
            title: 'Medium',
            start: DateTime.utc(2026, 8, 18, 20),
            end: DateTime.utc(2026, 8, 18, 22),
          ),
          _session(
            id: 'long',
            contentId: 'c',
            title: 'Long',
            start: DateTime.utc(2026, 8, 19, 20),
            end: DateTime.utc(2026, 8, 19, 23),
          ),
        ],
        period: period,
      );

      expect(insights.activeDays, 3);
      // The window stops the day after the last recorded viewing, so a week
      // that is only half over is not counted as half-idle.
      expect(insights.periodDays, 3);
      expect(insights.activeDayShare, 1);
      expect(
        insights.medianActiveDayMs,
        const Duration(hours: 2).inMilliseconds,
      );
      expect(
        insights.averageSessionMs,
        const Duration(hours: 2).inMilliseconds,
      );
      expect(
        insights.longestSessionMs,
        const Duration(hours: 3).inMilliseconds,
      );
    });

    test('completion rate counts finished titles against started ones', () {
      final insights = WellnessInsights.fromSessions(
        [
          _session(
            id: 'finished',
            contentId: 'a',
            title: 'Finished',
            start: DateTime.utc(2026, 8, 17, 20),
            end: DateTime.utc(2026, 8, 17, 22),
            completed: true,
          ),
          _session(
            id: 'unfinished',
            contentId: 'b',
            title: 'Unfinished',
            start: DateTime.utc(2026, 8, 18, 20),
            end: DateTime.utc(2026, 8, 18, 21),
          ),
        ],
        period: period,
      );

      expect(insights.titlesStarted, 2);
      expect(insights.completedTitles, 1);
      expect(insights.completionRate, closeTo(.5, .0001));
    });

    test('reads as empty rather than throwing with no sessions', () {
      final insights = WellnessInsights.fromSessions(
        const <WellnessViewingSession>[],
        period: period,
      );

      expect(insights.totalWatchedMs, 0);
      expect(insights.partOfDayMs, [0, 0, 0, 0]);
      expect(insights.peakHourOfWeek, isNull);
      expect(insights.busiestDay, isNull);
      expect(insights.completionRate, 0);
      expect(insights.activeDayShare, 0);
      expect(insights.medianActiveDayMs, 0);
      expect(insights.averageSessionMs, 0);
      expect(insights.currentStreakDays(DateTime(2026, 8, 23)), 0);
      expect(insights.longestStreakDays, 0);
      expect(insights.hasNetworkUsage, isFalse);
      expect(insights.networkBytesPerHour, 0);
    });

    test('adds up network data only from sessions that measured it', () {
      final insights = WellnessInsights.fromSessions(
        <WellnessViewingSession>[
          _session(
            id: 'measured',
            contentId: 'a',
            title: 'Measured',
            start: DateTime.utc(2026, 8, 18, 20),
            end: DateTime.utc(2026, 8, 18, 22),
            networkBytes: 3000,
          ),
          _session(
            id: 'before-tracking',
            contentId: 'b',
            title: 'Before tracking',
            start: DateTime.utc(2026, 8, 19, 20),
            end: DateTime.utc(2026, 8, 19, 21),
          ),
        ],
        period: period,
      );

      expect(insights.hasNetworkUsage, isTrue);
      expect(insights.networkMeasuredSessions, 1);
      expect(insights.networkBytes, 3000);
      expect(insights.networkBytesPerHour, 1500);
    });

    test('counts a session straddling the period by its share inside', () {
      final insights = WellnessInsights.fromSessions(
        <WellnessViewingSession>[
          _session(
            id: 'straddles',
            contentId: 'a',
            title: 'Late show',
            start: DateTime.utc(2026, 8, 16, 23),
            end: DateTime.utc(2026, 8, 17, 1),
            networkBytes: 4000,
          ),
        ],
        period: period,
      );

      expect(insights.networkBytes, 2000);
      expect(insights.networkBytesPerHour, 2000);
    });
  });

  group('WellnessViewingSession network data', () {
    final session = _session(
      id: 'measured',
      contentId: 'a',
      title: 'Measured',
      start: DateTime.utc(2026, 8, 18, 20),
      end: DateTime.utc(2026, 8, 18, 21),
      networkBytes: 123456789,
    );

    test('survives the local and cloud round trips', () {
      expect(
        WellnessViewingSession.fromMap(session.toMap()).networkBytes,
        123456789,
      );
      expect(
        WellnessViewingSession.fromMap(session.toCloudMap()).networkBytes,
        123456789,
      );
      expect(session.copyWith(synced: true).networkBytes, 123456789);
    });

    test('reads records written before it was tracked as unmeasured', () {
      final legacy = session.toCloudMap()..remove('networkBytes');
      final legacyRow = session.toMap()..remove('network_bytes');

      expect(WellnessViewingSession.fromMap(legacy).networkBytes, isNull);
      expect(WellnessViewingSession.fromMap(legacyRow).networkBytes, isNull);
    });

    test('leaves the field out of cloud documents when unmeasured', () {
      final unmeasured = _session(
        id: 'unmeasured',
        contentId: 'a',
        title: 'Unmeasured',
        start: DateTime.utc(2026, 8, 18, 20),
        end: DateTime.utc(2026, 8, 18, 21),
      );

      expect(unmeasured.toCloudMap().containsKey('networkBytes'), isFalse);
    });
  });
}

WellnessViewingSession _session({
  required String id,
  required String contentId,
  required String title,
  required DateTime start,
  required DateTime end,
  String? seriesId,
  WellnessMediaType mediaType = WellnessMediaType.movie,
  bool completed = false,
  int timezoneOffsetMinutes = 0,
  int? networkBytes,
}) {
  final watchedMs = end.difference(start).inMilliseconds;
  return WellnessViewingSession(
    id: id,
    ownerId: 'guest',
    deviceId: 'device',
    mediaType: mediaType,
    source: WellnessPlaybackSource.streaming,
    contentId: contentId,
    seriesId: seriesId,
    title: title,
    startedAtUtc: start,
    endedAtUtc: end,
    timezoneOffsetMinutes: timezoneOffsetMinutes,
    watchedMs: watchedMs,
    durationMs: watchedMs,
    progressEndMs: watchedMs,
    completed: completed,
    segments: <WellnessPlaybackSegment>[
      WellnessPlaybackSegment(startedAtUtc: start, endedAtUtc: end),
    ],
    networkBytes: networkBytes,
    updatedAtUtc: end,
  );
}
