// ignore_for_file: non_constant_identifier_names

import '/constants/api_constants.dart';

class Endpoints {
  static String discoverMoviesUrl(int page, String l) {
    return '$TMDB_API_BASE_URL'
        '/discover/movie?api_key='
        '$TMDB_API_KEY'
        '&language=$l&sort_by=popularity'
        '.desc&include_video=false&page'
        '=$page';
  }

  static String randomDiscoverMoviesUrl(
    String l, {
    int? page,
    String? year,
    String? genreId,
  }) {
    final p = page ?? 1;
    var url = '$TMDB_API_BASE_URL/discover/movie?api_key=$TMDB_API_KEY'
        '&language=$l&sort_by=popularity.desc&include_video=false'
        '&page=$p&vote_count.gte=30';
    if (year != null && year.isNotEmpty) {
      url += '&primary_release_year=$year';
    }
    if (genreId != null && genreId.isNotEmpty) {
      url += '&with_genres=$genreId';
    }
    return url;
  }

  static String randomDiscoverTVUrl(
    String l, {
    int? page,
    String? year,
    String? genreId,
  }) {
    final p = page ?? 1;
    var url = '$TMDB_API_BASE_URL/discover/tv?api_key=$TMDB_API_KEY'
        '&language=$l&sort_by=popularity.desc'
        '&page=$p&vote_count.gte=30';
    if (year != null && year.isNotEmpty) {
      url += '&first_air_date_year=$year';
    }
    if (genreId != null && genreId.isNotEmpty) {
      url += '&with_genres=$genreId';
    }
    return url;
  }

  static String nowPlayingMoviesUrl(int page, String l) {
    return '$TMDB_API_BASE_URL'
        '/movie/now_playing?api_key='
        '$TMDB_API_KEY'
        '&page=$page&language=$l';
  }

  static String getCreditsUrl(int id, String l) {
    return '$TMDB_API_BASE_URL/movie/$id/credits?api_key=$TMDB_API_KEY&language=$l';
  }

  static String topRatedUrl(String l) {
    return '$TMDB_API_BASE_URL'
        '/movie/top_rated?api_key='
        '$TMDB_API_KEY'
        '&region=US&language=$l';
  }

  static String popularMoviesUrl(String l) {
    return '$TMDB_API_BASE_URL'
        '/movie/popular?api_key='
        '$TMDB_API_KEY'
        '&language=$l';
  }

  static String trendingMoviesUrl(String l) {
    return '$TMDB_API_BASE_URL'
        '/trending/movie/week?api_key='
        '$TMDB_API_KEY'
        '&language=$l';
  }

  static String trendingMoviesTodayUrl(String l) {
    return '$TMDB_API_BASE_URL'
        '/trending/movie/day?api_key='
        '$TMDB_API_KEY'
        '&language=$l';
  }

  static String trendingTVTodayUrl(String l) {
    return '$TMDB_API_BASE_URL'
        '/trending/tv/day?api_key='
        '$TMDB_API_KEY'
        '&language=$l';
  }

  static String upcomingMoviesUrl(String l) {
    return '$TMDB_API_BASE_URL'
        '/movie/upcoming?api_key='
        '$TMDB_API_KEY'
        '&language=$l';
  }

  static String upcomingSeriesPremieresUrl(
    String l,
    DateTime today, {
    bool includeAdult = false,
  }) {
    String date(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
    final start = DateTime.utc(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 60));
    return '$TMDB_API_BASE_URL/discover/tv?api_key=$TMDB_API_KEY'
        '&language=$l&sort_by=popularity.desc&include_adult=$includeAdult'
        '&first_air_date.gte=${date(start)}'
        '&first_air_date.lte=${date(end)}';
  }

  static String movieDetailsUrl(int movieId, String l) {
    return '$TMDB_API_BASE_URL/movie/$movieId?api_key=$TMDB_API_KEY&language=$l';
  }

  static String movieGenresUrl(String l) {
    return '$TMDB_API_BASE_URL/genre/movie/list?api_key=$TMDB_API_KEY&language=$l';
  }

  static String tvGenresUrl(String l) {
    return '$TMDB_API_BASE_URL/genre/tv/list?api_key=$TMDB_API_KEY&language=$l';
  }

  static String getMoviesForGenre(int genreId, int page, String l) {
    return '$TMDB_API_BASE_URL/discover/movie?api_key=$TMDB_API_KEY'
        '&sort_by=popularity.desc'
        '&include_video=false'
        '&page=$page'
        '&with_genres=$genreId&language=$l';
  }

  static String movieReviewsUrl(int movieId, int page, String l) {
    return '$TMDB_API_BASE_URL/movie/$movieId/reviews?api_key=$TMDB_API_KEY'
        '&language=$l&page=$page';
  }

  static String movieSearchUrl(String query, bool includeAdult, String l) {
    return '$TMDB_API_BASE_URL/search/movie?query=$query&include_adult=$includeAdult&language=$l&api_key=$TMDB_API_KEY';
  }

  static String personSearchUrl(String query, bool includeAdult, String l) {
    return '$TMDB_API_BASE_URL/search/person?query=$query&include_adult=$includeAdult&language=$l&api_key=$TMDB_API_KEY';
  }

  static String tvSearchUrl(String query, bool includeAdult, String l) {
    return '$TMDB_API_BASE_URL/search/tv?query=$query&include_adult=$includeAdult&language=$l&api_key=$TMDB_API_KEY';
  }

  static getPerson(int personId, String l) {
    return '$TMDB_API_BASE_URL/person/$personId?api_key=$TMDB_API_KEY&language=$l&append_to_response=movie_credits';
  }

  static watchProvidersMovies(int providerId, int page, String l) {
    return '$TMDB_API_BASE_URL'
        '/discover/movie?api_key='
        '$TMDB_API_KEY'
        '&language=$l&sort_by=popularity'
        '.desc&include_video=false&page=$page'
        '&with_watch_providers=$providerId'
        '&watch_region=US';
  }

  static watchProvidersTVShows(int providerId, int page, String l) {
    return '$TMDB_API_BASE_URL'
        '/discover/tv?api_key='
        '$TMDB_API_KEY'
        '&language=$l&sort_by=popularity'
        '.desc&include_adult=false&page=$page'
        '&with_watch_providers=$providerId'
        '&watch_region=US';
  }

  static String getImages(int id) {
    return '$TMDB_API_BASE_URL/movie/$id/images?api_key=$TMDB_API_KEY';
  }

  static String getVideos(int id) {
    return '$TMDB_API_BASE_URL/movie/$id/videos?api_key=$TMDB_API_KEY';
  }

  static String getMovieRecommendations(int id, int page, String l) {
    return '$TMDB_API_BASE_URL'
        '/movie/$id/recommendations?api_key=$TMDB_API_KEY&language=$l&page=$page';
  }

  static String getExternalLinksForMovie(int id, String l) {
    return '$TMDB_API_BASE_URL'
        '/movie/$id/external_ids?api_key=$TMDB_API_KEY&language=$l';
  }

  static String getSimilarMovies(int id, int page, String l) {
    return '$TMDB_API_BASE_URL'
        '/movie/$id/similar?api_key=$TMDB_API_KEY&language=$l&page=$page';
  }

  static String getMovieCreditsForPerson(int id, String l) {
    return '$TMDB_API_BASE_URL'
        '/person/$id/movie_credits?api_key=$TMDB_API_KEY&language=$l';
  }

  static getPersonDetails(int id, String l) {
    return '$TMDB_API_BASE_URL'
        '/person/$id?api_key=$TMDB_API_KEY&language=$l';
  }

  static getPersonImages(int id) {
    return '$TMDB_API_BASE_URL'
        '/person/$id/images?api_key=$TMDB_API_KEY';
  }

  static getMovieWatchProviders(int id, String l) {
    return '$TMDB_API_BASE_URL'
        '/movie/$id/watch/providers?api_key=$TMDB_API_KEY&language=$l';
  }

  static discoverTVUrl(int page, String l) {
    return '$TMDB_API_BASE_URL'
        '/discover/tv?api_key=$TMDB_API_KEY&language=$l&sort_by=popularity.desc&page=$page';
  }

  static popularTVUrl(String l) {
    return '$TMDB_API_BASE_URL'
        '/tv/popular?api_key=$TMDB_API_KEY&language=$l';
  }

  static trendingTVUrl(String l) {
    return '$TMDB_API_BASE_URL'
        '/trending/tv/week?api_key=$TMDB_API_KEY&language=$l';
  }

  static topRatedTVUrl(String l) {
    return '$TMDB_API_BASE_URL'
        '/tv/top_rated?api_key=$TMDB_API_KEY&language=$l';
  }

  static airingTodayUrl(String l) {
    return '$TMDB_API_BASE_URL'
        '/tv/airing_today?api_key=$TMDB_API_KEY&language=$l';
  }

  static onTheAirUrl(String l) {
    return '$TMDB_API_BASE_URL'
        '/tv/on_the_air?api_key=$TMDB_API_KEY&language=$l';
  }

  static getFullTVCreditsUrl(int id, String l) {
    return '$TMDB_API_BASE_URL'
        '/tv/$id/aggregate_credits?api_key=$TMDB_API_KEY&language=$l';
  }

  static getTVCreditsUrl(int id, String l) {
    return '$TMDB_API_BASE_URL'
        '/tv/$id/credits?api_key=$TMDB_API_KEY&language=$l';
  }

  static getTVSeasonCreditsUrl(int id, int seasonNumber, String l) {
    return '$TMDB_API_BASE_URL'
        '/tv/$id/season/$seasonNumber/credits?api_key=$TMDB_API_KEY&language=$l';
  }

  static getFullTVSeasonCreditsUrl(int id, int seasonNumber, String l) {
    return '$TMDB_API_BASE_URL'
        '/tv/$id/season/$seasonNumber/aggregate_credits?api_key=$TMDB_API_KEY&language=$l';
  }

  static getTVSeasonImagesUrl(int id, int seasonNumber) {
    return '$TMDB_API_BASE_URL'
        '/tv/$id/season/$seasonNumber/images?api_key=$TMDB_API_KEY';
  }

  static getTVEpisodeImagesUrl(int id, int seasonNumber, int episodeNumber) {
    return '$TMDB_API_BASE_URL'
        '/tv/$id/season/$seasonNumber/episode/$episodeNumber/images?api_key=$TMDB_API_KEY';
  }

  static getTVEpisodeVideosUrl(int id, int seasonNumber, int episodeNumber) {
    return '$TMDB_API_BASE_URL'
        '/tv/$id/season/$seasonNumber/episode/$episodeNumber/videos?api_key=$TMDB_API_KEY';
  }

  static getTVSeasonVideosUrl(int id, int seasonNumber) {
    return '$TMDB_API_BASE_URL'
        '/tv/$id/season/$seasonNumber/videos?api_key=$TMDB_API_KEY';
  }

  static String tvDetailsUrl(int id, String l) {
    return '$TMDB_API_BASE_URL/tv/$id?api_key=$TMDB_API_KEY&language=$l';
  }

  static String getTVImages(int id) {
    return '$TMDB_API_BASE_URL/tv/$id/images?api_key=$TMDB_API_KEY';
  }

  static String getTVVideos(int id) {
    return '$TMDB_API_BASE_URL/tv/$id/videos?api_key=$TMDB_API_KEY';
  }

  static String getTVRecommendations(int id, int page, String l) {
    return '$TMDB_API_BASE_URL'
        '/tv/$id/recommendations?api_key=$TMDB_API_KEY&language=$l&page=$page';
  }

  static String getSimilarTV(int id, int page, String l) {
    return '$TMDB_API_BASE_URL'
        '/tv/$id/similar?api_key=$TMDB_API_KEY&language=$l&page=$page';
  }

  static String getTVShowsForGenre(int genreId, int page, String l) {
    return '$TMDB_API_BASE_URL/discover/tv?api_key=$TMDB_API_KEY'
        '&language=$l'
        '&sort_by=popularity.desc'
        '&page=$page'
        '&with_genres=$genreId';
  }

  static String getTVCreditsForPerson(int id, String l) {
    return '$TMDB_API_BASE_URL'
        '/person/$id/tv_credits?api_key=$TMDB_API_KEY&language=$l';
  }

  static String getExternalLinksForPerson(int id, String l) {
    return '$TMDB_API_BASE_URL'
        '/person/$id/external_ids?api_key=$TMDB_API_KEY&language=$l';
  }

  static String getExternalLinksForTV(int id, String l) {
    return '$TMDB_API_BASE_URL'
        '/tv/$id/external_ids?api_key=$TMDB_API_KEY&language=$l';
  }

  static String getTVSeasons(int id, String l) {
    return '$TMDB_API_BASE_URL'
        '/tv/$id?api_key=$TMDB_API_KEY&language=$l';
  }

  static String getSeasonDetails(int id, int seasonNum, String l) {
    return '$TMDB_API_BASE_URL'
        '/tv/$id/season/$seasonNum?api_key=$TMDB_API_KEY&language=$l';
  }

  static String getCollectionDetails(int id, String l) {
    return '$TMDB_API_BASE_URL'
        '/collection/$id?api_key=$TMDB_API_KEY&language=$l';
  }

  static String getEpisodeDetails(
      int id, int seasonNumber, int episodeNumber, String l) {
    return '$TMDB_API_BASE_URL'
        '/tv/$id/season/$seasonNumber/episode/$episodeNumber?api_key=$TMDB_API_KEY&language=$l';
  }

  static String getEpisodeCredits(
      int id, int seasonNumber, int episodeNumber, String l) {
    return '$TMDB_API_BASE_URL'
        '/tv/$id/season/$seasonNumber/episode/$episodeNumber/credits?api_key=$TMDB_API_KEY&language=$l';
  }

  static String getTVWatchProviders(int id, String l) {
    return '$TMDB_API_BASE_URL'
        '/tv/$id/watch/providers?api_key=$TMDB_API_KEY&language=$l';
  }

  static String getMovieDetails(int id, String l) {
    return '$TMDB_API_BASE_URL' '/movie/$id?api_key=$TMDB_API_KEY&language=$l';
  }

  static String getTVDetails(int id, String l) {
    return '$TMDB_API_BASE_URL' '/tv/$id?api_key=$TMDB_API_KEY&language=$l';
  }

  static String getIPTVEndpoint(String baseUrl) {
    return '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/api/v2/dlhd/channels';
  }

  /// Asks TMDB what it holds under an id from another site, such as an IMDb `tt` or `nm` id.
  ///
  /// The reply is grouped by kind of record, because the id itself does not say which kind it is.
  static String findByExternalId(String externalId, String source, String l) {
    return '$TMDB_API_BASE_URL'
        '/find/${Uri.encodeComponent(externalId)}'
        '?api_key=$TMDB_API_KEY&external_source=$source&language=$l';
  }
}
