import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flixquest/functions/function.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAnalytics extends Fake implements FirebaseAnalytics {
  final events = <({String name, Map<String, Object>? parameters})>[];
  @override
  Future<void> logEvent(
      {required String name,
      Map<String, Object>? parameters,
      List<AnalyticsEventItem>? items,
      AnalyticsCallOptions? callOptions}) async {
    events.add((name: name, parameters: parameters));
  }
}

void main() {
  test(
      'streaming duration retains its Google event name and cumulative seconds',
      () {
    final sdk = FakeAnalytics();
    totalStreamingDuration = 0;
    updateAndLogTotalStreamingDuration(30, analytics: sdk);
    updateAndLogTotalStreamingDuration(45, analytics: sdk);
    expect(sdk.events.map((event) => event.name),
        ['total_streaming_duration', 'total_streaming_duration']);
    expect(sdk.events.map((event) => event.parameters), [
      {'duration_seconds': 30},
      {'duration_seconds': 75}
    ]);
    totalStreamingDuration = 0;
  });
}
