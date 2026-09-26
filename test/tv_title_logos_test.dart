import 'dart:convert';

import 'package:flixquest/tv/controllers/tv_title_logos.dart';
import 'package:flixquest/tv/models/tv_media_item.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

TvMediaItem _item(int id, {TvMediaKind kind = TvMediaKind.movie}) =>
    TvMediaItem(
      kind: kind,
      id: id,
      title: 'Title $id',
      overview: '',
      posterPath: null,
      backdropPath: null,
      rating: null,
      releaseDate: null,
    );

Map<String, dynamic> _logo(
  String path, {
  String? language,
  num votes = 5,
  num aspect = 3,
}) =>
    <String, dynamic>{
      'file_path': path,
      'iso_639_1': language,
      'vote_average': votes,
      'aspect_ratio': aspect,
    };

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'FLIXQUEST_API_URL=https://example.com');
  });

  group('pickTitleLogo', () {
    test('prefers the app language, then English, then no text', () {
      final logos = <Map<String, dynamic>>[
        _logo('/none.png'),
        _logo('/en.png', language: 'en'),
        _logo('/fr.png', language: 'fr'),
        _logo('/de.png', language: 'de'),
      ];
      expect(pickTitleLogo(logos, language: 'fr'), '/fr.png');
      expect(pickTitleLogo(logos, language: 'es'), '/en.png');
      expect(
        pickTitleLogo(<Map<String, dynamic>>[_logo('/none.png')],
            language: 'es'),
        '/none.png',
      );
    });

    test('never picks a logo in another language', () {
      expect(
        pickTitleLogo(<Map<String, dynamic>>[_logo('/de.png', language: 'de')],
            language: 'fr'),
        isNull,
      );
    });

    test('skips SVGs and prefers wide logos, then the best voted', () {
      final logos = <Map<String, dynamic>>[
        _logo('/vector.svg', language: 'en', votes: 10),
        _logo('/tall.png', language: 'en', votes: 9, aspect: 0.8),
        _logo('/wide.png', language: 'en', votes: 4),
        _logo('/wider.png', language: 'en', votes: 6),
      ];
      expect(pickTitleLogo(logos, language: 'en'), '/wider.png');
    });

    test('keeps TMDB\'s order for a tie', () {
      final logos = <Map<String, dynamic>>[
        _logo('/first.png', language: 'en'),
        _logo('/second.png', language: 'en'),
      ];
      expect(pickTitleLogo(logos, language: 'en'), '/first.png');
    });
  });

  group('TvTitleLogos', () {
    test('looks a title up once and remembers the answer', () async {
      final requests = <Uri>[];
      final logos = TvTitleLogos(
        language: 'pt-BR',
        proxyEnabled: false,
        proxyUrl: '',
        client: MockClient((request) async {
          requests.add(request.url);
          return http.Response(
            jsonEncode(<String, dynamic>{
              'logos': <Object>[_logo('/logo.png', language: 'pt')],
            }),
            200,
          );
        }),
      );
      final item = _item(7, kind: TvMediaKind.series);

      expect(logos.isKnown(item), isFalse);
      final results = await Future.wait(<Future<String?>>[
        logos.resolve(item),
        logos.resolve(item),
      ]);
      expect(results, <String?>['/logo.png', '/logo.png']);
      expect(await logos.resolve(item), '/logo.png');
      expect(logos.isKnown(item), isTrue);
      expect(logos.known(item), '/logo.png');

      expect(requests, hasLength(1));
      expect(requests.single.path, endsWith('/tv/7/images'));
      expect(
        requests.single.queryParameters['include_image_language'],
        'pt,en,null',
      );
    });

    test('remembers that a title has no logo', () async {
      var calls = 0;
      final logos = TvTitleLogos(
        language: 'en',
        proxyEnabled: false,
        proxyUrl: '',
        client: MockClient((_) async {
          calls++;
          return http.Response('{"logos": []}', 200);
        }),
      );
      expect(await logos.resolve(_item(1)), isNull);
      expect(await logos.resolve(_item(1)), isNull);
      expect(logos.isKnown(_item(1)), isTrue);
      expect(calls, 1);
    });

    test('tries a failed lookup again', () async {
      var calls = 0;
      final logos = TvTitleLogos(
        language: 'en',
        proxyEnabled: false,
        proxyUrl: '',
        client: MockClient((_) async {
          calls++;
          return calls == 1
              ? http.Response('busy', 503)
              : http.Response(
                  jsonEncode(<String, dynamic>{
                    'logos': <Object>[_logo('/logo.png', language: 'en')],
                  }),
                  200,
                );
        }),
      );
      expect(await logos.resolve(_item(1)), isNull);
      expect(logos.isKnown(_item(1)), isFalse);
      expect(await logos.resolve(_item(1)), '/logo.png');
      expect(calls, 2);
    });

    test('goes through the TMDB proxy when it is on', () async {
      late Uri requested;
      final logos = TvTitleLogos(
        language: 'en',
        proxyEnabled: true,
        proxyUrl: 'https://proxy.example',
        client: MockClient((request) async {
          requested = request.url;
          return http.Response('{"logos": []}', 200);
        }),
      );
      await logos.resolve(_item(3));
      expect(requested.host, 'proxy.example');
      expect(requested.toString(), contains('destination='));
      expect(requested.toString(), contains('/movie/3/images'));
    });

    test('does not look up a title without an id', () async {
      var calls = 0;
      final logos = TvTitleLogos(
        language: 'en',
        proxyEnabled: false,
        proxyUrl: '',
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      expect(await logos.resolve(_item(-1)), isNull);
      expect(calls, 0);
    });
  });
}
