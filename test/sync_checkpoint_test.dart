import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flixquest/services/sync_checkpoint.dart';
import 'package:flixquest/services/wellness_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final now = DateTime(2026, 9, 27, 12);

  group('SyncCheckpoint.needsFullPull', () {
    test('a device that has never pulled reads everything', () {
      expect(const SyncCheckpoint().needsFullPull(now), isTrue);
    });

    test('a recent full pull allows a delta', () {
      final checkpoint = SyncCheckpoint(
        stampMicros: 10,
        fullPullAt: now.subtract(const Duration(days: 1)),
      );
      expect(checkpoint.needsFullPull(now), isFalse);
    });

    test('reads everything again once the full pull is a week old', () {
      final checkpoint = SyncCheckpoint(
        stampMicros: 10,
        fullPullAt: now.subtract(fullPullInterval),
      );
      expect(checkpoint.needsFullPull(now), isTrue);
    });

    test('a clock that moved backwards forces a full read', () {
      final checkpoint = SyncCheckpoint(
        stampMicros: 10,
        fullPullAt: now.add(const Duration(days: 1)),
      );
      expect(checkpoint.needsFullPull(now), isTrue);
    });
  });

  group('SyncCheckpoint.advance', () {
    Map<String, dynamic> stamped(int micros) => <String, dynamic>{
          syncedAtField: Timestamp.fromMicrosecondsSinceEpoch(micros),
        };

    test('a full pull starts from the newest stamp it saw', () {
      final next = const SyncCheckpoint(stampMicros: 900).advance(
        <Map<String, dynamic>>[stamped(300), stamped(500), <String, dynamic>{}],
        full: true,
        now: now,
      );
      expect(next.stampMicros, 500);
      expect(next.fullPullAt, now);
    });

    test('a full pull of unstamped documents starts from zero', () {
      final next = const SyncCheckpoint().advance(
        <Map<String, dynamic>>[
          <String, dynamic>{'id': 1}
        ],
        full: true,
        now: now,
      );
      expect(next.stampMicros, 0);
    });

    test('an empty delta keeps the cursor and the last full pull time', () {
      final fullAt = now.subtract(const Duration(days: 2));
      final next = SyncCheckpoint(stampMicros: 700, fullPullAt: fullAt)
          .advance(const <Map<String, dynamic>>[], full: false, now: now);
      expect(next.stampMicros, 700);
      expect(next.fullPullAt, fullAt);
    });

    test('a delta moves the cursor forward, never back', () {
      final next = SyncCheckpoint(stampMicros: 700, fullPullAt: now).advance(
        <Map<String, dynamic>>[stamped(650), stamped(800)],
        full: false,
        now: now,
      );
      expect(next.stampMicros, 800);
    });
  });

  group('SyncCheckpoint storage', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('round-trips and clears by prefix', () async {
      await SyncCheckpoint(stampMicros: 42, fullPullAt: now).save('a.uid.x');
      await SyncCheckpoint(stampMicros: 7, fullPullAt: now).save('b.uid.x');

      final loaded = await SyncCheckpoint.load('a.uid.x');
      expect(loaded.stampMicros, 42);
      expect(loaded.fullPullAt, now);

      await SyncCheckpoint.clear('a.uid.');
      expect((await SyncCheckpoint.load('a.uid.x')).stampMicros, isNull);
      expect((await SyncCheckpoint.load('b.uid.x')).stampMicros, 7);
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
