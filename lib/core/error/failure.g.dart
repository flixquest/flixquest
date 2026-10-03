// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'failure.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NetworkFailureImpl _$$NetworkFailureImplFromJson(Map<String, dynamic> json) =>
    _$NetworkFailureImpl(
      message: json['message'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$NetworkFailureImplToJson(
        _$NetworkFailureImpl instance) =>
    <String, dynamic>{
      'message': instance.message,
      'runtimeType': instance.$type,
    };

_$TimeoutFailureImpl _$$TimeoutFailureImplFromJson(Map<String, dynamic> json) =>
    _$TimeoutFailureImpl(
      message: json['message'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$TimeoutFailureImplToJson(
        _$TimeoutFailureImpl instance) =>
    <String, dynamic>{
      'message': instance.message,
      'runtimeType': instance.$type,
    };

_$UnauthorizedFailureImpl _$$UnauthorizedFailureImplFromJson(
        Map<String, dynamic> json) =>
    _$UnauthorizedFailureImpl(
      message: json['message'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$UnauthorizedFailureImplToJson(
        _$UnauthorizedFailureImpl instance) =>
    <String, dynamic>{
      'message': instance.message,
      'runtimeType': instance.$type,
    };

_$ForbiddenFailureImpl _$$ForbiddenFailureImplFromJson(
        Map<String, dynamic> json) =>
    _$ForbiddenFailureImpl(
      message: json['message'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$ForbiddenFailureImplToJson(
        _$ForbiddenFailureImpl instance) =>
    <String, dynamic>{
      'message': instance.message,
      'runtimeType': instance.$type,
    };

_$NotFoundFailureImpl _$$NotFoundFailureImplFromJson(
        Map<String, dynamic> json) =>
    _$NotFoundFailureImpl(
      message: json['message'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$NotFoundFailureImplToJson(
        _$NotFoundFailureImpl instance) =>
    <String, dynamic>{
      'message': instance.message,
      'runtimeType': instance.$type,
    };

_$ConflictFailureImpl _$$ConflictFailureImplFromJson(
        Map<String, dynamic> json) =>
    _$ConflictFailureImpl(
      message: json['message'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$ConflictFailureImplToJson(
        _$ConflictFailureImpl instance) =>
    <String, dynamic>{
      'message': instance.message,
      'runtimeType': instance.$type,
    };

_$ValidationFailureImpl _$$ValidationFailureImplFromJson(
        Map<String, dynamic> json) =>
    _$ValidationFailureImpl(
      (json['fields'] as Map<String, dynamic>).map(
        (k, e) =>
            MapEntry(k, (e as List<dynamic>).map((e) => e as String).toList()),
      ),
      message: json['message'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$ValidationFailureImplToJson(
        _$ValidationFailureImpl instance) =>
    <String, dynamic>{
      'fields': instance.fields,
      'message': instance.message,
      'runtimeType': instance.$type,
    };

_$RateLimitedFailureImpl _$$RateLimitedFailureImplFromJson(
        Map<String, dynamic> json) =>
    _$RateLimitedFailureImpl(
      retryAfter: (json['retryAfter'] as num?)?.toInt(),
      message: json['message'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$RateLimitedFailureImplToJson(
        _$RateLimitedFailureImpl instance) =>
    <String, dynamic>{
      'retryAfter': instance.retryAfter,
      'message': instance.message,
      'runtimeType': instance.$type,
    };

_$ServerFailureImpl _$$ServerFailureImplFromJson(Map<String, dynamic> json) =>
    _$ServerFailureImpl(
      status: (json['status'] as num).toInt(),
      message: json['message'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$ServerFailureImplToJson(_$ServerFailureImpl instance) =>
    <String, dynamic>{
      'status': instance.status,
      'message': instance.message,
      'runtimeType': instance.$type,
    };

_$ClockSkewFailureImpl _$$ClockSkewFailureImplFromJson(
        Map<String, dynamic> json) =>
    _$ClockSkewFailureImpl(
      serverTimeUtc: (json['serverTimeUtc'] as num).toInt(),
      driftMs: (json['driftMs'] as num).toInt(),
      message: json['message'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$ClockSkewFailureImplToJson(
        _$ClockSkewFailureImpl instance) =>
    <String, dynamic>{
      'serverTimeUtc': instance.serverTimeUtc,
      'driftMs': instance.driftMs,
      'message': instance.message,
      'runtimeType': instance.$type,
    };

_$CacheFailureImpl _$$CacheFailureImplFromJson(Map<String, dynamic> json) =>
    _$CacheFailureImpl(
      message: json['message'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$CacheFailureImplToJson(_$CacheFailureImpl instance) =>
    <String, dynamic>{
      'message': instance.message,
      'runtimeType': instance.$type,
    };

_$UnknownFailureImpl _$$UnknownFailureImplFromJson(Map<String, dynamic> json) =>
    _$UnknownFailureImpl(
      message: json['message'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$UnknownFailureImplToJson(
        _$UnknownFailureImpl instance) =>
    <String, dynamic>{
      'message': instance.message,
      'runtimeType': instance.$type,
    };
