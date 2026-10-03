import 'package:freezed_annotation/freezed_annotation.dart';
import '../../data/models/app_user.dart';
part 'session_state.freezed.dart';

@freezed
sealed class SessionState with _$SessionState {
  const factory SessionState.initializing() = InitializingSession;
  const factory SessionState.guest({@Default(false) bool browsing}) =
      GuestSession;
  const factory SessionState.authenticated(AppUser user) = AuthenticatedSession;
  const factory SessionState.expired() = ExpiredSession;
}
