// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'announcement.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AnnouncementImpl _$$AnnouncementImplFromJson(Map<String, dynamic> json) =>
    _$AnnouncementImpl(
      id: _announcementId(json['id']),
      title: json['title'] as String,
      body: json['body'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      actionUrl: json['action_url'] as String?,
      buttonText: json['button_text'] as String?,
      displayType: json['display_type'] as String? ?? 'modal',
      startsAt: json['starts_at'] == null
          ? null
          : DateTime.parse(json['starts_at'] as String),
      endsAt: json['ends_at'] == null
          ? null
          : DateTime.parse(json['ends_at'] as String),
    );

Map<String, dynamic> _$$AnnouncementImplToJson(_$AnnouncementImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'body': instance.body,
      'image_url': instance.imageUrl,
      'action_url': instance.actionUrl,
      'button_text': instance.buttonText,
      'display_type': instance.displayType,
      'starts_at': instance.startsAt?.toIso8601String(),
      'ends_at': instance.endsAt?.toIso8601String(),
    };
