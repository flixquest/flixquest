import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flixquest/services/google_error_reporting.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCrashlytics extends Fake implements FirebaseCrashlytics {
  final flutterReports = <FlutterErrorDetails>[];
  final platformReports = <({Object error, StackTrace? stack, bool fatal})>[];
  bool synchronousFailure = false;
  bool asynchronousFailure = false;
  void Function()? recurse;
  Future<void> _result() {
    if (synchronousFailure) throw StateError('SDK unavailable');
    if (asynchronousFailure) return Future.error(StateError('Upload failed'));
    return Future.value();
  }

  @override
  Future<void> recordFlutterFatalError(FlutterErrorDetails details) {
    flutterReports.add(details);
    recurse?.call();
    return _result();
  }

  @override
  Future<void> recordError(dynamic exception, StackTrace? stack,
      {dynamic reason,
      Iterable<Object> information = const [],
      bool? printDetails,
      bool fatal = false}) {
    platformReports
        .add((error: exception as Object, stack: stack, fatal: fatal));
    recurse?.call();
    return _result();
  }
}

void main() {
  test(
      'Flutter filtering and fatal platform payloads preserve the Google SDK path',
      () async {
    final sdk = FakeCrashlytics();
    final ignored =
        FlutterErrorDetails(exception: StateError('Image download'));
    final details = FlutterErrorDetails(exception: StateError('Build failed'));
    final reporting = GoogleErrorReporting(sdk,
        ignoreFlutterError: (value) => identical(value, ignored));
    reporting.flutterError(ignored);
    reporting.flutterError(details);
    final error = StateError('Platform failed');
    final stack = StackTrace.current;
    expect(reporting.platformError(error, stack), isTrue);
    expect(sdk.flutterReports, [details]);
    expect(
        sdk.platformReports.single, (error: error, stack: stack, fatal: true));
  });
  test(
      'synchronous and asynchronous SDK failures do not escape the uncaught error handlers',
      () async {
    final sdk = FakeCrashlytics();
    final reporting =
        GoogleErrorReporting(sdk, ignoreFlutterError: (_) => false);
    sdk.synchronousFailure = true;
    expect(
        () => reporting.flutterError(
            FlutterErrorDetails(exception: StateError('Original'))),
        returnsNormally);
    sdk.synchronousFailure = false;
    sdk.asynchronousFailure = true;
    reporting.platformError(StateError('Original'), StackTrace.current);
    await Future<void>.delayed(Duration.zero);
    expect(sdk.platformReports.length, 1);
  });
  test('an SDK that re-enters the handler cannot recursively report itself',
      () async {
    final sdk = FakeCrashlytics();
    final reporting =
        GoogleErrorReporting(sdk, ignoreFlutterError: (_) => false);
    sdk.recurse = () {
      sdk.recurse = null;
      reporting.platformError(StateError('SDK recursion'), StackTrace.current);
    };
    reporting.platformError(StateError('Original'), StackTrace.current);
    expect(sdk.platformReports.length, 1);
  });
}
