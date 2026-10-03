/// Development-only cutover switches; production stays on existing paths in F0.
class MigrationFlags {
  MigrationFlags.parse(String value)
      : _features = value.split(',').map((item) => item.trim()).toSet();

  factory MigrationFlags.fromRuntime() => MigrationFlags.parse(
        const String.fromEnvironment('FLIXQUEST_MIGRATION'),
      );

  final Set<String> _features;
  bool get auth => _features.contains('auth');
  bool get config => _features.contains('config');
  bool get ads => _features.contains('ads');
  bool get sync => _features.contains('sync');
  bool get notifications => _features.contains('notifications');
  bool get telemetry => _features.contains('telemetry');
}
