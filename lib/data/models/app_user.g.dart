// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AppUserImpl _$$AppUserImplFromJson(Map<String, dynamic> json) =>
    _$AppUserImpl(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      joinedAt: DateTime.parse(json['joinedAt'] as String),
      profileId: (json['profileId'] as num?)?.toInt() ?? 0,
      photoUrl: json['photoUrl'] as String?,
      provider: json['provider'] as String? ?? 'email',
      isVerified: json['isVerified'] as bool? ?? false,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$AppUserImplToJson(_$AppUserImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'email': instance.email,
      'username': instance.username,
      'joinedAt': instance.joinedAt.toIso8601String(),
      'profileId': instance.profileId,
      'photoUrl': instance.photoUrl,
      'provider': instance.provider,
      'isVerified': instance.isVerified,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
