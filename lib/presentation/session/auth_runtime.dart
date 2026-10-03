import '../../core/config/migration_flags.dart';
import 'session_view_model.dart';

/// Compatibility access for existing account routes; main installs Provider too.
class AuthRuntime {
  static bool enabled = MigrationFlags.fromRuntime().auth;
  static SessionViewModel? _session;
  static SessionViewModel get session =>
      _session ?? (throw StateError('Session is not configured'));
  static SessionViewModel? get maybeSession => _session;
  static void configure(SessionViewModel session, {required bool enabled}) {
    _session = session;
    AuthRuntime.enabled = enabled;
  }
}
