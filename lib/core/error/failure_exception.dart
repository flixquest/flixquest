import 'failure.dart';

/// Transitional boundary for legacy APIs whose signatures return values/throw.
class FailureException implements Exception {
  const FailureException(this.failure);
  final Failure failure;
  @override
  String toString() => failure.message ?? 'Request failed.';
}
