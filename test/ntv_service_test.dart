import 'dart:convert';

import 'package:flixquest/services/daddylive_service.dart';
import 'package:flixquest/services/live_tv_source.dart';
import 'package:flixquest/services/ntv_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('NtvService', () {
    NtvService service(
      Future<http.Response> Function(http.Request request) handler,
    ) {
      final ntv = NtvService(
        baseUrl: 'https://scraper.test/',
        client: MockClient(handler),
      );
      addTearDown(ntv.close);
      return ntv;
    }

    Map<String, dynamic> channel(String id, String name, String server) =>
        <String, dynamic>{'id': id, 'name': name, 'server': server};

    Map<String, dynamic> event(
      String title,
      String server,
      List<Map<String, dynamic>> channels, {
      String startsAt = '2026-11-01T18:00:00.000Z',
    }) =>
        <String, dynamic>{
          'title': title,
          'time': startsAt.substring(11, 16),
          'startsAt': startsAt,
          'server': server,
          'channels': channels,
        };

    test('leaves out the DaddyLive channels NTV relays, and namespaces IDs',
        () async {
      final ntv = service((request) async {
        if (request.url.path == '/api/v2/ntv/channels') {
          return _json(<String, dynamic>{
            'channels': <Map<String, dynamic>>[
              channel('51', 'ABC USA', 'phoenix'),
              channel('f-1', 'beIN SPORTS USA', 'falcon'),
              channel('cdnlive-2', 'DR 1 HD DK', 'titan'),
            ],
          });
        }
        if (request.url.path == '/api/v2/ntv/epg') {
          return _json(<String, dynamic>{
            'days': <Map<String, dynamic>>[
              <String, dynamic>{
                'date': '2026-11-01',
                'label': '2026-11-01',
                'categories': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'name': 'Football',
                    'events': <Map<String, dynamic>>[
                      event('Relayed match', 'phoenix', [
                        channel('51', 'ABC USA', 'phoenix'),
                      ]),
                      event('Champions League', 'falcon', [
                        channel('f-1', 'beIN SPORTS USA', 'falcon'),
                      ]),
                    ],
                  },
                ],
              },
            ],
          });
        }
        fail('Unexpected request: ${request.url}');
      });

      final catalog = await ntv.getCatalog();

      expect(catalog.channels.map((channel) => channel.id),
          <String>['ntv:f-1', 'ntv:cdnlive-2']);
      final events = catalog.epg.days.single.categories.single.events;
      expect(events.map((event) => event.title), <String>['Champions League']);
      expect(events.single.channels.single.id, 'ntv:f-1');
      expect(catalog.channels.first.categories, <String>['Football'],
          reason: 'the schedule still fills in what a channel airs');
    });

    test('opens on today, with the undated 24/7 events last', () async {
      Map<String, dynamic> day(String? date) => <String, dynamic>{
            if (date != null) 'date': date,
            'label': date ?? '24/7',
            'categories': <Map<String, dynamic>>[
              <String, dynamic>{
                'name': 'Football',
                'events': <Map<String, dynamic>>[
                  event('Match', 'raptor', [
                    channel('event-a', 'Match', 'raptor'),
                  ]),
                ],
              },
            ],
          };
      final ntv = service((request) async => request.url.path.endsWith('/epg')
          ? _json(<String, dynamic>{
              'days': <Map<String, dynamic>>[
                day(null),
                day('2026-11-02'),
                day('2026-11-01'),
              ],
            })
          : _json(<String, dynamic>{'channels': <dynamic>[]}));

      final catalog = await ntv.getCatalog();

      expect(catalog.epg.days.map((day) => day.label),
          <String>['2026-11-01', '2026-11-02', '24/7']);
    });

    test('numbers an event\'s streams that share its title', () async {
      final ntv = service((request) async => request.url.path.endsWith('/epg')
          ? _json(<String, dynamic>{
              'days': <Map<String, dynamic>>[
                <String, dynamic>{
                  'date': '2026-11-01',
                  'label': '2026-11-01',
                  'categories': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'name': 'American Football',
                      'events': <Map<String, dynamic>>[
                        event('Ravens at Bills', 'raptor', [
                          channel('event-a', 'Ravens at Bills', 'raptor'),
                          channel('event-b', 'Ravens at Bills', 'raptor'),
                          channel('event-c', 'ESPN', 'raptor'),
                        ]),
                      ],
                    },
                  ],
                },
              ],
            })
          : _json(<String, dynamic>{'channels': <dynamic>[]}));

      final catalog = await ntv.getCatalog();

      final channels =
          catalog.epg.days.single.categories.single.events.single.channels;
      expect(channels.map((channel) => channel.name),
          <String>['Stream 1', 'Stream 2', 'ESPN']);
    });

    test('keeps the channels when the schedule is down', () async {
      final ntv = service((request) async => request.url.path.endsWith('/epg')
          ? http.Response('error code: 502', 502)
          : _json(<String, dynamic>{
              'channels': <Map<String, dynamic>>[
                channel('f-1', 'beIN SPORTS USA', 'falcon'),
              ],
            }));

      final catalog = await ntv.getCatalog();

      expect(catalog.channels.single.id, 'ntv:f-1');
      expect(catalog.epg.days, isEmpty);
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

      expect(requested, <String>['/api/v2/ntv/channels/cdnlive-2/stream']);
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
