import 'package:freezed_annotation/freezed_annotation.dart';
import '../../models/banner_ad.dart';

part 'banner_ad_dto.freezed.dart';
part 'banner_ad_dto.g.dart';

@freezed
class BannerAdDto with _$BannerAdDto {
  const BannerAdDto._();
  const factory BannerAdDto({
    required String id,
    required String key,
    required String name,
    required String imageUrl,
    required String targetUrl,
    @Default('') String altText,
    @Default('rectangle') String shape,
    @Default(2.2) double aspectRatio,
    double? width,
    double? height,
    @Default([]) List<String> placements,
  }) = _BannerAdDto;

  factory BannerAdDto.fromJson(Map<String, dynamic> json) =>
      _$BannerAdDtoFromJson({
        ...json,
        'id': json['id']?.toString(),
        'altText': json['altText'] ?? '',
        'aspectRatio': _positive(json['aspectRatio']) ?? 2.2,
        'width': _positive(json['width']),
        'height': _positive(json['height'])
      });

  static double? _positive(Object? value) =>
      value is num && value.isFinite && value > 0 ? value.toDouble() : null;

  BannerAd toModel() => BannerAd(
      id: id,
      key: key,
      name: name,
      imageUrl: imageUrl,
      targetUrl: targetUrl,
      altText: altText,
      shape: shape,
      aspectRatio: aspectRatio,
      placements: placements,
      width: width,
      height: height);
}
