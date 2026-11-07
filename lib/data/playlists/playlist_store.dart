import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'playlist.dart';
import 'playlist_replay.dart';

/// Device-local custom lists. Every edit commits a complete snapshot atomically.
class PlaylistStore {
  PlaylistStore(this.database);
  final Database database;
  static final Map<String, Future<PlaylistStore>> _stores = {};
  static Future<PlaylistStore> forOwner(String owner) =>
      _stores.putIfAbsent(owner, () => open(owner: owner));
  static Future<PlaylistStore> open(
      {required String owner, String? directoryPath}) async {
    final directory = directoryPath == null
        ? await getApplicationDocumentsDirectory()
        : Directory(directoryPath);
    return PlaylistStore(await openDatabase(
        p.join(directory.path, 'public_playlists.db'),
        version: 1, onCreate: (db, _) async {
      await db.execute(
          'CREATE TABLE playlists(id TEXT PRIMARY KEY, name TEXT, description TEXT, version INTEGER, source_provider TEXT, source_id TEXT, created_at TEXT, share_code TEXT, share_url TEXT)');
      await db.execute(
          'CREATE TABLE playlist_items(playlist_id TEXT, media_type TEXT, media_id INTEGER, position INTEGER, title TEXT, poster_path TEXT, backdrop_path TEXT, vote_average REAL, release_date TEXT, genre_ids TEXT, added_at TEXT, PRIMARY KEY(playlist_id, media_type, media_id))');
    }));
  }

  Future<List<Playlist>> read() async => replayPlaylists(
      (await database.query('playlists')).map(PlaylistRecord.fromRow),
      (await database.query('playlist_items')).map(PlaylistEntry.fromRow),
      const []);
  Future<void> enqueue(PlaylistOperation operation) => enqueueAll([operation]);
  Future<void> enqueueAll(List<PlaylistOperation> operations) =>
      database.transaction((txn) async {
        final lists = replayPlaylists(
            (await txn.query('playlists')).map(PlaylistRecord.fromRow),
            (await txn.query('playlist_items')).map(PlaylistEntry.fromRow),
            operations);
        await txn.delete('playlist_items');
        await txn.delete('playlists');
        for (final list in lists) {
          await txn.insert('playlists', list.record.toRow());
          for (final item in list.entries) {
            await txn.insert('playlist_items', item.toRow());
          }
        }
      });
  Future<void> clear() => database.transaction((txn) async {
        await txn.delete('playlist_items');
        await txn.delete('playlists');
      });
}
