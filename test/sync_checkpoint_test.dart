import 'package:flixquest/data/sync/sync_cursor.dart';
import 'package:flixquest/services/wellness_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fakes.dart';

void main() {
  final now = DateTime.utc(2026, 9, 27, 12);
  group('SyncCursor.needsFullPull', () {
    test('a device that has never pulled reads everything', () {
      expect(const SyncCursor().needsFullPull(now), isTrue);
    });
    test('a recent full pull allows a delta', () {
      final checkpoint = SyncCursor(serverRevision: 10,
          lastFullPullAt: now.subtract(const Duration(days: 1)));
      expect(checkpoint.needsFullPull(now), isFalse);
    });
    test('reads everything again once the full pull is a week old', () {
      final checkpoint = SyncCursor(serverRevision: 10,
          lastFullPullAt: now.subtract(fullPullInterval));
      expect(checkpoint.needsFullPull(now), isTrue);
    });
    test('a clock that moved backwards forces a full read', () {
      final checkpoint = SyncCursor(serverRevision: 10,
          lastFullPullAt: now.add(const Duration(days: 1)));
      expect(checkpoint.needsFullPull(now), isTrue);
    });
  });
  group('SyncCursor.advance', () {
    test('a full pull resets to the server revision it saw', () {
      final next = const SyncCursor(serverRevision: 900)
          .advance(500, 1000, full: true, now: now);
      expect(next.serverRevision, 500);
      expect(next.lastFullPullAt, now);
      expect(next.lastServerTimeUtc, 1000);
      expect(next.lastSyncAt, now);
    });
    test('a full pull of legacy rows starts from the returned server revision', () {
      final next = const SyncCursor().advance(0, 1000, full: true, now: now);
      expect(next.serverRevision, 0);
    });
    test('an empty delta keeps the cursor and the last full pull time', () {
      final fullAt = now.subtract(const Duration(days: 2));
      final next = SyncCursor(serverRevision: 700, lastFullPullAt: fullAt)
          .advance(700, 1000, full: false, now: now);
      expect(next.serverRevision, 700);
      expect(next.lastFullPullAt, fullAt);
    });
    test('a delta moves the cursor forward, never back', () {
      final original = SyncCursor(serverRevision: 700, lastFullPullAt: now);
      expect(original.advance(650, 1000, full: false, now: now).serverRevision, 700);
      expect(original.advance(800, 1000, full: false, now: now).serverRevision, 800);
    });
  });
  group('SyncCursor storage', () {
    test('round-trips and clears by account prefix', () async {
      final store = FakeKvStore();
      await SyncCursor(serverRevision: 42, lastFullPullAt: now)
          .save(store, 'user:a', 'recent');
      await SyncCursor(serverRevision: 7, lastFullPullAt: now)
          .save(store, 'user:b', 'recent');
      final loaded = SyncCursor.load(store, 'user:a', 'recent');
      expect(loaded.serverRevision, 42);
      expect(loaded.lastFullPullAt, now);
      await store.removePrefix('sync.user:a.');
      expect(SyncCursor.load(store, 'user:a', 'recent').serverRevision, isNull);
      expect(SyncCursor.load(store, 'user:b', 'recent').serverRevision, 7);
    });
  });

  group('planDailyWrites', () {
    test('writes nothing when the ledger matches', () {
      final plan = planDailyWrites(
        ledger: <String, int?>{'2026-09-26': 1, '2026-09-27': 2},
        local: <String, int?>{'2026-09-26': 1, '2026-09-27': 2},
      );
      expect(plan.deletes, isEmpty);
      expect(plan.sets, isEmpty);
    });

    test('writes changed and new days, deletes days gone locally', () {
      final plan = planDailyWrites(
        ledger: <String, int?>{'2026-09-25': 1, '2026-09-26': 1},
        local: <String, int?>{'2026-09-26': 5, '2026-09-27': 3},
      );
      expect(plan.deletes, <String>['2026-09-25']);
      expect(plan.sets, unorderedEquals(<String>['2026-09-26', '2026-09-27']));
    });
  });
}
