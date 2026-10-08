import 'dart:async';

import 'package:flixquest/models/ad_network.dart';
import 'package:flixquest/models/vast_preroll_config.dart';
import 'package:flixquest/services/vast/vast.dart';
import 'package:flixquest/services/vast/vast_ad_session.dart';
import 'package:flixquest/services/vast/vast_client.dart';
import 'package:flixquest/widgets/vast_ad_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Shaped like the Clickadu video zone's response: one InLine ad, skippable
// after 5 s, four progressive MP4 renditions, no TrackingEvents.
const inlineVast = '''<?xml version="1.0" encoding="UTF-8"?>
<VAST version="3.0"><Ad id="2830533"><InLine><AdSystem>Clickadu</AdSystem>
<Error><![CDATA[https://ads.example/err?code=[ERRORCODE]]]></Error>
<Impression><![CDATA[https://ads.example/imp]]></Impression>
<Creatives><Creative sequence="1"><Linear skipoffset="00:00:05.000">
<Duration>00:00:30.000</Duration>
<TrackingEvents>
<Tracking event="start"><![CDATA[https://ads.example/start]]></Tracking>
<Tracking event="firstQuartile"><![CDATA[https://ads.example/q1]]></Tracking>
<Tracking event="midpoint"><![CDATA[https://ads.example/mid]]></Tracking>
<Tracking event="thirdQuartile"><![CDATA[https://ads.example/q3]]></Tracking>
<Tracking event="complete"><![CDATA[https://ads.example/complete]]></Tracking>
<Tracking event="skip"><![CDATA[https://ads.example/skip]]></Tracking>
<Tracking event="pause"><![CDATA[https://ads.example/pause]]></Tracking>
<Tracking event="resume"><![CDATA[https://ads.example/resume]]></Tracking>
<Tracking event="closeLinear"><![CDATA[https://ads.example/close]]></Tracking>
<Tracking event="progress" offset="00:00:10"><![CDATA[https://ads.example/p10]]></Tracking>
</TrackingEvents>
<VideoClicks>
<ClickThrough><![CDATA[https://ads.example/click]]></ClickThrough>
<ClickTracking><![CDATA[https://ads.example/clicktrack]]></ClickTracking>
</VideoClicks>
<MediaFiles>
<MediaFile delivery="progressive" type="video/mp4" bitrate="2400" width="1280" height="720"><![CDATA[https://cdn.example/720.mp4]]></MediaFile>
<MediaFile delivery="progressive" type="video/mp4" bitrate="1200" width="854" height="480"><![CDATA[https://cdn.example/480.mp4]]></MediaFile>
<MediaFile delivery="progressive" type="video/mp4" bitrate="720" width="640" height="360"><![CDATA[https://cdn.example/360.mp4]]></MediaFile>
<MediaFile delivery="progressive" type="video/mp4" bitrate="300" width="320" height="180"><![CDATA[https://cdn.example/240.mp4]]></MediaFile>
</MediaFiles></Linear></Creative></Creatives></InLine></Ad></VAST>''';

String wrapperVast(String next) => '''<VAST version="3.0"><Ad id="w"><Wrapper>
<AdSystem>Net</AdSystem><VASTAdTagURI><![CDATA[$next]]></VASTAdTagURI>
<Error><![CDATA[https://wrap.example/err?c=[ERRORCODE]]]></Error>
<Impression><![CDATA[https://wrap.example/imp]]></Impression>
<Creatives><Creative><Linear><TrackingEvents>
<Tracking event="start"><![CDATA[https://wrap.example/start]]></Tracking>
</TrackingEvents><VideoClicks>
<ClickTracking><![CDATA[https://wrap.example/click]]></ClickTracking>
</VideoClicks></Linear></Creative></Creatives></Wrapper></Ad></VAST>''';

// Shaped like the ExoClick video zone's response: one InLine ad, skippable
// after 5 s, a single MP4 without dimensions or bitrate, and only timed
// progress tracking.
const exoclickVast = '''<?xml version="1.0" encoding="UTF-8"?>
<VAST version="3.0"><Ad id="8679490"><InLine><AdSystem>ExoClick</AdSystem>
<AdTitle/>
<Impression id="msgtr"><![CDATA[https://exo.example/imp]]></Impression>
<Error><![CDATA[https://exo.example/err?errorcode=[ERRORCODE]]]></Error>
<Creatives><Creative sequence="1" id="154936984">
<Linear skipoffset="00:00:05.0"><Duration>00:00:12.0</Duration>
<TrackingEvents>
<Tracking id="prog_1" event="progress" offset="00:00:10.000"><![CDATA[https://exo.example/p10]]></Tracking>
<Tracking id="prog_2" event="progress" offset="00:00:02.000"><![CDATA[https://exo.example/p2]]></Tracking>
</TrackingEvents>
<VideoClicks><ClickThrough><![CDATA[https://exo.example/click]]></ClickThrough></VideoClicks>
<MediaFiles>
<MediaFile delivery="progressive" type="video/mp4"><![CDATA[https://cdn.exo.example/ad.mp4]]></MediaFile>
</MediaFiles>
<Icons><Icon><IconClicks><IconClickThrough>icon.example</IconClickThrough></IconClicks></Icon></Icons>
</Linear></Creative></Creatives></InLine></Ad></VAST>''';

void main() {
  group('VAST document', () {
    test('parses the inline ad, its skip offset and media', () {
      final document = VastDocument.parse(inlineVast);
      final ad = document.ads.single.toAd(const []);
      expect(ad.id, '2830533');
      expect(ad.adSystem, 'Clickadu');
      expect(ad.duration, const Duration(seconds: 30));
      expect(ad.skipAfter, const Duration(seconds: 5));
      expect(ad.mediaFiles, hasLength(4));
      expect(ad.clickThrough, Uri.parse('https://ads.example/click'));
      expect(
          ad.tracking['complete'], [Uri.parse('https://ads.example/complete')]);
      expect(ad.progress.single.offset.resolve(ad.duration),
          const Duration(seconds: 10));
    });

    test('picks the largest rendition within the height and bitrate caps', () {
      final ad = VastDocument.parse(inlineVast).ads.single.toAd(const []);
      expect(ad.pickMediaFile(maxHeight: 720, maxBitrate: 2500)!.height, 720);
      expect(ad.pickMediaFile(maxHeight: 720, maxBitrate: 1500)!.height, 480);
      expect(ad.pickMediaFile(maxHeight: 400)!.height, 360);
      // Nothing small enough: the smallest file still plays.
      expect(ad.pickMediaFile(maxHeight: 100)!.height, 180);
    });

    test('reads bitrates sent in bits per second as Kbps', () {
      // Clickadu's live tag states `bitrate="2000000"` for its 720p file.
      final bps = inlineVast
          .replaceFirst('bitrate="2400"', 'bitrate="2000000"')
          .replaceFirst('bitrate="1200"', 'bitrate="1800000"')
          .replaceFirst('bitrate="720"', 'bitrate="1100000"')
          .replaceFirst('bitrate="300"', 'bitrate="500000"');
      final ad = VastDocument.parse(bps).ads.single.toAd(const []);
      expect(
          ad.mediaFiles.map((file) => file.bitrate), [2000, 1800, 1100, 500]);
      expect(ad.pickMediaFile(maxHeight: 720, maxBitrate: 2500)!.height, 720);
      expect(ad.pickMediaFile(maxHeight: 720, maxBitrate: 1500)!.height, 360);
    });

    test('ignores VPAID and other interactive creatives', () {
      final vpaid = inlineVast.replaceAll('type="video/mp4"',
          'type="application/javascript" apiFramework="VPAID"');
      final ad = VastDocument.parse(vpaid).ads.single.toAd(const []);
      expect(ad.pickMediaFile(maxHeight: 1080), isNull);
    });

    test('reads percentage skip offsets and rejects malformed XML', () {
      final percent = inlineVast.replaceFirst(
          'skipoffset="00:00:05.000"', 'skipoffset="50%"');
      expect(VastDocument.parse(percent).ads.single.toAd(const []).skipAfter,
          const Duration(seconds: 15));
      final unskippable =
          inlineVast.replaceFirst(' skipoffset="00:00:05.000"', '');
      expect(
          VastDocument.parse(unskippable).ads.single.toAd(const []).skipAfter,
          isNull);
      expect(
          () => VastDocument.parse('<VAST><Ad>'),
          throwsA(isA<VastException>()
              .having((error) => error.code, 'code', VastError.xmlParsing)));
      expect(VastDocument.parse('<VAST version="3.0"/>').ads, isEmpty);
    });

    test('times and macros', () {
      expect(parseVastTime('00:01:02.5'),
          const Duration(minutes: 1, seconds: 2, milliseconds: 500));
      expect(parseVastTime('1:02'), isNull);
      final expanded = expandVastMacros(
        Uri.parse(
            'https://ads.example/e?c=[ERRORCODE]&t=[ADPLAYHEAD]&cb=[CACHEBUSTING]'),
        errorCode: 402,
        adPlayhead: const Duration(seconds: 12, milliseconds: 5),
      );
      expect(expanded.queryParameters['c'], '402');
      expect(expanded.queryParameters['t'], '00:00:12.005');
      expect(expanded.queryParameters['cb'], isNot('[CACHEBUSTING]'));
    });
  });

  group('VAST client', () {
    late List<Uri> requests;
    late Map<String, http.Response> responses;
    late VastClient client;

    setUp(() {
      requests = [];
      responses = {};
      client = VastClient(
        httpClient: MockClient((request) async {
          requests.add(request.url);
          final key = '${request.url.host}${request.url.path}';
          return responses[key] ?? http.Response('', 204);
        }),
        userAgent: () async => 'test',
      );
    });

    Future<void> drain() => Future<void>.delayed(Duration.zero);

    test('loads an inline tag', () async {
      responses['tag.example/vast.xml'] = http.Response(inlineVast, 200);
      final ad = await client.load(Uri.parse('https://tag.example/vast.xml'),
          timeout: const Duration(seconds: 5));
      expect(ad!.duration, const Duration(seconds: 30));
      expect(requests, hasLength(1));
    });

    test('follows wrappers and merges their tracking', () async {
      responses['tag.example/vast.xml'] =
          http.Response(wrapperVast('https://inner.example/vast.xml'), 200);
      responses['inner.example/vast.xml'] = http.Response(inlineVast, 200);
      final ad = await client.load(Uri.parse('https://tag.example/vast.xml'),
          timeout: const Duration(seconds: 5));
      expect(ad!.impressions, [
        Uri.parse('https://wrap.example/imp'),
        Uri.parse('https://ads.example/imp'),
      ]);
      expect(ad.tracking['start'], [
        Uri.parse('https://wrap.example/start'),
        Uri.parse('https://ads.example/start'),
      ]);
      expect(ad.clickTracking, hasLength(2));
    });

    test('reports the wrapper limit and plays no ad', () async {
      responses['tag.example/vast.xml'] =
          http.Response(wrapperVast('https://tag.example/vast.xml'), 200);
      final ad = await client.load(Uri.parse('https://tag.example/vast.xml'),
          timeout: const Duration(seconds: 5), maxWrappers: 2);
      await drain();
      expect(ad, isNull);
      expect(
          requests.where((url) => url.host == 'wrap.example'),
          everyElement(predicate<Uri>((url) =>
              url.queryParameters['c'] == '${VastError.wrapperLimit}')));
      expect(requests.where((url) => url.host == 'wrap.example'), isNotEmpty);
    });

    test('plays the ExoClick response: one MP4 without dimensions', () async {
      responses['exo.example/vast.php'] = http.Response(exoclickVast, 200);
      final ad = await client.load(Uri.parse('https://exo.example/vast.php'),
          timeout: const Duration(seconds: 5));
      expect(ad!.adSystem, 'ExoClick');
      expect(ad.duration, const Duration(seconds: 12));
      expect(ad.skipAfter, const Duration(seconds: 5));
      expect(ad.clickThrough, Uri.parse('https://exo.example/click'));
      expect(ad.progress.map((event) => event.url.path), ['/p10', '/p2']);
      final media = ad.pickMediaFile(maxHeight: 720, maxBitrate: 2500);
      expect(media!.url, Uri.parse('https://cdn.exo.example/ad.mp4'));
    });

    test('asks networks in priority order until one fills', () async {
      VastPrerollSource source(AdNetwork network, String host) =>
          VastPrerollSource(
              network: network, tagUrl: Uri.parse('https://$host/vast.xml'));
      final sources = [
        source(AdNetwork.exoclick, 'exo.example'),
        source(AdNetwork.clickadu, 'cl.example'),
      ];
      // The first network has no fill: the second one plays.
      responses['exo.example/vast.xml'] =
          http.Response('<VAST version="3.0"/>', 200);
      responses['cl.example/vast.xml'] = http.Response(inlineVast, 200);
      var preroll = await client.loadPreroll(sources, maxHeight: 720);
      expect(preroll!.source.network, AdNetwork.clickadu);
      expect(preroll.media.url, Uri.parse('https://cdn.example/720.mp4'));

      // The first network fills: the second one is never asked.
      responses['exo.example/vast.xml'] = http.Response(exoclickVast, 200);
      requests.clear();
      preroll = await client.loadPreroll(sources, maxHeight: 720);
      expect(preroll!.source.network, AdNetwork.exoclick);
      expect(requests.map((url) => url.host), ['exo.example']);

      // Nobody fills, or the player closed before asking.
      responses.clear();
      expect(await client.loadPreroll(sources, maxHeight: 720), isNull);
      requests.clear();
      expect(
          await client.loadPreroll(sources,
              maxHeight: 720, cancelled: () => true),
          isNull);
      expect(requests, isEmpty);
    });

    test('no fill, HTTP errors and timeouts return no ad', () async {
      responses['tag.example/vast.xml'] =
          http.Response('<VAST version="3.0"/>', 200);
      expect(
          await client.load(Uri.parse('https://tag.example/vast.xml'),
              timeout: const Duration(seconds: 5)),
          isNull);
      responses['tag.example/vast.xml'] = http.Response('nope', 500);
      expect(
          await client.load(Uri.parse('https://tag.example/vast.xml'),
              timeout: const Duration(seconds: 5)),
          isNull);
      final slow = VastClient(
        httpClient: MockClient((_) => Completer<http.Response>().future),
        userAgent: () async => 'test',
      );
      expect(
          await slow.load(Uri.parse('https://tag.example/vast.xml'),
              timeout: const Duration(milliseconds: 50)),
          isNull);
    });
  });

  group('ad session', () {
    late List<(Uri, int?)> pings;
    late VastAd ad;
    late DateTime now;

    VastAdSession session(
        {Duration startTimeout = const Duration(seconds: 8)}) {
      final result = VastAdSession(
        ad: ad,
        media: ad.mediaFiles.first,
        ping: (urls, {errorCode, adPlayhead, assetUri}) {
          for (final url in urls) {
            pings.add((url, errorCode));
          }
        },
        startTimeout: startTimeout,
        now: () => now,
      );
      return result;
    }

    List<String> paths() => [for (final ping in pings) ping.$1.path];

    void play(VastAdSession s, int seconds) {
      now = now.add(const Duration(seconds: 1));
      s.onPosition(
          position: Duration(seconds: seconds),
          duration: const Duration(seconds: 30),
          playing: true,
          buffering: false);
    }

    setUp(() {
      pings = [];
      ad = VastDocument.parse(inlineVast).ads.single.toAd(const []);
      now = DateTime(2026);
    });

    test('impression, start and quartiles fire once each, then complete', () {
      final s = session()..begin();
      s.onPosition(position: Duration.zero, playing: true, buffering: true);
      expect(pings, isEmpty);
      for (var second = 1; second <= 30; second++) {
        play(s, second);
      }
      play(s, 30);
      s.onEnded('completed');
      expect(paths(),
          ['/imp', '/start', '/q1', '/p10', '/mid', '/q3', '/complete']);
      expect(s.value.ended, isTrue);
      s.dispose();
    });

    test('Skip is refused before the offset and tracked after it', () {
      final s = session()..begin();
      var abandoned = 0;
      s.onAbandon = () => abandoned++;
      play(s, 3);
      expect(s.value.canSkip, isFalse);
      expect(s.value.skipCountdown, 2);
      expect(s.requestSkip(), isFalse);
      play(s, 5);
      expect(s.value.canSkip, isTrue);
      expect(s.requestSkip(), isTrue);
      expect(abandoned, 1);
      s.onEnded('skipped');
      expect(paths(), contains('/skip'));
      expect(paths(), isNot(contains('/complete')));
      s.dispose();
    });

    testWidgets('media that never starts reports 402 and leaves the ad',
        (tester) async {
      final s = session(startTimeout: const Duration(seconds: 8))..begin();
      var abandoned = 0;
      s.onAbandon = () => abandoned++;
      await tester.pump(const Duration(seconds: 8));
      expect(abandoned, 1);
      s.onEnded('skipped');
      expect(pings.single.$1.path, '/err');
      expect(pings.single.$2, VastError.mediaTimeout);
      s.dispose();
    });

    test('a native playback error reports 405 after the start', () {
      final s = session()..begin();
      play(s, 2);
      s.onEnded('error');
      expect(pings.last.$2, VastError.mediaDisplay);
      s.dispose();
    });

    test('a stall reports 402 and leaves the ad', () {
      final s = session()..begin();
      var abandoned = 0;
      s.onAbandon = () => abandoned++;
      play(s, 2);
      now = now.add(const Duration(seconds: 11));
      s.onPosition(
          position: const Duration(seconds: 2), playing: true, buffering: true);
      expect(abandoned, 1);
      s.onEnded('skipped');
      expect(pings.last.$2, VastError.mediaTimeout);
      s.dispose();
    });

    test('pause and resume are tracked; a deliberate pause is not a stall', () {
      final s = session()..begin();
      var abandoned = 0;
      s.onAbandon = () => abandoned++;
      play(s, 2);
      s.onPaused();
      now = now.add(const Duration(minutes: 1));
      s.onPosition(
          position: const Duration(seconds: 2),
          playing: false,
          buffering: false);
      s.onResumed();
      expect(abandoned, 0);
      expect(paths(), containsAllInOrder(['/pause', '/resume']));
      s.dispose();
    });

    test('closing the player mid-ad sends closeLinear, never complete', () {
      final s = session()..begin();
      play(s, 4);
      s.onClosed();
      expect(paths(), contains('/close'));
      expect(paths(), isNot(contains('/complete')));
      s.dispose();
    });

    test('click sends click tracking and returns the advertiser page', () {
      final s = session()..begin();
      play(s, 1);
      expect(s.click(), Uri.parse('https://ads.example/click'));
      expect(paths(), contains('/clicktrack'));
      s.dispose();
    });
  });

  group('config', () {
    test('requires an HTTPS tag and keeps values in range', () {
      expect(
          VastPrerollConfig.parse('{}',
              enabled: true, networks: [AdNetwork.clickadu]).isActive,
          isFalse);
      expect(
          VastPrerollConfig.parse('{"tag_url":"http://a.example/t.xml"}',
              enabled: true, networks: [AdNetwork.clickadu]).isActive,
          isFalse);
      final config = VastPrerollConfig.parse(
          '{"tag_url":"https://a.example/t.xml","request_timeout_ms":999999,'
          '"max_wrappers":-3,"tv_enabled":true}',
          enabled: true,
          networks: [AdNetwork.clickadu]);
      expect(config.isActive, isTrue);
      expect(config.sources.single.requestTimeout, const Duration(seconds: 15));
      expect(config.sources.single.maxWrappers, 0);
      expect(config.appliesTo(television: true), isTrue);
      final phoneOnly = VastPrerollConfig.parse(
          '{"tag_url":"https://a.example/t.xml"}',
          enabled: true,
          networks: [AdNetwork.clickadu]);
      expect(phoneOnly.appliesTo(television: false), isTrue);
      expect(phoneOnly.appliesTo(television: true), isFalse);
      final off = VastPrerollConfig.parse(
          '{"tag_url":"https://a.example/t.xml"}',
          enabled: false,
          networks: [AdNetwork.clickadu]);
      expect(off.isActive, isFalse);
      expect(off.sourcesFor(television: false), isEmpty);
    });

    test('vast_preroll_network picks that network\'s section', () {
      const catalog = '{"clickadu":{"tag_url":"https://cl.example/t.xml",'
          '"tv_enabled":true},'
          '"exoclick":{"tag_url":"https://exo.example/vast.php?idz=1",'
          '"request_timeout_ms":2000}}';
      final clickadu = VastPrerollConfig.parse(catalog,
          enabled: true, networks: [AdNetwork.clickadu]).sources.single;
      expect(clickadu.network, AdNetwork.clickadu);
      expect(clickadu.tagUrl, Uri.parse('https://cl.example/t.xml'));
      expect(clickadu.tvEnabled, isTrue);
      final exoclick = VastPrerollConfig.parse(catalog,
          enabled: true, networks: [AdNetwork.exoclick]).sources.single;
      expect(exoclick.network, AdNetwork.exoclick);
      expect(exoclick.tagUrl, Uri.parse('https://exo.example/vast.php?idz=1'));
      expect(exoclick.requestTimeout, const Duration(seconds: 2));
      expect(exoclick.tvEnabled, isFalse);
      expect(
          VastPrerollConfig.parse(catalog, enabled: true, networks: const [])
              .isActive,
          isFalse);
      // A network without a section plays nothing.
      expect(
          VastPrerollConfig.parse(
              '{"clickadu":{"tag_url":"https://cl.example/t.xml"}}',
              enabled: true,
              networks: [AdNetwork.exoclick]).isActive,
          isFalse);
      // A flat catalog from before the selector serves the first network.
      final flat = VastPrerollConfig.parse(
          '{"tag_url":"https://a.example/t.xml"}',
          enabled: true,
          networks: [AdNetwork.exoclick, AdNetwork.clickadu]);
      expect(
          flat.sources.map((source) => source.network), [AdNetwork.exoclick]);
      expect(flat.sources.single.tagUrl, Uri.parse('https://a.example/t.xml'));
    });

    test('a priority list keeps its order and skips networks without a tag',
        () {
      expect(AdNetwork.parseList(' ExoClick, clickadu ,bogus,exoclick'),
          [AdNetwork.exoclick, AdNetwork.clickadu]);
      expect(AdNetwork.parseList('none'), isEmpty);
      expect(AdNetwork.parseList(''), isEmpty);
      const catalog = '{"clickadu":{"tag_url":"https://cl.example/t.xml",'
          '"tv_enabled":true},'
          '"exoclick":{"tag_url":"https://exo.example/vast.php?idz=1"}}';
      final config = VastPrerollConfig.parse(catalog,
          enabled: true,
          networks: AdNetwork.parseList('adsterra,exoclick,clickadu'));
      expect(config.sources.map((source) => source.network),
          [AdNetwork.exoclick, AdNetwork.clickadu]);
      // TV asks only the networks that accept TV traffic.
      expect(
          config.sourcesFor(television: true).map((source) => source.network),
          [AdNetwork.clickadu]);
      expect(
          config,
          VastPrerollConfig.parse(catalog,
              enabled: true,
              networks: [AdNetwork.exoclick, AdNetwork.clickadu]));
    });
  });

  group('overlay', () {
    late VastAdSession session;

    setUp(() {
      final ad = VastDocument.parse(inlineVast).ads.single.toAd(const []);
      session = VastAdSession(
        ad: ad,
        media: ad.mediaFiles.first,
        ping: (urls, {errorCode, adPlayhead, assetUri}) {},
        startTimeout: const Duration(seconds: 8),
      );
    });

    tearDown(() => session.dispose());

    Future<void> pump(WidgetTester tester, {required bool television}) =>
        tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: VastAdOverlay(
              session: session,
              television: television,
              onVisitAdvertiser: (_) {},
              onExit: () {},
            ),
          ),
        ));

    void at(int seconds) => session.onPosition(
        position: Duration(seconds: seconds),
        duration: const Duration(seconds: 30),
        playing: true,
        buffering: false);

    testWidgets('counts down, then offers Skip', (tester) async {
      await pump(tester, television: false);
      expect(find.text('Ad'), findsOneWidget);
      at(2);
      await tester.pump();
      expect(find.text('Ad · 0:28'), findsOneWidget);
      expect(find.text('Skip in 3'), findsOneWidget);
      expect(find.text('Visit advertiser'), findsOneWidget);
      at(5);
      await tester.pump();
      var abandoned = 0;
      session.onAbandon = () => abandoned++;
      await tester.tap(find.text('Skip ad'));
      expect(abandoned, 1);
    });

    testWidgets('TV hides the advertiser link and focuses Skip',
        (tester) async {
      await pump(tester, television: true);
      at(6);
      await tester.pump();
      await tester.pump();
      expect(find.text('Visit advertiser'), findsNothing);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      final focused = FocusManager.instance.primaryFocus;
      expect(focused?.debugLabel, 'vast-skip');
    });
  });
}
