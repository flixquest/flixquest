import 'package:flixquest/models/movie_stream_metadata.dart';
import 'package:flixquest/models/recently_watched.dart';
import 'package:flixquest/models/tv_stream_metadata.dart';
import 'package:flixquest/provider/recently_watched_provider.dart';
import 'package:flixquest/screens/common/player/player_episode_selection.dart';
import 'package:flixquest/screens/common/player/player_movie_recommendations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('recommendations route can be opened from navigator overlay',
      (tester) async {
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold();
          },
        ),
      ),
    );

    final navigator = Navigator.of(pageContext, rootNavigator: true);
    final metadata = MovieStreamMetadata(
      backdropPath: null,
      elapsed: 0,
      movieId: 1,
      movieName: 'Current movie',
      posterPath: null,
      releaseYear: 2026,
      isAdult: false,
      releaseDate: '2026-01-01',
      recommendations: [MovieRecommendation(movieId: 2, title: 'Next movie')],
    );

    final closed =
        PlayerMovieRecommendations().showMovieRecommendationsBottomSheet(
      context: navigator.overlay!.context,
      colors: const [Colors.red, Colors.black],
      movieMetadata: metadata,
      onSaveProgress: () {},
      closePlayer: () {},
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Next movie'), findsOneWidget);
    navigator.pop();
    await tester.pump(const Duration(milliseconds: 300));
    await closed;
  });

  testWidgets('episodes route can be opened from navigator overlay',
      (tester) async {
    late BuildContext pageContext;
    await tester.pumpWidget(
      ChangeNotifierProvider<RecentProvider>(
        create: (_) => _RecentProvider(),
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              pageContext = context;
              return const Scaffold();
            },
          ),
        ),
      ),
    );

    final navigator = Navigator.of(pageContext, rootNavigator: true);
    final metadata = TVStreamMetadata(
      elapsed: 0,
      episodeId: 1,
      episodeName: 'Current episode',
      episodeNumber: 1,
      posterPath: null,
      seasonNumber: 1,
      seriesName: 'Series',
      tvId: 10,
      airDate: '2026-01-01',
      seasonEpisodes: [
        EpisodeMetadata(
          episodeId: 1,
          episodeName: 'Current episode',
          episodeNumber: 1,
          seasonNumber: 1,
        ),
        EpisodeMetadata(
          episodeId: 2,
          episodeName: 'Next episode',
          episodeNumber: 2,
          seasonNumber: 1,
        ),
      ],
    );

    final closed = PlayerEpisodeSelection(1).showEpisodeSelectionBottomSheet(
      context: navigator.overlay!.context,
      colors: const [Colors.red, Colors.black],
      tvMetadata: metadata,
      onSaveProgress: () {},
      closePlayer: () {},
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('2. Next episode'), findsOneWidget);
    navigator.pop();
    await tester.pump(const Duration(milliseconds: 300));
    await closed;
  });
}

// Route rendering only needs watch progress. Avoid initializing Firebase and
// cloud sync just to supply an empty episode history to this widget test.
class _RecentProvider extends ChangeNotifier implements RecentProvider {
  @override
  List<RecentEpisode> get episodes => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
