import 'package:flutter_test/flutter_test.dart';
import 'package:flixquest/functions/live_playback_policy.dart';
import 'package:flixquest/models/live_tv.dart';

void main() {
  test('live startup and refill thresholds fit a bounded forward-only buffer',
      () {
    expect(liveBufferingConfiguration.bufferForPlaybackMs, 1500);
    expect(liveBufferingConfiguration.bufferForPlaybackAfterRebufferMs, 3000);
    expect(liveBufferingConfiguration.minBufferMs, 10000);
    expect(liveBufferingConfiguration.maxBufferMs, 30000);
    expect(liveBufferingConfiguration.backBufferDurationMs, 0);
  });

  test(
      'silent stalled playback triggers after 25 seconds without useful progress',
      () {
    final watchdog = LivePlaybackWatchdog();
    bool sample(int seconds) => watchdog.observe(
          elapsed: Duration(seconds: seconds),
          position: const Duration(seconds: 10),
          bufferedAhead: Duration.zero,
          shouldPlay: true,
        );
    expect(sample(0), isFalse);
    expect(sample(24), isFalse);
    expect(sample(25), isTrue);
    expect(sample(26), isFalse);
  });

  test('growing startup buffer gets time but cannot suppress recovery forever',
      () {
    final watchdog = LivePlaybackWatchdog();
    for (var seconds = 0; seconds <= 60; seconds += 10) {
      expect(
          watchdog.observe(
            elapsed: Duration(seconds: seconds),
            position: Duration.zero,
            bufferedAhead: Duration(milliseconds: seconds * 50),
            shouldPlay: true,
          ),
          seconds == 60);
    }
  });

  test(
      'intentional pause resets the watchdog and resume starts a fresh interval',
      () {
    final watchdog = LivePlaybackWatchdog();
    for (final seconds in [0, 20, 100, 120]) {
      expect(
          watchdog.observe(
            elapsed: Duration(seconds: seconds),
            position: Duration.zero,
            bufferedAhead: Duration.zero,
            shouldPlay: seconds != 20,
          ),
          isFalse);
    }
  });

  test('a moving live window and source changes do not cause false stalls', () {
    final watchdog = LivePlaybackWatchdog();
    for (var seconds = 0; seconds < 100; seconds += 10) {
      expect(
          watchdog.observe(
            elapsed: Duration(seconds: seconds),
            position: Duration(seconds: seconds % 30),
            bufferedAhead: const Duration(seconds: 3),
            shouldPlay: true,
          ),
          isFalse);
    }
    watchdog.reset();
    expect(
        watchdog.observe(
          elapsed: const Duration(seconds: 200),
          position: Duration.zero,
          bufferedAhead: Duration.zero,
          shouldPlay: true,
        ),
        isFalse);
  });

  test('backup streams advance once in advertised order', () {
    final queue = LiveStreamFailoverQueue()
      ..replace(
        <LiveStreamVariant>[
          _variant('one'),
          _variant('two'),
          _variant('three'),
        ],
        currentUrl: 'one',
      );

    expect(queue.next()?.url, 'two');
    expect(queue.next()?.url, 'three');
    expect(queue.next(), isNull);
    expect(queue.next(), isNull);
  });

  test('fresh resolution resets failover and preserves provider order', () {
    final queue = LiveStreamFailoverQueue()
      ..replace(<LiveStreamVariant>[_variant('old')], currentUrl: 'old');
    expect(queue.next(), isNull);

    queue.replace(
      <LiveStreamVariant>[
        _variant('fresh-one', title: 'Stream 1'),
        _variant('fresh-one', title: 'Stream 2'),
        _variant('fresh-two'),
      ],
      currentUrl: 'fresh-one',
    );

    expect(queue.next()?.title, 'Stream 2');
    expect(queue.next()?.url, 'fresh-two');
    expect(queue.next(), isNull);
  });
}

LiveStreamVariant _variant(String url, {String? title}) => LiveStreamVariant(
      url: url,
      headers: const <String, String>{},
      mediaType: 'hls',
      title: title ?? url,
    );
