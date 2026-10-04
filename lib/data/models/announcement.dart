// Freezed forwards parameter annotations to generated fields.
// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flixquest/models/in_app_message_payload.dart';

part 'announcement.freezed.dart';
part 'announcement.g.dart';

String _announcementId(Object? value) {
  final id = int.tryParse('$value');
  if (id == null || id <= 0) {
    throw const FormatException('Invalid announcement id');
  }
  return '$id';
}

@freezed
class Announcement with _$Announcement {
  const Announcement._();
  const factory Announcement({
    @JsonKey(fromJson: _announcementId) required String id,
    required String title,
    @Default('') String body,
    @JsonKey(name: 'image_url') String? imageUrl,
    @JsonKey(name: 'action_url') String? actionUrl,
    @JsonKey(name: 'button_text') String? buttonText,
    @JsonKey(name: 'display_type') @Default('modal') String displayType,
    @JsonKey(name: 'starts_at') DateTime? startsAt,
    @JsonKey(name: 'ends_at') DateTime? endsAt,
  }) = _Announcement;
  factory Announcement.fromJson(Map<String, dynamic> json) =>
      _$AnnouncementFromJson({
        ...json,
        'body': json['body'] ?? '',
        'image_url': json['image_url'] ?? json['imageUrl'],
        'action_url': json['action_url'] ?? json['actionUrl'],
        'button_text': json['button_text'] ?? json['buttonText'],
        'display_type': json['display_type'] ?? json['displayType'] ?? 'modal',
      });
  bool isActive(DateTime now) =>
      (startsAt == null || !now.isBefore(startsAt!)) &&
      (endsAt == null || !now.isAfter(endsAt!));
  InAppMessagePayload toPayload() => InAppMessagePayload(
        id: id,
        title: title,
        body: body,
        imageUrl: imageUrl,
        actionUrl: actionUrl,
        buttonText: buttonText,
        displayType: displayType.toLowerCase(),
        startsAt: startsAt,
        endsAt: endsAt,
      );
}
