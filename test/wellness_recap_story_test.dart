import 'package:flixquest/models/wellness.dart';
import 'package:flixquest/models/wellness_insights.dart';
import 'package:flixquest/models/wellness_recap.dart';
import 'package:flixquest/models/wellness_recap_story.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 6, 21);
  final october = WellnessRecapPeriod.month(DateTime(2026, 10), now);

  WellnessRecapStory storyOf(
    List<WellnessViewingSession> sessions, [
    WellnessRecapPeriod? period,
  ]) {
    final target = period ?? october;
    return WellnessRecapStory.of(
      WellnessInsights.fromSessions(sessions, period: target.wellnessPeriod),
      target,
    );
  }

  group('viewer type', () {
    test('needs enough viewing to claim anything', () {
      final story = storyOf([
        _session('a', DateTime(2026, 10, 3, 23), minutes: 40),
        _session('b', DateTime(2026, 10, 4, 23), minutes: 40),
      ]);
      expect(story.profile, isNull);
    });

    test('a single day never gets one', () {
      final day = WellnessRecapPeriod.today(DateTime(2026, 10, 3, 23));
      final story = storyOf([
        for (var hour = 0; hour < 4; hour++)
          _session('s$hour', DateTime(2026, 10, 3, hour), minutes: 50),
      ], day);
      expect(story.profile, isNull);
    });

    test('late-night viewing earns the night owl with its share', () {
      final story = storyOf([
        for (var day = 1; day <= 4; day++)
          _session('late$day', DateTime(2026, 10, day * 3, 23), minutes: 90),
        _session('day', DateTime(2026, 10, 20, 14), minutes: 60),
      ]);
      expect(story.profile?.type, WellnessViewerType.nightOwl);
      // 360 of 420 minutes.
      expect(story.profile?.value, 86);
    });

    test('the most distinctive habit wins, not the first one checked', () {
      // Slightly over the night-owl bar, far past the rewatch bar.
      final story = storyOf([
        for (var i = 0; i < 7; i++)
          _session(
            'rewatch$i',
            DateTime(2026, 10, 2 + i * 3, 23),
            minutes: 45,
            title: 'Comfort',
            contentId: 'comfort',
            completed: true,
          ),
        for (var i = 0; i < 7; i++)
          _session('noon$i', DateTime(2026, 10, 3 + i * 3, 13), minutes: 70),
      ]);
      expect(story.profile?.type, WellnessViewerType.comfortRewatcher);
      expect(story.profile?.value, 6);
    });

    test('ordinary viewing still gets a type, with its typical day', () {
      final story = storyOf([
        for (final (day, hour) in [(2, 18), (9, 19), (15, 13), (23, 20)])
          _session('s$day', DateTime(2026, 10, day, hour), minutes: 60),
      ]);
      expect(story.profile?.type, WellnessViewerType.storyChaser);
      expect(
        story.profile?.value,
        const Duration(hours: 1).inMilliseconds,
      );
    });
  });

  group('titles', () {
    test('keep rank order and the newest artwork any session recorded', () {
      final story = storyOf([
        _session('old', DateTime(2026, 10, 2, 20),
            title: 'First', minutes: 100, poster: '/old.jpg'),
        _session('new', DateTime(2026, 10, 9, 20),
            title: 'First', minutes: 100, poster: '/new.jpg'),
        _session('download', DateTime(2026, 10, 10, 20),
            title: 'First', minutes: 10),
        _session('other', DateTime(2026, 10, 3, 20),
            title: 'Second', minutes: 30, poster: '/second.jpg'),
      ]);
      expect(story.titles.map((title) => title.title), ['First', 'Second']);
      expect(story.titles.first.posterPath, '/new.jpg');
    });

    test('posters skip titles without art and the background falls back', () {
      final story = storyOf([
        _session('a', DateTime(2026, 10, 2, 20), title: 'No art', minutes: 90),
        _session('b', DateTime(2026, 10, 3, 20),
            title: 'Art', minutes: 30, poster: '/art.jpg'),
      ]);
      expect(story.postersUpTo(3).map((title) => title.title), ['Art']);
      expect(story.backgroundPath, '/art.jpg');
    });

    test('live channels never become titles or artwork', () {
      final story = storyOf([
        _session('live', DateTime(2026, 10, 2, 20),
            title: 'Channel', minutes: 90, type: WellnessMediaType.live),
      ]);
      expect(story.titles, isEmpty);
      expect(story.backgroundPath, isNull);
    });
  });

  group('stats', () {
    List<WellnessRecapStatKind> kinds(
      WellnessRecapStory story, {
      bool habits = true,
    }) =>
        story
            .stats(includeHabits: habits)
            .map((stat) => stat.kind)
            .toList(growable: false);

    test('one finished film does not repeat itself', () {
      final day = WellnessRecapPeriod.today(DateTime(2026, 10, 3, 23));
      final story = storyOf([
        _session('a', DateTime(2026, 10, 3, 20), minutes: 95, completed: true),
      ], day);
      // No "1 titles", and no longest sitting equal to the headline total.
      expect(kinds(story), [WellnessRecapStatKind.finished]);
    });

    test('habits off drops streak and longest sitting', () {
      final story = storyOf([
        for (var day = 1; day <= 4; day++)
          _session('s$day', DateTime(2026, 10, day, 20), minutes: 60),
      ]);
      expect(kinds(story), contains(WellnessRecapStatKind.streak));
      expect(kinds(story), contains(WellnessRecapStatKind.longestSitting));
      final private = kinds(story, habits: false);
      expect(private, isNot(contains(WellnessRecapStatKind.streak)));
      expect(private, isNot(contains(WellnessRecapStatKind.longestSitting)));
    });

    test('the viewer type line is not said twice', () {
      final story = storyOf([
        for (var day = 1; day <= 10; day++)
          _session('s$day', DateTime(2026, 10, day, 20),
              minutes: 60, completed: true),
      ]);
      expect(story.profile?.type, WellnessViewerType.streakKeeper);
      expect(kinds(story), isNot(contains(WellnessRecapStatKind.streak)));
      // Nor as active days, when every one of them is in the streak.
      expect(kinds(story), isNot(contains(WellnessRecapStatKind.activeDays)));
    });
  });

  group('rhythm', () {
    test('a month has a bar per day, adding up to the headline', () {
      final story = storyOf([
        _session('a', DateTime(2026, 10, 1, 20), minutes: 60),
        _session('b', DateTime(2026, 10, 31, 20), minutes: 30),
      ]);
      expect(story.bars, hasLength(31));
      expect(story.bars.first.watchedMs, 60 * 60000);
      expect(story.bars.last.watchedMs, 30 * 60000);
      expect(story.bars.first.label, '1');
      expect(story.bars[1].label, isEmpty);
      expect(
        story.bars.fold<int>(0, (sum, bar) => sum + bar.watchedMs),
        story.totalWatchedMs,
      );
    });

    test('February has as many bars as days', () {
      final february = WellnessRecapPeriod.month(DateTime(2026, 2), now);
      expect(storyOf(const [], february).bars, hasLength(28));
    });
  });

  test('formatWatchedTime drops the empty part', () {
    expect(formatWatchedTime(0), '0m');
    expect(formatWatchedTime(45 * 60000), '45m');
    expect(formatWatchedTime(120 * 60000), '2h');
    expect(formatWatchedTime(135 * 60000), '2h 15m');
  });
}

WellnessViewingSession _session(
  String id,
  DateTime localStart, {
  int minutes = 60,
  String? title,
  String? contentId,
  String? poster,
  bool completed = false,
  WellnessMediaType type = WellnessMediaType.movie,
}) {
  final end = localStart.add(Duration(minutes: minutes));
  final watchedMs = minutes * 60000;
  return WellnessViewingSession(
    id: id,
    ownerId: 'guest',
    deviceId: 'device',
    mediaType: type,
    source: type == WellnessMediaType.live
        ? WellnessPlaybackSource.live
        : WellnessPlaybackSource.streaming,
    contentId: contentId ?? id,
    title: title ?? 'Title $id',
    startedAtUtc: localStart.toUtc(),
    endedAtUtc: end.toUtc(),
    timezoneOffsetMinutes: localStart.timeZoneOffset.inMinutes,
    watchedMs: watchedMs,
    durationMs: watchedMs,
    progressEndMs: watchedMs,
    completed: completed,
    posterPath: poster,
    segments: [
      WellnessPlaybackSegment(
        startedAtUtc: localStart.toUtc(),
        endedAtUtc: end.toUtc(),
      ),
    ],
    updatedAtUtc: end.toUtc(),
  );
}
