// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'banner_ad_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BannerAdDtoImpl _$$BannerAdDtoImplFromJson(Map<String, dynamic> json) =>
    _$BannerAdDtoImpl(
      id: json['id'] as String,
      key: json['key'] as String,
      name: json['name'] as String,
      imageUrl: json['imageUrl'] as String,
      targetUrl: json['targetUrl'] as String,
      altText: json['altText'] as String? ?? '',
      shape: json['shape'] as String? ?? 'rectangle',
      aspectRatio: (json['aspectRatio'] as num?)?.toDouble() ?? 2.2,
      width: (json['width'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      placements: (json['placements'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$BannerAdDtoImplToJson(_$BannerAdDtoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'key': instance.key,
      'name': instance.name,
      'imageUrl': instance.imageUrl,
      'targetUrl': instance.targetUrl,
      'altText': instance.altText,
      'shape': instance.shape,
      'aspectRatio': instance.aspectRatio,
      'width': instance.width,
      'height': instance.height,
      'placements': instance.placements,
    };
