import 'dart:convert';

import 'package:flixquest/services/daddylive_service.dart';
import 'package:flixquest/services/live_tv_source.dart';
import 'package:flixquest/services/ntv_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'support/sealed_scraper.dart';

void main() {
  group('NtvService', () {
    NtvService service(
      Future<http.Response> Function(http.Request request) handler,
    ) {
      final ntv = NtvService(
        baseUrl: 'https://scraper.test/',
        client: sealedMockClient(handler),
      );
      addTearDown(ntv.close);
      return ntv;
    }

    Map<String, dynamic> channel(String id, String name, String server) =>
        <String, dynamic>{'id': id, 'name': name, 'server': server};

    test('leaves out the DaddyLive channels NTV relays, and namespaces IDs',
        () async {
      final requested = <String>[];
      final ntv = service((request) async {
        requested.add(request.url.path);
        return _json(<String, dynamic>{
          'channels': <Map<String, dynamic>>[
            channel('51', 'ABC USA', 'phoenix'),
            channel('f-1', 'beIN SPORTS USA', 'falcon'),
            channel('cdnlive-2', 'DR 1 HD DK', 'titan'),
          ],
        });
      });

      final catalog = await ntv.getCatalog();

      expect(catalog.channels.map((channel) => channel.id),
          <String>['ntv:f-1', 'ntv:cdnlive-2']);
      expect(catalog.epg.days, isEmpty);
      expect(requested, <String>['/api/v2/ntv/channels'],
          reason: 'NTV offers channels only, so its schedule is never asked');
    });

    test('plays the scraper\'s stream for the unprefixed channel', () async {
      final requested = <String>[];
      final ntv = service((request) async {
        requested.add(request.url.path);
        return _json(<String, dynamic>{
          'success': true,
          'stream': <String, dynamic>{
            'url': 'https://cdn.test/live/index.m3u8?token=abc',
            'isM3U8': true,
            'headers': <String, String>{'Referer': 'https://player.test/'},
            'embedUrl': 'https://player.test/e/1',
          },
        });
      });

      final stream = await ntv.getStream('ntv:cdnlive-2');

      expect(requested, <String>['/api/v3/ntv/stream']);
      expect(stream.url, 'https://cdn.test/live/index.m3u8?token=abc');
      expect(stream.headers['Referer'], 'https://player.test/');
    });

    test('reports a channel the CDN answers for as unplayable', () async {
      final ntv = service(
        (request) async => http.Response('error code: 502', 502),
      );

      await expectLater(
        ntv.getStream('ntv:f-1'),
        throwsA(isA<DaddyLiveException>().having(
          (error) => error.message,
          'message',
          'The channel returned no playable stream.',
        )),
      );
    });
  });

  group('LiveTvSource', () {
    test('tells the source from a channel ID', () {
      expect(LiveTvSource.forChannel('51'), LiveTvSource.daddyLive);
      expect(LiveTvSource.forChannel('ntv:f-1'), LiveTvSource.ntv);
    });

    test('remembers the source last browsed', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      expect(await LiveTvSource.lastUsed(), LiveTvSource.daddyLive);
      await LiveTvSource.ntv.remember();
      expect(await LiveTvSource.lastUsed(), LiveTvSource.ntv);
    });

    test('shows viewers Ethiopian names, not the upstream brands', () {
      expect(LiveTvSource.values.map((source) => source.label),
          <String>['Awash', 'Abay']);
      for (final source in LiveTvSource.values) {
        expect(source.label,
            isNot(matches(RegExp('dlhd|daddy|ntv', caseSensitive: false))));
      }
    });

    test('hides upstream names in live TV errors', () {
      expect(
        friendlyLiveTvError(StateError('DLHD playback session closed')),
        liveTvUnavailableMessage,
      );
    });

    test('offers a schedule only where one plays', () {
      expect(LiveTvSource.daddyLive.hasSchedule, isTrue);
      expect(LiveTvSource.ntv.hasSchedule, isFalse);
    });

    test('keeps DaddyLive\'s existing store', () {
      expect(LiveTvSource.daddyLive.id, 'daddylive',
          reason: 'favourites saved before NTV live under this name');
    });
  });
}

http.Response _json(Map<String, dynamic> value) => http.Response(
      jsonEncode(value),
      200,
      headers: const <String, String>{'content-type': 'application/json'},
    );
