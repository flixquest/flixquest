import 'package:flixquest/services/ad_redirect_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final popup = Uri.parse('https://flix.quest/api/exoclick-popup');

  test('reads the delivery host without following the redirect', () async {
    final requests = <http.BaseRequest>[];
    final resolver = AdRedirectResolver(
      clientFactory: () => MockClient((request) async {
        requests.add(request);
        return http.Response('', 302, headers: {
          'location': 'https://s.rotating.example/v1/link.php?idzone=6070628'
        });
      }),
    );
    expect(await resolver.hosts({popup}), {'s.rotating.example'});
    expect(requests.single.method, 'HEAD');
    expect(requests.single.followRedirects, isFalse);
  });

  test('reuses a fresh host and keeps the last one when the server is down',
      () async {
    var now = DateTime(2026, 10, 31);
    var calls = 0;
    var serverUp = true;
    final resolver = AdRedirectResolver(
      now: () => now,
      clientFactory: () => MockClient((_) async {
        calls++;
        if (!serverUp) throw http.ClientException('Connection refused');
        return http.Response('', 302,
            headers: {'location': 'https://s.rotating.example/v1/link.php'});
      }),
    );
    expect(await resolver.host(popup), 's.rotating.example');
    expect(await resolver.host(popup), 's.rotating.example');
    expect(calls, 1);

    now = now.add(const Duration(hours: 2));
    serverUp = false;
    expect(await resolver.host(popup), 's.rotating.example');
    expect(calls, 2);
  });

  test('errors, plain responses and first-party hops resolve to nothing',
      () async {
    for (final response in [
      http.Response('Ad delivery unavailable', 502),
      http.Response('', 200),
      http.Response('', 302, headers: {'location': '/download'}),
      http.Response('', 302,
          headers: {'location': 'https://www.flix.quest/elsewhere'}),
    ]) {
      final resolver = AdRedirectResolver(
          clientFactory: () => MockClient((_) async => response));
      expect(await resolver.host(popup), isNull,
          reason: '${response.statusCode} ${response.headers}');
    }
  });

  test('resolved chains drop any ad whose source stays unknown', () async {
    final resolver = AdRedirectResolver(
      clientFactory: () => MockClient((request) async => request.url == popup
          ? http.Response('', 302,
              headers: {'location': 'https://s.rotating.example/l'})
          : http.Response('page', 200)),
    );
    final page = Uri.parse('https://flix.quest/a/3ad05c8e4d');
    final ads = await resolver.resolve((
      required: {Uri.parse('https://ads.example/s.js'), page, null},
      alternatives: [
        {popup, Uri.parse('https://smart.example/l')},
        {popup, null},
        {page, Uri.parse('https://other.example/l')},
      ],
    ));
    expect(ads.required, {'ads.example'});
    expect(ads.alternatives, [
      {'s.rotating.example', 'smart.example'}
    ]);
    expect(ads.blockedBy({'s.rotating.example'}), isFalse);
    expect(ads.blockedBy({'s.rotating.example', 'smart.example'}), isTrue);
    expect(ads.blockedBy({'ads.example'}), isTrue);
  });
}
