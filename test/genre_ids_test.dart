import 'package:flixquest/models/genre_ids.dart';
import 'package:flixquest/models/movie.dart';
import 'package:flixquest/models/tv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads genres however they were stored', () {
    expect(parseGenreIds(<dynamic>[28, 12]), <int>[28, 12]);
    expect(parseGenreIds('28,12'), <int>[28, 12]);
    expect(parseGenreIds(' 28, 12 '), <int>[28, 12]);
    expect(parseGenreIds('[28,12]'), <int>[28, 12]);
    expect(parseGenreIds(<dynamic>['28', 12]), <int>[28, 12]);
    // Rows from before genres were kept, and anything unreadable.
    expect(parseGenreIds(null), isNull);
    expect(parseGenreIds(''), isNull);
    expect(parseGenreIds('[oops'), isNull);
    expect(parseGenreIds(42), isNull);
    expect(encodeGenreIds(<int>[28, 12]), '28,12');
    expect(encodeGenreIds(const <int>[]), isNull);
  });

  group('a bookmarked movie', () {
    test('keeps its genres in the local table', () {
      final movie = Movie.fromJson(<String, dynamic>{
        'id': 1,
        'title': 'Dune',
        'genre_ids': <int>[878, 12],
      });
      final row = movie.toMap();
      expect(row['genre_ids'], '878,12');
      expect(Movie.fromMapObject(row).genreIds, <int>[878, 12]);
    });

    test('a row saved before genres were kept still reads', () {
      final movie = Movie.fromMapObject(<String, dynamic>{
        'id': 1,
        'title': 'Dune',
        'date_added': '2025-01-01 10:00:00.000',
      });
      expect(movie.genreIds, isNull);
      expect(movie.title, 'Dune');
    });

    test('an update without genres leaves the stored ones alone', () {
      final movie = Movie(id: 1, title: 'Dune');
      expect(movie.toMap().containsKey('genre_ids'), isFalse);
    });

    test('goes to the cloud as a list and comes back either way', () {
      final movie = Movie(id: 1, title: 'Dune', genreIds: <int>[878]);
      expect(movie.toJson()['genre_ids'], <int>[878]);
      // Cloud copies are written with toMap, so genres arrive as text.
      expect(Movie.fromJson(movie.toMap()).genreIds, <int>[878]);
      // And an older app's copy has none, without failing.
      expect(Movie.fromJson(<String, dynamic>{'id': 1}).genreIds, isNull);
    });
  });

  group('a bookmarked series', () {
    test('keeps its genres in the local table and the cloud', () {
      final series = TV.fromJson(<String, dynamic>{
        'id': 7,
        'name': 'Severance',
        'genre_ids': <int>[18, 9648],
      });
      final row = series.toMap();
      expect(row['genre_ids'], '18,9648');
      expect(TV.fromMapObject(row).genreIds, <int>[18, 9648]);
      expect(TV.fromJson(row).genreIds, <int>[18, 9648]);
    });

    test('rows and cloud copies from before still read', () {
      expect(
        TV.fromMapObject(<String, dynamic>{'id': 7, 'name': 'S'}).genreIds,
        isNull,
      );
      expect(TV(id: 7).toMap().containsKey('genre_ids'), isFalse);
      expect(TV(id: 7).toJson().containsKey('genre_ids'), isFalse);
    });
  });
}
