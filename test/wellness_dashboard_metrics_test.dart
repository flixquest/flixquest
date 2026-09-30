import 'package:flixquest/models/wellness.dart';
import 'package:flixquest/models/wellness_insights.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final period = WellnessPeriod(
    startUtc: DateTime.utc(2026, 9, 1),
    endUtc: DateTime.utc(2026, 10, 1),
  );

  test('sources and devices use qualifying, clipped playback', () {
    final insights = WellnessInsights.fromSessions([
      _session('stream',
          start: DateTime.utc(2026, 8, 31, 23), minutes: 120, bytes: 2048),
      _session('offline',
          start: DateTime.utc(2026, 9, 1, 1),
          source: WellnessPlaybackSource.offline,
          device: 'second'),
      _session('live',
          start: DateTime.utc(2026, 9, 1, 2),
          source: WellnessPlaybackSource.live,
          type: WellnessMediaType.live,
          device: ''),
      _session('deleted',
              start: DateTime.utc(2026, 9, 1, 3), device: 'deleted-device')
          .copyWith(deletedAtUtc: DateTime.utc(2026, 9, 2)),
      _session('short',
          start: DateTime.utc(2026, 9, 1, 3),
          minutes: 0,
          device: 'short-device'),
    ], period: period);
    const hour = 3600000;
    expect(insights.sourceWatchedMs, {
      WellnessPlaybackSource.streaming: hour,
      WellnessPlaybackSource.offline: hour,
      WellnessPlaybackSource.live: hour,
    });
    expect(insights.deviceCount, 2);
    expect(insights.networkBytes, 1024);
    expect(insights.networkCoverage, closeTo(1 / 3, .0001));
    expect(insights.sourceWatchedMs.values.reduce((a, b) => a + b),
        insights.sumPlaybackMs);
  });

  test('measurement coverage uses playback sum for concurrent streams', () {
    final insights = WellnessInsights.fromSessions([
      _session('one', start: DateTime.utc(2026, 9, 1, 20), bytes: 0),
      _session('two', start: DateTime.utc(2026, 9, 1, 20)),
    ], period: period);
    expect(insights.totalWatchedMs, 3600000);
    expect(insights.sumPlaybackMs, 7200000);
    expect(insights.hasNetworkUsage, isTrue);
    expect(insights.networkCoverage, .5);
    expect(insights.networkBytes, 0);
  });

  test('discovery uses title identity and only eligible earlier history', () {
    final insights = WellnessInsights.fromSessions([
      _session('old', titleId: 'returning', start: DateTime.utc(2026, 8, 20)),
      _session('resume', titleId: 'returning', start: DateTime.utc(2026, 9, 2)),
      _session('new', titleId: 'new', start: DateTime.utc(2026, 9, 3)),
      _session('new-again', titleId: 'new', start: DateTime.utc(2026, 9, 4)),
      _session('old-deleted',
              titleId: 'deleted', start: DateTime.utc(2026, 8, 20))
          .copyWith(deletedAtUtc: DateTime.utc(2026, 8, 21)),
      _session('now-deleted',
          titleId: 'deleted', start: DateTime.utc(2026, 9, 5)),
      _session('old-short',
          titleId: 'short', start: DateTime.utc(2026, 8, 20), minutes: 0),
      _session('now-short', titleId: 'short', start: DateTime.utc(2026, 9, 6)),
      _session('episode',
          titleId: 'new',
          start: DateTime.utc(2026, 9, 7),
          type: WellnessMediaType.episode),
      _session('live',
          start: DateTime.utc(2026, 9, 8), type: WellnessMediaType.live),
    ], period: period);
    expect(insights.titlesStarted, 5);
    expect(insights.firstTimeTitles, 4);
    expect(insights.returningTitles, 1);
  });

  test('a straddling session is returning only if playback started earlier',
      () {
    final start = DateTime.utc(2026, 8, 31, 23);
    final straddling = _session('straddling', start: start, minutes: 120);
    final delayed = WellnessViewingSession.fromMap(straddling.toCloudMap()
      ..['id'] = 'delayed'
      ..['contentId'] = 'delayed'
      ..['watchedMs'] = 3600000
      ..['segments'] = [
        WellnessPlaybackSegment(
          startedAtUtc: DateTime.utc(2026, 9, 1),
          endedAtUtc: DateTime.utc(2026, 9, 1, 1),
        ).toMap()
      ]);
    final insights =
        WellnessInsights.fromSessions([straddling, delayed], period: period);
    expect(insights.firstTimeTitles, 1);
    expect(insights.returningTitles, 1);
  });

  test('all-time discovery and empty history stay bounded', () {
    final insights = WellnessInsights.fromSessions([
      _session('old', start: DateTime.utc(2026, 8, 20)),
      _session('old-again', titleId: 'old', start: DateTime.utc(2026, 9, 3)),
    ],
        period: WellnessPeriod.forRange(
            WellnessRange.allTime, DateTime(2026, 9, 30)));
    expect(insights.firstTimeTitles, 1);
    expect(insights.returningTitles, 0);
    final empty = WellnessInsights.empty();
    expect(empty.sourceWatchedMs, isEmpty);
    expect(empty.deviceCount, 0);
    expect(empty.networkCoverage, 0);
    expect(empty.firstTimeTitles, 0);
  });
}

WellnessViewingSession _session(
  String id, {
  required DateTime start,
  String? titleId,
  int minutes = 60,
  String device = 'first',
  WellnessMediaType type = WellnessMediaType.movie,
  WellnessPlaybackSource source = WellnessPlaybackSource.streaming,
  int? bytes,
}) {
  final end = start.add(Duration(minutes: minutes));
  final ms = end.difference(start).inMilliseconds;
  return WellnessViewingSession(
    id: id,
    ownerId: 'guest',
    deviceId: device,
    mediaType: type,
    source: source,
    contentId: titleId ?? id,
    title: 'Shared title',
    startedAtUtc: start,
    endedAtUtc: end,
    timezoneOffsetMinutes: 0,
    watchedMs: ms,
    durationMs: ms,
    progressEndMs: ms,
    completed: false,
    segments: [WellnessPlaybackSegment(startedAtUtc: start, endedAtUtc: end)],
    networkBytes: bytes,
    updatedAtUtc: end,
  );
}
