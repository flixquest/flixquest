// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_requests.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$LoginRequestImpl _$$LoginRequestImplFromJson(Map<String, dynamic> json) =>
    _$LoginRequestImpl(
      email: json['email'] as String,
      password: json['password'] as String,
    );

Map<String, dynamic> _$$LoginRequestImplToJson(_$LoginRequestImpl instance) =>
    <String, dynamic>{
      'email': instance.email,
      'password': instance.password,
    };

_$RegisterRequestImpl _$$RegisterRequestImplFromJson(
        Map<String, dynamic> json) =>
    _$RegisterRequestImpl(
      name: json['name'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      profileId: (json['profile_id'] as num?)?.toInt() ?? 0,
      photoUrl: json['photo_url'] as String?,
    );

Map<String, dynamic> _$$RegisterRequestImplToJson(
        _$RegisterRequestImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'email': instance.email,
      'username': instance.username,
      'password': instance.password,
      'profile_id': instance.profileId,
      'photo_url': instance.photoUrl,
    };

_$UpdateProfileRequestImpl _$$UpdateProfileRequestImplFromJson(
        Map<String, dynamic> json) =>
    _$UpdateProfileRequestImpl(
      name: json['name'] as String?,
      username: json['username'] as String?,
      profileId: (json['profile_id'] as num?)?.toInt(),
      photoUrl: json['photo_url'] as String?,
    );

Map<String, dynamic> _$$UpdateProfileRequestImplToJson(
        _$UpdateProfileRequestImpl instance) =>
    <String, dynamic>{
      if (instance.name case final value?) 'name': value,
      if (instance.username case final value?) 'username': value,
      if (instance.profileId case final value?) 'profile_id': value,
      if (instance.photoUrl case final value?) 'photo_url': value,
    };

_$ChangePasswordRequestImpl _$$ChangePasswordRequestImplFromJson(
        Map<String, dynamic> json) =>
    _$ChangePasswordRequestImpl(
      currentPassword: json['current_password'] as String,
      password: json['password'] as String,
    );

Map<String, dynamic> _$$ChangePasswordRequestImplToJson(
        _$ChangePasswordRequestImpl instance) =>
    <String, dynamic>{
      'current_password': instance.currentPassword,
      'password': instance.password,
    };

_$ChangeEmailRequestImpl _$$ChangeEmailRequestImplFromJson(
        Map<String, dynamic> json) =>
    _$ChangeEmailRequestImpl(
      currentPassword: json['current_password'] as String,
      email: json['email'] as String,
    );

Map<String, dynamic> _$$ChangeEmailRequestImplToJson(
        _$ChangeEmailRequestImpl instance) =>
    <String, dynamic>{
      'current_password': instance.currentPassword,
      'email': instance.email,
    };
