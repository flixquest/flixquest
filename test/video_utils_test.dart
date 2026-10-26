import 'package:flixquest/functions/video_utils.dart';
import 'package:flixquest/video_providers/common.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VideoUtils.videoQualityHeight', () {
    test('parses provider labels with codec and audio metadata', () {
      expect(VideoUtils.videoQualityHeight('480p AAC'), 480);
      expect(VideoUtils.videoQualityHeight('480 AAC'), 480);
      expect(VideoUtils.videoQualityHeight('1080P (HEVC/AAC)'), 1080);
    });

    test('parses dimensions and ignores audio bitrates', () {
      expect(VideoUtils.videoQualityHeight('1920x1080 • AAC 128'), 1080);
      expect(VideoUtils.videoQualityHeight('AAC 320 kbps'), isNull);
      expect(VideoUtils.videoQualityHeight('Auto'), isNull);
    });
  });

  group('VideoUtils.preferredVideoSource', () {
    final sources = <String, String>{
      '1080p HEVC': 'high',
      '480p AAC': 'medium',
      '360 AAC': 'low',
    };

    test('matches an exact parsed height', () {
      expect(VideoUtils.preferredVideoSource(sources, 1080)?.key, '1080p HEVC');
    });

    test('uses the highest source below a missing preferred height', () {
      expect(VideoUtils.preferredVideoSource(sources, 720)?.key, '480p AAC');
    });

    test('uses the smallest source when all exceed the preference', () {
      expect(VideoUtils.preferredVideoSource(sources, 240)?.key, '360 AAC');
    });

    test('prefers an explicitly automatic source for auto', () {
      final withAuto = {'1080p': 'high', 'Auto AAC': 'master'};
      expect(VideoUtils.preferredVideoSource(withAuto, 0)?.key, 'Auto AAC');
    });

    test('uses a safe measured quality when auto has no master playlist', () {
      final cinebyStyleSources = {
        'Voesx': 'alternate-host',
        'playhq': 'another-host',
        '480p': 'medium',
        '720p': 'balanced',
        '1080p': 'high',
        '2160p': 'ultra',
      };

      expect(
        VideoUtils.preferredVideoSource(cinebyStyleSources, 0)?.key,
        '720p',
      );
    });

    test('uses the closest lower quality for automatic fallback', () {
      final sourcesWithout720p = {
        'Provider fallback': 'alternate-host',
        '480p': 'medium',
        '1080p': 'high',
      };

      expect(
        VideoUtils.preferredVideoSource(sourcesWithout720p, 0)?.key,
        '480p',
      );
    });
  });

  group('VideoUtils.downloadSource', () {
    const sources = {
      '360p': 'a',
      '480p': 'b',
      '1080p': 'c',
    };

    test('takes an exact height', () {
      final pick = VideoUtils.downloadSource(sources, 480)!;
      expect(pick.entry.key, '480p');
      expect(pick.exact, isTrue);
    });

    test('takes the tallest for best', () {
      final pick = VideoUtils.downloadSource(sources, 0)!;
      expect(pick.entry.key, '1080p');
      expect(pick.exact, isTrue);
    });

    test('falls back below a missing height and says so', () {
      final pick = VideoUtils.downloadSource(sources, 720)!;
      expect(pick.entry.key, '480p');
      expect(pick.exact, isFalse);
    });

    test('counts an adaptive stream as having the height', () {
      final pick = VideoUtils.downloadSource(
        const {'360p': 'a', 'Auto': 'm'},
        720,
      )!;
      expect(pick.entry.key, 'Auto');
      expect(pick.exact, isTrue);
    });
  });

  group('VideoUtils.reverseVideoQualityMap', () {
    test('sorts measured qualities and leaves host labels at the end', () {
      final ordered = VideoUtils.reverseVideoQualityMap({
        '480p': 'medium',
        'Voesx': 'alternate-1',
        '2160p': 'ultra',
        'playhq': 'alternate-2',
        '1080p': 'high',
        '720p': 'balanced',
      });

      expect(
        ordered.keys,
        ['2160p', '1080p', '720p', '480p', 'Voesx', 'playhq'],
      );
    });
  });

  group('VideoUtils source maps', () {
    final showboxLinks = [
      RegularVideoLinks(
        url: 'https://showbox.example/1080.m3u8',
        quality: '1080p H.264 | AAC',
        server: 'ShowBox 2',
        isM3U8: true,
      ),
      RegularVideoLinks(
        url: 'https://showbox.example/server-1-720.m3u8',
        quality: '720p H.264 | AAC',
        server: 'ShowBox 1',
        isM3U8: true,
        sizeToken: 'token-server-1-720',
      ),
      RegularVideoLinks(
        url: 'https://showbox.example/server-2-720.m3u8',
        quality: '720p H.264 | AAC',
        server: 'ShowBox 2',
        isM3U8: true,
        sizeToken: 'token-server-2-720',
      ),
      RegularVideoLinks(
        url: 'https://showbox.example/server-1-360.mpd',
        quality: '360p H.264 | AAC',
        server: 'ShowBox 1',
        isDash: true,
        headers: {'Referer': 'https://showbox.example/'},
      ),
      RegularVideoLinks(
        url: 'https://showbox.example/server-2-360.mpd',
        quality: '360p H.264 | AAC',
        server: 'ShowBox 2',
        isDash: true,
      ),
    ];

    test('preserves same-quality streams from different servers', () {
      final sources = VideoUtils.convertVideoLinksToMap(showboxLinks);

      expect(sources, hasLength(5));
      expect(sources.keys, [
        '1080p H.264 | AAC',
        '720p H.264 | AAC · ShowBox 1',
        '720p H.264 | AAC · ShowBox 2',
        '360p H.264 | AAC · ShowBox 1',
        '360p H.264 | AAC · ShowBox 2',
      ]);
    });

    test('keeps formats and headers aligned with unique source keys', () {
      final formats = VideoUtils.convertVideoFormatsToMap(showboxLinks);
      final headers = VideoUtils.convertVideoHeadersToMap(showboxLinks);
      final sizeTokens = VideoUtils.convertVideoSizeTokensToMap(showboxLinks);

      expect(
        formats['720p H.264 | AAC · ShowBox 2'],
        BetterPlayerVideoFormat.hls,
      );
      expect(
        formats['360p H.264 | AAC · ShowBox 1'],
        BetterPlayerVideoFormat.dash,
      );
      expect(headers['360p H.264 | AAC · ShowBox 1'], {
        'Referer': 'https://showbox.example/',
      });
      expect(
        sizeTokens['720p H.264 | AAC · ShowBox 1'],
        'token-server-1-720',
      );
      expect(
        sizeTokens['720p H.264 | AAC · ShowBox 2'],
        'token-server-2-720',
      );
    });

    test('keeps default quality matching based on the quality prefix', () {
      final sources = VideoUtils.convertVideoLinksToMap(showboxLinks);

      expect(
        VideoUtils.preferredVideoSource(sources, 720)?.key,
        '720p H.264 | AAC · ShowBox 1',
      );
    });
  });
}
