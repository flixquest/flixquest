import 'package:flixquest/models/provider_load_state.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/widgets/playback_loading_screen.dart';
import 'package:flixquest/widgets/provider_loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'FLIXQUEST_API_URL=https://example.com');
  });

  testWidgets('fits the provider loader in a compact landscape viewport',
      (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppDependencyProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SingleChildScrollView(
                child: ProviderLoadingWidget(
                  currentIndex: 1,
                  providers: [
                    ProviderLoadState(
                      codeName: 'first',
                      fullName: 'First provider with a long display name',
                      status: ProviderStatus.failed,
                    ),
                    ProviderLoadState(
                      codeName: 'second',
                      fullName: 'Second provider',
                      content: 'Hollywood: English | Anime: Japanese',
                      status: ProviderStatus.loading,
                    ),
                    ProviderLoadState(
                      codeName: 'third',
                      fullName: 'Third provider',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Second provider'), findsOneWidget);
    expect(find.text('Hollywood: English | Anime: Japanese'), findsOneWidget);
  });

  testWidgets('playback loader lays out in a tall phone viewport',
      (tester) async {
    // Regression for a Spacer receiving an unbounded height from the loader's
    // scroll view on phones taller than 820 logical pixels.
    tester.view.physicalSize = const Size(411.4, 826.3);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppDependencyProvider(),
        child: MaterialApp(
          home: PlaybackLoadingScreen(
            title: 'The Last Voyage',
            subtitle: '2026',
            currentProviderIndex: 0,
            providers: [
              ProviderLoadState(
                codeName: 'first',
                fullName: 'First provider',
                status: ProviderStatus.loading,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('The Last Voyage'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('provider-loading-panel')),
      findsOneWidget,
    );
  });

  for (final viewport in const <Size>[Size(960, 540), Size(640, 360)]) {
    testWidgets('playback loader fits a long source list at $viewport',
        (tester) async {
      // 960x540 is an Android TV at density 2; 640x360 a small landscape
      // phone, where the ads stack under the race instead of beside it.
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AppDependencyProvider(),
          child: MaterialApp(
            home: PlaybackLoadingScreen(
              title: 'A title long enough to need a second line on a phone',
              subtitle: 'S1:E3  ·  The Episode',
              currentProviderIndex: 3,
              providers: [
                for (var index = 0; index < 14; index++)
                  ProviderLoadState(
                    codeName: 'provider$index',
                    fullName: 'Provider number $index',
                    content: 'Hollywood: English | Anime: Japanese',
                    status: index < 3
                        ? ProviderStatus.failed
                        : index < 6
                            ? ProviderStatus.loading
                            : ProviderStatus.pending,
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Provider number 13'), findsOneWidget);
    });
  }

  testWidgets('shows a skeleton until the source list arrives', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppDependencyProvider(),
        child: const MaterialApp(
          home: Scaffold(
            body: ProviderLoadingWidget(providers: [], currentIndex: 0),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('loading_video_sources'), findsOneWidget);
  });
}
