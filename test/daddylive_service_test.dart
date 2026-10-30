import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flixquest/services/daddylive_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('DaddyLiveService local DLHD resolution', () {
    test(
        'returns only Player 1 and defers other players until content advances',
        () async {
      final requests = <http.Request>[];
      final releaseBackup = Completer<void>();
      addTearDown(() {
        if (!releaseBackup.isCompleted) releaseBackup.complete();
      });
      final service = DaddyLiveService(
        baseUrl: 'https://metadata.example',
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.host == 'metadata.example' &&
              request.url.path == '/api/v2/dlhd/channels') {
            return _jsonResponse(<String, dynamic>{
              'success': true,
              'channels': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': '24',
                  'name': 'Test channel',
                  'watchUrl': 'https://dlhd.test/watch.php?id=24',
                },
              ],
            });
          }
          if (request.url.path.endsWith('/segment.ts')) {
            return http.Response.bytes(_ts(), 200);
          }
          switch (request.url.toString()) {
            case 'https://dlhd.test/watch.php?id=24':
              return http.Response('''
                <button class="btn player-btn" data-url="/stream/stream-24.php" title="PLAYER 1"></button>
                <button title='PLAYER 2' data-url='/cast/stream-24.php' class='player-btn btn'></button>
                <button class="player-btn" data-url="/watch/stream-24.php" title="PLAYER 3"></button>
              ''', 200);
            case 'https://dlhd.test/stream/stream-24.php':
              return http.Response(
                '<iframe src="https://one.embed.test/e/24"></iframe>',
                200,
              );
            case 'https://dlhd.test/cast/stream-24.php':
              return http.Response(
                '<iframe src="https://two.embed.test/e/24"></iframe>',
                200,
              );
            case 'https://dlhd.test/watch/stream-24.php':
              return http.Response(
                '<iframe src="https://three.embed.test/e/24"></iframe>',
                200,
              );
            case 'https://one.embed.test/e/24':
              return http.Response(
                'const source = "https://one.cdn.test/live/24.m3u8";',
                200,
              );
            case 'https://two.embed.test/e/24':
              return http.Response(
                'const source = "https://two.cdn.test/live/24.m3u8";',
                200,
              );
            case 'https://three.embed.test/e/24':
              return http.Response(
                'const source = "https://three.cdn.test/live/24.m3u8";',
                200,
              );
            case 'https://one.cdn.test/live/24.m3u8':
            case 'https://two.cdn.test/live/24.m3u8':
              return http.Response('#EXTM3U\n#EXTINF:6,\nsegment.ts', 200);
            case 'https://three.cdn.test/live/24.m3u8':
              await releaseBackup.future;
              return http.Response('#EXTM3U\n#EXTINF:6,\nsegment.ts', 200);
            default:
              return http.Response('not found', 404);
          }
        }),
      );
      addTearDown(service.close);

      await service.getChannels();
      final stream = await service.getStream('24').onError(
            (error, stackTrace) => fail(
              '$error\nRequests:\n${requests.map((request) => request.url).join('\n')}',
            ),
          );

      expect(stream.url, 'https://one.cdn.test/live/24.m3u8');
      expect(
        stream.variants.map((variant) => variant.url),
        <String>[
          'https://one.cdn.test/live/24.m3u8',
        ],
      );
      expect(
        stream.variants.map((variant) => variant.title),
        <String?>['Stream 1'],
      );
      expect(stream.headers['Origin'], 'https://one.embed.test');
      expect(stream.headers['Referer'], 'https://one.embed.test/e/24');
      expect(requests.any((request) => request.url.host == 'two.embed.test'),
          isFalse);
      expect(requests.any((request) => request.url.host == 'three.embed.test'),
          isFalse);
      final discovery = stream.discovery!;
      final firstBackup = discovery.updates.first;
      discovery.observePlayback(
        position: const Duration(seconds: 1),
        isPlaying: true,
        isBuffering: false,
        isAd: false,
      );
      expect((await firstBackup).map((variant) => variant.title),
          ['Stream 1', 'Stream 2']);
      expect(
        requests.any((request) => request.url.host == 'three.cdn.test'),
        isTrue,
        reason: 'after playback, backup resolutions run concurrently',
      );
      final allBackups =
          discovery.updates.firstWhere((items) => items.length == 3);
      releaseBackup.complete();
      expect((await allBackups).map((variant) => variant.title),
          ['Stream 1', 'Stream 2', 'Stream 3']);
      expect(
        requests.any((request) => request.url.path.endsWith('/stream')),
        isFalse,
        reason: 'a successful local page walk must not request an IP-bound URL',
      );
    });

    test('drops a failed player without losing later backup streams', () async {
      final service = DaddyLiveService(
        baseUrl: 'https://metadata.example',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/segment.ts')) {
            return http.Response.bytes(_ts(), 200);
          }
          switch (request.url.toString()) {
            case 'https://dlhd.st/watch.php?id=51':
              return http.Response('''
                <button class="player-btn" data-url="https://p1.test/51" title="PLAYER 1"></button>
                <button class="player-btn" data-url="https://p2.test/51" title="PLAYER 2"></button>
                <button class="player-btn" data-url="https://p3.test/51" title="PLAYER 3"></button>
              ''', 200);
            case 'https://p1.test/51':
              return http.Response('https://cdn.test/one.m3u8', 200);
            case 'https://p2.test/51':
              return http.Response('https://cdn.test/two.m3u8', 200);
            case 'https://p3.test/51':
              return http.Response('https://cdn.test/three.m3u8', 200);
            case 'https://cdn.test/one.m3u8':
            case 'https://cdn.test/three.m3u8':
              return http.Response('#EXTM3U\n#EXTINF:4,\nsegment.ts', 200);
            case 'https://cdn.test/two.m3u8':
              return http.Response('forbidden', 403);
            default:
              return http.Response('{"error":"unexpected request"}', 404);
          }
        }),
      );
      addTearDown(service.close);

      final stream = await service.getStream('51');

      expect(
        stream.variants.map((variant) => variant.title),
        <String?>['Stream 1'],
      );
      final discovery = stream.discovery!;
      await discovery.resolveNext();
      expect(discovery.variants.map((variant) => variant.title),
          ['Stream 1', 'Stream 3']);
      expect(discovery.variants.last.url, 'https://cdn.test/three.m3u8');
    });

    test(
        'tries Player 2 only after Player 1 fails and leaves Player 3 deferred',
        () async {
      final requested = <String>[];
      final service = DaddyLiveService(
        baseUrl: 'https://metadata.example',
        client: MockClient((request) async {
          requested.add(request.url.toString());
          if (request.url.path == '/watch.php') {
            return http.Response('''
              <button class="player-btn" data-url="https://p1.test/embed" title="PLAYER 1"></button>
              <button class="player-btn" data-url="https://p2.test/embed" title="PLAYER 2"></button>
              <button class="player-btn" data-url="https://p3.test/embed" title="PLAYER 3"></button>
            ''', 200);
          }
          if (request.url.host == 'p1.test') return http.Response('down', 503);
          if (request.url.host == 'p2.test') {
            expect(requested, contains('https://p1.test/embed'));
            return http.Response('https://cdn.test/two.m3u8', 200);
          }
          if (request.url.path.endsWith('/segment.ts')) {
            return http.Response.bytes(_ts(), 200);
          }
          if (request.url.host == 'cdn.test') {
            return http.Response('#EXTM3U\n#EXTINF:4,\nsegment.ts', 200);
          }
          fail('Unexpected request: ${request.url}');
        }),
      );
      addTearDown(service.close);

      final stream = await service.getStream('51');

      expect(stream.title, 'Stream 2');
      expect(stream.variants.single.url, 'https://cdn.test/two.m3u8');
      expect(requested.any((url) => url.contains('p3.test')), isFalse);
      expect(stream.discovery, isNotNull);
    });

    test('leaving a channel stops following a pending backup iframe', () async {
      final requested = <String>[];
      final backupStarted = Completer<void>();
      final releaseBackup = Completer<http.Response>();
      final service = DaddyLiveService(
        baseUrl: 'https://metadata.example',
        client: MockClient((request) async {
          requested.add(request.url.toString());
          if (request.url.path == '/watch.php') {
            return http.Response('''
              <button class="player-btn" data-url="https://p1.test/embed"></button>
              <button class="player-btn" data-url="https://p2.test/embed"></button>
            ''', 200);
          }
          if (request.url.host == 'p1.test') {
            return http.Response('https://cdn.test/one.m3u8', 200);
          }
          if (request.url.path.endsWith('/segment.ts')) {
            return http.Response.bytes(_ts(), 200);
          }
          if (request.url.host == 'cdn.test') {
            return http.Response('#EXTM3U\n#EXTINF:4,\nsegment.ts', 200);
          }
          if (request.url.host == 'p2.test') {
            backupStarted.complete();
            return releaseBackup.future;
          }
          fail('Unexpected request after leaving channel: ${request.url}');
        }),
      );
      addTearDown(service.close);
      final stream = await service.getStream('51');
      final discovery = stream.discovery!;
      final resolving = discovery.resolveNext();
      await backupStarted.future;
      discovery.dispose();
      releaseBackup.complete(http.Response(
          '<iframe src="https://late.embed.test/channel"></iframe>', 200));
      await resolving;

      expect(requested.any((url) => url.contains('late.embed.test')), isFalse);
      expect(discovery.variants, hasLength(1));
    });

    test('scraper fallback resolves its embed on the device', () async {
      final requested = <String>[];
      final service = DaddyLiveService(
        baseUrl: 'https://metadata.example',
        client: MockClient((request) async {
          requested.add(request.url.toString());
          if (request.url.path == '/watch.php') {
            return http.Response('blocked', 403);
          }
          if (request.url.path == '/api/v2/dlhd/channels/51/stream') {
            return _jsonResponse(<String, dynamic>{
              'stream': <String, dynamic>{
                'embedUrl': 'https://embed.test/channel/51',
                'url': 'https://server-signed.test/51.m3u8',
              },
            });
          }
          if (request.url.host == 'embed.test') {
            return http.Response('https://cdn.test/51.m3u8', 200);
          }
          if (request.url.path.endsWith('/segment.ts')) {
            return http.Response.bytes(_ts(), 200);
          }
          if (request.url.host == 'cdn.test') {
            return http.Response('#EXTM3U\n#EXTINF:4,\nsegment.ts', 200);
          }
          fail('Unexpected request: ${request.url}');
        }),
      );
      addTearDown(service.close);

      final stream = await service.getStream('51');

      expect(stream.url, 'https://cdn.test/51.m3u8');
      expect(stream.embedUrl, 'https://embed.test/channel/51');
      expect(requested.any((url) => url.contains('server-signed.test')),
          isFalse);
    });

    test('never plays the scraper-signed URL when its embed fails', () async {
      final requested = <String>[];
      final service = DaddyLiveService(
        baseUrl: 'https://metadata.example',
        client: MockClient((request) async {
          requested.add(request.url.toString());
          if (request.url.path == '/watch.php') {
            return http.Response('blocked', 403);
          }
          if (request.url.path == '/api/v2/dlhd/channels/51/stream') {
            return _jsonResponse(<String, dynamic>{
              'stream': <String, dynamic>{
                'embedUrl': 'https://embed.test/channel/51',
                'url': 'https://server-signed.test/51.m3u8',
              },
            });
          }
          if (request.url.host == 'embed.test') {
            return http.Response('down', 503);
          }
          fail('Unexpected request: ${request.url}');
        }),
      );
      addTearDown(service.close);

      await expectLater(
        service.getStream('51'),
        throwsA(isA<DaddyLiveException>()),
      );
      expect(requested.any((url) => url.contains('server-signed.test')),
          isFalse,
          reason: 'the scraper URL is signed for the server IP, not ours');
    });

    test('keeps the channel catalog available when the EPG is down', () async {
      final service = DaddyLiveService(
        baseUrl: 'https://metadata.example',
        client: MockClient((request) async {
          if (request.url.path == '/api/v2/dlhd/channels') {
            return _jsonResponse(<String, dynamic>{
              'success': true,
              'channels': <Map<String, dynamic>>[
                <String, dynamic>{'id': '1', 'name': 'Always on'},
              ],
            });
          }
          if (request.url.path == '/api/v2/dlhd/epg') {
            return http.Response('{"error":"guide unavailable"}', 502);
          }
          return http.Response('not found', 404);
        }),
      );
      addTearDown(service.close);

      final catalog = await service.getCatalog();

      expect(catalog.channels.single.name, 'Always on');
      expect(catalog.epg.days, isEmpty);
      expect(catalog.categories, isEmpty);
    });
  });
}

http.Response _jsonResponse(Map<String, dynamic> value) => http.Response(
      jsonEncode(value),
      200,
      headers: const <String, String>{'content-type': 'application/json'},
    );

Uint8List _ts() => Uint8List.fromList(
    List.generate(188 * 3, (i) => i % 188 == 0 ? 0x47 : i % 251));
