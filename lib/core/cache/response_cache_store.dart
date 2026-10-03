import 'dart:convert';
import 'dart:typed_data';

import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:path/path.dart' as paths;
import 'package:sqflite/sqflite.dart';

/// Bounded SQLite persistence for the package's HTTP cache model.
class ResponseCacheStore extends CacheStore {
  ResponseCacheStore._(this._database, this.maxEntries, this.maxBytes,
      this.memoryEntries, this.memoryBytes, this._now);

  static Future<ResponseCacheStore> open({
    DatabaseFactory? factory,
    String? path,
    int maxEntries = 5000,
    int maxBytes = 50 * 1024 * 1024,
    int memoryEntries = 300,
    int memoryBytes = 16 * 1024 * 1024,
    DateTime Function()? now,
  }) async {
    if (maxEntries < 0 ||
        maxBytes < 0 ||
        memoryEntries < 0 ||
        memoryBytes < 0) {
      throw ArgumentError('Cache limits cannot be negative.');
    }
    final dbFactory = factory ?? databaseFactory;
    final dbPath = path ??
        paths.join(
            await dbFactory.getDatabasesPath(), 'flixquest_http_cache_v1.db');
    final database = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute('''CREATE TABLE http_cache (
          key TEXT PRIMARY KEY, scope TEXT NOT NULL, auth_scope TEXT NOT NULL,
          url TEXT NOT NULL, status_code INTEGER NOT NULL, body BLOB NOT NULL,
          headers BLOB, etag TEXT, last_modified TEXT, cache_control TEXT NOT NULL,
          date INTEGER, expires INTEGER, request_date INTEGER NOT NULL,
          fetched_at INTEGER NOT NULL, max_age_ms INTEGER NOT NULL,
          max_stale_ms INTEGER NOT NULL, priority INTEGER NOT NULL,
          accessed_at INTEGER NOT NULL
        )''');
            await db.execute(
                'CREATE INDEX idx_http_cache_scope ON http_cache(scope, fetched_at)');
            await db.execute(
                'CREATE INDEX idx_http_cache_access ON http_cache(accessed_at)');
          }),
    );
    final store = ResponseCacheStore._(database, maxEntries, maxBytes,
        memoryEntries, memoryBytes, now ?? DateTime.now);
    store._lastAccessedAt = (await database.rawQuery(
            'SELECT COALESCE(MAX(accessed_at), 0) AS latest FROM http_cache'))
        .single['latest'] as int;
    return store;
  }

  final Database _database;
  final int maxEntries, maxBytes, memoryEntries, memoryBytes;
  final DateTime Function() _now;
  final _memory = <String, CacheResponse>{};
  int _generation = 0;
  int _lastAccessedAt = 0;
  int _nextAccess() {
    final now = _now().millisecondsSinceEpoch;
    return _lastAccessedAt = now > _lastAccessedAt ? now : _lastAccessedAt + 1;
  }

  static List<String> keyParts(String key) {
    final value = jsonDecode(key);
    if (value is! List ||
        value.length != 4 ||
        value.any((item) => item is! String)) {
      throw const FormatException('Invalid scoped cache key');
    }
    return List<String>.from(value);
  }

  int _bytes(CacheResponse response) =>
      (response.content?.length ?? 0) + (response.headers?.length ?? 0);

  void _remember(CacheResponse response) {
    _memory.remove(response.key);
    if (_bytes(response) <= memoryBytes && memoryEntries > 0) {
      _memory[response.key] = response;
    }
    var bytes =
        _memory.values.fold<int>(0, (sum, entry) => sum + _bytes(entry));
    while (_memory.isNotEmpty &&
        (_memory.length > memoryEntries || bytes > memoryBytes)) {
      bytes -= _bytes(_memory.remove(_memory.keys.first)!);
    }
  }

  @override
  Future<CacheResponse?> get(String key) async {
    final generation = _generation;
    var response = _memory.remove(key);
    if (response == null) {
      final rows = await _database
          .query('http_cache', where: 'key = ?', whereArgs: [key]);
      if (rows.isEmpty) return null;
      try {
        response = _fromRow(rows.single);
      } catch (_) {
        await delete(key);
        return null;
      }
    }
    if (response.maxStale?.isBefore(_now()) == true) {
      await delete(key);
      return null;
    }
    await _database.update('http_cache', {'accessed_at': _nextAccess()},
        where: 'key = ?', whereArgs: [key]);
    if (generation == _generation) _remember(response);
    return response;
  }

  @override
  Future<bool> exists(String key) async => await get(key) != null;

  @override
  Future<void> set(CacheResponse response) async {
    if (response.statusCode != 200 || response.cacheControl.noStore) return;
    if (response.maxStale?.isBefore(_now()) == true) {
      await delete(response.key);
      return;
    }
    final parts = keyParts(response.key);
    // The package can extend maxStale on cache hits. Preserve a fixed deadline
    // unless an actual network response/revalidation changed responseDate.
    final previous = await get(response.key);
    if (previous != null && previous.responseDate == response.responseDate) {
      response = response.copyWith(maxStale: previous.maxStale);
    }
    final saved = response.copyWith(url: parts[3]);
    if (_bytes(saved) > maxBytes || maxEntries < 1) {
      await delete(saved.key);
      return;
    }
    _generation++;
    final evicted = await _database.transaction((transaction) async {
      await transaction.insert('http_cache', _toRow(saved, parts),
          conflictAlgorithm: ConflictAlgorithm.replace);
      final rows = await transaction.rawQuery(
          'SELECT key, length(body) + COALESCE(length(headers), 0) AS bytes FROM http_cache ORDER BY accessed_at, rowid');
      var count = rows.length;
      var bytes = rows.fold<int>(0, (sum, row) => sum + (row['bytes'] as int));
      final removed = <String>[];
      for (final row in rows) {
        if (count <= maxEntries && bytes <= maxBytes) break;
        final key = row['key'] as String;
        await transaction
            .delete('http_cache', where: 'key = ?', whereArgs: [key]);
        removed.add(key);
        count--;
        bytes -= row['bytes'] as int;
      }
      return removed;
    });
    for (final key in evicted) {
      _memory.remove(key);
    }
    if (!evicted.contains(saved.key)) _remember(saved);
  }

  Future<void> put(CacheResponse response) => set(response);
  Future<void> evict(String key) => delete(key);

  Future<void> touch(String key, DateTime fetchedAt) async {
    final entry = await get(key);
    if (entry == null) return;
    final lifetime = entry.maxStale?.difference(entry.responseDate);
    await set(entry.copyWith(
        requestDate: fetchedAt,
        responseDate: fetchedAt,
        maxStale: lifetime == null ? null : fetchedAt.add(lifetime)));
  }

  @override
  Future<void> delete(String key, {bool staleOnly = false}) async {
    _generation++;
    if (staleOnly) {
      await _database.delete('http_cache',
          where:
              'key = ? AND max_stale_ms >= 0 AND fetched_at + max_stale_ms < ?',
          whereArgs: [key, _now().millisecondsSinceEpoch]);
    } else {
      await _database.delete('http_cache', where: 'key = ?', whereArgs: [key]);
    }
    _memory.remove(key);
  }

  Future<void> clearScope(String scope) async {
    _generation++;
    final where = scope == 'user'
        ? "auth_scope != 'public'"
        : scope.startsWith('user:')
            ? 'auth_scope = ?'
            : 'scope = ?';
    await _database.delete('http_cache',
        where: where, whereArgs: scope == 'user' ? null : [scope]);
    _memory.removeWhere((key, _) {
      final parts = keyParts(key);
      return scope == 'user'
          ? parts[1] != 'public'
          : scope.startsWith('user:')
              ? parts[1] == scope
              : parts[0] == scope;
    });
  }

  Future<void> clearAll() => clean();
  Future<int> sizeBytes() async => (await _database.rawQuery(
          'SELECT COALESCE(SUM(length(body) + COALESCE(length(headers), 0)), 0) AS bytes FROM http_cache'))
      .single['bytes'] as int;
  Future<void> pruneExpired() => clean(staleOnly: true);

  @override
  Future<void> clean(
      {CachePriority priorityOrBelow = CachePriority.high,
      bool staleOnly = false}) async {
    _generation++;
    final where = staleOnly
        ? 'priority <= ? AND max_stale_ms >= 0 AND fetched_at + max_stale_ms < ?'
        : 'priority <= ?';
    await _database.delete('http_cache', where: where, whereArgs: [
      priorityOrBelow.index,
      if (staleOnly) _now().millisecondsSinceEpoch,
    ]);
    _memory.removeWhere((_, entry) =>
        entry.priority.index <= priorityOrBelow.index &&
        (!staleOnly || entry.maxStale?.isBefore(_now()) == true));
  }

  @override
  Future<List<CacheResponse>> getFromPath(RegExp pathPattern,
      {Map<String, String?>? queryParams}) async {
    final rows = await _database.query('http_cache', columns: ['key', 'url']);
    final entries = <CacheResponse>[];
    for (final row in rows) {
      if (!pathExists(row['url'] as String, pathPattern,
          queryParams: queryParams)) {
        continue;
      }
      final entry = await get(row['key'] as String);
      if (entry != null) entries.add(entry);
    }
    return entries;
  }

  @override
  Future<void> deleteFromPath(RegExp pathPattern,
      {Map<String, String?>? queryParams}) async {
    for (final entry
        in await getFromPath(pathPattern, queryParams: queryParams)) {
      await delete(entry.key);
    }
  }

  @override
  Future<void> close() async {
    _memory.clear();
    await _database.close();
  }

  Map<String, Object?> _toRow(CacheResponse entry, List<String> parts) => {
        'key': entry.key,
        'scope': parts[0],
        'auth_scope': parts[1],
        'url': entry.url,
        'status_code': entry.statusCode,
        'body': Uint8List.fromList(entry.content ?? []),
        'headers':
            entry.headers == null ? null : Uint8List.fromList(entry.headers!),
        'etag': entry.eTag,
        'last_modified': entry.lastModified,
        'cache_control': entry.cacheControl.toHeader(),
        'date': entry.date?.millisecondsSinceEpoch,
        'expires': entry.expires?.millisecondsSinceEpoch,
        'request_date': entry.requestDate.millisecondsSinceEpoch,
        'fetched_at': entry.responseDate.millisecondsSinceEpoch,
        'max_age_ms': entry.cacheControl.maxAge * 1000,
        'max_stale_ms':
            entry.maxStale?.difference(entry.responseDate).inMilliseconds ?? -1,
        'priority': entry.priority.index,
        'accessed_at': _nextAccess(),
      };

  CacheResponse _fromRow(Map<String, Object?> row) {
    DateTime date(int milliseconds) =>
        DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
    final fetchedAt = row['fetched_at'] as int;
    final maxStale = row['max_stale_ms'] as int;
    return CacheResponse(
      key: row['key'] as String,
      url: row['url'] as String,
      statusCode: row['status_code'] as int,
      content: row['body'] as Uint8List,
      headers: row['headers'] as Uint8List?,
      eTag: row['etag'] as String?,
      lastModified: row['last_modified'] as String?,
      cacheControl: CacheControl.fromString(row['cache_control'] as String),
      date: row['date'] == null ? null : date(row['date'] as int),
      expires: row['expires'] == null ? null : date(row['expires'] as int),
      requestDate: date(row['request_date'] as int),
      responseDate: date(fetchedAt),
      maxStale: maxStale < 0 ? null : date(fetchedAt + maxStale),
      priority: CachePriority.values[row['priority'] as int],
    );
  }
}
