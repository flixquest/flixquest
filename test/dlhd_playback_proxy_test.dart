import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flixquest/services/daddylive_service.dart';
import 'package:flixquest/services/dlhd_playback_proxy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as image;

Uint8List _ts() => Uint8List.fromList(
    List.generate(188 * 3, (i) => i % 188 == 0 ? 0x47 : (i % 251)));

String _embed(String origin) => '''
const SRC = "$origin/premium110/index.m3u8";
const EDGE = "$origin";
const CHANNEL = "premium110";
function fetchPlaylistToken() { fetch(EDGE + '/api/playlist-token?slug=' + CHANNEL); }
class LiveLoader {}
''';

void main() {
  test(
      'adapts tokens, master/variant URLs, keys and wrapped segments over HTTP',
      () async {
    final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => upstream.close(force: true));
    final origin = 'http://127.0.0.1:${upstream.port}';
    final seen = <Uri>[];
    var tokenRequests = 0;
    var rejectFirstToken = false;
    upstream.listen((request) async {
      seen.add(request.uri);
      switch (request.uri.path) {
        case '/api/playlist-token':
          expect(request.uri.queryParameters['slug'], 'premium110');
          expect(request.headers.value('referer'), '$origin/embed');
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({
            'token': 'viewer-${++tokenRequests}',
            'ttl': 120,
          }));
        case '/premium110/index.m3u8':
        case '/premium110/variant.m3u8':
          final token = request.uri.queryParameters['t'];
          if (token == null || (rejectFirstToken && token == 'viewer-1')) {
            request.response.statusCode = 403;
          } else if (request.uri.path.endsWith('index.m3u8')) {
            request.response.write('#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000\n'
                'variant.m3u8?quality=hd\n');
          } else {
            request.response.write('#EXTM3U\n#EXT-X-TARGETDURATION:6\n'
                '#EXT-X-KEY:METHOD=AES-128,URI="../key"\n'
                '#EXT-X-MAP:URI="../init"\n'
                '#EXT-X-KEY:METHOD=NONE\n#EXTINF:6,\n../segment.png\n');
          }
        case '/segment.png':
          request.response.add([
            ...utf8.encode('TIKTIKTSGZ'),
            ...gzip.encode(_ts()),
          ]);
        case '/key':
          request.response.add(List.filled(16, 7));
        case '/init':
          request.response.add([1, 2, 3, 4]);
        default:
          request.response.statusCode = 501;
      }
      await request.response.close();
    });
    final client = http.Client();
    addTearDown(client.close);
    final proxy = DlhdPlaybackProxy.fromEmbed(
      _embed(origin),
      headers: {'Referer': '$origin/embed', 'Origin': origin},
      client: client,
    )!;
    addTearDown(proxy.close);
    final local = Uri.parse(await proxy.start());
    rejectFirstToken = true;
    final master = await client.get(local);
    expect(master.statusCode, 200);
    expect(master.body, isNot(contains('viewer-')));
    expect(master.headers['cache-control'], 'no-store');
    expect(tokenRequests, 2, reason: 'a refused token must renew once');
    // The relay exposes the rendition whose media passed validation, so a
    // native player cannot choose a broken rendition from the original master.
    final variant = master;
    expect(variant.statusCode, 200);
    expect(seen.last.queryParameters['quality'], 'hd');
    expect(seen.last.queryParameters['t'], 'viewer-2');
    final attributePaths = RegExp('URI="([^"]+)"')
        .allMatches(variant.body)
        .map((m) => m.group(1)!)
        .toList();
    expect((await client.get(local.resolve(attributePaths[0]))).bodyBytes,
        List.filled(16, 7));
    expect((await client.get(local.resolve(attributePaths[1]))).bodyBytes,
        [1, 2, 3, 4]);
    final segmentPath = const LineSplitter()
        .convert(variant.body)
        .firstWhere((line) => line.startsWith('/media/'));
    final segment = await client.get(local.resolve(segmentPath));
    expect(segment.statusCode, 200);
    expect(segment.bodyBytes, _ts());
    expect(tokenRequests, 2);
    final denied =
        await client.get(local.resolve('/media/unknown.ts?url=$origin'));
    expect(denied.statusCode, 404,
        reason:
            'loopback endpoints must only serve registered playlist resources');
  });

  test('service uses the signed loader instead of rejecting a bare playlist',
      () async {
    final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => upstream.close(force: true));
    final origin = 'http://127.0.0.1:${upstream.port}';
    var bareRequests = 0;
    var tokenRequests = 0;
    upstream.listen((request) async {
      switch (request.uri.path) {
        case '/api/v2/dlhd/channels':
          request.response.write(jsonEncode({
            'success': true,
            'channels': [
              {'id': '110', 'name': 'Live', 'watchUrl': '$origin/watch'}
            ],
          }));
        case '/watch':
          request.response.write('''
<button class="player-btn" data-url="$origin/embed" title="PLAYER 1"></button>
<button class="player-btn" data-url="$origin/embed" title="PLAYER 2"></button>
''');
        case '/embed':
          request.response.write(_embed(origin));
        case '/api/playlist-token':
          tokenRequests++;
          request.response.write('{"token":"device-token","ttl":120}');
        case '/premium110/index.m3u8':
          if (request.uri.queryParameters['t'] != 'device-token') {
            bareRequests++;
            request.response.statusCode = 403;
          } else {
            request.response.write('#EXTM3U\n#EXTINF:6,\nsegment.ts\n');
          }
        case '/premium110/segment.ts':
          request.response.add(_ts());
        default:
          request.response.statusCode = 501;
      }
      await request.response.close();
    });
    final service = DaddyLiveService(baseUrl: origin);
    addTearDown(service.close);
    await service.getChannels(refresh: true);
    final stream = await service.getStream('110');
    expect(Uri.parse(stream.url).host, '127.0.0.1');
    expect(stream.variants.map((v) => v.title), ['Stream 1']);
    final discovery = stream.discovery!;
    final backups = discovery.updates.first;
    discovery.observePlayback(
      position: const Duration(seconds: 1),
      isPlaying: true,
      isBuffering: false,
      isAd: false,
    );
    final variants = await backups;
    expect(variants.map((v) => v.title), ['Stream 1', 'Stream 2']);
    expect(variants.map((v) => v.url).toSet(), hasLength(1));
    expect(tokenRequests, 1,
        reason: 'duplicate embeds must share the same loader');
    expect(bareRequests, 0);
    final client = http.Client();
    addTearDown(client.close);
    final playlist = await client.get(Uri.parse(stream.url));
    expect(playlist.statusCode, 200);
    expect(playlist.body, contains('/media/'));
  });

  test('renews tokens before expiry and rejects broken signed media', () async {
    final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => upstream.close(force: true));
    final origin = 'http://127.0.0.1:${upstream.port}';
    var tokens = 0;
    var broken = true;
    upstream.listen((request) async {
      if (request.uri.path == '/api/playlist-token') {
        request.response
            .write(jsonEncode({'token': 'token-${++tokens}', 'ttl': 1}));
      } else if (request.uri.path.endsWith('.m3u8')) {
        request.response.write('#EXTM3U\n#EXTINF:6,\nsegment.ts\n');
      } else if (broken) {
        request.response.statusCode = 403;
      } else {
        request.response.add(_ts());
      }
      await request.response.close();
    });
    final client = http.Client();
    addTearDown(client.close);
    final proxy = DlhdPlaybackProxy.fromEmbed(_embed(origin),
        headers: {}, client: client)!;
    addTearDown(proxy.close);
    await expectLater(proxy.start(), throwsStateError);
    broken = false;
    final local = Uri.parse(await proxy.start());
    final initialTokens = tokens;
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect((await client.get(local)).statusCode, 200);
    expect(tokens, initialTokens + 1,
        reason: 'the advertised TTL must trigger renewal without a 403');
  });

  test('keeps AES media encrypted for the native HLS player', () async {
    final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => upstream.close(force: true));
    final origin = 'http://127.0.0.1:${upstream.port}';
    final encrypted =
        Uint8List.fromList(List.generate(16 * 40, (i) => i % 251));
    upstream.listen((request) async {
      if (request.uri.path == '/api/playlist-token') {
        request.response.write('{"token":"viewer","ttl":120}');
      } else if (request.uri.path.endsWith('.m3u8')) {
        request.response.write('#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI="key"\n'
            '#EXTINF:6,\nsegment.ts\n');
      } else if (request.uri.path.endsWith('/key')) {
        request.response.add(List.filled(16, 7));
      } else {
        request.response.add(encrypted);
      }
      await request.response.close();
    });
    final client = http.Client();
    addTearDown(client.close);
    final proxy = DlhdPlaybackProxy.fromEmbed(_embed(origin),
        headers: {}, client: client)!;
    addTearDown(proxy.close);
    final local = Uri.parse(await proxy.start());
    final playlist = await client.get(local);
    final path = const LineSplitter()
        .convert(playlist.body)
        .lastWhere((line) => line.startsWith('/media/'));
    final response = await client.get(local.resolve(path));
    expect(response.statusCode, 200);
    expect(response.bodyBytes, encrypted,
        reason: 'ciphertext must reach the native AES loader unchanged');
  });

  group('DLHD media wrappers', () {
    final ts = _ts();
    test('plain TS, raw marker, gzip marker and prefixed TS', () {
      for (final bytes in [
        ts,
        [...utf8.encode('TIKTIKRAW'), ...ts],
        [...utf8.encode('headerTIKTIKTSGZ'), ...gzip.encode(ts)],
        [1, 2, 3, ...ts],
      ]) {
        expect(unwrapDlhdSegment(Uint8List.fromList(bytes)), ts);
      }
    });
    test('PNG trailer and legacy RGB pixel payload', () {
      final png = image.encodePng(image.Image(width: 2, height: 2));
      expect(unwrapDlhdSegment(Uint8List.fromList([...png, ...ts])), ts);
      final compressed = gzip.encode(ts);
      final size = ByteData(4)..setUint32(0, compressed.length);
      final payload = [
        ...utf8.encode('TIKTIKPX'),
        ...size.buffer.asUint8List(),
        ...compressed,
      ];
      final pixels = image.Image(width: (payload.length / 3).ceil(), height: 1);
      for (var i = 0; i < pixels.width; i++) {
        int value(int n) => n < payload.length ? payload[n] : 0;
        pixels.setPixelRgb(
            i, 0, value(i * 3), value(i * 3 + 1), value(i * 3 + 2));
      }
      expect(unwrapDlhdSegment(image.encodePng(pixels)), ts);
    });
    test('WebP EXIF payload', () {
      final size = ByteData(4)..setUint32(0, ts.length, Endian.little);
      final wrapper = Uint8List.fromList([
        ...utf8.encode('RIFF'),
        0,
        0,
        0,
        0,
        ...utf8.encode('WEBPEXIF'),
        ...size.buffer.asUint8List(),
        ...ts,
      ]);
      expect(unwrapDlhdSegment(wrapper), ts);
    });
    test('rejects invalid media and malformed images', () {
      expect(() => unwrapDlhdSegment(Uint8List.fromList([1, 2, 3])),
          throwsFormatException);
      expect(
          () => unwrapDlhdSegment(
              image.encodePng(image.Image(width: 1, height: 1))),
          throwsFormatException);
    });
  });
}
