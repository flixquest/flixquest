import 'package:freezed_annotation/freezed_annotation.dart';
import 'app_user.dart';
part 'auth_session.freezed.dart';
part 'auth_session.g.dart';

@Freezed(toStringOverride: false)
class AuthSession with _$AuthSession {
  const AuthSession._();
  const factory AuthSession({required String token, required AppUser user}) =
      _AuthSession;
  factory AuthSession.fromJson(Map<String, dynamic> json) =>
      _$AuthSessionFromJson(json);
  @override
  String toString() => 'AuthSession(user: ${user.id})';
}
