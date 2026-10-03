import 'package:flixquest/core/storage/kv_store.dart';
import 'package:flixquest/core/time/server_clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'server clock corrects device timestamps and restores offset after restart',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = KvStore(await SharedPreferences.getInstance());
    var deviceMs = 1700000100000;
    final clock = ServerClock(store,
        now: () => DateTime.fromMillisecondsSinceEpoch(deviceMs));
    await clock.recordServerTimeUtc(1700000000000);
    expect(clock.offsetMs, -100000);
    deviceMs += 5000;
    expect(clock.nowUtcMs(), 1700000005000);
    expect(clock.toServerMs(DateTime.fromMillisecondsSinceEpoch(1700000090000)),
        1699999990000);
    final restored = ServerClock(store,
        now: () => DateTime.fromMillisecondsSinceEpoch(deviceMs));
    expect(restored.nowUtcMs(), 1700000005000);
  });

  test(
      'clock can correct a device behind the server without changing elapsed time',
      () async {
    final clock = FakeServerClock(deviceTimeMs: 1700000000000);
    await clock.recordServerTimeUtc(1700000060000);
    expect(clock.offsetMs, 60000);
    clock.advance(const Duration(seconds: 10));
    expect(clock.nowUtcMs(), 1700000070000);
  });
}
