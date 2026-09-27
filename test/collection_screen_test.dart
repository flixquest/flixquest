import 'package:flixquest/catalog/catalog_controller.dart';
import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/mobile/screens/collection_screen.dart';
import 'package:flixquest/mobile/widgets/poster_card.dart';
import 'package:flixquest/models/movie.dart';
import 'package:flixquest/models/tv.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

MediaCollection _collection(MediaKind kind, List<int> requested) =>
    MediaCollection(
      id: kind.name,
      title: 'Netflix',
      kicker: 'STREAMING',
      loadPage: (page) async {
        requested.add(page);
        if (page > 1) return const <MediaItem>[];
        return kind == MediaKind.movie
            ? <MediaItem>[MediaItem.fromMovie(Movie(id: 1, title: 'M'))]
            : <MediaItem>[MediaItem.fromSeries(TV(id: 2, name: 'S'))];
      },
    );

void main() {
  setUp(() async {
    dotenv.testLoad(fileInput: 'FLIXQUEST_API_URL=https://example.com');
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
  });

  testWidgets('movies and series each have their own grid', (tester) async {
    final moviePages = <int>[];
    final seriesPages = <int>[];
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => AppDependencyProvider()),
        ],
        child: MaterialApp(
          home: CollectionScreen.tabbed(
            tabs: <(String, MediaCollection)>[
              ('Movies', _collection(MediaKind.movie, moviePages)),
              ('Series', _collection(MediaKind.series, seriesPages)),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    List<MediaKind> shown() => tester
        .widgetList<PosterCard>(find.byType(PosterCard).hitTestable())
        .map((card) => card.item.kind)
        .toList();
    expect(shown(), <MediaKind>[MediaKind.movie]);
    // The series grid waits until it's asked for.
    expect(seriesPages, isEmpty);

    await tester.tap(find.text('Series'));
    await tester.pumpAndSettle();
    expect(shown(), <MediaKind>[MediaKind.series]);

    // Back again: the movie grid kept its place, nothing reloaded.
    final loaded = moviePages.length;
    await tester.tap(find.text('Movies'));
    await tester.pumpAndSettle();
    expect(shown(), <MediaKind>[MediaKind.movie]);
    expect(moviePages.length, loaded);
  });
}
