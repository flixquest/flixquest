import '../controllers/bookmark_database_controller.dart';
import '../controllers/recently_watched_database_controller.dart';
import '../controllers/wellness_database_controller.dart';

class LocalAccountData {
  static Future<void> delete(String owner) async {
    final movies = MovieDatabaseController();
    final tv = TVDatabaseController();
    for (final movie in await movies.getMovieList()) {
      if (movie.id != null) await movies.deleteMovie(movie.id!);
    }
    for (final show in await tv.getTVList()) {
      if (show.id != null) await tv.deleteTV(show.id!);
    }
    await RecentlyWatchedMoviesController().clear();
    await RecentlyWatchedEpisodeController().clear();
    await WellnessDatabaseController.instance.permanentlyDeleteOwner(owner);
  }
}
