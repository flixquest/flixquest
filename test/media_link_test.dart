import 'package:flixquest/services/media_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TMDB addresses', () {
    test('a film opens as that film, and the slug names it', () {
      final target =
          MediaLink.parse('https://www.themoviedb.org/movie/550-fight-club');
      expect(target, isA<TmdbMovieLink>());
      final movie = target as TmdbMovieLink;
      expect(movie.id, 550);
      expect(movie.title, 'Fight Club');
    });

    test('an id with no slug behind it still opens', () {
      final target = MediaLink.parse('https://themoviedb.org/movie/550');
      expect((target as TmdbMovieLink).id, 550);
      expect(target.title, isNull);
    });

    test('a series without a season opens as the series', () {
      final target =
          MediaLink.parse('https://www.themoviedb.org/tv/1396-breaking-bad');
      expect(target, isA<TmdbTvLink>());
      final show = target as TmdbTvLink;
      expect(show.id, 1396);
      expect(show.name, 'Breaking Bad');
    });

    test('a season address opens that season, not the series', () {
      final target = MediaLink.parse(
          'https://www.themoviedb.org/tv/1396-breaking-bad/season/4');
      expect(target, isA<TmdbSeasonLink>());
      final season = target as TmdbSeasonLink;
      expect(season.seriesId, 1396);
      expect(season.seasonNumber, 4);
      expect(season.seriesName, 'Breaking Bad');
    });

    test('specials are season zero, not a missing season', () {
      final target =
          MediaLink.parse('https://www.themoviedb.org/tv/1396/season/0');
      expect((target as TmdbSeasonLink).seasonNumber, 0);
    });

    test('an episode address keeps both of its numbers', () {
      final target = MediaLink.parse(
          'https://www.themoviedb.org/tv/1396-breaking-bad/season/4/episode/13');
      expect(target, isA<TmdbEpisodeLink>());
      final episode = target as TmdbEpisodeLink;
      expect(episode.seriesId, 1396);
      expect(episode.seasonNumber, 4);
      expect(episode.episodeNumber, 13);
      expect(episode.seriesName, 'Breaking Bad');
    });

    test('a season that is not a number falls back to the series', () {
      final target =
          MediaLink.parse('https://www.themoviedb.org/tv/1396/season/latest');
      expect(target, isA<TmdbTvLink>());
      expect((target as TmdbTvLink).id, 1396);
    });

    test('a person opens as that person', () {
      final target = MediaLink.parse(
          'https://www.themoviedb.org/person/1245-scarlett-johansson');
      expect(target, isA<TmdbPersonLink>());
      final person = target as TmdbPersonLink;
      expect(person.id, 1245);
      expect(person.name, 'Scarlett Johansson');
    });

    test('a collection opens as that collection', () {
      final target = MediaLink.parse(
          'https://www.themoviedb.org/collection/86311-the-avengers-collection');
      expect(target, isA<TmdbCollectionLink>());
      final collection = target as TmdbCollectionLink;
      expect(collection.id, 86311);
      expect(collection.name, 'The Avengers Collection');
    });

    test('a tab of a page is still that page', () {
      final cast = MediaLink.parse('https://www.themoviedb.org/movie/550/cast');
      expect((cast as TmdbMovieLink).id, 550);

      final images =
          MediaLink.parse('https://www.themoviedb.org/person/1245/images');
      expect((images as TmdbPersonLink).id, 1245);

      final stills = MediaLink.parse(
          'https://www.themoviedb.org/tv/1396/season/4/episode/13/images');
      expect((stills as TmdbEpisodeLink).episodeNumber, 13);
    });

    test('a query on the end changes nothing', () {
      final target = MediaLink.parse(
          'https://www.themoviedb.org/movie/550-fight-club?language=en-US');
      expect((target as TmdbMovieLink).id, 550);
      expect(target.title, 'Fight Club');
    });

    test('the kind is found even behind an API version', () {
      final target = MediaLink.parse(
          'https://api.themoviedb.org/3/movie/550?api_key=secret');
      expect((target as TmdbMovieLink).id, 550);
    });
  });

  group('IMDb addresses', () {
    test('a title is kept as the id it is, for TMDB to place', () {
      final target = MediaLink.parse('https://www.imdb.com/title/tt0111161/');
      expect(target, isA<ImdbTitleLink>());
      final title = target as ImdbTitleLink;
      expect(title.imdbId, 'tt0111161');
      expect(title.seasonNumber, isNull);
    });

    test('the season view carries its season across', () {
      final target = MediaLink.parse(
          'https://www.imdb.com/title/tt0903747/episodes/?season=4');
      expect((target as ImdbTitleLink).seasonNumber, 4);
    });

    test('the episodes view with no season named asks for none', () {
      final target =
          MediaLink.parse('https://www.imdb.com/title/tt0903747/episodes/');
      expect((target as ImdbTitleLink).seasonNumber, isNull);
    });

    test('a season in the query of a plain title page is not a season link',
        () {
      final target =
          MediaLink.parse('https://www.imdb.com/title/tt0903747/?season=4');
      expect((target as ImdbTitleLink).seasonNumber, isNull);
    });

    test('a person is kept as a name id', () {
      final target = MediaLink.parse('https://www.imdb.com/name/nm0000138/');
      expect(target, isA<ImdbNameLink>());
      expect((target as ImdbNameLink).imdbId, 'nm0000138');
    });

    test('a localised path is the same address', () {
      final target =
          MediaLink.parse('https://www.imdb.com/es-es/title/tt0111161/');
      expect((target as ImdbTitleLink).imdbId, 'tt0111161');
    });

    test('an id in capitals is the same id', () {
      final target = MediaLink.parse('https://www.IMDb.com/title/TT0111161');
      expect((target as ImdbTitleLink).imdbId, 'tt0111161');
    });

    test('a tracking parameter is not part of the id', () {
      final target = MediaLink.parse(
          'https://m.imdb.com/title/tt0111161/?ref_=nv_sr_srsg_0');
      expect((target as ImdbTitleLink).imdbId, 'tt0111161');
    });
  });

  group('flix.quest addresses', () {
    test('a film is its id', () {
      final target = MediaLink.parse('https://flix.quest/m/123');
      expect(target, isA<TmdbMovieLink>());
      expect((target as TmdbMovieLink).id, 123);
      expect(target.title, isNull);
    });

    test('a series is its id alone', () {
      final target = MediaLink.parse('https://flix.quest/t/2316');
      expect(target, isA<TmdbTvLink>());
      expect((target as TmdbTvLink).id, 2316);
    });

    test('a season follows the id after a dot', () {
      final target = MediaLink.parse('https://flix.quest/t/2316.4');
      expect(target, isA<TmdbSeasonLink>());
      final season = target as TmdbSeasonLink;
      expect(season.seriesId, 2316);
      expect(season.seasonNumber, 4);
    });

    test('an episode keeps both of its numbers', () {
      final target = MediaLink.parse('https://flix.quest/t/2316.1.1');
      expect(target, isA<TmdbEpisodeLink>());
      final episode = target as TmdbEpisodeLink;
      expect(episode.seriesId, 2316);
      expect(episode.seasonNumber, 1);
      expect(episode.episodeNumber, 1);
    });

    test('specials are season zero', () {
      final target = MediaLink.parse('https://flix.quest/t/2316.0.3');
      expect((target as TmdbEpisodeLink).seasonNumber, 0);
    });

    test('a full stop after a shared episode is not part of it', () {
      final target =
          MediaLink.parse('Watch this: https://flix.quest/t/2316.1.1.');
      expect((target as TmdbEpisodeLink).episodeNumber, 1);
    });

    test('an address typed without a scheme still reads', () {
      final target = MediaLink.parse('flix.quest/m/550');
      expect((target as TmdbMovieLink).id, 550);
    });

    test('a query on the end changes nothing', () {
      final target =
          MediaLink.parse('https://flix.quest/m/550?utm_source=share');
      expect((target as TmdbMovieLink).id, 550);
    });

    test('a malformed address is not guessed at', () {
      expect(MediaLink.parse('https://flix.quest/'), isNull);
      expect(MediaLink.parse('https://flix.quest/m/'), isNull);
      expect(MediaLink.parse('https://flix.quest/m/abc'), isNull);
      expect(MediaLink.parse('https://flix.quest/m/550.1'), isNull);
      expect(MediaLink.parse('https://flix.quest/m/550/extra'), isNull);
      expect(MediaLink.parse('https://flix.quest/t/2316.1.1.1'), isNull);
      expect(MediaLink.parse('https://flix.quest/t/2316..1'), isNull);
      expect(MediaLink.parse('https://flix.quest/x/550'), isNull);
    });

    test('a live channel is the provider\'s id for it', () {
      final target = MediaLink.parse('https://flix.quest/l/51');
      expect(target, isA<LiveChannelLink>());
      expect((target as LiveChannelLink).channelId, '51');
    });

    test('a channel id need not be a number', () {
      final target = MediaLink.parse('https://flix.quest/l/sky-sports_1');
      expect((target as LiveChannelLink).channelId, 'sky-sports_1');
    });

    test('shared channel addresses open the same channel', () {
      final url = MediaLink.liveChannelUrl('sky-sports_1');
      expect(url.toString(), 'https://flix.quest/l/sky-sports_1');
      expect((MediaLink.parse(url.toString()) as LiveChannelLink).channelId,
          'sky-sports_1');
      expect(MediaLink.liveChannelUrl('bad/id'), isNull);
    });

    test('shareable catalog addresses use the verified app domain', () {
      expect(MediaLink.movieUrl(550).toString(), 'https://flix.quest/m/550');
      expect(MediaLink.tvUrl(1396).toString(), 'https://flix.quest/t/1396');
      expect(
        MediaLink.episodeUrl(1396, 4, 13).toString(),
        'https://flix.quest/t/1396.4.13',
      );

      expect(
          MediaLink.parse('${MediaLink.movieUrl(550)}'), isA<TmdbMovieLink>());
      expect(MediaLink.parse('${MediaLink.tvUrl(1396)}'), isA<TmdbTvLink>());
      expect(
        MediaLink.parse('${MediaLink.episodeUrl(1396, 4, 13)}'),
        isA<TmdbEpisodeLink>(),
      );
    });

    test('a channel id with anything else in it is not guessed at', () {
      expect(MediaLink.parse('https://flix.quest/l/'), isNull);
      expect(MediaLink.parse('https://flix.quest/l/51/extra'), isNull);
      expect(MediaLink.parse('https://flix.quest/l/51%20x'), isNull);
      expect(MediaLink.parse('https://flix.quest/l/${'a' * 65}'), isNull);
    });

    test('another site with the same paths is not ours', () {
      expect(MediaLink.parse('https://example.com/m/550'), isNull);
      expect(MediaLink.parse('https://flix.quest.evil.com/m/550'), isNull);
    });
  });

  group('links as they actually arrive', () {
    test('a subdomain in front of either site is still that site', () {
      expect(MediaLink.parse('https://m.themoviedb.org/movie/550'),
          isA<TmdbMovieLink>());
      expect(MediaLink.parse('https://imdb.com/title/tt0111161'),
          isA<ImdbTitleLink>());
    });

    test('an address typed without a scheme still reads', () {
      final target = MediaLink.parse('themoviedb.org/tv/1396/season/2');
      expect((target as TmdbSeasonLink).seasonNumber, 2);
    });

    test('the sentence a shared link sits in is not part of it', () {
      final target = MediaLink.parse(
          'Have a look at https://www.themoviedb.org/movie/550-fight-club.');
      expect((target as TmdbMovieLink).title, 'Fight Club');
    });

    test('brackets around a link are not part of it', () {
      final target =
          MediaLink.parse('Fight Club (https://themoviedb.org/movie/550)');
      expect((target as TmdbMovieLink).id, 550);
    });

    test('the IMDb app shares a title and a year in front of its link', () {
      final target = MediaLink.parse(
        'The Shawshank Redemption (1994)\nhttps://www.imdb.com/title/tt0111161/'
        '?ref_=share_ios',
      );
      expect((target as ImdbTitleLink).imdbId, 'tt0111161');
    });

    test('an address on another site does not hide the one we know', () {
      final target = MediaLink.parse(
        'https://example.com/redirect https://www.themoviedb.org/person/1245',
      );
      expect((target as TmdbPersonLink).id, 1245);
    });

    test('what this app shares, this app reads back', () {
      final movie = MediaLink.parse(
        'Checkout the movie Fight Club!\nIt is rated 8.4 out of 10\n'
        'https://themoviedb.org/movie/550',
      );
      expect((movie as TmdbMovieLink).id, 550);

      final show = MediaLink.parse(
        'Checkout the TV Show Breaking Bad!\nIt is rated 8.9 out of 10\n'
        'https://themoviedb.org/tv/1396',
      );
      expect((show as TmdbTvLink).id, 1396);

      final episode = MediaLink.parse(
        'Checkout the TV episode Ozymandias from Breaking Bad!\n'
        'It is rated 9.9 out of 10\n'
        'https://themoviedb.org/tv/1396/season/5/episode/14',
      );
      expect((episode as TmdbEpisodeLink).seasonNumber, 5);
      expect(episode.episodeNumber, 14);
    });
  });

  group('links this app has no screen for', () {
    test('text with no address in it', () {
      expect(MediaLink.parse('watch something good tonight'), isNull);
      expect(MediaLink.parse(''), isNull);
      expect(MediaLink.parse('   '), isNull);
    });

    test('another site laid out the same way', () {
      expect(
          MediaLink.parse('https://example.com/movie/550-fight-club'), isNull);
      expect(MediaLink.parse('https://notthemoviedb.org.evil.com/movie/550'),
          isNull);
    });

    test('a page on either site that is not a record', () {
      expect(MediaLink.parse('https://www.imdb.com/'), isNull);
      expect(MediaLink.parse('https://www.themoviedb.org/search?query=fight'),
          isNull);
      expect(MediaLink.parse('https://www.themoviedb.org/movie'), isNull);
      expect(MediaLink.parse('https://www.imdb.com/title/notanid'), isNull);
      expect(MediaLink.parse('https://www.imdb.com/chart/top/'), isNull);
    });
  });
}
