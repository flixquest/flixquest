import 'package:flixquest/services/start_io_ads_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InterstitialPacing', () {
    late DateTime now;
    late InterstitialPacing pacing;

    setUp(() {
      now = DateTime(2026, 9, 27, 20);
      pacing = InterstitialPacing(now: () => now);
    });

    test('the first play of a session may show an ad', () {
      expect(pacing.canShow(const Duration(minutes: 10)), isTrue);
    });

    test('a second play inside the interval shows none', () {
      pacing.recordShown();
      now = now.add(const Duration(minutes: 3));
      expect(pacing.canShow(const Duration(minutes: 10)), isFalse);

      now = now.add(const Duration(minutes: 7));
      expect(pacing.canShow(const Duration(minutes: 10)), isTrue);
    });

    test('an ad-free pass holds every ad until it expires', () {
      final until = pacing.grantAdFree(const Duration(hours: 2));
      expect(until, DateTime(2026, 9, 27, 22));
      expect(pacing.adFreeActive, isTrue);
      expect(pacing.adFreeUntil, until);
      expect(pacing.canShow(Duration.zero), isFalse);

      now = until;
      expect(pacing.adFreeActive, isFalse);
      expect(pacing.adFreeUntil, isNull);
      expect(pacing.canShow(Duration.zero), isTrue);
    });

    test('a restored pass that already expired is ignored', () {
      pacing.restoreAdFree(now.subtract(const Duration(minutes: 1)));
      expect(pacing.adFreeActive, isFalse);
      expect(pacing.canShow(Duration.zero), isTrue);
    });
  });

  group('StartIoInterstitialMode.parse', () {
    test('reads automatic and falls back to video', () {
      expect(
        StartIoInterstitialMode.parse(' Automatic '),
        StartIoInterstitialMode.automatic,
      );
      expect(
        StartIoInterstitialMode.parse('video'),
        StartIoInterstitialMode.video,
      );
      expect(StartIoInterstitialMode.parse(''), StartIoInterstitialMode.video);
    });
  });

  test('StartIoAdsConfig compares by value', () {
    const config = StartIoAdsConfig();
    expect(config.copyWith(), config);
    expect(
      config.copyWith(interstitialInterval: const Duration(minutes: 5)),
      isNot(config),
    );
  });

  test('TV placements carry their own tag', () {
    final ads = StartIoAdsService.instance;
    addTearDown(() => ads.setTelevision(false));
    expect(ads.tagFor('title_detail'), 'title_detail');
    ads.setTelevision(true);
    expect(ads.tagFor('title_detail'), 'title_detail_tv');
  });
}
