import 'package:better_player_plus/better_player_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flixquest/functions/subtitle_options.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/screens/common/player/player_subtitle_side_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    EasyLocalization.logger.enableLevels = [];
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('PlayerSubtitleSidePanel displays main menu and switches to timing submenu',
      (tester) async {
    final controller = BetterPlayerController(
      const BetterPlayerConfiguration(),
      betterPlayerDataSource: BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        'https://example.com/test.mp4',
      ),
    );

    final settings = SettingsProvider();

    final options = [
      SubtitleOption(
        source: BetterPlayerSubtitlesSource(type: BetterPlayerSubtitlesSourceType.none),
        name: 'Off',
        provider: '',
        number: null,
        fallbacks: const [],
      ),
      SubtitleOption(
        source: BetterPlayerSubtitlesSource(
          type: BetterPlayerSubtitlesSourceType.memory,
          name: 'English',
          content: '1\n00:00:01,000 --> 00:00:03,000\nHello\n',
        ),
        name: 'English',
        provider: '',
        number: 1,
        fallbacks: const [],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerSubtitleSidePanel(
            controller: controller,
            options: options,
            settings: settings,
            onClose: () {},
            onSearchOnline: () {},
            onUpload: () {},
            onAutoTranslate: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify track list is shown
    expect(find.text('Off'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'english', caseSensitive: false)),
      findsOneWidget,
    );

    // Tap Timing chip
    final timingChip = find.byIcon(PhosphorIcons.timer());
    expect(timingChip, findsOneWidget);
    await tester.tap(timingChip);
    await tester.pumpAndSettle();

    // Now in timing submenu
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('0.0s'), findsOneWidget);

    // Tap plus button to increment timing offset
    final plusButton = find.byIcon(PhosphorIcons.plus());
    expect(plusButton, findsOneWidget);
    await tester.tap(plusButton);
    await tester.pumpAndSettle();

    // Verify controller offset changed
    expect(controller.subtitleOffset, const Duration(milliseconds: 500));
    expect(find.text('+0.5s'), findsOneWidget);

    // Tap back button
    final backButton = find.byIcon(PhosphorIcons.caretLeft());
    expect(backButton, findsOneWidget);
    await tester.tap(backButton);
    await tester.pumpAndSettle();

    // Back on main page
    expect(find.text('Off'), findsOneWidget);

    controller.dispose();
  });
}
