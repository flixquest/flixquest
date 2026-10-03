// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$SessionState {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() initializing,
    required TResult Function(bool browsing) guest,
    required TResult Function(AppUser user) authenticated,
    required TResult Function() expired,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? initializing,
    TResult? Function(bool browsing)? guest,
    TResult? Function(AppUser user)? authenticated,
    TResult? Function()? expired,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? initializing,
    TResult Function(bool browsing)? guest,
    TResult Function(AppUser user)? authenticated,
    TResult Function()? expired,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(InitializingSession value) initializing,
    required TResult Function(GuestSession value) guest,
    required TResult Function(AuthenticatedSession value) authenticated,
    required TResult Function(ExpiredSession value) expired,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(InitializingSession value)? initializing,
    TResult? Function(GuestSession value)? guest,
    TResult? Function(AuthenticatedSession value)? authenticated,
    TResult? Function(ExpiredSession value)? expired,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(InitializingSession value)? initializing,
    TResult Function(GuestSession value)? guest,
    TResult Function(AuthenticatedSession value)? authenticated,
    TResult Function(ExpiredSession value)? expired,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SessionStateCopyWith<$Res> {
  factory $SessionStateCopyWith(
          SessionState value, $Res Function(SessionState) then) =
      _$SessionStateCopyWithImpl<$Res, SessionState>;
}

/// @nodoc
class _$SessionStateCopyWithImpl<$Res, $Val extends SessionState>
    implements $SessionStateCopyWith<$Res> {
  _$SessionStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SessionState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$InitializingSessionImplCopyWith<$Res> {
  factory _$$InitializingSessionImplCopyWith(_$InitializingSessionImpl value,
          $Res Function(_$InitializingSessionImpl) then) =
      __$$InitializingSessionImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$InitializingSessionImplCopyWithImpl<$Res>
    extends _$SessionStateCopyWithImpl<$Res, _$InitializingSessionImpl>
    implements _$$InitializingSessionImplCopyWith<$Res> {
  __$$InitializingSessionImplCopyWithImpl(_$InitializingSessionImpl _value,
      $Res Function(_$InitializingSessionImpl) _then)
      : super(_value, _then);

  /// Create a copy of SessionState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$InitializingSessionImpl implements InitializingSession {
  const _$InitializingSessionImpl();

  @override
  String toString() {
    return 'SessionState.initializing()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InitializingSessionImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() initializing,
    required TResult Function(bool browsing) guest,
    required TResult Function(AppUser user) authenticated,
    required TResult Function() expired,
  }) {
    return initializing();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? initializing,
    TResult? Function(bool browsing)? guest,
    TResult? Function(AppUser user)? authenticated,
    TResult? Function()? expired,
  }) {
    return initializing?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? initializing,
    TResult Function(bool browsing)? guest,
    TResult Function(AppUser user)? authenticated,
    TResult Function()? expired,
    required TResult orElse(),
  }) {
    if (initializing != null) {
      return initializing();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(InitializingSession value) initializing,
    required TResult Function(GuestSession value) guest,
    required TResult Function(AuthenticatedSession value) authenticated,
    required TResult Function(ExpiredSession value) expired,
  }) {
    return initializing(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(InitializingSession value)? initializing,
    TResult? Function(GuestSession value)? guest,
    TResult? Function(AuthenticatedSession value)? authenticated,
    TResult? Function(ExpiredSession value)? expired,
  }) {
    return initializing?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(InitializingSession value)? initializing,
    TResult Function(GuestSession value)? guest,
    TResult Function(AuthenticatedSession value)? authenticated,
    TResult Function(ExpiredSession value)? expired,
    required TResult orElse(),
  }) {
    if (initializing != null) {
      return initializing(this);
    }
    return orElse();
  }
}

abstract class InitializingSession implements SessionState {
  const factory InitializingSession() = _$InitializingSessionImpl;
}

/// @nodoc
abstract class _$$GuestSessionImplCopyWith<$Res> {
  factory _$$GuestSessionImplCopyWith(
          _$GuestSessionImpl value, $Res Function(_$GuestSessionImpl) then) =
      __$$GuestSessionImplCopyWithImpl<$Res>;
  @useResult
  $Res call({bool browsing});
}

/// @nodoc
class __$$GuestSessionImplCopyWithImpl<$Res>
    extends _$SessionStateCopyWithImpl<$Res, _$GuestSessionImpl>
    implements _$$GuestSessionImplCopyWith<$Res> {
  __$$GuestSessionImplCopyWithImpl(
      _$GuestSessionImpl _value, $Res Function(_$GuestSessionImpl) _then)
      : super(_value, _then);

  /// Create a copy of SessionState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? browsing = null,
  }) {
    return _then(_$GuestSessionImpl(
      browsing: null == browsing
          ? _value.browsing
          : browsing // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$GuestSessionImpl implements GuestSession {
  const _$GuestSessionImpl({this.browsing = false});

  @override
  @JsonKey()
  final bool browsing;

  @override
  String toString() {
    return 'SessionState.guest(browsing: $browsing)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GuestSessionImpl &&
            (identical(other.browsing, browsing) ||
                other.browsing == browsing));
  }

  @override
  int get hashCode => Object.hash(runtimeType, browsing);

  /// Create a copy of SessionState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GuestSessionImplCopyWith<_$GuestSessionImpl> get copyWith =>
      __$$GuestSessionImplCopyWithImpl<_$GuestSessionImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() initializing,
    required TResult Function(bool browsing) guest,
    required TResult Function(AppUser user) authenticated,
    required TResult Function() expired,
  }) {
    return guest(browsing);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? initializing,
    TResult? Function(bool browsing)? guest,
    TResult? Function(AppUser user)? authenticated,
    TResult? Function()? expired,
  }) {
    return guest?.call(browsing);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? initializing,
    TResult Function(bool browsing)? guest,
    TResult Function(AppUser user)? authenticated,
    TResult Function()? expired,
    required TResult orElse(),
  }) {
    if (guest != null) {
      return guest(browsing);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(InitializingSession value) initializing,
    required TResult Function(GuestSession value) guest,
    required TResult Function(AuthenticatedSession value) authenticated,
    required TResult Function(ExpiredSession value) expired,
  }) {
    return guest(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(InitializingSession value)? initializing,
    TResult? Function(GuestSession value)? guest,
    TResult? Function(AuthenticatedSession value)? authenticated,
    TResult? Function(ExpiredSession value)? expired,
  }) {
    return guest?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(InitializingSession value)? initializing,
    TResult Function(GuestSession value)? guest,
    TResult Function(AuthenticatedSession value)? authenticated,
    TResult Function(ExpiredSession value)? expired,
    required TResult orElse(),
  }) {
    if (guest != null) {
      return guest(this);
    }
    return orElse();
  }
}

abstract class GuestSession implements SessionState {
  const factory GuestSession({final bool browsing}) = _$GuestSessionImpl;

  bool get browsing;

  /// Create a copy of SessionState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GuestSessionImplCopyWith<_$GuestSessionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$AuthenticatedSessionImplCopyWith<$Res> {
  factory _$$AuthenticatedSessionImplCopyWith(_$AuthenticatedSessionImpl value,
          $Res Function(_$AuthenticatedSessionImpl) then) =
      __$$AuthenticatedSessionImplCopyWithImpl<$Res>;
  @useResult
  $Res call({AppUser user});

  $AppUserCopyWith<$Res> get user;
}

/// @nodoc
class __$$AuthenticatedSessionImplCopyWithImpl<$Res>
    extends _$SessionStateCopyWithImpl<$Res, _$AuthenticatedSessionImpl>
    implements _$$AuthenticatedSessionImplCopyWith<$Res> {
  __$$AuthenticatedSessionImplCopyWithImpl(_$AuthenticatedSessionImpl _value,
      $Res Function(_$AuthenticatedSessionImpl) _then)
      : super(_value, _then);

  /// Create a copy of SessionState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? user = null,
  }) {
    return _then(_$AuthenticatedSessionImpl(
      null == user
          ? _value.user
          : user // ignore: cast_nullable_to_non_nullable
              as AppUser,
    ));
  }

  /// Create a copy of SessionState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AppUserCopyWith<$Res> get user {
    return $AppUserCopyWith<$Res>(_value.user, (value) {
      return _then(_value.copyWith(user: value));
    });
  }
}

/// @nodoc

class _$AuthenticatedSessionImpl implements AuthenticatedSession {
  const _$AuthenticatedSessionImpl(this.user);

  @override
  final AppUser user;

  @override
  String toString() {
    return 'SessionState.authenticated(user: $user)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AuthenticatedSessionImpl &&
            (identical(other.user, user) || other.user == user));
  }

  @override
  int get hashCode => Object.hash(runtimeType, user);

  /// Create a copy of SessionState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AuthenticatedSessionImplCopyWith<_$AuthenticatedSessionImpl>
      get copyWith =>
          __$$AuthenticatedSessionImplCopyWithImpl<_$AuthenticatedSessionImpl>(
              this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() initializing,
    required TResult Function(bool browsing) guest,
    required TResult Function(AppUser user) authenticated,
    required TResult Function() expired,
  }) {
    return authenticated(user);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? initializing,
    TResult? Function(bool browsing)? guest,
    TResult? Function(AppUser user)? authenticated,
    TResult? Function()? expired,
  }) {
    return authenticated?.call(user);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? initializing,
    TResult Function(bool browsing)? guest,
    TResult Function(AppUser user)? authenticated,
    TResult Function()? expired,
    required TResult orElse(),
  }) {
    if (authenticated != null) {
      return authenticated(user);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(InitializingSession value) initializing,
    required TResult Function(GuestSession value) guest,
    required TResult Function(AuthenticatedSession value) authenticated,
    required TResult Function(ExpiredSession value) expired,
  }) {
    return authenticated(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(InitializingSession value)? initializing,
    TResult? Function(GuestSession value)? guest,
    TResult? Function(AuthenticatedSession value)? authenticated,
    TResult? Function(ExpiredSession value)? expired,
  }) {
    return authenticated?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(InitializingSession value)? initializing,
    TResult Function(GuestSession value)? guest,
    TResult Function(AuthenticatedSession value)? authenticated,
    TResult Function(ExpiredSession value)? expired,
    required TResult orElse(),
  }) {
    if (authenticated != null) {
      return authenticated(this);
    }
    return orElse();
  }
}

abstract class AuthenticatedSession implements SessionState {
  const factory AuthenticatedSession(final AppUser user) =
      _$AuthenticatedSessionImpl;

  AppUser get user;

  /// Create a copy of SessionState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AuthenticatedSessionImplCopyWith<_$AuthenticatedSessionImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ExpiredSessionImplCopyWith<$Res> {
  factory _$$ExpiredSessionImplCopyWith(_$ExpiredSessionImpl value,
          $Res Function(_$ExpiredSessionImpl) then) =
      __$$ExpiredSessionImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$ExpiredSessionImplCopyWithImpl<$Res>
    extends _$SessionStateCopyWithImpl<$Res, _$ExpiredSessionImpl>
    implements _$$ExpiredSessionImplCopyWith<$Res> {
  __$$ExpiredSessionImplCopyWithImpl(
      _$ExpiredSessionImpl _value, $Res Function(_$ExpiredSessionImpl) _then)
      : super(_value, _then);

  /// Create a copy of SessionState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$ExpiredSessionImpl implements ExpiredSession {
  const _$ExpiredSessionImpl();

  @override
  String toString() {
    return 'SessionState.expired()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$ExpiredSessionImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() initializing,
    required TResult Function(bool browsing) guest,
    required TResult Function(AppUser user) authenticated,
    required TResult Function() expired,
  }) {
    return expired();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? initializing,
    TResult? Function(bool browsing)? guest,
    TResult? Function(AppUser user)? authenticated,
    TResult? Function()? expired,
  }) {
    return expired?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? initializing,
    TResult Function(bool browsing)? guest,
    TResult Function(AppUser user)? authenticated,
    TResult Function()? expired,
    required TResult orElse(),
  }) {
    if (expired != null) {
      return expired();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(InitializingSession value) initializing,
    required TResult Function(GuestSession value) guest,
    required TResult Function(AuthenticatedSession value) authenticated,
    required TResult Function(ExpiredSession value) expired,
  }) {
    return expired(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(InitializingSession value)? initializing,
    TResult? Function(GuestSession value)? guest,
    TResult? Function(AuthenticatedSession value)? authenticated,
    TResult? Function(ExpiredSession value)? expired,
  }) {
    return expired?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(InitializingSession value)? initializing,
    TResult Function(GuestSession value)? guest,
    TResult Function(AuthenticatedSession value)? authenticated,
    TResult Function(ExpiredSession value)? expired,
    required TResult orElse(),
  }) {
    if (expired != null) {
      return expired(this);
    }
    return orElse();
  }
}

abstract class ExpiredSession implements SessionState {
  const factory ExpiredSession() = _$ExpiredSessionImpl;
}
