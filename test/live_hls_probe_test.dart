import 'dart:typed_data';

import 'package:flixquest/services/daddylive_service.dart';
import 'package:flixquest/services/live_hls_probe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Uint8List _ts() => Uint8List.fromList(
    List.generate(188 * 3, (i) => i % 188 == 0 ? 0x47 : i % 251));

void main() {
  test('rejects a valid manifest when its media is forbidden or HTML',
      () async {
    for (final status in [403, 200]) {
      final client = MockClient((request) async =>
          request.url.path.endsWith('.m3u8')
              ? http.Response('#EXTM3U\n#EXTINF:6,\nsegment.ts\n', 200)
              : http.Response('<html>unavailable</html>', status));
      addTearDown(client.close);
      await expectLater(
          probeLiveHls(Uri.parse('https://cdn.test/live.m3u8'),
              client: client, headers: {}),
          status == 403 ? throwsStateError : throwsFormatException);
    }
  });

  test('tries another rendition and resolves media against redirected playlist',
      () async {
    final seen = <Uri>[];
    final client = MockClient((request) async {
      seen.add(request.url);
      switch (request.url.path) {
        case '/master.m3u8':
          return http.Response(
              '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000\n'
              'bad.m3u8\n#EXT-X-STREAM-INF:BANDWIDTH=2000\ngood.m3u8\n',
              200);
        case '/bad.m3u8':
          return http.Response('offline', 503);
        case '/good.m3u8':
          return http.Response('#EXTM3U\n#EXTINF:6,\nsegment.ts\n', 200,
              request: http.Request(
                  'GET', Uri.parse('https://media.test/new/live.m3u8')));
        case '/new/segment.ts':
          expect(request.url.host, 'media.test');
          return http.Response.bytes(_ts(), 200);
      }
      return http.Response('not found', 404);
    });
    addTearDown(client.close);
    final playable = await probeLiveHls(
        Uri.parse('https://cdn.test/master.m3u8'),
        client: client,
        headers: {});
    expect(playable.toString(), 'https://media.test/new/live.m3u8');
    expect(seen.map((uri) => uri.path), contains('/bad.m3u8'));
  });

  test('rejects encrypted media when the key is unavailable', () async {
    final client =
        MockClient((request) async => request.url.path.endsWith('.m3u8')
            ? http.Response(
                '#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI="key"\n'
                '#EXTINF:6,\nsegment.ts\n',
                200)
            : http.Response('forbidden', 403));
    addTearDown(client.close);
    await expectLater(
        probeLiveHls(Uri.parse('https://cdn.test/live.m3u8'),
            client: client, headers: {}),
        throwsStateError);
  });

  test('preserves a master that carries separate audio', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/master.m3u8') {
        return http.Response(
            '#EXTM3U\n#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",'
            'URI="audio.m3u8"\n#EXT-X-STREAM-INF:BANDWIDTH=1000,AUDIO="audio"\n'
            'video.m3u8\n',
            200);
      }
      if (request.url.path.endsWith('.m3u8')) {
        return http.Response('#EXTM3U\n#EXTINF:6,\nsegment.ts\n', 200);
      }
      return http.Response.bytes(_ts(), 200);
    });
    addTearDown(client.close);
    final uri = Uri.parse('https://cdn.test/master.m3u8');
    expect(await probeLiveHls(uri, client: client, headers: {}), uri);
  });

  test('uses the canonical mirror and skips a server with broken segments',
      () async {
    final client = MockClient((request) async {
      switch (request.url.toString()) {
        case 'https://dlhd.st/watch.php?id=412':
          return http.Response('''
<link rel="canonical" href="https://mirror.test/watch.php?id=412">
<button class="player-btn" data-url="/first" title="PLAYER 1"></button>
<button class="player-btn" data-url="/second" title="PLAYER 2"></button>
''', 200);
        case 'https://mirror.test/first':
        case 'https://mirror.test/second':
          expect(request.headers['Referer'],
              'https://mirror.test/watch.php?id=412');
          return http.Response('https://cdn.test${request.url.path}.m3u8', 200);
        case 'https://cdn.test/first.m3u8':
          return http.Response('#EXTM3U\n#EXTINF:6,\nbad.ts\n', 200);
        case 'https://cdn.test/second.m3u8':
          return http.Response('#EXTM3U\n#EXTINF:6,\ngood.ts\n', 200);
        case 'https://cdn.test/good.ts':
          return http.Response.bytes(_ts(), 200);
      }
      return http.Response('unavailable', 403);
    });
    final service =
        DaddyLiveService(baseUrl: 'https://metadata.test', client: client);
    addTearDown(service.close);
    final stream = await service.getStream('412');
    expect(stream.title, 'Stream 2');
    expect(stream.url, 'https://cdn.test/second.m3u8');
  });
}
