class CachePolicy {
  const CachePolicy(
      {required this.scope,
      required this.fresh,
      required this.maxStale,
      this.validators = true,
      this.enabled = true});

  static const noStore = CachePolicy(
      scope: 'none',
      fresh: Duration.zero,
      maxStale: Duration.zero,
      enabled: false);
  static const logo = CachePolicy(
      scope: 'assets', fresh: Duration(days: 7), maxStale: Duration(days: 30));

  final String scope;
  final Duration fresh;

  /// Null means an indefinite offline fallback (bootstrap only).
  final Duration? maxStale;
  final bool validators;
  final bool enabled;
}
