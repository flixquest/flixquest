import 'package:flixquest/core/json/json_reader.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'api_error.freezed.dart';
part 'api_error.g.dart';

@freezed
class ApiError with _$ApiError {
  const factory ApiError({
    String? code,
    @Default('Request failed.') String message,
    @Default({}) Map<String, List<String>> errors,
    int? retryAfter,
    ClockSkewDetails? clockSkew,
  }) = _ApiError;

  factory ApiError.fromJson(Map<String, dynamic> json) =>
      _$ApiErrorFromJson(_normalize(json));

  static Map<String, dynamic> _normalize(Map<String, dynamic> json) {
    final reader = JsonReader(json);
    final fields = JsonReader.asMap(reader.firstOf(['errors'])) ?? {};
    final errors = <String, List<String>>{};
    for (final entry in fields.entries) {
      final messages = entry.value is String
          ? [entry.value as String]
          : (JsonReader.asList(entry.value) ?? []).whereType<String>().toList();
      if (messages.isNotEmpty) errors[entry.key] = messages;
    }
    final nestedSkew =
        JsonReader.asMap(reader.firstOf(['clockSkew', 'clock_skew']));
    final skewReader = JsonReader(nestedSkew ?? json);
    final serverTime = JsonReader.asInt(
      skewReader.firstOf(['server_time_utc', 'serverTimeUtc']),
    );
    final maxDrift = JsonReader.asInt(
      skewReader.firstOf(['max_drift_ms', 'maxDriftMs']),
    );
    return {
      'code': JsonReader.asString(reader.firstOf(['code', 'error'])),
      'message':
          JsonReader.asString(reader.firstOf(['message'])) ?? 'Request failed.',
      'errors': errors,
      'retryAfter':
          JsonReader.asInt(reader.firstOf(['retry_after', 'retryAfter'])),
      'clockSkew': serverTime != null && maxDrift != null
          ? {'serverTimeUtc': serverTime, 'maxDriftMs': maxDrift}
          : null,
    };
  }
}

@freezed
class ClockSkewDetails with _$ClockSkewDetails {
  const factory ClockSkewDetails({
    required int serverTimeUtc,
    required int maxDriftMs,
  }) = _ClockSkewDetails;

  factory ClockSkewDetails.fromJson(Map<String, dynamic> json) =>
      _$ClockSkewDetailsFromJson(json);
}
