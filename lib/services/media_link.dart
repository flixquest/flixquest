/// Every address on TMDB, IMDb or FlixQuest's own flix.quest that this app has a screen for.
///
/// The two sites name the same things differently. A TMDB address says both what kind of record it
/// is and which one, so the app can go straight to the screen for it. An IMDb address only ever
/// carries an id — nothing about `tt0959621` says whether it is a film, a series or one episode of
/// one — so those are kept as the id they are and translated by TMDB before anything is opened.
///
/// Reading both here, into one set of destinations, is what lets the rest of the app treat a shared
/// IMDb page and a pasted TMDB page as the same request. It is also what stops a link from being
/// answered with less than it asked for: an address that names a season opens that season, and one
/// that names an episode opens that episode, rather than both landing on the series.
///
/// flix.quest is this app's own short form of a TMDB address: `/m/550` is a film, and `/t/1396`,
/// `/t/1396.4` and `/t/1396.4.13` are a series, one of its seasons and one of its episodes, and
/// `/l/51` is a live TV channel. Being our domain, it is the one Android verifies, so these open the
/// app straight from a tap.
class MediaLink {
  const MediaLink._();

  /// Registrable domains this reads, matched after any `www.`, `m.` or `api.` in front is dropped.
  static const String _tmdb = 'themoviedb.org';
  static const String _imdb = 'imdb.com';
  static const String _flixquest = 'flix.quest';

  /// A whole URL sitting in shared text, which is how another app hands one over.
  static final RegExp _schemed = RegExp(r'https?://\S+', caseSensitive: false);

  /// The same link with the scheme left off, as it appears in text people typed themselves.
  static final RegExp _bare = RegExp(
    r'\b(?:[\w-]+\.)*(?:imdb\.com|themoviedb\.org|flix\.quest)/\S*',
    caseSensitive: false,
  );

  static final RegExp _imdbTitleId = RegExp(r'^tt\d+$');
  static final RegExp _imdbNameId = RegExp(r'^nm\d+$');
  static final RegExp _leadingDigits = RegExp(r'^\d+');

  /// A flix.quest film is its id alone. A series is its id with, optionally, a season and then an
  /// episode after it, joined by dots.
  static final RegExp _flixquestMovie = RegExp(r'^\d+$');
  static final RegExp _flixquestSeries =
      RegExp(r'^(\d+)(?:\.(\d+)(?:\.(\d+))?)?$');

  /// A live channel is the live TV provider's own id for it, which is not a TMDB number.
  static final RegExp _flixquestChannel = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  /// Shareable addresses for catalog titles and episodes on FlixQuest's verified domain.
  static Uri movieUrl(int movieId) => Uri.https(_flixquest, '/m/$movieId');

  static Uri tvUrl(int seriesId) => Uri.https(_flixquest, '/t/$seriesId');

  static Uri episodeUrl(int seriesId, int seasonNumber, int episodeNumber) =>
      Uri.https(
        _flixquest,
        '/t/$seriesId.$seasonNumber.$episodeNumber',
      );

  /// A shareable address for a DLHD channel. Returns null for ids that our link parser cannot open.
  static Uri? liveChannelUrl(String channelId) =>
      _flixquestChannel.hasMatch(channelId)
          ? Uri.https(_flixquest, '/l/$channelId')
          : null;

  /// Reads whatever link [value] carries.
  ///
  /// [value] is either a link on its own or the text an app shares alongside one — the IMDb app
  /// sends the title and year in front of its URL — so every URL in it is tried in turn and the
  /// first one belonging to a site this understands wins. Returns null for anything else, which is
  /// the caller's cue to say so rather than to open something arbitrary.
  static MediaLinkTarget? parse(String value) {
    for (final uri in _urls(value)) {
      final host = _registrableDomain(uri);
      final target = switch (host) {
        _tmdb => _tmdbTarget(uri),
        _imdb => _imdbTarget(uri),
        _flixquest => _flixquestTarget(uri),
        _ => null,
      };
      if (target != null) return target;
    }
    return null;
  }

  static Iterable<Uri> _urls(String value) {
    final text = value.trim();
    if (text.isEmpty) return const <Uri>[];
    final found = <Uri>[];
    for (final pattern in <RegExp>[_schemed, _bare]) {
      for (final match in pattern.allMatches(text)) {
        final uri = _toUri(match.group(0)!);
        if (uri != null) {
          found.add(uri);
        }
      }
    }
    return found;
  }

  /// Text around a link comes with the punctuation of the sentence it sat in, and `\S+` swallows it.
  static Uri? _toUri(String match) {
    var text = match;
    while (
        text.isNotEmpty && '.,;:!?)]}\'"<>»'.contains(text[text.length - 1])) {
      text = text.substring(0, text.length - 1);
    }
    if (text.isEmpty) return null;
    final absolute =
        text.toLowerCase().startsWith('http') ? text : 'https://$text';
    final uri = Uri.tryParse(absolute);
    return uri == null || uri.host.isEmpty ? null : uri;
  }

  /// `m.imdb.com` and `www.imdb.com` are the same site, and so is the host an API URL was written
  /// against, so only the last two labels are compared.
  static String _registrableDomain(Uri uri) {
    final labels = uri.host.toLowerCase().split('.');
    return labels.length < 2
        ? labels.join('.')
        : labels.sublist(labels.length - 2).join('.');
  }

  /// TMDB puts the kind of record in the path, followed by the id and a slug of the title.
  ///
  /// The kind is searched for rather than read off the front, because it is not always there: an API
  /// URL has a version in front of it. Everything after the address itself — `/cast`, `/images`,
  /// `/watch` — describes a tab of the same page and is ignored.
  static MediaLinkTarget? _tmdbTarget(Uri uri) {
    final segments =
        uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    for (var index = 0; index + 1 < segments.length; index++) {
      final id = _id(segments[index + 1]);
      if (id == null) continue;
      final name = _slugName(segments[index + 1]);
      switch (segments[index].toLowerCase()) {
        case 'movie':
          return TmdbMovieLink(id: id, title: name);
        case 'collection':
          return TmdbCollectionLink(id: id, name: name);
        case 'person':
          return TmdbPersonLink(id: id, name: name);
        case 'tv':
          return _tmdbSeriesTarget(id, name, segments.sublist(index + 2));
      }
    }
    return null;
  }

  /// Which part of a series a `/tv/…` address names: the series, one of its seasons, or one episode.
  static MediaLinkTarget _tmdbSeriesTarget(
      int id, String? name, List<String> rest) {
    final season = _number(rest, 'season');
    if (season == null) return TmdbTvLink(id: id, name: name);
    final episode = _number(
        rest.length > 2 ? rest.sublist(2) : const <String>[], 'episode');
    return episode == null
        ? TmdbSeasonLink(seriesId: id, seasonNumber: season, seriesName: name)
        : TmdbEpisodeLink(
            seriesId: id,
            seasonNumber: season,
            episodeNumber: episode,
            seriesName: name,
          );
  }

  /// The number [label] introduces, when that is what the next two segments say. Specials are season
  /// zero, so a number is only rejected for being negative.
  static int? _number(List<String> segments, String label) {
    if (segments.length < 2 || segments[0].toLowerCase() != label) return null;
    final number = int.tryParse(segments[1]);
    return number == null || number < 0 ? null : number;
  }

  /// flix.quest puts the kind first, as a single letter, and everything else in the one segment after
  /// it. Anything that does not fit that exactly is not read at all, since these addresses are ours
  /// and a malformed one is a broken link rather than a layout to guess at.
  static MediaLinkTarget? _flixquestTarget(Uri uri) {
    final segments =
        uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    if (segments.length != 2) return null;
    final value = segments[1];
    switch (segments[0].toLowerCase()) {
      case 'm':
        return _flixquestMovie.hasMatch(value)
            ? TmdbMovieLink(id: int.parse(value))
            : null;
      case 't':
        final match = _flixquestSeries.firstMatch(value);
        if (match == null) return null;
        final id = int.parse(match.group(1)!);
        final season = match.group(2);
        final episode = match.group(3);
        if (season == null) return TmdbTvLink(id: id);
        if (episode == null) {
          return TmdbSeasonLink(seriesId: id, seasonNumber: int.parse(season));
        }
        return TmdbEpisodeLink(
          seriesId: id,
          seasonNumber: int.parse(season),
          episodeNumber: int.parse(episode),
        );
      case 'l':
        return _flixquestChannel.hasMatch(value)
            ? LiveChannelLink(channelId: value)
            : null;
    }
    return null;
  }

  /// IMDb addresses a title under `/title/tt…` and a person under `/name/nm…`, and says nothing more
  /// about either. The one exception is its season view, which puts the season in the query.
  static MediaLinkTarget? _imdbTarget(Uri uri) {
    final segments =
        uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    for (var index = 0; index + 1 < segments.length; index++) {
      final kind = segments[index].toLowerCase();
      final id = segments[index + 1].toLowerCase();
      if (kind == 'title' && _imdbTitleId.hasMatch(id)) {
        return ImdbTitleLink(
          imdbId: id,
          seasonNumber: _imdbSeason(uri, segments.sublist(index + 2)),
        );
      }
      if (kind == 'name' && _imdbNameId.hasMatch(id)) {
        return ImdbNameLink(imdbId: id);
      }
    }
    return null;
  }

  static int? _imdbSeason(Uri uri, List<String> rest) {
    if (!rest.any((segment) => segment.toLowerCase() == 'episodes')) {
      return null;
    }
    final season = int.tryParse(uri.queryParameters['season'] ?? '');
    return season == null || season < 0 ? null : season;
  }

  /// The id at the front of a `550-fight-club` segment.
  static int? _id(String segment) {
    final digits = _leadingDigits.stringMatch(segment);
    return digits == null ? null : int.tryParse(digits);
  }

  /// The title spelled out in the rest of that segment.
  ///
  /// It is the only thing a link says that a person would recognise, so it is worth keeping: it
  /// gives the wait for the record a name to show instead of a bare spinner. It is a display hint
  /// and nothing more — the record that arrives is what the screen is actually built from.
  static String? _slugName(String segment) {
    final dash = segment.indexOf('-');
    if (dash < 0) return null;
    final words = segment
        .substring(dash + 1)
        .split('-')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1));
    return words.isEmpty ? null : words.join(' ');
  }
}

/// What a link points at.
///
/// A TMDB link resolves to a destination the app can open on its own. An IMDb link resolves to an id
/// TMDB has to place first, which is why the two are different kinds of thing rather than one with a
/// missing field.
sealed class MediaLinkTarget {
  const MediaLinkTarget();
}

class TmdbMovieLink extends MediaLinkTarget {
  const TmdbMovieLink({required this.id, this.title});

  final int id;

  /// The title as the link spelled it, for the wait before the record arrives.
  final String? title;
}

class TmdbTvLink extends MediaLinkTarget {
  const TmdbTvLink({required this.id, this.name});

  final int id;
  final String? name;
}

class TmdbSeasonLink extends MediaLinkTarget {
  const TmdbSeasonLink({
    required this.seriesId,
    required this.seasonNumber,
    this.seriesName,
  });

  final int seriesId;
  final int seasonNumber;
  final String? seriesName;
}

class TmdbEpisodeLink extends MediaLinkTarget {
  const TmdbEpisodeLink({
    required this.seriesId,
    required this.seasonNumber,
    required this.episodeNumber,
    this.seriesName,
  });

  final int seriesId;
  final int seasonNumber;
  final int episodeNumber;
  final String? seriesName;
}

class TmdbPersonLink extends MediaLinkTarget {
  const TmdbPersonLink({required this.id, this.name});

  final int id;
  final String? name;
}

class TmdbCollectionLink extends MediaLinkTarget {
  const TmdbCollectionLink({required this.id, this.name});

  final int id;
  final String? name;
}

/// An IMDb title id, which stands for a film, a series or a single episode without saying which.
class ImdbTitleLink extends MediaLinkTarget {
  const ImdbTitleLink({required this.imdbId, this.seasonNumber});

  final String imdbId;

  /// Set when the link was IMDb's season view, so a series resolved from it can open on that season.
  final int? seasonNumber;
}

/// A live TV channel, by the id the live TV provider gives it.
class LiveChannelLink extends MediaLinkTarget {
  const LiveChannelLink({required this.channelId});

  final String channelId;
}

class ImdbNameLink extends MediaLinkTarget {
  const ImdbNameLink({required this.imdbId});

  final String imdbId;
}
