import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixquest/data/sync/library_scope.dart';
import 'package:flixquest/data/sync/sync_runner.dart';

void main() {
  test(
      'coalesces requests and schedules one follow-up after an in-flight local write',
      () async {
    LibraryScope.activate('user:1');
    final first = Completer<void>();
    final second = Completer<void>();
    var runs = 0;
    final runner = SyncRunner(
        canSync: () => true,
        run: (_, __) async {
          runs++;
          if (runs == 1) {
            await first.future;
          } else {
            second.complete();
          }
        },
        autoInterval: const Duration(minutes: 2),
        debounce: const Duration(seconds: 5));
    final started = runner.sync();
    runner.changed();
    first.complete();
    expect(await started, isTrue);
    await second.future;
    expect(runs, 2);
    await Future<void>.delayed(Duration.zero);
    runner.dispose();
    LibraryScope.activate(null);
  });
  test(
      'an account transition invalidates the old result and runs the requested new account afterward',
      () async {
    LibraryScope.activate('user:1');
    final first = Completer<void>();
    final done = Completer<void>();
    final owners = <String>[];
    final runner = SyncRunner(
        canSync: () => true,
        run: (owner, current) async {
          owners.add(owner);
          if (owner == 'user:1') {
            await first.future;
          } else {
            done.complete();
          }
        },
        autoInterval: const Duration(minutes: 2),
        debounce: const Duration(seconds: 5));
    final old = runner.sync();
    LibraryScope.activate('user:2');
    runner.ownerChanged();
    runner.sync();
    first.complete();
    expect(await old, isFalse);
    await done.future.timeout(const Duration(seconds: 1));
    expect(owners, ['user:1', 'user:2']);
    await Future<void>.delayed(Duration.zero);
    runner.dispose();
    LibraryScope.activate(null);
  });
}
