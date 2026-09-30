import 'dart:async';
import 'dart:convert';

import 'package:flixquest/services/daddylive_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('DaddyLiveService local DLHD resolution', () {
    test('returns Players 1 and 2 while later players resolve concurrently',
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
          'https://two.cdn.test/live/24.m3u8',
        ],
      );
      expect(
        stream.variants.map((variant) => variant.title),
        <String?>['Stream 1', 'Stream 2'],
      );
      expect(stream.headers['Origin'], 'https://one.embed.test');
      expect(stream.headers['Referer'], 'https://one.embed.test/e/24');
      expect(
        requests.any(
          (request) =>
              request.url.toString() == 'https://three.cdn.test/live/24.m3u8',
        ),
        isTrue,
        reason: 'later providers must start without blocking priority playback',
      );

      releaseBackup.complete();
      final backupStream = await service.getStream('24');
      expect(backupStream.title, 'Stream 3');
      expect(
        backupStream.variants.map((variant) => variant.title),
        <String?>['Stream 3'],
      );
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
      final backup = await service.getStream('51');
      expect(backup.variants.single.title, 'Stream 3');
      expect(backup.url, 'https://cdn.test/three.m3u8');
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
