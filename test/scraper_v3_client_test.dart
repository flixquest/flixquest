import 'dart:convert';

import 'package:flixquest/core/network/scraper_v3/scraper_cipher.dart';
import 'package:flixquest/core/network/scraper_v3/scraper_key_derivation.dart';
import 'package:flixquest/core/network/scraper_v3/scraper_v3_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/sealed_scraper.dart';

void main() {
  const route = '/stream-movie';
  const path = '/api/v3/stream-movie';

  setUp(useTestScraperCipher);

  ScraperV3Client client(
    Future<ScraperV3RawResponse> Function(Uri, Map<String, Object?>) reply,
  ) =>
      ScraperV3Client((uri, envelope, _) => reply(uri, envelope));

  Future<String> sealed(Map<String, Object?> envelope, Object payload) async {
    final opened = await openTestRequest(path, envelope);
    return sealTestResponse(
        path, opened.nonce, utf8.encode(jsonEncode(payload)));
  }

  test('opens what the Node server seals', () async {
    // Produced by src/utils/sealed-envelope.ts with a root key of 32 bytes of 7.
    final cipher = ScraperCipher(kid: 'k', rootKey: List<int>.filled(32, 7));
    final body =
        await cipher.open(_nodeVector['path']!, _nodeVector['nonce']!, {
      'iv': _nodeVector['iv'],
      'ct': _nodeVector['ct'],
    });
    expect(jsonDecode(body), {'success': true, 'from': 'node', 'n': 1});
  });

  test('seals params the server can open, without exposing them', () async {
    late Map<String, Object?> sent;
    late Uri sentTo;
    final response = await client((uri, envelope) async {
      sentTo = uri;
      sent = envelope;
      return ScraperV3RawResponse(
          200, await sealed(envelope, {'success': true}));
    }).post('https://scraper.example/api/v2', route, {'tmdbId': '550'});

    expect(sentTo.toString(), 'https://scraper.example/api/v3/stream-movie');
    expect(sent.keys, unorderedEquals(['kid', 'iv', 'ct']));
    expect(sent.toString(), isNot(contains('550')));
    final opened = await openTestRequest(path, sent);
    expect(opened.params, {'tmdbId': '550'});
    expect(response.isSuccess, isTrue);
    expect(jsonDecode(response.body), {'success': true});
  });

  test('keeps the status of a sealed error', () async {
    final response = await client((_, envelope) async => ScraperV3RawResponse(
          404,
          await sealed(envelope, {'success': false, 'error': 'No streams'}),
        )).post('https://scraper.example', route, const {});
    expect(response.statusCode, 404);
    expect(jsonDecode(response.body)['error'], 'No streams');
  });

  test('passes through a plain rejection', () async {
    final response = await client((_, __) async => const ScraperV3RawResponse(
          401,
          '{"success":false,"error":"Unauthorized"}',
        )).post('https://scraper.example', route, const {});
    expect(response.statusCode, 401);
    expect(jsonDecode(response.body)['error'], 'Unauthorized');
  });

  test('rejects a 2xx that is not JSON, such as a captive portal', () async {
    await expectLater(
      client((_, __) async => const ScraperV3RawResponse(
            200,
            '<html>Sign in to Wi-Fi</html>',
          )).post('https://scraper.example', route, const {}),
      throwsA(isA<ScraperV3Exception>()),
    );
  });

  test('rejects a reply sealed for a different request', () async {
    final other = await sealTestResponse(
      path,
      'c29tZS1vdGhlci1ub25jZQ==',
      utf8.encode('{"success":true}'),
    );
    await expectLater(
      client((_, __) async => ScraperV3RawResponse(200, other))
          .post('https://scraper.example', route, const {}),
      throwsA(isA<ScraperV3Exception>()),
    );
  });

  test('corrects a wrong device clock and retries once', () async {
    final serverTime = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 7200;
    final timestamps = <int>[];
    final response = await client((_, envelope) async {
      final opened = await openTestRequest(path, envelope);
      timestamps.add(opened.timestamp);
      return timestamps.length == 1
          ? ScraperV3RawResponse(
              401,
              await sealed(envelope, {
                'success': false,
                'error': 'clock_skew',
                'serverTime': serverTime,
              }),
            )
          : ScraperV3RawResponse(
              200, await sealed(envelope, {'success': true}));
    }).post('https://scraper.example', route, const {});

    expect(response.isSuccess, isTrue);
    expect(timestamps, hasLength(2));
    expect((timestamps.last - serverTime).abs(), lessThan(5));
  });

  test('does not loop when the clock stays rejected', () async {
    var calls = 0;
    final response = await client((_, envelope) async {
      calls++;
      return ScraperV3RawResponse(
        401,
        await sealed(envelope, {
          'success': false,
          'error': 'clock_skew',
          'serverTime': 1,
        }),
      );
    }).post('https://scraper.example', route, const {});
    expect(calls, 2);
    expect(response.statusCode, 401);
  });

  group('fail-safe', () {
    late List<String> reported;
    final plainRequest = {
      'plain': true,
      'params': {'tmdbId': '550'},
    };

    setUp(() {
      reported = [];
      ScraperV3Client.fallbackReporter = reported.add;
    });
    tearDown(() {
      ScraperV3Client.fallbackReporter = (_) {};
    });

    void breakKey() {
      ScraperV3Client.reset();
      ScraperV3Client.cipherLoader = () => Future.error(StateError('no key'));
    }

    test('sends plain straight away when the app has no key', () async {
      breakKey();
      final bodies = <Map<String, Object?>>[];
      final response = await ScraperV3Client((uri, body, _) async {
        bodies.add(body);
        return const ScraperV3RawResponse(200, '{"success":true}');
      }).post('https://scraper.example', route, const {'tmdbId': '550'});

      expect(bodies, [plainRequest]);
      expect(jsonDecode(response.body), {'success': true});
      expect(reported, ['key_unavailable']);
    });

    test('still falls back when the loader throws synchronously', () async {
      ScraperV3Client.reset();
      ScraperV3Client.cipherLoader = () => throw UnsupportedError('no key');
      final response = await ScraperV3Client(
        (_, __, ___) async =>
            const ScraperV3RawResponse(200, '{"success":true}'),
      ).post('https://scraper.example', route, const {});
      expect(response.isSuccess, isTrue);
      expect(reported, ['key_unavailable']);
    });

    test('shows the rejection when a sealed server refuses plain', () async {
      breakKey();
      final response = await ScraperV3Client(
          (_, __, ___) async => const ScraperV3RawResponse(
                401,
                '{"success":false,"error":"Unauthorized"}',
              )).post('https://scraper.example', route, const {});
      expect(response.statusCode, 401);
    });

    test('tries the key again on the next call', () async {
      var loads = 0;
      final working = ScraperV3Client.cipherLoader;
      ScraperV3Client.reset();
      ScraperV3Client.cipherLoader = () {
        loads++;
        return loads == 1 ? Future.error(StateError('no native')) : working();
      };
      final bodies = <Map<String, Object?>>[];
      final api = ScraperV3Client((_, body, __) async {
        bodies.add(body);
        return ScraperV3RawResponse(
          200,
          body['plain'] == true
              ? '{"success":true}'
              : await sealed(body, {'success': true}),
        );
      });

      await api.post('https://scraper.example', route, const {});
      await api.post('https://scraper.example', route, const {});

      expect(bodies.first['plain'], isTrue);
      expect(bodies.last.keys, unorderedEquals(['kid', 'iv', 'ct']));
    });

    test('resends plain once when the server cannot read the request',
        () async {
      final bodies = <Map<String, Object?>>[];
      final response = await ScraperV3Client((_, body, __) async {
        bodies.add(body);
        return body['plain'] == true
            ? const ScraperV3RawResponse(200, '{"success":true}')
            : const ScraperV3RawResponse(
                401,
                '{"success":false,"error":"Unauthorized","fallback":"plain"}',
              );
      }).post('https://scraper.example', route, const {'tmdbId': '550'});

      expect(bodies, hasLength(2));
      expect(bodies.first.keys, unorderedEquals(['kid', 'iv', 'ct']));
      expect(bodies.last, plainRequest);
      expect(response.isSuccess, isTrue);
      expect(reported, ['key_rejected']);
    });

    test('never loops when plain is refused too', () async {
      var calls = 0;
      final response = await ScraperV3Client((_, __, ___) async {
        calls++;
        return const ScraperV3RawResponse(
          401,
          '{"success":false,"error":"Unauthorized","fallback":"plain"}',
        );
      }).post('https://scraper.example', route, const {});
      expect(calls, 2);
      expect(response.statusCode, 401);
    });

    test('does not downgrade on a plain 401 from a sealed server', () async {
      var calls = 0;
      final response = await ScraperV3Client((_, __, ___) async {
        calls++;
        return const ScraperV3RawResponse(
          401,
          '{"success":false,"error":"Unauthorized"}',
        );
      }).post('https://scraper.example', route, const {});
      expect(calls, 1);
      expect(response.statusCode, 401);
      expect(reported, isEmpty);
    });

    test('accepts a plain reply to a sealed request, from open mode', () async {
      final response = await client((_, __) async =>
              const ScraperV3RawResponse(200, '{"success":true,"links":[]}'))
          .post('https://scraper.example', route, const {});
      expect(response.isSuccess, isTrue);
      expect(jsonDecode(response.body)['links'], isEmpty);
      expect(reported, isEmpty);
    });

    test('keeps trying encryption after a downgrade', () async {
      var serverOpen = true;
      final bodies = <Map<String, Object?>>[];
      final api = ScraperV3Client((_, body, __) async {
        bodies.add(body);
        if (body['plain'] == true) {
          return const ScraperV3RawResponse(200, '{"success":true}');
        }
        return serverOpen
            ? const ScraperV3RawResponse(
                401,
                '{"success":false,"fallback":"plain"}',
              )
            : ScraperV3RawResponse(200, await sealed(body, {'success': true}));
      });

      await api.post('https://scraper.example', route, const {});
      serverOpen = false;
      bodies.clear();
      await api.post('https://scraper.example', route, const {});

      expect(bodies, hasLength(1));
      expect(bodies.single.containsKey('plain'), isFalse);
    });
  });

  group('key derivation', () {
    const hash =
        '802EB4659CDBF44CD623B671573928512B5CD32BA67E675ABB3A3537F95C3507';

    Future<List<int>> derive({
      List<int>? fragment,
      List<int>? mix,
      String certificateHash = hash,
      String kid = 'k1',
    }) =>
        deriveScraperRootKey(
          fragment: fragment ?? List<int>.filled(32, 1),
          nativeMix: mix ?? List<int>.filled(32, 2),
          certificateHash: certificateHash,
          packageName: 'dev.example',
          kid: kid,
        );

    test('normalizes keytool and PackageInfo hashes alike', () {
      final colons = RegExp(r'..').allMatches(hash).map((m) => m[0]).join(':');
      expect(normalizeCertificateHash(colons), hash);
      expect(normalizeCertificateHash(hash.toLowerCase()), hash);
      expect(() => normalizeCertificateHash('abc'), throwsFormatException);
    });

    test('every input changes the key', () async {
      final base = await derive();
      expect(await derive(), base);
      expect(await derive(fragment: List<int>.filled(32, 9)), isNot(base));
      expect(await derive(mix: List<int>.filled(32, 9)), isNot(base));
      expect(await derive(kid: 'k2'), isNot(base));
      expect(
        await derive(certificateHash: hash.replaceFirst('8', '9')),
        isNot(base),
        reason: 'a re-signed APK must derive a different key',
      );
    });
  });
}

const _nodeVector = <String, String>{
  'path': '/api/v3/stream-movie',
  'nonce': 'dmVjdG9yLW5vbmNlLTEyMw==',
  'iv': '5XIBvQrKJTYdExUT',
  'ct':
      'G+1U70k8EsguY6poIGD9M5XiY2ObJltlsUGg6keHt9Yng+EP+Yb1OEn1LA5iqyYUBH23LT14p81h83JZjlGMYIWU7ww8ZNc8',
};
