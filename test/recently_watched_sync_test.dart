import 'package:flixquest/models/recently_watched.dart';
import 'package:flixquest/services/recently_watched_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveCloudWinners', () {
    test('pulls a cloud row whose progress is newer than the local copy', () {
      final winners = resolveCloudWinners(
        cloudVersions: <int, int>{550: 2000},
        localVersions: <int, int>{550: 1000},
      );

      expect(winners, <int>{550});
    });

    test('keeps the local row when it was written more recently', () {
      final winners = resolveCloudWinners(
        cloudVersions: <int, int>{550: 1000},
        localVersions: <int, int>{550: 2000},
      );

      expect(winners, isEmpty);
    });

    test('keeps the local row on an identical stamp so a tie is not rewritten',
        () {
      final winners = resolveCloudWinners(
        cloudVersions: <int, int>{550: 1500},
        localVersions: <int, int>{550: 1500},
      );

      expect(winners, isEmpty);
    });

    test('pulls a live row this device has never seen', () {
      final winners = resolveCloudWinners(
        cloudVersions: <int, int>{550: 1000},
        localVersions: <int, int>{},
      );

      expect(winners, <int>{550});
    });

    test('a newer cloud tombstone removes a locally visible row', () {
      final winners = resolveCloudWinners(
        cloudVersions: <int, int>{550: 2000},
        localVersions: <int, int>{550: 1000},
        cloudDeleted: <int>{550},
      );

      expect(winners, <int>{550});
    });

    test('an older cloud tombstone loses to fresh local progress', () {
      final winners = resolveCloudWinners(
        cloudVersions: <int, int>{550: 1000},
        localVersions: <int, int>{550: 3000},
        cloudDeleted: <int>{550},
      );

      expect(winners, isEmpty);
    });

    test('skips tombstones for rows this device never stored', () {
      final winners = resolveCloudWinners(
        cloudVersions: <int, int>{550: 2000, 66732: 2000},
        localVersions: <int, int>{},
        cloudDeleted: <int>{550},
      );

      expect(winners, <int>{66732});
    });
  });

  group('RecentMovie sync fields', () {
    RecentMovie buildMovie({int? updatedAtUtc, int? deletedAtUtc}) => RecentMovie(
          backdropPath: '/backdrop.jpg',
          dateTime: '2026-09-05 12:00:00.000',
          elapsed: 600,
          id: 550,
          posterPath: '/poster.jpg',
          releaseYear: 1999,
          remaining: 300,
          title: 'Fight Club',
          updatedAtUtc: updatedAtUtc,
          deletedAtUtc: deletedAtUtc,
        );

    test('stamps new rows as pending and undeleted', () {
      final movie = buildMovie();

      expect(movie.synced, isFalse);
      expect(movie.isDeleted, isFalse);
      expect(movie.updatedAtUtc, greaterThan(0));
    });

    test('survives a round trip through the local database map', () {
      final movie = buildMovie(updatedAtUtc: 4242, deletedAtUtc: 5353);

      final restored = RecentMovie.fromMapObject(movie.toMap());

      expect(restored.id, 550);
      expect(restored.elapsed, 600);
      expect(restored.remaining, 300);
      expect(restored.updatedAtUtc, 4242);
      expect(restored.deletedAtUtc, 5353);
      expect(restored.isDeleted, isTrue);
      expect(restored.synced, isFalse);
    });

    test('survives a round trip through the backend payload', () {
      final movie = buildMovie(updatedAtUtc: 4242);

      final restored = RecentMovie.fromLaravelMap(movie.toLaravelMap());

      expect(restored.id, 550);
      expect(restored.title, 'Fight Club');
      expect(restored.backdropPath, '/backdrop.jpg');
      expect(restored.dateTime, '2026-09-05 12:00:00.000');
      expect(restored.updatedAtUtc, 4242);
      expect(restored.deletedAtUtc, isNull);
    });

    test('uses the backend media id when the legacy payload id is omitted', () {
      final payload = buildMovie(updatedAtUtc: 4242).toLaravelMap()
        ..remove('id');

      final restored = RecentMovie.fromLaravelMap(payload);

      expect(restored.id, 550);
    });

    test('treats a cloud row with no stamp as older than any local write', () {
      final restored = RecentMovie.fromLaravelMap(<String, dynamic>{'movie_id': 550});

      expect(restored.updatedAtUtc, 0);
    });
  });

  group('RecentEpisode sync fields', () {
    RecentEpisode buildEpisode({int? updatedAtUtc, int? deletedAtUtc}) =>
        RecentEpisode(
          dateTime: '2026-09-05 12:00:00.000',
          elapsed: 900,
          episodeName: 'Pilot',
          episodeNum: 1,
          id: 62085,
          posterPath: '/poster.jpg',
          backdropPath: '/still.jpg',
          remaining: 1200,
          seasonNum: 1,
          seriesName: 'Breaking Bad',
          seriesId: 1396,
          updatedAtUtc: updatedAtUtc,
          deletedAtUtc: deletedAtUtc,
        );

    test('survives a round trip through the local database map', () {
      final episode = buildEpisode(updatedAtUtc: 909, deletedAtUtc: 1001);

      final restored = RecentEpisode.fromMapObject(episode.toMap());

      expect(restored.id, 62085);
      expect(restored.seriesId, 1396);
      expect(restored.episodeNum, 1);
      expect(restored.seasonNum, 1);
      expect(restored.backdropPath, '/still.jpg');
      expect(restored.updatedAtUtc, 909);
      expect(restored.deletedAtUtc, 1001);
      expect(restored.isDeleted, isTrue);
    });

    test('survives a round trip through the backend payload', () {
      final episode = buildEpisode(updatedAtUtc: 909);

      final restored = RecentEpisode.fromLaravelMap(episode.toLaravelMap());

      expect(restored.id, 62085);
      expect(restored.seriesName, 'Breaking Bad');
      expect(restored.episodeName, 'Pilot');
      expect(restored.elapsed, 900);
      expect(restored.remaining, 1200);
      expect(restored.dateTime, '2026-09-05 12:00:00.000');
      expect(restored.updatedAtUtc, 909);
      expect(restored.deletedAtUtc, isNull);
    });
  });
}
