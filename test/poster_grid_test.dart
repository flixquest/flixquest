import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/mobile/widgets/poster_card.dart';
import 'package:flixquest/mobile/widgets/poster_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MediaItem _item(int id) => MediaItem(
      kind: MediaKind.movie,
      id: id,
      title: 'Movie $id',
      overview: '',
      posterPath: null,
      backdropPath: null,
      rating: 7.6,
      releaseDate: '2024-01-01',
    );

void main() {
  testWidgets('artwork only, with no name or rating under the posters',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PosterGrid(items: List<MediaItem>.generate(5, _item)),
        ),
      ),
    );

    expect(find.byType(PosterCard), findsNWidgets(5));
    expect(find.text('Movie 0'), findsNothing);
    expect(find.text('7.6'), findsNothing);
  });
}
