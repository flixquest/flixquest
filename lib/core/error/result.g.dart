// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$OkImpl<T> _$$OkImplFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) =>
    _$OkImpl<T>(
      fromJsonT(json['value']),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$OkImplToJson<T>(
  _$OkImpl<T> instance,
  Object? Function(T value) toJsonT,
) =>
    <String, dynamic>{
      'value': toJsonT(instance.value),
      'runtimeType': instance.$type,
    };

_$ErrImpl<T> _$$ErrImplFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) =>
    _$ErrImpl<T>(
      Failure.fromJson(json['failure'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$ErrImplToJson<T>(
  _$ErrImpl<T> instance,
  Object? Function(T value) toJsonT,
) =>
    <String, dynamic>{
      'failure': instance.failure.toJson(),
      'runtimeType': instance.$type,
    };
