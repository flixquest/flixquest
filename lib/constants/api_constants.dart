// ignore_for_file: non_constant_identifier_names, constant_identifier_names

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Base URL for TMDB API requests.
///
/// On networks where api.themoviedb.org is unreachable (e.g. Jio in India),
/// point it at a proxy at build time:
/// `--dart-define=TMDB_API_BASE_URL=https://your-proxy/ab/3`
const String TMDB_API_BASE_URL = String.fromEnvironment(
  'TMDB_API_BASE_URL',
  defaultValue: 'https://api.themoviedb.org/3',
);
String? _remoteTmdbApiKey;

/// The TMDB API key used across all metadata and search endpoints.
///
/// Initially falls back to `dotenv.env['TMDB_API_KEY']` (from the local `.env`).
/// If a non-empty key is fetched from Firebase Remote Config (`tmdb_api_key`),
/// it overrides this value at runtime.
String get TMDB_API_KEY =>
    _remoteTmdbApiKey ?? dotenv.env['TMDB_API_KEY'] ?? '';

set TMDB_API_KEY(String value) {
  final trimmed = value.trim();
  _remoteTmdbApiKey = trimmed.isNotEmpty ? trimmed : null;
}
String mixpanelKey = dotenv.env['MIXPANEL_API_KEY']!;
/// Base URL for TMDB poster/backdrop images. Override at build time:
/// `--dart-define=TMDB_BASE_IMAGE_URL=https://your-proxy/im/`
const TMDB_BASE_IMAGE_URL = String.fromEnvironment(
  'TMDB_BASE_IMAGE_URL',
  defaultValue: 'https://image.tmdb.org/t/p/',
);
const String EMBED_BASE_MOVIE_URL =
    'https://www.2embed.to/embed/tmdb/movie?id=';
const String EMBED_BASE_TV_URL = 'https://www.2embed.to/embed/tmdb/tv?id=';
const String YOUTUBE_THUMBNAIL_URL = 'https://i3.ytimg.com/vi/';
const String YOUTUBE_BASE_URL = 'https://youtube.com/watch?v=';
const String FACEBOOK_BASE_URL = 'https://facebook.com/';
const String INSTAGRAM_BASE_URL = 'https://instagram.com/';
const String TWITTER_BASE_URL = 'https://twitter.com/';
const String IMDB_BASE_URL = 'https://imdb.com/title/';
const String TWOEMBED_BASE_URL = 'https://2embed.biz';
String flixquestApiUrl = dotenv.env['FLIXQUEST_API_URL']!;
