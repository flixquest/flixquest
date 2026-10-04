import 'package:path/path.dart' as paths;
import 'package:sqflite/sqflite.dart';

class AdEvent {
  const AdEvent(this.id, this.adId, this.type);
  final int id;
  final String adId, type;
}

/// Public campaign events persist independently of account sessions.
/// Opening is lazy so flag-off launches never need this database.
class AdEventQueue {
  AdEventQueue({DatabaseFactory? factory, String? path})
      : _factory = factory,
        _path = path;
  final DatabaseFactory? _factory;
  final String? _path;
  Future<Database>? _database;

  Future<Database> _open() => _database ??= _create();
  Future<Database> _create() async {
    try {
      final factory = _factory ?? databaseFactory;
      final path = _path ??
          paths.join(
              await factory.getDatabasesPath(), 'flixquest_ad_events_v1.db');
      return await factory.openDatabase(path,
          options: OpenDatabaseOptions(
              version: 1,
              onCreate: (db, _) async {
                await db.execute('''CREATE TABLE ad_events (
          id INTEGER PRIMARY KEY AUTOINCREMENT, ad_id TEXT NOT NULL,
          type TEXT NOT NULL CHECK(type IN ('impression', 'click')),
          created_at INTEGER NOT NULL, sent INTEGER NOT NULL DEFAULT 0
        )''');
                await db.execute(
                    'CREATE INDEX idx_ad_events_pending ON ad_events(sent, id)');
              }));
    } catch (_) {
      _database = null;
      rethrow;
    }
  }

  Future<void> enqueue(String adId, String type, DateTime createdAt) async {
    if (adId.isEmpty || !{'impression', 'click'}.contains(type)) {
      throw ArgumentError('Invalid ad event');
    }
    await (await _open()).insert('ad_events', {
      'ad_id': adId,
      'type': type,
      'created_at': createdAt.toUtc().millisecondsSinceEpoch,
      'sent': 0
    });
  }

  Future<List<AdEvent>> pending({int limit = 100}) async =>
      (await (await _open()).query('ad_events',
              where: 'sent = 0', orderBy: 'id ASC', limit: limit))
          .map((row) => AdEvent(
              row['id'] as int, row['ad_id'] as String, row['type'] as String))
          .toList();

  Future<void> markSent(int id) async {
    await (await _open())
        .update('ad_events', {'sent': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> prune(DateTime cutoff) async {
    await (await _open()).delete('ad_events',
        where: 'created_at < ?',
        whereArgs: [cutoff.toUtc().millisecondsSinceEpoch]);
  }

  Future<void> close() async {
    final database = _database;
    _database = null;
    if (database != null) await (await database).close();
  }
}
