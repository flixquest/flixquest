// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';
part 'auth_requests.freezed.dart';
part 'auth_requests.g.dart';

@Freezed(toStringOverride: false)
class LoginRequest with _$LoginRequest {
  const factory LoginRequest(
      {required String email, required String password}) = _LoginRequest;
  factory LoginRequest.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestFromJson(json);
}

@Freezed(toStringOverride: false)
class RegisterRequest with _$RegisterRequest {
  const factory RegisterRequest(
      {required String name,
      required String email,
      required String username,
      required String password,
      @JsonKey(name: 'profile_id') @Default(0) int profileId,
      @JsonKey(name: 'photo_url') String? photoUrl}) = _RegisterRequest;
  factory RegisterRequest.fromJson(Map<String, dynamic> json) =>
      _$RegisterRequestFromJson(json);
}

@freezed
class UpdateProfileRequest with _$UpdateProfileRequest {
  @JsonSerializable(includeIfNull: false)
  const factory UpdateProfileRequest(
      {String? name,
      String? username,
      @JsonKey(name: 'profile_id') int? profileId,
      @JsonKey(name: 'photo_url') String? photoUrl}) = _UpdateProfileRequest;
  factory UpdateProfileRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateProfileRequestFromJson(json);
}

@Freezed(toStringOverride: false)
class ChangePasswordRequest with _$ChangePasswordRequest {
  const factory ChangePasswordRequest(
      {@JsonKey(name: 'current_password') required String currentPassword,
      required String password}) = _ChangePasswordRequest;
  factory ChangePasswordRequest.fromJson(Map<String, dynamic> json) =>
      _$ChangePasswordRequestFromJson(json);
}

@Freezed(toStringOverride: false)
class ChangeEmailRequest with _$ChangeEmailRequest {
  const factory ChangeEmailRequest(
      {@JsonKey(name: 'current_password') required String currentPassword,
      required String email}) = _ChangeEmailRequest;
  factory ChangeEmailRequest.fromJson(Map<String, dynamic> json) =>
      _$ChangeEmailRequestFromJson(json);
}
