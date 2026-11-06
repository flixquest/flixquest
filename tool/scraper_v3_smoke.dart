// Calls a real scraper's encrypted routes from a real signed build, so the key
// the device derives is checked against the key the server holds.
//
//   fvm flutter run --flavor dev -d <device> -t tool/scraper_v3_smoke.dart \
//     --dart-define=SCRAPER_URL=http://10.0.2.2:3000
//
// Prints each result and SCRAPER_V3_SMOKE PASS or FAIL, then exits.
import 'dart:convert';
import 'dart:io';

import 'package:flixquest/core/network/scraper_v3/scraper_v3_client.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

const _baseUrl = String.fromEnvironment('SCRAPER_URL');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final client = ScraperV3Client.http(http.Client());
  var passed = true;

  // Each route must answer sealed with the status its handler chose, and a
  // missing parameter proves the handler ran without scraping anything.
  Future<void> check(
    String route,
    Map<String, Object?> params,
    int expectedStatus,
  ) async {
    try {
      final response = await client.post(_baseUrl, route, params);
      final ok = response.statusCode == expectedStatus &&
          jsonDecode(response.body) is Map;
      passed = passed && ok;
      debugPrint('SCRAPER_V3_SMOKE ${ok ? 'ok' : 'WRONG'} $route '
          '${response.statusCode} ${_summary(response.body)}');
    } catch (error) {
      passed = false;
      debugPrint('SCRAPER_V3_SMOKE ERROR $route $error');
    }
  }

  await check('/stream-movie', const {'tmdbId': '550'}, 400);
  await check('/stream-tv', const {'tmdbId': '1'}, 400);
  await check('/stream-size', const {}, 400);
  await check('/dlhd/stream', const {'id': 'not-a-number'}, 400);
  await check('/ntv/stream', const {'id': '!'}, 400);
  await check(
      '/stream-movie', const {'provider': 'no-such', 'tmdbId': '1'}, 404);

  debugPrint('SCRAPER_V3_SMOKE ${passed ? 'PASS' : 'FAIL'}');
  exit(passed ? 0 : 1);
}

String _summary(String body) =>
    body.length <= 90 ? body : '${body.substring(0, 90)}...';
