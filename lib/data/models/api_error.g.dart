// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_error.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ApiErrorImpl _$$ApiErrorImplFromJson(Map<String, dynamic> json) =>
    _$ApiErrorImpl(
      code: json['code'] as String?,
      message: json['message'] as String? ?? 'Request failed.',
      errors: (json['errors'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(
                k, (e as List<dynamic>).map((e) => e as String).toList()),
          ) ??
          const {},
      retryAfter: (json['retryAfter'] as num?)?.toInt(),
      clockSkew: json['clockSkew'] == null
          ? null
          : ClockSkewDetails.fromJson(
              json['clockSkew'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$ApiErrorImplToJson(_$ApiErrorImpl instance) =>
    <String, dynamic>{
      'code': instance.code,
      'message': instance.message,
      'errors': instance.errors,
      'retryAfter': instance.retryAfter,
      'clockSkew': instance.clockSkew?.toJson(),
    };

_$ClockSkewDetailsImpl _$$ClockSkewDetailsImplFromJson(
        Map<String, dynamic> json) =>
    _$ClockSkewDetailsImpl(
      serverTimeUtc: (json['serverTimeUtc'] as num).toInt(),
      maxDriftMs: (json['maxDriftMs'] as num).toInt(),
    );

Map<String, dynamic> _$$ClockSkewDetailsImplToJson(
        _$ClockSkewDetailsImpl instance) =>
    <String, dynamic>{
      'serverTimeUtc': instance.serverTimeUtc,
      'maxDriftMs': instance.maxDriftMs,
    };
