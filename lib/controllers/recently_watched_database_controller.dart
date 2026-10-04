import '../data/sync/library_scope.dart';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/recently_watched.dart';

/// Columns shared by both recently-watched tables to support cloud sync.
const String _updatedAtCol = 'updated_at_utc';
const String _deletedAtCol = 'deleted_at_utc';
const String _syncedCol = 'synced';

/// Adds the sync bookkeeping columns to a pre-sync table and seeds
/// [_updatedAtCol] from the row's existing local timestamp so a first merge has
/// a usable version stamp. Unparsable dates fall back to 0, which loses to any
/// later write from any device.
Future<void> _addSyncColumns(
  Database db, {
  required String table,
  required String dateColumn,
}) async {
  await db.execute('ALTER TABLE $table ADD COLUMN $_updatedAtCol INTEGER');
  await db.execute('ALTER TABLE $table ADD COLUMN $_deletedAtCol INTEGER');
  await db.execute(
    'ALTER TABLE $table ADD COLUMN $_syncedCol INTEGER NOT NULL DEFAULT 0',
  );
  await db.execute(
    'UPDATE $table SET $_updatedAtCol = COALESCE('
    "CAST(strftime('%s', substr($dateColumn, 1, 19)) AS INTEGER) * 1000, 0)",
  );
}

class RecentlyWatchedMoviesController {
  static RecentlyWatchedMoviesController? _recentlyWatchedMoviesController;
  final Map<String, Future<Database>> _databases = {};
  String tableName = 'recently_watched_movies_table';
  String colId = 'id';
  String colTitle = 'title';
  String colReleaseYear = 'release_year';
  String elapsedCol = 'elapsed';
  String remainingCol = 'remaining';
  String dateTimeCol = 'date_watched';
  String posterPathCol = 'poster_path';
  String backdropPathCol = 'backdrop_path';

  RecentlyWatchedMoviesController._createInstance();

  factory RecentlyWatchedMoviesController() {
    _recentlyWatchedMoviesController ??=
        RecentlyWatchedMoviesController._createInstance();
    return _recentlyWatchedMoviesController!;
  }

  Future<Database> initializeDatabase({String? owner, String? directoryPath}) async {
    final capturedOwner = owner ?? LibraryScope.owner;
    Directory directory = directoryPath == null
        ? await getApplicationDocumentsDirectory() : Directory(directoryPath);
    String path = LibraryScope.filename('${directory.path}recent_movies.db', capturedOwner);
    var recentMoviesDatabase = await openDatabase(
      path,
      version: 2,
      onCreate: _createDb,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _addSyncColumns(
            db,
            table: tableName,
            dateColumn: dateTimeCol,
          );
        }
      },
    );
    return recentMoviesDatabase;
  }

  Future<Database> get database async {
    return databaseForOwner(LibraryScope.owner);
  }

  Future<Database> databaseForOwner(String owner) {
    final key = LibraryScope.enabled ? owner : 'legacy';
    return _databases.putIfAbsent(key, () => initializeDatabase(owner: owner));
  }

  Future<void> _createDb(Database db, int newVersion) async {
    await db.execute(
        'CREATE TABLE $tableName($colId INTEGER PRIMARY KEY, $colTitle TEXT, $posterPathCol TEXT, $backdropPathCol TEXT, $colReleaseYear INTEGER, $elapsedCol NUMERIC, $remainingCol NUMERIC, $dateTimeCol TEXT, $_updatedAtCol INTEGER, $_deletedAtCol INTEGER, $_syncedCol INTEGER NOT NULL DEFAULT 0)');
  }

  Future<List<Map<String, dynamic>>> getMovieMapList() async {
    Database db = await database;
    var result = await db.query(tableName,
        where: '$_deletedAtCol IS NULL', orderBy: '$dateTimeCol DESC');
    return result;
  }

  Future<int> insertMovie(RecentMovie rMovie) async {
    Database db = await database;
    // Replace on conflict so re-watching a finished or dismissed title revives
    // the row (and clears its tombstone) instead of failing on the primary key.
    var result = await db.insert(tableName, rMovie.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return result;
  }

  Future<int> updateMovie(RecentMovie rMovie, int id) async {
    var db = await database;
    var result = await db.update(tableName, rMovie.toMap(),
        where: '$colId = ?', whereArgs: [id]);
    return result;
  }

  /// Marks a movie as removed and leaves the row behind so the removal reaches
  /// the other devices on the next sync.
  Future<int> tombstoneMovie(int id) async {
    var db = await database;
    final now = LibraryScope.nowUtcMs();
    return db.update(
      tableName,
      <String, dynamic>{
        _deletedAtCol: now,
        _updatedAtCol: now,
        _syncedCol: 0,
      },
      where: '$colId = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteMovie(int id) async {
    var db = await database;
    int result = await db
        .delete(tableName, where: '$colId = ?', whereArgs: [id]);
    return result;
  }

  Future<int> getCount() async {
    Database db = await database;
    List<Map<String, dynamic>> x = await db.rawQuery(
        'SELECT COUNT (*) from $tableName WHERE $_deletedAtCol IS NULL');
    int result = Sqflite.firstIntValue(x)!;
    return result;
  }

  Future<List<RecentMovie>> getRecentMovieList() async {
    var movieMapList = await getMovieMapList();
    int count = movieMapList.length;
    List<RecentMovie> movieList = [];

    for (int i = 0; i < count; i++) {
      movieList.add(RecentMovie.fromMapObject(movieMapList[i]));
    }
    return movieList;
  }

  Future<bool> contain(int id) async {
    Database db = await database;
    List<Map<String, dynamic>> x = await db.rawQuery(
        'SELECT COUNT (*) from $tableName WHERE $colId = ? AND $_deletedAtCol IS NULL',
        [id]);
    int result = Sqflite.firstIntValue(x)!;
    if (result == 0) return false;
    return true;
  }

  /// Every row, tombstones included, for two-way merges.
  Future<List<RecentMovie>> allMovies() async {
    Database db = await database;
    final rows = await db.query(tableName);
    return rows.map(RecentMovie.fromMapObject).toList();
  }

  /// Rows still waiting to be pushed to the cloud, tombstones included.
  Future<List<RecentMovie>> pendingMovies() async {
    Database db = await database;
    final rows = await db.query(tableName, where: '$_syncedCol = 0');
    return rows.map(RecentMovie.fromMapObject).toList();
  }

  /// Writes rows that won a merge against the local copy. They are already in
  /// the cloud, so they are stored as synced.
  Future<void> upsertFromCloud(Iterable<RecentMovie> movies) async {
    if (movies.isEmpty) return;
    Database db = await database;
    await db.transaction((txn) async {
      for (final movie in movies) {
        movie.synced = true;
        await txn.insert(tableName, movie.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> markSynced(Iterable<int> ids) async {
    final idList = ids.toList(growable: false);
    if (idList.isEmpty) return;
    Database db = await database;
    final placeholders = List.filled(idList.length, '?').join(', ');
    await db.update(
      tableName,
      <String, dynamic>{_syncedCol: 1},
      where: '$colId IN ($placeholders)',
      whereArgs: idList,
    );
  }

  /// Drops tombstones that every device has had ample time to observe.
  Future<List<int>> prunedTombstones(int olderThanUtcMillis) async {
    Database db = await database;
    final rows = await db.query(
      tableName,
      columns: [colId],
      where: '$_deletedAtCol IS NOT NULL AND $_deletedAtCol < ? AND $_syncedCol = 1',
      whereArgs: [olderThanUtcMillis],
    );
    final ids = rows.map((row) => row[colId] as int).toList(growable: false);
    if (ids.isEmpty) return ids;
    final placeholders = List.filled(ids.length, '?').join(', ');
    await db.delete(tableName,
        where: '$colId IN ($placeholders)', whereArgs: ids);
    return ids;
  }

  /// Wipes the table, used when the signed-in account is deleted.
  Future<void> clear() async {
    Database db = await database;
    await db.delete(tableName);
  }
}

class RecentlyWatchedEpisodeController {
  static RecentlyWatchedEpisodeController? _recentlyWatchedEpisodeController;
  static final Map<String, Future<Database>> _databases = {};
  String tableName = 'recently_watched_tv_shows_table';
  String colId = 'id';
  String colTitle = 'series_name';
  String colEpisodeTitle = 'episode_name';
  String colEpisodeNum = 'episode_num';
  String colSeasonNum = 'season_num';
  String colPosterPath = 'poster_path';
  String colBackdropPath = 'backdrop_path';
  String colElapsed = 'elapsed';
  String colRemaining = 'remaining';
  String colDateAdded = 'date_added';
  String colSeriesId = 'series_id';
  RecentlyWatchedEpisodeController._createInstance();

  factory RecentlyWatchedEpisodeController() {
    _recentlyWatchedEpisodeController ??=
        RecentlyWatchedEpisodeController._createInstance();
    return _recentlyWatchedEpisodeController!;
  }
  Future<Database> initializeDatabase({String? owner, String? directoryPath}) async {
    final capturedOwner = owner ?? LibraryScope.owner;
    Directory directory = directoryPath == null
        ? await getApplicationDocumentsDirectory() : Directory(directoryPath);
    String path = LibraryScope.filename('${directory.path}recent_episodes_v2.db', capturedOwner);
    var episodesDatabase = await openDatabase(
      path,
      version: 3,
      onCreate: _createDb,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE $tableName ADD COLUMN $colBackdropPath TEXT',
          );
        }
        if (oldVersion < 3) {
          await _addSyncColumns(
            db,
            table: tableName,
            dateColumn: colDateAdded,
          );
        }
      },
    );
    return episodesDatabase;
  }

  Future<Database> get database async {
    return databaseForOwner(LibraryScope.owner);
  }

  Future<Database> databaseForOwner(String owner) {
    final key = LibraryScope.enabled ? owner : 'legacy';
    return _databases.putIfAbsent(key, () => initializeDatabase(owner: owner));
  }

  Future<void> _createDb(Database db, int newVersion) async {
    await db.execute(
        'CREATE TABLE $tableName($colId INTEGER PRIMARY KEY, $colSeriesId INTEGER, $colTitle TEXT, $colEpisodeTitle TEXT, $colEpisodeNum INTEGER, $colSeasonNum INTEGER, $colElapsed NUMERIC, $colRemaining NUMERIC, $colPosterPath TEXT, $colBackdropPath TEXT, $colDateAdded TEXT, $_updatedAtCol INTEGER, $_deletedAtCol INTEGER, $_syncedCol INTEGER NOT NULL DEFAULT 0)');
  }

  //this function will return all the tv in the database.
  Future<List<Map<String, dynamic>>> getTVMapList() async {
    Database db = await database;
    var result = await db.query(tableName,
        where: '$_deletedAtCol IS NULL', orderBy: '$colDateAdded DESC');
    return result;
  }

  // this method will be used to insert tv in the database.
  Future<int> insertTV(RecentEpisode rEpisode) async {
    Database db = await database;
    // See [RecentlyWatchedMoviesController.insertMovie] for why this replaces.
    var result = await db.insert(tableName, rEpisode.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return result;
  }

  // this method will update a tv
  Future<int> updateTV(
      RecentEpisode rEpisode, int id, int episodeNum, int seasonNum) async {
    var db = await database;
    var result = await db.update(tableName, rEpisode.toMap(),
        where: '$colId = ? AND $colEpisodeNum = ? AND $colSeasonNum = ?',
        whereArgs: [id, episodeNum, seasonNum]);
    return result;
  }

  /// Marks an episode as removed, leaving the row behind so other devices pick
  /// the removal up on their next sync.
  Future<int> tombstoneTV(int id, int episodeNum, int seasonNum) async {
    var db = await database;
    final now = LibraryScope.nowUtcMs();
    return db.update(
      tableName,
      <String, dynamic>{
        _deletedAtCol: now,
        _updatedAtCol: now,
        _syncedCol: 0,
      },
      where: '$colId = ? AND $colEpisodeNum = ? AND $colSeasonNum = ?',
      whereArgs: [id, episodeNum, seasonNum],
    );
  }

  // this method will delete a tv
  Future<int> deleteTV(int id, int episodeNum, int seasonNum) async {
    var db = await database;
    int result = await db.delete(tableName,
        where: '$colId = ? AND $colEpisodeNum = ? AND $colSeasonNum = ?',
        whereArgs: [id, episodeNum, seasonNum]);
    return result;
  }

  // Get number of TV objects in database
  Future<int> getCount() async {
    Database db = await database;
    List<Map<String, dynamic>> x = await db.rawQuery(
        'SELECT COUNT (*) from $tableName WHERE $_deletedAtCol IS NULL');
    int result = Sqflite.firstIntValue(x)!;
    return result;
  }

  // Get the 'Map List' [ List<Map> ] and convert it to 'TV List' [ List<Movie> ]
  Future<List<RecentEpisode>> getEpisodeList() async {
    var tvMapList = await getTVMapList(); // Get 'Map List' from database
    int count = tvMapList.length; // Count the number of map entries in db table
    List<RecentEpisode> tvList = <RecentEpisode>[];
    // For loop to create a 'TV List' from a 'Map List'
    for (int i = 0; i < count; i++) {
      tvList.add(RecentEpisode.fromMapObject(tvMapList[i]));
    }
    return tvList;
  }

  // this function will check if a movies exists in the database.
  Future<bool> contain(int id) async {
    Database db = await database;
    List<Map<String, dynamic>> x = await db.rawQuery(
        'SELECT COUNT (*) from $tableName WHERE $colId = ? AND $_deletedAtCol IS NULL',
        [id]);
    int result = Sqflite.firstIntValue(x)!;
    if (result == 0) return false;
    return true;
  }

  /// Every row, tombstones included, for two-way merges.
  Future<List<RecentEpisode>> allEpisodes() async {
    Database db = await database;
    final rows = await db.query(tableName);
    return rows.map(RecentEpisode.fromMapObject).toList();
  }

  /// Rows still waiting to be pushed to the cloud, tombstones included.
  Future<List<RecentEpisode>> pendingEpisodes() async {
    Database db = await database;
    final rows = await db.query(tableName, where: '$_syncedCol = 0');
    return rows.map(RecentEpisode.fromMapObject).toList();
  }

  /// Writes rows that won a merge against the local copy.
  Future<void> upsertFromCloud(Iterable<RecentEpisode> episodes) async {
    if (episodes.isEmpty) return;
    Database db = await database;
    await db.transaction((txn) async {
      for (final episode in episodes) {
        episode.synced = true;
        await txn.insert(tableName, episode.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> markSynced(Iterable<int> ids) async {
    final idList = ids.toList(growable: false);
    if (idList.isEmpty) return;
    Database db = await database;
    final placeholders = List.filled(idList.length, '?').join(', ');
    await db.update(
      tableName,
      <String, dynamic>{_syncedCol: 1},
      where: '$colId IN ($placeholders)',
      whereArgs: idList,
    );
  }

  /// Drops tombstones that every device has had ample time to observe.
  Future<List<int>> prunedTombstones(int olderThanUtcMillis) async {
    Database db = await database;
    final rows = await db.query(
      tableName,
      columns: [colId],
      where: '$_deletedAtCol IS NOT NULL AND $_deletedAtCol < ? AND $_syncedCol = 1',
      whereArgs: [olderThanUtcMillis],
    );
    final ids = rows.map((row) => row[colId] as int).toList(growable: false);
    if (ids.isEmpty) return ids;
    final placeholders = List.filled(ids.length, '?').join(', ');
    await db.delete(tableName,
        where: '$colId IN ($placeholders)', whereArgs: ids);
    return ids;
  }

  /// Wipes the table, used when the signed-in account is deleted.
  Future<void> clear() async {
    Database db = await database;
    await db.delete(tableName);
  }
}
