import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/movie.dart';
import '../models/tv.dart';

class MovieDatabaseController {
  static MovieDatabaseController? _movieDatabaseController;
  static Database? _database;
  String tableName = 'movie_bookmark_table';
  String colId = 'id';
  String colAdult = 'adult';
  String colBackdropPath = 'backdrop_path';
  String colTitle = 'title';
  String colOriginalLanguage = 'original_language';
  String colOriginalTitle = 'original_title';
  String colOverview = 'overview';
  String colPopularity = 'popularity';
  String colReleaseDate = 'release_date';
  String colVideo = 'video';
  String colVoteAverage = 'vote_average';
  String colVoteCount = 'vote_count';
  // String colGenre = 'genre';
  String colPosterPath = 'poster_path';
  String colDateAdded = 'date_added';
  MovieDatabaseController._createInstance();

  factory MovieDatabaseController() {
    _movieDatabaseController ??= MovieDatabaseController._createInstance();
    return _movieDatabaseController!;
  }
  Future<Database> initializeDatabase() async {
    Directory directory = await getApplicationDocumentsDirectory();
    String path = '${directory.path}movies.db';
    var bookmarkDatabase =
        await openDatabase(path, version: 1, onCreate: _createDb);
    return bookmarkDatabase;
  }

  Future<Database> get database async {
    _database ??= await initializeDatabase();
    return _database!;
  }

  void _createDb(Database db, int newVersion) async {
    await db.execute(
        'CREATE TABLE $tableName($colId INTEGER PRIMARY KEY, $colTitle TEXT, $colOriginalTitle TEXT, $colOriginalLanguage TEXT, $colOverview TEXT, $colReleaseDate TEXT, $colPopularity NUMERIC, $colBackdropPath TEXT, $colVoteAverage REAL, $colVoteCount INTEGER, $colPosterPath TEXT, $colDateAdded TEXT)');
  }

  //this function will return all the movies in the database.
  Future<List<Map<String, dynamic>>> getMovieMapList() async {
    Database db = await database;
    var result = await db.query(tableName, orderBy: '$colDateAdded DESC');
    return result;
  }

  // this method will be used to insert movies in the database.
  Future<int> insertMovie(Movie movie) async {
    Database db = await database;
    // A bookmark may already have been saved by another screen or cloud sync.
    // Keep its original date_added when the same movie is saved again.
    var result = await db.insert(
      tableName,
      movie.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return result;
  }

  // this method will update a movie
  //
  // The stored row is refreshed from whatever the app is showing, but never restamped: date_added is
  // what orders this list, and opening a bookmarked title is not saving it again.
  Future<int> updateMovie(Movie movie, int id) async {
    var db = await database;
    var result = await db.update(tableName, movie.toMap()..remove(colDateAdded),
        where: '$colId = $id');
    return result;
  }

  // this method will delete a movie
  Future<int> deleteMovie(int id) async {
    var db = await database;
    int result =
        await db.rawDelete('DELETE FROM $tableName WHERE $colId = $id');
    return result;
  }

  // Get number of Movie objects in database
  Future<int> getCount() async {
    Database db = await database;
    List<Map<String, dynamic>> x =
        await db.rawQuery('SELECT COUNT (*) from $tableName');
    int result = Sqflite.firstIntValue(x)!;
    return result;
  }

  // Get the 'Map List' [ List<Map> ] and convert it to 'Movie List' [ List<Movie> ]
  Future<List<Movie>> getMovieList() async {
    var movieMapList = await getMovieMapList(); // Get 'Map List' from database
    int count =
        movieMapList.length; // Count the number of map entries in db table
    List<Movie> movieList = <Movie>[];
    // For loop to create a 'Movie List' from a 'Map List'
    for (int i = 0; i < count; i++) {
      movieList.add(Movie.fromMapObject(movieMapList[i]));
    }
    return movieList;
  }

  // this function will check if a movies exists in the database.
  Future<bool> contain(int id) async {
    Database db = await database;
    List<Map<String, dynamic>> x = await db
        .rawQuery('SELECT COUNT (*) from $tableName WHERE $colId = $id');
    int result = Sqflite.firstIntValue(x)!;
    if (result == 0) return false;
    return true;
  }
}

class TVDatabaseController {
  static TVDatabaseController? _tvDatabaseController;
  static Database? _database;
  String tableName = 'tv_bookmark_table';
  String colId = 'id';
  String colBackdropPath = 'backdrop_path';
  String colTitle = 'name';
  String colOriginalLanguage = 'original_language';
  String colOriginalTitle = 'original_title';
  String colOverview = 'overview';
  String colPopularity = 'popularity';
  String colFirstAirDate = 'first_air_date';
  String colVoteAverage = 'vote_average';
  String colVoteCount = 'vote_count';
  // String colGenre = 'genre';
  String colPosterPath = 'poster_path';
  String colDateAdded = 'date_added';
  TVDatabaseController._createInstance();

  factory TVDatabaseController() {
    _tvDatabaseController ??= TVDatabaseController._createInstance();
    return _tvDatabaseController!;
  }
  Future<Database> initializeDatabase() async {
    Directory directory = await getApplicationDocumentsDirectory();
    String path = '${directory.path}tv.db';
    var notesDatabase =
        await openDatabase(path, version: 1, onCreate: _createDb);
    return notesDatabase;
  }

  Future<Database> get database async {
    _database ??= await initializeDatabase();
    return _database!;
  }

  void _createDb(Database db, int newVersion) async {
    await db.execute(
        'CREATE TABLE $tableName($colId INTEGER PRIMARY KEY, $colTitle TEXT, $colOriginalTitle TEXT, $colOriginalLanguage TEXT, $colOverview TEXT, $colFirstAirDate TEXT, $colPopularity NUMERIC, $colBackdropPath TEXT, $colVoteAverage REAL, $colVoteCount INTEGER, $colPosterPath TEXT, $colDateAdded TEXT)');
  }

  //this function will return all the tv in the database.
  Future<List<Map<String, dynamic>>> getTVMapList() async {
    Database db = await database;
    var result = await db.query(tableName, orderBy: '$colDateAdded DESC');
    return result;
  }

  // this method will be used to insert tv in the database.
  Future<int> insertTV(TV tv) async {
    Database db = await database;
    // A bookmark may already have been saved by another screen or cloud sync.
    // Keep its original date_added when the same show is saved again.
    var result = await db.insert(
      tableName,
      tv.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return result;
  }

  // this method will update a tv
  //
  // As with movies, refreshing a saved show's facts must not move it to the top of the list.
  Future<int> updateTV(TV tv, int id) async {
    var db = await database;
    var result = await db.update(tableName, tv.toMap()..remove(colDateAdded),
        where: '$colId = $id');
    return result;
  }

  // this method will delete a tv
  Future<int> deleteTV(int id) async {
    var db = await database;
    int result =
        await db.rawDelete('DELETE FROM $tableName WHERE $colId = $id');
    return result;
  }

  // Get number of TV objects in database
  Future<int> getCount() async {
    Database db = await database;
    List<Map<String, dynamic>> x =
        await db.rawQuery('SELECT COUNT (*) from $tableName');
    int result = Sqflite.firstIntValue(x)!;
    return result;
  }

  // Get the 'Map List' [ List<Map> ] and convert it to 'TV List' [ List<Movie> ]
  Future<List<TV>> getTVList() async {
    var movieMapList = await getTVMapList(); // Get 'Map List' from database
    int count =
        movieMapList.length; // Count the number of map entries in db table
    List<TV> tvList = <TV>[];
    // For loop to create a 'TV List' from a 'Map List'
    for (int i = 0; i < count; i++) {
      tvList.add(TV.fromMapObject(movieMapList[i]));
    }
    return tvList;
  }

  // this function will check if a movies exists in the database.
  Future<bool> contain(int id) async {
    Database db = await database;
    List<Map<String, dynamic>> x = await db
        .rawQuery('SELECT COUNT (*) from $tableName WHERE $colId = $id');
    int result = Sqflite.firstIntValue(x)!;
    if (result == 0) return false;
    return true;
  }
}
