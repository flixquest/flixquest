import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flixquest/controllers/wellness_database_controller.dart';
import 'package:flixquest/core/time/server_clock.dart';
import 'package:flixquest/data/repositories/wellness_repository.dart';
import 'package:flixquest/data/sync/wellness_sync_engine.dart';
import 'package:flixquest/models/wellness.dart';
import '../support/fakes.dart';
import '../support/fake_dio.dart';
import 'wellness_repository_test.dart' show page;

Map<String, dynamic> session(String id, int version, {int? deleted}) => {
      'id': id,
      'owner_id': 'user:1',
      'device_id': 'test',
      'media_type': 'movie',
      'source': 'stream',
      'content_id': '1',
      'title': 'Title',
      'started_at_utc': 10,
      'ended_at_utc': 60010,
      'timezone_offset_minutes': 0,
      'watched_ms': 60000,
      'duration_ms': 600000,
      'progress_end_ms': 60000,
      'completed': false,
      'updated_at_utc': version,
      'deleted_at_utc': deleted,
      'network_bytes': 1024,
      'segments': [],
    };
void main() {
  test(
      'wellness applies LWW and tombstones without acknowledging a concurrent edit',
      () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('f5-wellness-');
    final db = await WellnessDatabaseController.instance
        .initializeDatabase(databasePath: '${dir.path}/wellness.db');
    final local = WellnessDatabaseController.forDatabase(db);
    await local
        .upsertSession(WellnessViewingSession.fromMap(session('a', 100)));
    await local
        .upsertSession(WellnessViewingSession.fromMap(session('b', 100)));
    final store = FakeKvStore();
    final clock = ServerClock(store,
        now: () => DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true));
    final adapter = FakeDioAdapter()
      ..enqueueJson(page(1))
      ..enqueueJson(page(2, sessions: [
        session('a', 100),
        session('b', 200, deleted: 200),
        session('c', 200)
      ]));
    final dio = Dio(BaseOptions(baseUrl: 'https://backend.test/api/v1/'))
      ..httpClientAdapter = adapter;
    dio.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) async {
      if ((options.data['sessions'] as List).isNotEmpty) {
        await local
            .upsertSession(WellnessViewingSession.fromMap(session('a', 300)));
      }
      handler.next(options);
    }));
    await WellnessSyncEngine(
            WellnessRepository(dio, store, clock), local, clock)
        .sync('user:1');
    final rows = {
      for (final row
          in await local.sessionsForOwner('user:1', includeDeleted: true))
        row.id: row
    };
    expect(rows['a']!.updatedAtUtc.millisecondsSinceEpoch, 300);
    expect(rows['a']!.synced, isFalse);
    expect(rows['b']!.isDeleted, isTrue);
    expect(rows['c']!.networkBytes, 1024);
    expect(rows['c']!.ownerId, 'user:1');
    await db.close();
    dio.close();
    await dir.delete(recursive: true);
  });
}
