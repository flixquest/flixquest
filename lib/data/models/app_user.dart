import 'package:flixquest/core/json/json_reader.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

@freezed
class AppUser with _$AppUser {
  const factory AppUser({
    required int id,
    required String name,
    required String email,
    required String username,
    required DateTime joinedAt,
    @Default(0) int profileId,
    String? photoUrl,
    @Default('email') String provider,
    @Default(false) bool isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(_normalize(json));

  static Map<String, dynamic> _normalize(Map<String, dynamic> json) {
    final reader = JsonReader(json);
    final id = JsonReader.asInt(reader.firstOf(['id']));
    if (id == null || id <= 0) {
      throw const FormatException(
          'Laravel user id must be a positive integer.');
    }
    return {
      ...json,
      'id': id,
      'name': reader.firstOf(['name', 'fullName', 'full_name']),
      'profileId':
          JsonReader.asInt(reader.firstOf(['profileId', 'profile_id'])) ?? 0,
      'photoUrl': reader.firstOf(['photoUrl', 'photo_url']),
      'isVerified': JsonReader.asBool(
            reader.firstOf(['isVerified', 'verified', 'is_verified']),
          ) ??
          false,
      'joinedAt':
          reader.firstOf(['joinedAt', 'joined_at', 'createdAt', 'created_at']),
      'createdAt': reader.firstOf(['createdAt', 'created_at']),
      'updatedAt': reader.firstOf(['updatedAt', 'updated_at']),
    };
  }
}
