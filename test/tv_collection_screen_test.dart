import 'package:flixquest/api/endpoints.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/tv/controllers/tv_catalog_controller.dart';
import 'package:flixquest/tv/focus/tv_focus_memory.dart';
import 'package:flixquest/tv/models/tv_media_item.dart';
import 'package:flixquest/tv/screens/tv_collection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/tv_localization.dart';

// No artwork, so nothing reaches for the network.
TvMediaItem _item(int id) => TvMediaItem(
      kind: TvMediaKind.movie,
      id: id,
      title: 'Title $id',
      overview: '',
      posterPath: null,
      backdropPath: null,
      rating: 7,
      releaseDate: '2024-01-01',
    );

List<TvMediaItem> _items(Iterable<int> ids) =>
    ids.map(_item).toList(growable: false);

Future<void> _pumpCollection(
  WidgetTester tester,
  Future<List<TvMediaItem>> Function(int page) loadPage,
) async {
  tester.view.physicalSize = const Size(960, 540);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AppDependencyProvider()),
      ],
      child: MaterialApp(
        home: TvFocusMemoryScope(
          memory: TvFocusMemory(),
          child: TvCollectionScreen(
            collection: TvCollection(
              id: 'test',
              title: 'Popular movies',
              kicker: 'MOVIES',
              loadPage: loadPage,
            ),
            onOpenMedia: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  initializeTvTranslations();
  setUpAll(() {});

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
  });

  testWidgets('a page of only repeats does not end the collection',
      (tester) async {
    final requested = <int>[];
    await _pumpCollection(tester, (page) async {
      requested.add(page);
      return switch (page) {
        1 => _items(<int>[1, 2, 3]),
        // TMDB shuffled the boundary: everything here is already shown.
        2 => _items(<int>[3, 2, 1]),
        3 => _items(<int>[4, 5]),
        _ => const <TvMediaItem>[],
      };
    });

    // Focus never moved past the repeats, yet the next page came anyway.
    expect(requested, <int>[1, 2, 3]);
    expect(find.text('Title 5'), findsOneWidget);
    expect(find.text('Title 1'), findsOneWidget);
  });

  testWidgets('a later page failing keeps the titles, says so, and retries',
      (tester) async {
    var failSecondPage = true;
    await _pumpCollection(tester, (page) async {
      if (page == 1) return _items(<int>[1, 2, 3]);
      if (page == 2) {
        if (failSecondPage) throw Exception('offline');
        return _items(<int>[4, 5]);
      }
      return const <TvMediaItem>[];
    });

    expect(find.text('Title 3'), findsOneWidget);
    expect(
      find.text('Couldn\'t load more titles. Move down again to retry.'),
      findsOneWidget,
    );

    failSecondPage = false;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Title 5'), findsOneWidget);
    expect(
      find.text('Couldn\'t load more titles. Move down again to retry.'),
      findsNothing,
    );
  });

  group('catalog lists', () {
    test('a row and its See all read the same TMDB list', () {
      expect(
        TvCatalogController.listUrl(
            TvMediaKind.movie, CatalogList.trendingToday, 'en'),
        Endpoints.trendingMoviesTodayUrl('en'),
      );
      expect(
        TvCatalogController.listUrl(
            TvMediaKind.series, CatalogList.trendingWeek, 'en'),
        Endpoints.trendingTVUrl('en'),
      );
      expect(
        TvCatalogController.listUrl(TvMediaKind.movie, CatalogList.fresh, 'en'),
        Endpoints.upcomingMoviesUrl('en'),
      );
      expect(
        TvCatalogController.listUrl(
            TvMediaKind.series, CatalogList.fresh, 'en'),
        Endpoints.onTheAirUrl('en'),
      );
    });

    test('past TMDB\'s last page a list has ended, without asking', () async {
      final collection = const TvCatalogController().catalogListCollection(
        kind: TvMediaKind.series,
        list: CatalogList.popular,
        title: 'Popular series',
        settings: SettingsProvider(),
        dependencies: AppDependencyProvider(),
      );
      expect(collection.id, 'series-popular');
      expect(collection.title, 'Popular series');
      expect(await collection.loadPage(501), isEmpty);
    });
  });
}
