import 'dart:async';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Keeps Google reporting failures from becoming another uncaught report.
class GoogleErrorReporting {
  GoogleErrorReporting(this.crashlytics, {required this.ignoreFlutterError});
  final FirebaseCrashlytics crashlytics;
  final bool Function(FlutterErrorDetails) ignoreFlutterError;
  void flutterError(FlutterErrorDetails details) {
    if (ignoreFlutterError(details)) return;
    _record(() => crashlytics.recordFlutterFatalError(details));
  }

  bool platformError(Object error, StackTrace stack) {
    _record(() => crashlytics.recordError(error, stack, fatal: true));
    return true;
  }

  bool _recording = false;
  void _record(Future<void> Function() report) {
    if (_recording) return;
    _recording = true;
    try {
      unawaited(report().catchError((Object _, StackTrace __) {}));
    } catch (_) {
      /* Reporting failures must not re-enter uncaught error handling. */
    } finally {
      _recording = false;
    }
  }
}
