import '../data/sync/library_scope.dart';
import 'package:flutter/material.dart';

import '../controllers/bookmark_database_controller.dart';
import '../models/movie.dart';
import '../models/tv.dart';

class BookmarkProvider extends ChangeNotifier {
  BookmarkProvider();

  final MovieDatabaseController _movieDb = MovieDatabaseController();
  final TVDatabaseController _tvDb = TVDatabaseController();

  List<Movie> _movies = [];
  List<Movie> get movies => _movies;

  List<TV> _tvShows = [];
  List<TV> get tvShows => _tvShows;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void resetForOwner() {
    _movies = [];
    _tvShows = [];
    notifyListeners();
  }

  Future<void> fetchBookmarks() async {
    final owner = LibraryScope.owner;
    final generation = LibraryScope.generation;
    _isLoading = true;
    notifyListeners();

    try {
      final moviesDb = await _movieDb.databaseForOwner(owner);
      final tvDb = await _tvDb.databaseForOwner(owner);
      final movies = (await moviesDb.query(_movieDb.tableName,
              orderBy: '${_movieDb.colDateAdded} DESC'))
          .map(Movie.fromMapObject)
          .toList();
      final shows = (await tvDb.query(_tvDb.tableName,
              orderBy: '${_tvDb.colDateAdded} DESC'))
          .map(TV.fromMapObject)
          .toList();
      if (generation != LibraryScope.generation) return;
      _movies = movies;
      _tvShows = shows;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addMovie(Movie movie) async {
    await _movieDb.insertMovie(movie);
    await fetchBookmarks();
  }

  Future<void> removeMovie(int id) async {
    final generation = LibraryScope.generation;
    await _movieDb.deleteMovie(id);
    await fetchBookmarks();
    if (LibraryScope.enabled && generation != LibraryScope.generation) return;
  }

  Future<void> addTV(TV tv) async {
    await _tvDb.insertTV(tv);
    await fetchBookmarks();
  }

  Future<void> removeTV(int id) async {
    final generation = LibraryScope.generation;
    await _tvDb.deleteTV(id);
    await fetchBookmarks();
    if (LibraryScope.enabled && generation != LibraryScope.generation) return;
  }

  bool isMovieBookmarked(int id) {
    return _movies.any((m) => m.id == id);
  }

  bool isTVBookmarked(int id) {
    return _tvShows.any((t) => t.id == id);
  }
}
