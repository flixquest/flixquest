// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'failure.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Failure _$FailureFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'network':
      return NetworkFailure.fromJson(json);
    case 'timeout':
      return TimeoutFailure.fromJson(json);
    case 'unauthorized':
      return UnauthorizedFailure.fromJson(json);
    case 'forbidden':
      return ForbiddenFailure.fromJson(json);
    case 'notFound':
      return NotFoundFailure.fromJson(json);
    case 'conflict':
      return ConflictFailure.fromJson(json);
    case 'validation':
      return ValidationFailure.fromJson(json);
    case 'rateLimited':
      return RateLimitedFailure.fromJson(json);
    case 'server':
      return ServerFailure.fromJson(json);
    case 'clockSkew':
      return ClockSkewFailure.fromJson(json);
    case 'cache':
      return CacheFailure.fromJson(json);
    case 'unknown':
      return UnknownFailure.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'runtimeType', 'Failure',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$Failure {
  String? get message => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String? message) network,
    required TResult Function(String? message) timeout,
    required TResult Function(String? message) unauthorized,
    required TResult Function(String? message) forbidden,
    required TResult Function(String? message) notFound,
    required TResult Function(String? message) conflict,
    required TResult Function(Map<String, List<String>> fields, String? message)
        validation,
    required TResult Function(int? retryAfter, String? message) rateLimited,
    required TResult Function(int status, String? message) server,
    required TResult Function(int serverTimeUtc, int driftMs, String? message)
        clockSkew,
    required TResult Function(String? message) cache,
    required TResult Function(String? message) unknown,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String? message)? network,
    TResult? Function(String? message)? timeout,
    TResult? Function(String? message)? unauthorized,
    TResult? Function(String? message)? forbidden,
    TResult? Function(String? message)? notFound,
    TResult? Function(String? message)? conflict,
    TResult? Function(Map<String, List<String>> fields, String? message)?
        validation,
    TResult? Function(int? retryAfter, String? message)? rateLimited,
    TResult? Function(int status, String? message)? server,
    TResult? Function(int serverTimeUtc, int driftMs, String? message)?
        clockSkew,
    TResult? Function(String? message)? cache,
    TResult? Function(String? message)? unknown,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String? message)? network,
    TResult Function(String? message)? timeout,
    TResult Function(String? message)? unauthorized,
    TResult Function(String? message)? forbidden,
    TResult Function(String? message)? notFound,
    TResult Function(String? message)? conflict,
    TResult Function(Map<String, List<String>> fields, String? message)?
        validation,
    TResult Function(int? retryAfter, String? message)? rateLimited,
    TResult Function(int status, String? message)? server,
    TResult Function(int serverTimeUtc, int driftMs, String? message)?
        clockSkew,
    TResult Function(String? message)? cache,
    TResult Function(String? message)? unknown,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NetworkFailure value) network,
    required TResult Function(TimeoutFailure value) timeout,
    required TResult Function(UnauthorizedFailure value) unauthorized,
    required TResult Function(ForbiddenFailure value) forbidden,
    required TResult Function(NotFoundFailure value) notFound,
    required TResult Function(ConflictFailure value) conflict,
    required TResult Function(ValidationFailure value) validation,
    required TResult Function(RateLimitedFailure value) rateLimited,
    required TResult Function(ServerFailure value) server,
    required TResult Function(ClockSkewFailure value) clockSkew,
    required TResult Function(CacheFailure value) cache,
    required TResult Function(UnknownFailure value) unknown,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NetworkFailure value)? network,
    TResult? Function(TimeoutFailure value)? timeout,
    TResult? Function(UnauthorizedFailure value)? unauthorized,
    TResult? Function(ForbiddenFailure value)? forbidden,
    TResult? Function(NotFoundFailure value)? notFound,
    TResult? Function(ConflictFailure value)? conflict,
    TResult? Function(ValidationFailure value)? validation,
    TResult? Function(RateLimitedFailure value)? rateLimited,
    TResult? Function(ServerFailure value)? server,
    TResult? Function(ClockSkewFailure value)? clockSkew,
    TResult? Function(CacheFailure value)? cache,
    TResult? Function(UnknownFailure value)? unknown,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NetworkFailure value)? network,
    TResult Function(TimeoutFailure value)? timeout,
    TResult Function(UnauthorizedFailure value)? unauthorized,
    TResult Function(ForbiddenFailure value)? forbidden,
    TResult Function(NotFoundFailure value)? notFound,
    TResult Function(ConflictFailure value)? conflict,
    TResult Function(ValidationFailure value)? validation,
    TResult Function(RateLimitedFailure value)? rateLimited,
    TResult Function(ServerFailure value)? server,
    TResult Function(ClockSkewFailure value)? clockSkew,
    TResult Function(CacheFailure value)? cache,
    TResult Function(UnknownFailure value)? unknown,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  /// Serializes this Failure to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FailureCopyWith<Failure> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FailureCopyWith<$Res> {
  factory $FailureCopyWith(Failure value, $Res Function(Failure) then) =
      _$FailureCopyWithImpl<$Res, Failure>;
  @useResult
  $Res call({String? message});
}

/// @nodoc
class _$FailureCopyWithImpl<$Res, $Val extends Failure>
    implements $FailureCopyWith<$Res> {
  _$FailureCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = freezed,
  }) {
    return _then(_value.copyWith(
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$NetworkFailureImplCopyWith<$Res>
    implements $FailureCopyWith<$Res> {
  factory _$$NetworkFailureImplCopyWith(_$NetworkFailureImpl value,
          $Res Function(_$NetworkFailureImpl) then) =
      __$$NetworkFailureImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String? message});
}

/// @nodoc
class __$$NetworkFailureImplCopyWithImpl<$Res>
    extends _$FailureCopyWithImpl<$Res, _$NetworkFailureImpl>
    implements _$$NetworkFailureImplCopyWith<$Res> {
  __$$NetworkFailureImplCopyWithImpl(
      _$NetworkFailureImpl _value, $Res Function(_$NetworkFailureImpl) _then)
      : super(_value, _then);

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = freezed,
  }) {
    return _then(_$NetworkFailureImpl(
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$NetworkFailureImpl implements NetworkFailure {
  const _$NetworkFailureImpl({this.message, final String? $type})
      : $type = $type ?? 'network';

  factory _$NetworkFailureImpl.fromJson(Map<String, dynamic> json) =>
      _$$NetworkFailureImplFromJson(json);

  @override
  final String? message;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'Failure.network(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NetworkFailureImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NetworkFailureImplCopyWith<_$NetworkFailureImpl> get copyWith =>
      __$$NetworkFailureImplCopyWithImpl<_$NetworkFailureImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String? message) network,
    required TResult Function(String? message) timeout,
    required TResult Function(String? message) unauthorized,
    required TResult Function(String? message) forbidden,
    required TResult Function(String? message) notFound,
    required TResult Function(String? message) conflict,
    required TResult Function(Map<String, List<String>> fields, String? message)
        validation,
    required TResult Function(int? retryAfter, String? message) rateLimited,
    required TResult Function(int status, String? message) server,
    required TResult Function(int serverTimeUtc, int driftMs, String? message)
        clockSkew,
    required TResult Function(String? message) cache,
    required TResult Function(String? message) unknown,
  }) {
    return network(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String? message)? network,
    TResult? Function(String? message)? timeout,
    TResult? Function(String? message)? unauthorized,
    TResult? Function(String? message)? forbidden,
    TResult? Function(String? message)? notFound,
    TResult? Function(String? message)? conflict,
    TResult? Function(Map<String, List<String>> fields, String? message)?
        validation,
    TResult? Function(int? retryAfter, String? message)? rateLimited,
    TResult? Function(int status, String? message)? server,
    TResult? Function(int serverTimeUtc, int driftMs, String? message)?
        clockSkew,
    TResult? Function(String? message)? cache,
    TResult? Function(String? message)? unknown,
  }) {
    return network?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String? message)? network,
    TResult Function(String? message)? timeout,
    TResult Function(String? message)? unauthorized,
    TResult Function(String? message)? forbidden,
    TResult Function(String? message)? notFound,
    TResult Function(String? message)? conflict,
    TResult Function(Map<String, List<String>> fields, String? message)?
        validation,
    TResult Function(int? retryAfter, String? message)? rateLimited,
    TResult Function(int status, String? message)? server,
    TResult Function(int serverTimeUtc, int driftMs, String? message)?
        clockSkew,
    TResult Function(String? message)? cache,
    TResult Function(String? message)? unknown,
    required TResult orElse(),
  }) {
    if (network != null) {
      return network(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NetworkFailure value) network,
    required TResult Function(TimeoutFailure value) timeout,
    required TResult Function(UnauthorizedFailure value) unauthorized,
    required TResult Function(ForbiddenFailure value) forbidden,
    required TResult Function(NotFoundFailure value) notFound,
    required TResult Function(ConflictFailure value) conflict,
    required TResult Function(ValidationFailure value) validation,
    required TResult Function(RateLimitedFailure value) rateLimited,
    required TResult Function(ServerFailure value) server,
    required TResult Function(ClockSkewFailure value) clockSkew,
    required TResult Function(CacheFailure value) cache,
    required TResult Function(UnknownFailure value) unknown,
  }) {
    return network(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NetworkFailure value)? network,
    TResult? Function(TimeoutFailure value)? timeout,
    TResult? Function(UnauthorizedFailure value)? unauthorized,
    TResult? Function(ForbiddenFailure value)? forbidden,
    TResult? Function(NotFoundFailure value)? notFound,
    TResult? Function(ConflictFailure value)? conflict,
    TResult? Function(ValidationFailure value)? validation,
    TResult? Function(RateLimitedFailure value)? rateLimited,
    TResult? Function(ServerFailure value)? server,
    TResult? Function(ClockSkewFailure value)? clockSkew,
    TResult? Function(CacheFailure value)? cache,
    TResult? Function(UnknownFailure value)? unknown,
  }) {
    return network?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NetworkFailure value)? network,
    TResult Function(TimeoutFailure value)? timeout,
    TResult Function(UnauthorizedFailure value)? unauthorized,
    TResult Function(ForbiddenFailure value)? forbidden,
    TResult Function(NotFoundFailure value)? notFound,
    TResult Function(ConflictFailure value)? conflict,
    TResult Function(ValidationFailure value)? validation,
    TResult Function(RateLimitedFailure value)? rateLimited,
    TResult Function(ServerFailure value)? server,
    TResult Function(ClockSkewFailure value)? clockSkew,
    TResult Function(CacheFailure value)? cache,
    TResult Function(UnknownFailure value)? unknown,
    required TResult orElse(),
  }) {
    if (network != null) {
      return network(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$NetworkFailureImplToJson(
      this,
    );
  }
}

abstract class NetworkFailure implements Failure {
  const factory NetworkFailure({final String? message}) = _$NetworkFailureImpl;

  factory NetworkFailure.fromJson(Map<String, dynamic> json) =
      _$NetworkFailureImpl.fromJson;

  @override
  String? get message;

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NetworkFailureImplCopyWith<_$NetworkFailureImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$TimeoutFailureImplCopyWith<$Res>
    implements $FailureCopyWith<$Res> {
  factory _$$TimeoutFailureImplCopyWith(_$TimeoutFailureImpl value,
          $Res Function(_$TimeoutFailureImpl) then) =
      __$$TimeoutFailureImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String? message});
}

/// @nodoc
class __$$TimeoutFailureImplCopyWithImpl<$Res>
    extends _$FailureCopyWithImpl<$Res, _$TimeoutFailureImpl>
    implements _$$TimeoutFailureImplCopyWith<$Res> {
  __$$TimeoutFailureImplCopyWithImpl(
      _$TimeoutFailureImpl _value, $Res Function(_$TimeoutFailureImpl) _then)
      : super(_value, _then);

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = freezed,
  }) {
    return _then(_$TimeoutFailureImpl(
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TimeoutFailureImpl implements TimeoutFailure {
  const _$TimeoutFailureImpl({this.message, final String? $type})
      : $type = $type ?? 'timeout';

  factory _$TimeoutFailureImpl.fromJson(Map<String, dynamic> json) =>
      _$$TimeoutFailureImplFromJson(json);

  @override
  final String? message;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'Failure.timeout(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TimeoutFailureImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TimeoutFailureImplCopyWith<_$TimeoutFailureImpl> get copyWith =>
      __$$TimeoutFailureImplCopyWithImpl<_$TimeoutFailureImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String? message) network,
    required TResult Function(String? message) timeout,
    required TResult Function(String? message) unauthorized,
    required TResult Function(String? message) forbidden,
    required TResult Function(String? message) notFound,
    required TResult Function(String? message) conflict,
    required TResult Function(Map<String, List<String>> fields, String? message)
        validation,
    required TResult Function(int? retryAfter, String? message) rateLimited,
    required TResult Function(int status, String? message) server,
    required TResult Function(int serverTimeUtc, int driftMs, String? message)
        clockSkew,
    required TResult Function(String? message) cache,
    required TResult Function(String? message) unknown,
  }) {
    return timeout(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String? message)? network,
    TResult? Function(String? message)? timeout,
    TResult? Function(String? message)? unauthorized,
    TResult? Function(String? message)? forbidden,
    TResult? Function(String? message)? notFound,
    TResult? Function(String? message)? conflict,
    TResult? Function(Map<String, List<String>> fields, String? message)?
        validation,
    TResult? Function(int? retryAfter, String? message)? rateLimited,
    TResult? Function(int status, String? message)? server,
    TResult? Function(int serverTimeUtc, int driftMs, String? message)?
        clockSkew,
    TResult? Function(String? message)? cache,
    TResult? Function(String? message)? unknown,
  }) {
    return timeout?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String? message)? network,
    TResult Function(String? message)? timeout,
    TResult Function(String? message)? unauthorized,
    TResult Function(String? message)? forbidden,
    TResult Function(String? message)? notFound,
    TResult Function(String? message)? conflict,
    TResult Function(Map<String, List<String>> fields, String? message)?
        validation,
    TResult Function(int? retryAfter, String? message)? rateLimited,
    TResult Function(int status, String? message)? server,
    TResult Function(int serverTimeUtc, int driftMs, String? message)?
        clockSkew,
    TResult Function(String? message)? cache,
    TResult Function(String? message)? unknown,
    required TResult orElse(),
  }) {
    if (timeout != null) {
      return timeout(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NetworkFailure value) network,
    required TResult Function(TimeoutFailure value) timeout,
    required TResult Function(UnauthorizedFailure value) unauthorized,
    required TResult Function(ForbiddenFailure value) forbidden,
    required TResult Function(NotFoundFailure value) notFound,
    required TResult Function(ConflictFailure value) conflict,
    required TResult Function(ValidationFailure value) validation,
    required TResult Function(RateLimitedFailure value) rateLimited,
    required TResult Function(ServerFailure value) server,
    required TResult Function(ClockSkewFailure value) clockSkew,
    required TResult Function(CacheFailure value) cache,
    required TResult Function(UnknownFailure value) unknown,
  }) {
    return timeout(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NetworkFailure value)? network,
    TResult? Function(TimeoutFailure value)? timeout,
    TResult? Function(UnauthorizedFailure value)? unauthorized,
    TResult? Function(ForbiddenFailure value)? forbidden,
    TResult? Function(NotFoundFailure value)? notFound,
    TResult? Function(ConflictFailure value)? conflict,
    TResult? Function(ValidationFailure value)? validation,
    TResult? Function(RateLimitedFailure value)? rateLimited,
    TResult? Function(ServerFailure value)? server,
    TResult? Function(ClockSkewFailure value)? clockSkew,
    TResult? Function(CacheFailure value)? cache,
    TResult? Function(UnknownFailure value)? unknown,
  }) {
    return timeout?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NetworkFailure value)? network,
    TResult Function(TimeoutFailure value)? timeout,
    TResult Function(UnauthorizedFailure value)? unauthorized,
    TResult Function(ForbiddenFailure value)? forbidden,
    TResult Function(NotFoundFailure value)? notFound,
    TResult Function(ConflictFailure value)? conflict,
    TResult Function(ValidationFailure value)? validation,
    TResult Function(RateLimitedFailure value)? rateLimited,
    TResult Function(ServerFailure value)? server,
    TResult Function(ClockSkewFailure value)? clockSkew,
    TResult Function(CacheFailure value)? cache,
    TResult Function(UnknownFailure value)? unknown,
    required TResult orElse(),
  }) {
    if (timeout != null) {
      return timeout(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$TimeoutFailureImplToJson(
      this,
    );
  }
}

abstract class TimeoutFailure implements Failure {
  const factory TimeoutFailure({final String? message}) = _$TimeoutFailureImpl;

  factory TimeoutFailure.fromJson(Map<String, dynamic> json) =
      _$TimeoutFailureImpl.fromJson;

  @override
  String? get message;

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TimeoutFailureImplCopyWith<_$TimeoutFailureImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$UnauthorizedFailureImplCopyWith<$Res>
    implements $FailureCopyWith<$Res> {
  factory _$$UnauthorizedFailureImplCopyWith(_$UnauthorizedFailureImpl value,
          $Res Function(_$UnauthorizedFailureImpl) then) =
      __$$UnauthorizedFailureImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String? message});
}

/// @nodoc
class __$$UnauthorizedFailureImplCopyWithImpl<$Res>
    extends _$FailureCopyWithImpl<$Res, _$UnauthorizedFailureImpl>
    implements _$$UnauthorizedFailureImplCopyWith<$Res> {
  __$$UnauthorizedFailureImplCopyWithImpl(_$UnauthorizedFailureImpl _value,
      $Res Function(_$UnauthorizedFailureImpl) _then)
      : super(_value, _then);

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = freezed,
  }) {
    return _then(_$UnauthorizedFailureImpl(
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UnauthorizedFailureImpl implements UnauthorizedFailure {
  const _$UnauthorizedFailureImpl({this.message, final String? $type})
      : $type = $type ?? 'unauthorized';

  factory _$UnauthorizedFailureImpl.fromJson(Map<String, dynamic> json) =>
      _$$UnauthorizedFailureImplFromJson(json);

  @override
  final String? message;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'Failure.unauthorized(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UnauthorizedFailureImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UnauthorizedFailureImplCopyWith<_$UnauthorizedFailureImpl> get copyWith =>
      __$$UnauthorizedFailureImplCopyWithImpl<_$UnauthorizedFailureImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String? message) network,
    required TResult Function(String? message) timeout,
    required TResult Function(String? message) unauthorized,
    required TResult Function(String? message) forbidden,
    required TResult Function(String? message) notFound,
    required TResult Function(String? message) conflict,
    required TResult Function(Map<String, List<String>> fields, String? message)
        validation,
    required TResult Function(int? retryAfter, String? message) rateLimited,
    required TResult Function(int status, String? message) server,
    required TResult Function(int serverTimeUtc, int driftMs, String? message)
        clockSkew,
    required TResult Function(String? message) cache,
    required TResult Function(String? message) unknown,
  }) {
    return unauthorized(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String? message)? network,
    TResult? Function(String? message)? timeout,
    TResult? Function(String? message)? unauthorized,
    TResult? Function(String? message)? forbidden,
    TResult? Function(String? message)? notFound,
    TResult? Function(String? message)? conflict,
    TResult? Function(Map<String, List<String>> fields, String? message)?
        validation,
    TResult? Function(int? retryAfter, String? message)? rateLimited,
    TResult? Function(int status, String? message)? server,
    TResult? Function(int serverTimeUtc, int driftMs, String? message)?
        clockSkew,
    TResult? Function(String? message)? cache,
    TResult? Function(String? message)? unknown,
  }) {
    return unauthorized?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String? message)? network,
    TResult Function(String? message)? timeout,
    TResult Function(String? message)? unauthorized,
    TResult Function(String? message)? forbidden,
    TResult Function(String? message)? notFound,
    TResult Function(String? message)? conflict,
    TResult Function(Map<String, List<String>> fields, String? message)?
        validation,
    TResult Function(int? retryAfter, String? message)? rateLimited,
    TResult Function(int status, String? message)? server,
    TResult Function(int serverTimeUtc, int driftMs, String? message)?
        clockSkew,
    TResult Function(String? message)? cache,
    TResult Function(String? message)? unknown,
    required TResult orElse(),
  }) {
    if (unauthorized != null) {
      return unauthorized(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NetworkFailure value) network,
    required TResult Function(TimeoutFailure value) timeout,
    required TResult Function(UnauthorizedFailure value) unauthorized,
    required TResult Function(ForbiddenFailure value) forbidden,
    required TResult Function(NotFoundFailure value) notFound,
    required TResult Function(ConflictFailure value) conflict,
    required TResult Function(ValidationFailure value) validation,
    required TResult Function(RateLimitedFailure value) rateLimited,
    required TResult Function(ServerFailure value) server,
    required TResult Function(ClockSkewFailure value) clockSkew,
    required TResult Function(CacheFailure value) cache,
    required TResult Function(UnknownFailure value) unknown,
  }) {
    return unauthorized(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NetworkFailure value)? network,
    TResult? Function(TimeoutFailure value)? timeout,
    TResult? Function(UnauthorizedFailure value)? unauthorized,
    TResult? Function(ForbiddenFailure value)? forbidden,
    TResult? Function(NotFoundFailure value)? notFound,
    TResult? Function(ConflictFailure value)? conflict,
    TResult? Function(ValidationFailure value)? validation,
    TResult? Function(RateLimitedFailure value)? rateLimited,
    TResult? Function(ServerFailure value)? server,
    TResult? Function(ClockSkewFailure value)? clockSkew,
    TResult? Function(CacheFailure value)? cache,
    TResult? Function(UnknownFailure value)? unknown,
  }) {
    return unauthorized?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NetworkFailure value)? network,
    TResult Function(TimeoutFailure value)? timeout,
    TResult Function(UnauthorizedFailure value)? unauthorized,
    TResult Function(ForbiddenFailure value)? forbidden,
    TResult Function(NotFoundFailure value)? notFound,
    TResult Function(ConflictFailure value)? conflict,
    TResult Function(ValidationFailure value)? validation,
    TResult Function(RateLimitedFailure value)? rateLimited,
    TResult Function(ServerFailure value)? server,
    TResult Function(ClockSkewFailure value)? clockSkew,
    TResult Function(CacheFailure value)? cache,
    TResult Function(UnknownFailure value)? unknown,
    required TResult orElse(),
  }) {
    if (unauthorized != null) {
      return unauthorized(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$UnauthorizedFailureImplToJson(
      this,
    );
  }
}

abstract class UnauthorizedFailure implements Failure {
  const factory UnauthorizedFailure({final String? message}) =
      _$UnauthorizedFailureImpl;

  factory UnauthorizedFailure.fromJson(Map<String, dynamic> json) =
      _$UnauthorizedFailureImpl.fromJson;

  @override
  String? get message;

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UnauthorizedFailureImplCopyWith<_$UnauthorizedFailureImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ForbiddenFailureImplCopyWith<$Res>
    implements $FailureCopyWith<$Res> {
  factory _$$ForbiddenFailureImplCopyWith(_$ForbiddenFailureImpl value,
          $Res Function(_$ForbiddenFailureImpl) then) =
      __$$ForbiddenFailureImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String? message});
}

/// @nodoc
class __$$ForbiddenFailureImplCopyWithImpl<$Res>
    extends _$FailureCopyWithImpl<$Res, _$ForbiddenFailureImpl>
    implements _$$ForbiddenFailureImplCopyWith<$Res> {
  __$$ForbiddenFailureImplCopyWithImpl(_$ForbiddenFailureImpl _value,
      $Res Function(_$ForbiddenFailureImpl) _then)
      : super(_value, _then);

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = freezed,
  }) {
    return _then(_$ForbiddenFailureImpl(
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ForbiddenFailureImpl implements ForbiddenFailure {
  const _$ForbiddenFailureImpl({this.message, final String? $type})
      : $type = $type ?? 'forbidden';

  factory _$ForbiddenFailureImpl.fromJson(Map<String, dynamic> json) =>
      _$$ForbiddenFailureImplFromJson(json);

  @override
  final String? message;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'Failure.forbidden(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ForbiddenFailureImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ForbiddenFailureImplCopyWith<_$ForbiddenFailureImpl> get copyWith =>
      __$$ForbiddenFailureImplCopyWithImpl<_$ForbiddenFailureImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String? message) network,
    required TResult Function(String? message) timeout,
    required TResult Function(String? message) unauthorized,
    required TResult Function(String? message) forbidden,
    required TResult Function(String? message) notFound,
    required TResult Function(String? message) conflict,
    required TResult Function(Map<String, List<String>> fields, String? message)
        validation,
    required TResult Function(int? retryAfter, String? message) rateLimited,
    required TResult Function(int status, String? message) server,
    required TResult Function(int serverTimeUtc, int driftMs, String? message)
        clockSkew,
    required TResult Function(String? message) cache,
    required TResult Function(String? message) unknown,
  }) {
    return forbidden(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String? message)? network,
    TResult? Function(String? message)? timeout,
    TResult? Function(String? message)? unauthorized,
    TResult? Function(String? message)? forbidden,
    TResult? Function(String? message)? notFound,
    TResult? Function(String? message)? conflict,
    TResult? Function(Map<String, List<String>> fields, String? message)?
        validation,
    TResult? Function(int? retryAfter, String? message)? rateLimited,
    TResult? Function(int status, String? message)? server,
    TResult? Function(int serverTimeUtc, int driftMs, String? message)?
        clockSkew,
    TResult? Function(String? message)? cache,
    TResult? Function(String? message)? unknown,
  }) {
    return forbidden?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String? message)? network,
    TResult Function(String? message)? timeout,
    TResult Function(String? message)? unauthorized,
    TResult Function(String? message)? forbidden,
    TResult Function(String? message)? notFound,
    TResult Function(String? message)? conflict,
    TResult Function(Map<String, List<String>> fields, String? message)?
        validation,
    TResult Function(int? retryAfter, String? message)? rateLimited,
    TResult Function(int status, String? message)? server,
    TResult Function(int serverTimeUtc, int driftMs, String? message)?
        clockSkew,
    TResult Function(String? message)? cache,
    TResult Function(String? message)? unknown,
    required TResult orElse(),
  }) {
    if (forbidden != null) {
      return forbidden(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NetworkFailure value) network,
    required TResult Function(TimeoutFailure value) timeout,
    required TResult Function(UnauthorizedFailure value) unauthorized,
    required TResult Function(ForbiddenFailure value) forbidden,
    required TResult Function(NotFoundFailure value) notFound,
    required TResult Function(ConflictFailure value) conflict,
    required TResult Function(ValidationFailure value) validation,
    required TResult Function(RateLimitedFailure value) rateLimited,
    required TResult Function(ServerFailure value) server,
    required TResult Function(ClockSkewFailure value) clockSkew,
    required TResult Function(CacheFailure value) cache,
    required TResult Function(UnknownFailure value) unknown,
  }) {
    return forbidden(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NetworkFailure value)? network,
    TResult? Function(TimeoutFailure value)? timeout,
    TResult? Function(UnauthorizedFailure value)? unauthorized,
    TResult? Function(ForbiddenFailure value)? forbidden,
    TResult? Function(NotFoundFailure value)? notFound,
    TResult? Function(ConflictFailure value)? conflict,
    TResult? Function(ValidationFailure value)? validation,
    TResult? Function(RateLimitedFailure value)? rateLimited,
    TResult? Function(ServerFailure value)? server,
    TResult? Function(ClockSkewFailure value)? clockSkew,
    TResult? Function(CacheFailure value)? cache,
    TResult? Function(UnknownFailure value)? unknown,
  }) {
    return forbidden?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NetworkFailure value)? network,
    TResult Function(TimeoutFailure value)? timeout,
    TResult Function(UnauthorizedFailure value)? unauthorized,
    TResult Function(ForbiddenFailure value)? forbidden,
    TResult Function(NotFoundFailure value)? notFound,
    TResult Function(ConflictFailure value)? conflict,
    TResult Function(ValidationFailure value)? validation,
    TResult Function(RateLimitedFailure value)? rateLimited,
    TResult Function(ServerFailure value)? server,
    TResult Function(ClockSkewFailure value)? clockSkew,
    TResult Function(CacheFailure value)? cache,
    TResult Function(UnknownFailure value)? unknown,
    required TResult orElse(),
  }) {
    if (forbidden != null) {
      return forbidden(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$ForbiddenFailureImplToJson(
      this,
    );
  }
}

abstract class ForbiddenFailure implements Failure {
  const factory ForbiddenFailure({final String? message}) =
      _$ForbiddenFailureImpl;

  factory ForbiddenFailure.fromJson(Map<String, dynamic> json) =
      _$ForbiddenFailureImpl.fromJson;

  @override
  String? get message;

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ForbiddenFailureImplCopyWith<_$ForbiddenFailureImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$NotFoundFailureImplCopyWith<$Res>
    implements $FailureCopyWith<$Res> {
  factory _$$NotFoundFailureImplCopyWith(_$NotFoundFailureImpl value,
          $Res Function(_$NotFoundFailureImpl) then) =
      __$$NotFoundFailureImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String? message});
}

/// @nodoc
class __$$NotFoundFailureImplCopyWithImpl<$Res>
    extends _$FailureCopyWithImpl<$Res, _$NotFoundFailureImpl>
    implements _$$NotFoundFailureImplCopyWith<$Res> {
  __$$NotFoundFailureImplCopyWithImpl(
      _$NotFoundFailureImpl _value, $Res Function(_$NotFoundFailureImpl) _then)
      : super(_value, _then);

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = freezed,
  }) {
    return _then(_$NotFoundFailureImpl(
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$NotFoundFailureImpl implements NotFoundFailure {
  const _$NotFoundFailureImpl({this.message, final String? $type})
      : $type = $type ?? 'notFound';

  factory _$NotFoundFailureImpl.fromJson(Map<String, dynamic> json) =>
      _$$NotFoundFailureImplFromJson(json);

  @override
  final String? message;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'Failure.notFound(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NotFoundFailureImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NotFoundFailureImplCopyWith<_$NotFoundFailureImpl> get copyWith =>
      __$$NotFoundFailureImplCopyWithImpl<_$NotFoundFailureImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String? message) network,
    required TResult Function(String? message) timeout,
    required TResult Function(String? message) unauthorized,
    required TResult Function(String? message) forbidden,
    required TResult Function(String? message) notFound,
    required TResult Function(String? message) conflict,
    required TResult Function(Map<String, List<String>> fields, String? message)
        validation,
    required TResult Function(int? retryAfter, String? message) rateLimited,
    required TResult Function(int status, String? message) server,
    required TResult Function(int serverTimeUtc, int driftMs, String? message)
        clockSkew,
    required TResult Function(String? message) cache,
    required TResult Function(String? message) unknown,
  }) {
    return notFound(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String? message)? network,
    TResult? Function(String? message)? timeout,
    TResult? Function(String? message)? unauthorized,
    TResult? Function(String? message)? forbidden,
    TResult? Function(String? message)? notFound,
    TResult? Function(String? message)? conflict,
    TResult? Function(Map<String, List<String>> fields, String? message)?
        validation,
    TResult? Function(int? retryAfter, String? message)? rateLimited,
    TResult? Function(int status, String? message)? server,
    TResult? Function(int serverTimeUtc, int driftMs, String? message)?
        clockSkew,
    TResult? Function(String? message)? cache,
    TResult? Function(String? message)? unknown,
  }) {
    return notFound?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String? message)? network,
    TResult Function(String? message)? timeout,
    TResult Function(String? message)? unauthorized,
    TResult Function(String? message)? forbidden,
    TResult Function(String? message)? notFound,
    TResult Function(String? message)? conflict,
    TResult Function(Map<String, List<String>> fields, String? message)?
        validation,
    TResult Function(int? retryAfter, String? message)? rateLimited,
    TResult Function(int status, String? message)? server,
    TResult Function(int serverTimeUtc, int driftMs, String? message)?
        clockSkew,
    TResult Function(String? message)? cache,
    TResult Function(String? message)? unknown,
    required TResult orElse(),
  }) {
    if (notFound != null) {
      return notFound(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NetworkFailure value) network,
    required TResult Function(TimeoutFailure value) timeout,
    required TResult Function(UnauthorizedFailure value) unauthorized,
    required TResult Function(ForbiddenFailure value) forbidden,
    required TResult Function(NotFoundFailure value) notFound,
    required TResult Function(ConflictFailure value) conflict,
    required TResult Function(ValidationFailure value) validation,
    required TResult Function(RateLimitedFailure value) rateLimited,
    required TResult Function(ServerFailure value) server,
    required TResult Function(ClockSkewFailure value) clockSkew,
    required TResult Function(CacheFailure value) cache,
    required TResult Function(UnknownFailure value) unknown,
  }) {
    return notFound(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NetworkFailure value)? network,
    TResult? Function(TimeoutFailure value)? timeout,
    TResult? Function(UnauthorizedFailure value)? unauthorized,
    TResult? Function(ForbiddenFailure value)? forbidden,
    TResult? Function(NotFoundFailure value)? notFound,
    TResult? Function(ConflictFailure value)? conflict,
    TResult? Function(ValidationFailure value)? validation,
    TResult? Function(RateLimitedFailure value)? rateLimited,
    TResult? Function(ServerFailure value)? server,
    TResult? Function(ClockSkewFailure value)? clockSkew,
    TResult? Function(CacheFailure value)? cache,
    TResult? Function(UnknownFailure value)? unknown,
  }) {
    return notFound?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NetworkFailure value)? network,
    TResult Function(TimeoutFailure value)? timeout,
    TResult Function(UnauthorizedFailure value)? unauthorized,
    TResult Function(ForbiddenFailure value)? forbidden,
    TResult Function(NotFoundFailure value)? notFound,
    TResult Function(ConflictFailure value)? conflict,
    TResult Function(ValidationFailure value)? validation,
    TResult Function(RateLimitedFailure value)? rateLimited,
    TResult Function(ServerFailure value)? server,
    TResult Function(ClockSkewFailure value)? clockSkew,
    TResult Function(CacheFailure value)? cache,
    TResult Function(UnknownFailure value)? unknown,
    required TResult orElse(),
  }) {
    if (notFound != null) {
      return notFound(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$NotFoundFailureImplToJson(
      this,
    );
  }
}

abstract class NotFoundFailure implements Failure {
  const factory NotFoundFailure({final String? message}) =
      _$NotFoundFailureImpl;

  factory NotFoundFailure.fromJson(Map<String, dynamic> json) =
      _$NotFoundFailureImpl.fromJson;

  @override
  String? get message;

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NotFoundFailureImplCopyWith<_$NotFoundFailureImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ConflictFailureImplCopyWith<$Res>
    implements $FailureCopyWith<$Res> {
  factory _$$ConflictFailureImplCopyWith(_$ConflictFailureImpl value,
          $Res Function(_$ConflictFailureImpl) then) =
      __$$ConflictFailureImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String? message});
}

/// @nodoc
class __$$ConflictFailureImplCopyWithImpl<$Res>
    extends _$FailureCopyWithImpl<$Res, _$ConflictFailureImpl>
    implements _$$ConflictFailureImplCopyWith<$Res> {
  __$$ConflictFailureImplCopyWithImpl(
      _$ConflictFailureImpl _value, $Res Function(_$ConflictFailureImpl) _then)
      : super(_value, _then);

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = freezed,
  }) {
    return _then(_$ConflictFailureImpl(
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ConflictFailureImpl implements ConflictFailure {
  const _$ConflictFailureImpl({this.message, final String? $type})
      : $type = $type ?? 'conflict';

  factory _$ConflictFailureImpl.fromJson(Map<String, dynamic> json) =>
      _$$ConflictFailureImplFromJson(json);

  @override
  final String? message;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'Failure.conflict(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConflictFailureImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConflictFailureImplCopyWith<_$ConflictFailureImpl> get copyWith =>
      __$$ConflictFailureImplCopyWithImpl<_$ConflictFailureImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String? message) network,
    required TResult Function(String? message) timeout,
    required TResult Function(String? message) unauthorized,
    required TResult Function(String? message) forbidden,
    required TResult Function(String? message) notFound,
    required TResult Function(String? message) conflict,
    required TResult Function(Map<String, List<String>> fields, String? message)
        validation,
    required TResult Function(int? retryAfter, String? message) rateLimited,
    required TResult Function(int status, String? message) server,
    required TResult Function(int serverTimeUtc, int driftMs, String? message)
        clockSkew,
    required TResult Function(String? message) cache,
    required TResult Function(String? message) unknown,
  }) {
    return conflict(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String? message)? network,
    TResult? Function(String? message)? timeout,
    TResult? Function(String? message)? unauthorized,
    TResult? Function(String? message)? forbidden,
    TResult? Function(String? message)? notFound,
    TResult? Function(String? message)? conflict,
    TResult? Function(Map<String, List<String>> fields, String? message)?
        validation,
    TResult? Function(int? retryAfter, String? message)? rateLimited,
    TResult? Function(int status, String? message)? server,
    TResult? Function(int serverTimeUtc, int driftMs, String? message)?
        clockSkew,
    TResult? Function(String? message)? cache,
    TResult? Function(String? message)? unknown,
  }) {
    return conflict?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String? message)? network,
    TResult Function(String? message)? timeout,
    TResult Function(String? message)? unauthorized,
    TResult Function(String? message)? forbidden,
    TResult Function(String? message)? notFound,
    TResult Function(String? message)? conflict,
    TResult Function(Map<String, List<String>> fields, String? message)?
        validation,
    TResult Function(int? retryAfter, String? message)? rateLimited,
    TResult Function(int status, String? message)? server,
    TResult Function(int serverTimeUtc, int driftMs, String? message)?
        clockSkew,
    TResult Function(String? message)? cache,
    TResult Function(String? message)? unknown,
    required TResult orElse(),
  }) {
    if (conflict != null) {
      return conflict(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NetworkFailure value) network,
    required TResult Function(TimeoutFailure value) timeout,
    required TResult Function(UnauthorizedFailure value) unauthorized,
    required TResult Function(ForbiddenFailure value) forbidden,
    required TResult Function(NotFoundFailure value) notFound,
    required TResult Function(ConflictFailure value) conflict,
    required TResult Function(ValidationFailure value) validation,
    required TResult Function(RateLimitedFailure value) rateLimited,
    required TResult Function(ServerFailure value) server,
    required TResult Function(ClockSkewFailure value) clockSkew,
    required TResult Function(CacheFailure value) cache,
    required TResult Function(UnknownFailure value) unknown,
  }) {
    return conflict(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NetworkFailure value)? network,
    TResult? Function(TimeoutFailure value)? timeout,
    TResult? Function(UnauthorizedFailure value)? unauthorized,
    TResult? Function(ForbiddenFailure value)? forbidden,
    TResult? Function(NotFoundFailure value)? notFound,
    TResult? Function(ConflictFailure value)? conflict,
    TResult? Function(ValidationFailure value)? validation,
    TResult? Function(RateLimitedFailure value)? rateLimited,
    TResult? Function(ServerFailure value)? server,
    TResult? Function(ClockSkewFailure value)? clockSkew,
    TResult? Function(CacheFailure value)? cache,
    TResult? Function(UnknownFailure value)? unknown,
  }) {
    return conflict?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NetworkFailure value)? network,
    TResult Function(TimeoutFailure value)? timeout,
    TResult Function(UnauthorizedFailure value)? unauthorized,
    TResult Function(ForbiddenFailure value)? forbidden,
    TResult Function(NotFoundFailure value)? notFound,
    TResult Function(ConflictFailure value)? conflict,
    TResult Function(ValidationFailure value)? validation,
    TResult Function(RateLimitedFailure value)? rateLimited,
    TResult Function(ServerFailure value)? server,
    TResult Function(ClockSkewFailure value)? clockSkew,
    TResult Function(CacheFailure value)? cache,
    TResult Function(UnknownFailure value)? unknown,
    required TResult orElse(),
  }) {
    if (conflict != null) {
      return conflict(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$ConflictFailureImplToJson(
      this,
    );
  }
}

abstract class ConflictFailure implements Failure {
  const factory ConflictFailure({final String? message}) =
      _$ConflictFailureImpl;

  factory ConflictFailure.fromJson(Map<String, dynamic> json) =
      _$ConflictFailureImpl.fromJson;

  @override
  String? get message;

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConflictFailureImplCopyWith<_$ConflictFailureImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ValidationFailureImplCopyWith<$Res>
    implements $FailureCopyWith<$Res> {
  factory _$$ValidationFailureImplCopyWith(_$ValidationFailureImpl value,
          $Res Function(_$ValidationFailureImpl) then) =
      __$$ValidationFailureImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({Map<String, List<String>> fields, String? message});
}

/// @nodoc
class __$$ValidationFailureImplCopyWithImpl<$Res>
    extends _$FailureCopyWithImpl<$Res, _$ValidationFailureImpl>
    implements _$$ValidationFailureImplCopyWith<$Res> {
  __$$ValidationFailureImplCopyWithImpl(_$ValidationFailureImpl _value,
      $Res Function(_$ValidationFailureImpl) _then)
      : super(_value, _then);

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fields = null,
    Object? message = freezed,
  }) {
    return _then(_$ValidationFailureImpl(
      null == fields
          ? _value._fields
          : fields // ignore: cast_nullable_to_non_nullable
              as Map<String, List<String>>,
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ValidationFailureImpl implements ValidationFailure {
  const _$ValidationFailureImpl(final Map<String, List<String>> fields,
      {this.message, final String? $type})
      : _fields = fields,
        $type = $type ?? 'validation';

  factory _$ValidationFailureImpl.fromJson(Map<String, dynamic> json) =>
      _$$ValidationFailureImplFromJson(json);

  final Map<String, List<String>> _fields;
  @override
  Map<String, List<String>> get fields {
    if (_fields is EqualUnmodifiableMapView) return _fields;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_fields);
  }

  @override
  final String? message;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'Failure.validation(fields: $fields, message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ValidationFailureImpl &&
            const DeepCollectionEquality().equals(other._fields, _fields) &&
            (identical(other.message, message) || other.message == message));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(_fields), message);

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ValidationFailureImplCopyWith<_$ValidationFailureImpl> get copyWith =>
      __$$ValidationFailureImplCopyWithImpl<_$ValidationFailureImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String? message) network,
    required TResult Function(String? message) timeout,
    required TResult Function(String? message) unauthorized,
    required TResult Function(String? message) forbidden,
    required TResult Function(String? message) notFound,
    required TResult Function(String? message) conflict,
    required TResult Function(Map<String, List<String>> fields, String? message)
        validation,
    required TResult Function(int? retryAfter, String? message) rateLimited,
    required TResult Function(int status, String? message) server,
    required TResult Function(int serverTimeUtc, int driftMs, String? message)
        clockSkew,
    required TResult Function(String? message) cache,
    required TResult Function(String? message) unknown,
  }) {
    return validation(fields, message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String? message)? network,
    TResult? Function(String? message)? timeout,
    TResult? Function(String? message)? unauthorized,
    TResult? Function(String? message)? forbidden,
    TResult? Function(String? message)? notFound,
    TResult? Function(String? message)? conflict,
    TResult? Function(Map<String, List<String>> fields, String? message)?
        validation,
    TResult? Function(int? retryAfter, String? message)? rateLimited,
    TResult? Function(int status, String? message)? server,
    TResult? Function(int serverTimeUtc, int driftMs, String? message)?
        clockSkew,
    TResult? Function(String? message)? cache,
    TResult? Function(String? message)? unknown,
  }) {
    return validation?.call(fields, message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String? message)? network,
    TResult Function(String? message)? timeout,
    TResult Function(String? message)? unauthorized,
    TResult Function(String? message)? forbidden,
    TResult Function(String? message)? notFound,
    TResult Function(String? message)? conflict,
    TResult Function(Map<String, List<String>> fields, String? message)?
        validation,
    TResult Function(int? retryAfter, String? message)? rateLimited,
    TResult Function(int status, String? message)? server,
    TResult Function(int serverTimeUtc, int driftMs, String? message)?
        clockSkew,
    TResult Function(String? message)? cache,
    TResult Function(String? message)? unknown,
    required TResult orElse(),
  }) {
    if (validation != null) {
      return validation(fields, message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NetworkFailure value) network,
    required TResult Function(TimeoutFailure value) timeout,
    required TResult Function(UnauthorizedFailure value) unauthorized,
    required TResult Function(ForbiddenFailure value) forbidden,
    required TResult Function(NotFoundFailure value) notFound,
    required TResult Function(ConflictFailure value) conflict,
    required TResult Function(ValidationFailure value) validation,
    required TResult Function(RateLimitedFailure value) rateLimited,
    required TResult Function(ServerFailure value) server,
    required TResult Function(ClockSkewFailure value) clockSkew,
    required TResult Function(CacheFailure value) cache,
    required TResult Function(UnknownFailure value) unknown,
  }) {
    return validation(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NetworkFailure value)? network,
    TResult? Function(TimeoutFailure value)? timeout,
    TResult? Function(UnauthorizedFailure value)? unauthorized,
    TResult? Function(ForbiddenFailure value)? forbidden,
    TResult? Function(NotFoundFailure value)? notFound,
    TResult? Function(ConflictFailure value)? conflict,
    TResult? Function(ValidationFailure value)? validation,
    TResult? Function(RateLimitedFailure value)? rateLimited,
    TResult? Function(ServerFailure value)? server,
    TResult? Function(ClockSkewFailure value)? clockSkew,
    TResult? Function(CacheFailure value)? cache,
    TResult? Function(UnknownFailure value)? unknown,
  }) {
    return validation?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NetworkFailure value)? network,
    TResult Function(TimeoutFailure value)? timeout,
    TResult Function(UnauthorizedFailure value)? unauthorized,
    TResult Function(ForbiddenFailure value)? forbidden,
    TResult Function(NotFoundFailure value)? notFound,
    TResult Function(ConflictFailure value)? conflict,
    TResult Function(ValidationFailure value)? validation,
    TResult Function(RateLimitedFailure value)? rateLimited,
    TResult Function(ServerFailure value)? server,
    TResult Function(ClockSkewFailure value)? clockSkew,
    TResult Function(CacheFailure value)? cache,
    TResult Function(UnknownFailure value)? unknown,
    required TResult orElse(),
  }) {
    if (validation != null) {
      return validation(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$ValidationFailureImplToJson(
      this,
    );
  }
}

abstract class ValidationFailure implements Failure {
  const factory ValidationFailure(final Map<String, List<String>> fields,
      {final String? message}) = _$ValidationFailureImpl;

  factory ValidationFailure.fromJson(Map<String, dynamic> json) =
      _$ValidationFailureImpl.fromJson;

  Map<String, List<String>> get fields;
  @override
  String? get message;

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ValidationFailureImplCopyWith<_$ValidationFailureImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RateLimitedFailureImplCopyWith<$Res>
    implements $FailureCopyWith<$Res> {
  factory _$$RateLimitedFailureImplCopyWith(_$RateLimitedFailureImpl value,
          $Res Function(_$RateLimitedFailureImpl) then) =
      __$$RateLimitedFailureImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int? retryAfter, String? message});
}

/// @nodoc
class __$$RateLimitedFailureImplCopyWithImpl<$Res>
    extends _$FailureCopyWithImpl<$Res, _$RateLimitedFailureImpl>
    implements _$$RateLimitedFailureImplCopyWith<$Res> {
  __$$RateLimitedFailureImplCopyWithImpl(_$RateLimitedFailureImpl _value,
      $Res Function(_$RateLimitedFailureImpl) _then)
      : super(_value, _then);

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? retryAfter = freezed,
    Object? message = freezed,
  }) {
    return _then(_$RateLimitedFailureImpl(
      retryAfter: freezed == retryAfter
          ? _value.retryAfter
          : retryAfter // ignore: cast_nullable_to_non_nullable
              as int?,
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RateLimitedFailureImpl implements RateLimitedFailure {
  const _$RateLimitedFailureImpl(
      {this.retryAfter, this.message, final String? $type})
      : $type = $type ?? 'rateLimited';

  factory _$RateLimitedFailureImpl.fromJson(Map<String, dynamic> json) =>
      _$$RateLimitedFailureImplFromJson(json);

  @override
  final int? retryAfter;
  @override
  final String? message;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'Failure.rateLimited(retryAfter: $retryAfter, message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RateLimitedFailureImpl &&
            (identical(other.retryAfter, retryAfter) ||
                other.retryAfter == retryAfter) &&
            (identical(other.message, message) || other.message == message));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, retryAfter, message);

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RateLimitedFailureImplCopyWith<_$RateLimitedFailureImpl> get copyWith =>
      __$$RateLimitedFailureImplCopyWithImpl<_$RateLimitedFailureImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String? message) network,
    required TResult Function(String? message) timeout,
    required TResult Function(String? message) unauthorized,
    required TResult Function(String? message) forbidden,
    required TResult Function(String? message) notFound,
    required TResult Function(String? message) conflict,
    required TResult Function(Map<String, List<String>> fields, String? message)
        validation,
    required TResult Function(int? retryAfter, String? message) rateLimited,
    required TResult Function(int status, String? message) server,
    required TResult Function(int serverTimeUtc, int driftMs, String? message)
        clockSkew,
    required TResult Function(String? message) cache,
    required TResult Function(String? message) unknown,
  }) {
    return rateLimited(retryAfter, message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String? message)? network,
    TResult? Function(String? message)? timeout,
    TResult? Function(String? message)? unauthorized,
    TResult? Function(String? message)? forbidden,
    TResult? Function(String? message)? notFound,
    TResult? Function(String? message)? conflict,
    TResult? Function(Map<String, List<String>> fields, String? message)?
        validation,
    TResult? Function(int? retryAfter, String? message)? rateLimited,
    TResult? Function(int status, String? message)? server,
    TResult? Function(int serverTimeUtc, int driftMs, String? message)?
        clockSkew,
    TResult? Function(String? message)? cache,
    TResult? Function(String? message)? unknown,
  }) {
    return rateLimited?.call(retryAfter, message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String? message)? network,
    TResult Function(String? message)? timeout,
    TResult Function(String? message)? unauthorized,
    TResult Function(String? message)? forbidden,
    TResult Function(String? message)? notFound,
    TResult Function(String? message)? conflict,
    TResult Function(Map<String, List<String>> fields, String? message)?
        validation,
    TResult Function(int? retryAfter, String? message)? rateLimited,
    TResult Function(int status, String? message)? server,
    TResult Function(int serverTimeUtc, int driftMs, String? message)?
        clockSkew,
    TResult Function(String? message)? cache,
    TResult Function(String? message)? unknown,
    required TResult orElse(),
  }) {
    if (rateLimited != null) {
      return rateLimited(retryAfter, message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NetworkFailure value) network,
    required TResult Function(TimeoutFailure value) timeout,
    required TResult Function(UnauthorizedFailure value) unauthorized,
    required TResult Function(ForbiddenFailure value) forbidden,
    required TResult Function(NotFoundFailure value) notFound,
    required TResult Function(ConflictFailure value) conflict,
    required TResult Function(ValidationFailure value) validation,
    required TResult Function(RateLimitedFailure value) rateLimited,
    required TResult Function(ServerFailure value) server,
    required TResult Function(ClockSkewFailure value) clockSkew,
    required TResult Function(CacheFailure value) cache,
    required TResult Function(UnknownFailure value) unknown,
  }) {
    return rateLimited(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NetworkFailure value)? network,
    TResult? Function(TimeoutFailure value)? timeout,
    TResult? Function(UnauthorizedFailure value)? unauthorized,
    TResult? Function(ForbiddenFailure value)? forbidden,
    TResult? Function(NotFoundFailure value)? notFound,
    TResult? Function(ConflictFailure value)? conflict,
    TResult? Function(ValidationFailure value)? validation,
    TResult? Function(RateLimitedFailure value)? rateLimited,
    TResult? Function(ServerFailure value)? server,
    TResult? Function(ClockSkewFailure value)? clockSkew,
    TResult? Function(CacheFailure value)? cache,
    TResult? Function(UnknownFailure value)? unknown,
  }) {
    return rateLimited?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NetworkFailure value)? network,
    TResult Function(TimeoutFailure value)? timeout,
    TResult Function(UnauthorizedFailure value)? unauthorized,
    TResult Function(ForbiddenFailure value)? forbidden,
    TResult Function(NotFoundFailure value)? notFound,
    TResult Function(ConflictFailure value)? conflict,
    TResult Function(ValidationFailure value)? validation,
    TResult Function(RateLimitedFailure value)? rateLimited,
    TResult Function(ServerFailure value)? server,
    TResult Function(ClockSkewFailure value)? clockSkew,
    TResult Function(CacheFailure value)? cache,
    TResult Function(UnknownFailure value)? unknown,
    required TResult orElse(),
  }) {
    if (rateLimited != null) {
      return rateLimited(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$RateLimitedFailureImplToJson(
      this,
    );
  }
}

abstract class RateLimitedFailure implements Failure {
  const factory RateLimitedFailure(
      {final int? retryAfter,
      final String? message}) = _$RateLimitedFailureImpl;

  factory RateLimitedFailure.fromJson(Map<String, dynamic> json) =
      _$RateLimitedFailureImpl.fromJson;

  int? get retryAfter;
  @override
  String? get message;

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RateLimitedFailureImplCopyWith<_$RateLimitedFailureImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ServerFailureImplCopyWith<$Res>
    implements $FailureCopyWith<$Res> {
  factory _$$ServerFailureImplCopyWith(
          _$ServerFailureImpl value, $Res Function(_$ServerFailureImpl) then) =
      __$$ServerFailureImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int status, String? message});
}

/// @nodoc
class __$$ServerFailureImplCopyWithImpl<$Res>
    extends _$FailureCopyWithImpl<$Res, _$ServerFailureImpl>
    implements _$$ServerFailureImplCopyWith<$Res> {
  __$$ServerFailureImplCopyWithImpl(
      _$ServerFailureImpl _value, $Res Function(_$ServerFailureImpl) _then)
      : super(_value, _then);

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? message = freezed,
  }) {
    return _then(_$ServerFailureImpl(
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as int,
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ServerFailureImpl implements ServerFailure {
  const _$ServerFailureImpl(
      {required this.status, this.message, final String? $type})
      : $type = $type ?? 'server';

  factory _$ServerFailureImpl.fromJson(Map<String, dynamic> json) =>
      _$$ServerFailureImplFromJson(json);

  @override
  final int status;
  @override
  final String? message;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'Failure.server(status: $status, message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ServerFailureImpl &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.message, message) || other.message == message));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, status, message);

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ServerFailureImplCopyWith<_$ServerFailureImpl> get copyWith =>
      __$$ServerFailureImplCopyWithImpl<_$ServerFailureImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String? message) network,
    required TResult Function(String? message) timeout,
    required TResult Function(String? message) unauthorized,
    required TResult Function(String? message) forbidden,
    required TResult Function(String? message) notFound,
    required TResult Function(String? message) conflict,
    required TResult Function(Map<String, List<String>> fields, String? message)
        validation,
    required TResult Function(int? retryAfter, String? message) rateLimited,
    required TResult Function(int status, String? message) server,
    required TResult Function(int serverTimeUtc, int driftMs, String? message)
        clockSkew,
    required TResult Function(String? message) cache,
    required TResult Function(String? message) unknown,
  }) {
    return server(status, message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String? message)? network,
    TResult? Function(String? message)? timeout,
    TResult? Function(String? message)? unauthorized,
    TResult? Function(String? message)? forbidden,
    TResult? Function(String? message)? notFound,
    TResult? Function(String? message)? conflict,
    TResult? Function(Map<String, List<String>> fields, String? message)?
        validation,
    TResult? Function(int? retryAfter, String? message)? rateLimited,
    TResult? Function(int status, String? message)? server,
    TResult? Function(int serverTimeUtc, int driftMs, String? message)?
        clockSkew,
    TResult? Function(String? message)? cache,
    TResult? Function(String? message)? unknown,
  }) {
    return server?.call(status, message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String? message)? network,
    TResult Function(String? message)? timeout,
    TResult Function(String? message)? unauthorized,
    TResult Function(String? message)? forbidden,
    TResult Function(String? message)? notFound,
    TResult Function(String? message)? conflict,
    TResult Function(Map<String, List<String>> fields, String? message)?
        validation,
    TResult Function(int? retryAfter, String? message)? rateLimited,
    TResult Function(int status, String? message)? server,
    TResult Function(int serverTimeUtc, int driftMs, String? message)?
        clockSkew,
    TResult Function(String? message)? cache,
    TResult Function(String? message)? unknown,
    required TResult orElse(),
  }) {
    if (server != null) {
      return server(status, message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NetworkFailure value) network,
    required TResult Function(TimeoutFailure value) timeout,
    required TResult Function(UnauthorizedFailure value) unauthorized,
    required TResult Function(ForbiddenFailure value) forbidden,
    required TResult Function(NotFoundFailure value) notFound,
    required TResult Function(ConflictFailure value) conflict,
    required TResult Function(ValidationFailure value) validation,
    required TResult Function(RateLimitedFailure value) rateLimited,
    required TResult Function(ServerFailure value) server,
    required TResult Function(ClockSkewFailure value) clockSkew,
    required TResult Function(CacheFailure value) cache,
    required TResult Function(UnknownFailure value) unknown,
  }) {
    return server(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NetworkFailure value)? network,
    TResult? Function(TimeoutFailure value)? timeout,
    TResult? Function(UnauthorizedFailure value)? unauthorized,
    TResult? Function(ForbiddenFailure value)? forbidden,
    TResult? Function(NotFoundFailure value)? notFound,
    TResult? Function(ConflictFailure value)? conflict,
    TResult? Function(ValidationFailure value)? validation,
    TResult? Function(RateLimitedFailure value)? rateLimited,
    TResult? Function(ServerFailure value)? server,
    TResult? Function(ClockSkewFailure value)? clockSkew,
    TResult? Function(CacheFailure value)? cache,
    TResult? Function(UnknownFailure value)? unknown,
  }) {
    return server?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NetworkFailure value)? network,
    TResult Function(TimeoutFailure value)? timeout,
    TResult Function(UnauthorizedFailure value)? unauthorized,
    TResult Function(ForbiddenFailure value)? forbidden,
    TResult Function(NotFoundFailure value)? notFound,
    TResult Function(ConflictFailure value)? conflict,
    TResult Function(ValidationFailure value)? validation,
    TResult Function(RateLimitedFailure value)? rateLimited,
    TResult Function(ServerFailure value)? server,
    TResult Function(ClockSkewFailure value)? clockSkew,
    TResult Function(CacheFailure value)? cache,
    TResult Function(UnknownFailure value)? unknown,
    required TResult orElse(),
  }) {
    if (server != null) {
      return server(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$ServerFailureImplToJson(
      this,
    );
  }
}

abstract class ServerFailure implements Failure {
  const factory ServerFailure(
      {required final int status, final String? message}) = _$ServerFailureImpl;

  factory ServerFailure.fromJson(Map<String, dynamic> json) =
      _$ServerFailureImpl.fromJson;

  int get status;
  @override
  String? get message;

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ServerFailureImplCopyWith<_$ServerFailureImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ClockSkewFailureImplCopyWith<$Res>
    implements $FailureCopyWith<$Res> {
  factory _$$ClockSkewFailureImplCopyWith(_$ClockSkewFailureImpl value,
          $Res Function(_$ClockSkewFailureImpl) then) =
      __$$ClockSkewFailureImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int serverTimeUtc, int driftMs, String? message});
}

/// @nodoc
class __$$ClockSkewFailureImplCopyWithImpl<$Res>
    extends _$FailureCopyWithImpl<$Res, _$ClockSkewFailureImpl>
    implements _$$ClockSkewFailureImplCopyWith<$Res> {
  __$$ClockSkewFailureImplCopyWithImpl(_$ClockSkewFailureImpl _value,
      $Res Function(_$ClockSkewFailureImpl) _then)
      : super(_value, _then);

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? serverTimeUtc = null,
    Object? driftMs = null,
    Object? message = freezed,
  }) {
    return _then(_$ClockSkewFailureImpl(
      serverTimeUtc: null == serverTimeUtc
          ? _value.serverTimeUtc
          : serverTimeUtc // ignore: cast_nullable_to_non_nullable
              as int,
      driftMs: null == driftMs
          ? _value.driftMs
          : driftMs // ignore: cast_nullable_to_non_nullable
              as int,
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ClockSkewFailureImpl implements ClockSkewFailure {
  const _$ClockSkewFailureImpl(
      {required this.serverTimeUtc,
      required this.driftMs,
      this.message,
      final String? $type})
      : $type = $type ?? 'clockSkew';

  factory _$ClockSkewFailureImpl.fromJson(Map<String, dynamic> json) =>
      _$$ClockSkewFailureImplFromJson(json);

  @override
  final int serverTimeUtc;
  @override
  final int driftMs;
  @override
  final String? message;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'Failure.clockSkew(serverTimeUtc: $serverTimeUtc, driftMs: $driftMs, message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ClockSkewFailureImpl &&
            (identical(other.serverTimeUtc, serverTimeUtc) ||
                other.serverTimeUtc == serverTimeUtc) &&
            (identical(other.driftMs, driftMs) || other.driftMs == driftMs) &&
            (identical(other.message, message) || other.message == message));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, serverTimeUtc, driftMs, message);

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ClockSkewFailureImplCopyWith<_$ClockSkewFailureImpl> get copyWith =>
      __$$ClockSkewFailureImplCopyWithImpl<_$ClockSkewFailureImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String? message) network,
    required TResult Function(String? message) timeout,
    required TResult Function(String? message) unauthorized,
    required TResult Function(String? message) forbidden,
    required TResult Function(String? message) notFound,
    required TResult Function(String? message) conflict,
    required TResult Function(Map<String, List<String>> fields, String? message)
        validation,
    required TResult Function(int? retryAfter, String? message) rateLimited,
    required TResult Function(int status, String? message) server,
    required TResult Function(int serverTimeUtc, int driftMs, String? message)
        clockSkew,
    required TResult Function(String? message) cache,
    required TResult Function(String? message) unknown,
  }) {
    return clockSkew(serverTimeUtc, driftMs, message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String? message)? network,
    TResult? Function(String? message)? timeout,
    TResult? Function(String? message)? unauthorized,
    TResult? Function(String? message)? forbidden,
    TResult? Function(String? message)? notFound,
    TResult? Function(String? message)? conflict,
    TResult? Function(Map<String, List<String>> fields, String? message)?
        validation,
    TResult? Function(int? retryAfter, String? message)? rateLimited,
    TResult? Function(int status, String? message)? server,
    TResult? Function(int serverTimeUtc, int driftMs, String? message)?
        clockSkew,
    TResult? Function(String? message)? cache,
    TResult? Function(String? message)? unknown,
  }) {
    return clockSkew?.call(serverTimeUtc, driftMs, message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String? message)? network,
    TResult Function(String? message)? timeout,
    TResult Function(String? message)? unauthorized,
    TResult Function(String? message)? forbidden,
    TResult Function(String? message)? notFound,
    TResult Function(String? message)? conflict,
    TResult Function(Map<String, List<String>> fields, String? message)?
        validation,
    TResult Function(int? retryAfter, String? message)? rateLimited,
    TResult Function(int status, String? message)? server,
    TResult Function(int serverTimeUtc, int driftMs, String? message)?
        clockSkew,
    TResult Function(String? message)? cache,
    TResult Function(String? message)? unknown,
    required TResult orElse(),
  }) {
    if (clockSkew != null) {
      return clockSkew(serverTimeUtc, driftMs, message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NetworkFailure value) network,
    required TResult Function(TimeoutFailure value) timeout,
    required TResult Function(UnauthorizedFailure value) unauthorized,
    required TResult Function(ForbiddenFailure value) forbidden,
    required TResult Function(NotFoundFailure value) notFound,
    required TResult Function(ConflictFailure value) conflict,
    required TResult Function(ValidationFailure value) validation,
    required TResult Function(RateLimitedFailure value) rateLimited,
    required TResult Function(ServerFailure value) server,
    required TResult Function(ClockSkewFailure value) clockSkew,
    required TResult Function(CacheFailure value) cache,
    required TResult Function(UnknownFailure value) unknown,
  }) {
    return clockSkew(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NetworkFailure value)? network,
    TResult? Function(TimeoutFailure value)? timeout,
    TResult? Function(UnauthorizedFailure value)? unauthorized,
    TResult? Function(ForbiddenFailure value)? forbidden,
    TResult? Function(NotFoundFailure value)? notFound,
    TResult? Function(ConflictFailure value)? conflict,
    TResult? Function(ValidationFailure value)? validation,
    TResult? Function(RateLimitedFailure value)? rateLimited,
    TResult? Function(ServerFailure value)? server,
    TResult? Function(ClockSkewFailure value)? clockSkew,
    TResult? Function(CacheFailure value)? cache,
    TResult? Function(UnknownFailure value)? unknown,
  }) {
    return clockSkew?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NetworkFailure value)? network,
    TResult Function(TimeoutFailure value)? timeout,
    TResult Function(UnauthorizedFailure value)? unauthorized,
    TResult Function(ForbiddenFailure value)? forbidden,
    TResult Function(NotFoundFailure value)? notFound,
    TResult Function(ConflictFailure value)? conflict,
    TResult Function(ValidationFailure value)? validation,
    TResult Function(RateLimitedFailure value)? rateLimited,
    TResult Function(ServerFailure value)? server,
    TResult Function(ClockSkewFailure value)? clockSkew,
    TResult Function(CacheFailure value)? cache,
    TResult Function(UnknownFailure value)? unknown,
    required TResult orElse(),
  }) {
    if (clockSkew != null) {
      return clockSkew(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$ClockSkewFailureImplToJson(
      this,
    );
  }
}

abstract class ClockSkewFailure implements Failure {
  const factory ClockSkewFailure(
      {required final int serverTimeUtc,
      required final int driftMs,
      final String? message}) = _$ClockSkewFailureImpl;

  factory ClockSkewFailure.fromJson(Map<String, dynamic> json) =
      _$ClockSkewFailureImpl.fromJson;

  int get serverTimeUtc;
  int get driftMs;
  @override
  String? get message;

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ClockSkewFailureImplCopyWith<_$ClockSkewFailureImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$CacheFailureImplCopyWith<$Res>
    implements $FailureCopyWith<$Res> {
  factory _$$CacheFailureImplCopyWith(
          _$CacheFailureImpl value, $Res Function(_$CacheFailureImpl) then) =
      __$$CacheFailureImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String? message});
}

/// @nodoc
class __$$CacheFailureImplCopyWithImpl<$Res>
    extends _$FailureCopyWithImpl<$Res, _$CacheFailureImpl>
    implements _$$CacheFailureImplCopyWith<$Res> {
  __$$CacheFailureImplCopyWithImpl(
      _$CacheFailureImpl _value, $Res Function(_$CacheFailureImpl) _then)
      : super(_value, _then);

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = freezed,
  }) {
    return _then(_$CacheFailureImpl(
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CacheFailureImpl implements CacheFailure {
  const _$CacheFailureImpl({this.message, final String? $type})
      : $type = $type ?? 'cache';

  factory _$CacheFailureImpl.fromJson(Map<String, dynamic> json) =>
      _$$CacheFailureImplFromJson(json);

  @override
  final String? message;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'Failure.cache(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CacheFailureImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CacheFailureImplCopyWith<_$CacheFailureImpl> get copyWith =>
      __$$CacheFailureImplCopyWithImpl<_$CacheFailureImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String? message) network,
    required TResult Function(String? message) timeout,
    required TResult Function(String? message) unauthorized,
    required TResult Function(String? message) forbidden,
    required TResult Function(String? message) notFound,
    required TResult Function(String? message) conflict,
    required TResult Function(Map<String, List<String>> fields, String? message)
        validation,
    required TResult Function(int? retryAfter, String? message) rateLimited,
    required TResult Function(int status, String? message) server,
    required TResult Function(int serverTimeUtc, int driftMs, String? message)
        clockSkew,
    required TResult Function(String? message) cache,
    required TResult Function(String? message) unknown,
  }) {
    return cache(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String? message)? network,
    TResult? Function(String? message)? timeout,
    TResult? Function(String? message)? unauthorized,
    TResult? Function(String? message)? forbidden,
    TResult? Function(String? message)? notFound,
    TResult? Function(String? message)? conflict,
    TResult? Function(Map<String, List<String>> fields, String? message)?
        validation,
    TResult? Function(int? retryAfter, String? message)? rateLimited,
    TResult? Function(int status, String? message)? server,
    TResult? Function(int serverTimeUtc, int driftMs, String? message)?
        clockSkew,
    TResult? Function(String? message)? cache,
    TResult? Function(String? message)? unknown,
  }) {
    return cache?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String? message)? network,
    TResult Function(String? message)? timeout,
    TResult Function(String? message)? unauthorized,
    TResult Function(String? message)? forbidden,
    TResult Function(String? message)? notFound,
    TResult Function(String? message)? conflict,
    TResult Function(Map<String, List<String>> fields, String? message)?
        validation,
    TResult Function(int? retryAfter, String? message)? rateLimited,
    TResult Function(int status, String? message)? server,
    TResult Function(int serverTimeUtc, int driftMs, String? message)?
        clockSkew,
    TResult Function(String? message)? cache,
    TResult Function(String? message)? unknown,
    required TResult orElse(),
  }) {
    if (cache != null) {
      return cache(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NetworkFailure value) network,
    required TResult Function(TimeoutFailure value) timeout,
    required TResult Function(UnauthorizedFailure value) unauthorized,
    required TResult Function(ForbiddenFailure value) forbidden,
    required TResult Function(NotFoundFailure value) notFound,
    required TResult Function(ConflictFailure value) conflict,
    required TResult Function(ValidationFailure value) validation,
    required TResult Function(RateLimitedFailure value) rateLimited,
    required TResult Function(ServerFailure value) server,
    required TResult Function(ClockSkewFailure value) clockSkew,
    required TResult Function(CacheFailure value) cache,
    required TResult Function(UnknownFailure value) unknown,
  }) {
    return cache(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NetworkFailure value)? network,
    TResult? Function(TimeoutFailure value)? timeout,
    TResult? Function(UnauthorizedFailure value)? unauthorized,
    TResult? Function(ForbiddenFailure value)? forbidden,
    TResult? Function(NotFoundFailure value)? notFound,
    TResult? Function(ConflictFailure value)? conflict,
    TResult? Function(ValidationFailure value)? validation,
    TResult? Function(RateLimitedFailure value)? rateLimited,
    TResult? Function(ServerFailure value)? server,
    TResult? Function(ClockSkewFailure value)? clockSkew,
    TResult? Function(CacheFailure value)? cache,
    TResult? Function(UnknownFailure value)? unknown,
  }) {
    return cache?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NetworkFailure value)? network,
    TResult Function(TimeoutFailure value)? timeout,
    TResult Function(UnauthorizedFailure value)? unauthorized,
    TResult Function(ForbiddenFailure value)? forbidden,
    TResult Function(NotFoundFailure value)? notFound,
    TResult Function(ConflictFailure value)? conflict,
    TResult Function(ValidationFailure value)? validation,
    TResult Function(RateLimitedFailure value)? rateLimited,
    TResult Function(ServerFailure value)? server,
    TResult Function(ClockSkewFailure value)? clockSkew,
    TResult Function(CacheFailure value)? cache,
    TResult Function(UnknownFailure value)? unknown,
    required TResult orElse(),
  }) {
    if (cache != null) {
      return cache(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$CacheFailureImplToJson(
      this,
    );
  }
}

abstract class CacheFailure implements Failure {
  const factory CacheFailure({final String? message}) = _$CacheFailureImpl;

  factory CacheFailure.fromJson(Map<String, dynamic> json) =
      _$CacheFailureImpl.fromJson;

  @override
  String? get message;

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CacheFailureImplCopyWith<_$CacheFailureImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$UnknownFailureImplCopyWith<$Res>
    implements $FailureCopyWith<$Res> {
  factory _$$UnknownFailureImplCopyWith(_$UnknownFailureImpl value,
          $Res Function(_$UnknownFailureImpl) then) =
      __$$UnknownFailureImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String? message});
}

/// @nodoc
class __$$UnknownFailureImplCopyWithImpl<$Res>
    extends _$FailureCopyWithImpl<$Res, _$UnknownFailureImpl>
    implements _$$UnknownFailureImplCopyWith<$Res> {
  __$$UnknownFailureImplCopyWithImpl(
      _$UnknownFailureImpl _value, $Res Function(_$UnknownFailureImpl) _then)
      : super(_value, _then);

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = freezed,
  }) {
    return _then(_$UnknownFailureImpl(
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UnknownFailureImpl implements UnknownFailure {
  const _$UnknownFailureImpl({this.message, final String? $type})
      : $type = $type ?? 'unknown';

  factory _$UnknownFailureImpl.fromJson(Map<String, dynamic> json) =>
      _$$UnknownFailureImplFromJson(json);

  @override
  final String? message;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'Failure.unknown(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UnknownFailureImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UnknownFailureImplCopyWith<_$UnknownFailureImpl> get copyWith =>
      __$$UnknownFailureImplCopyWithImpl<_$UnknownFailureImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String? message) network,
    required TResult Function(String? message) timeout,
    required TResult Function(String? message) unauthorized,
    required TResult Function(String? message) forbidden,
    required TResult Function(String? message) notFound,
    required TResult Function(String? message) conflict,
    required TResult Function(Map<String, List<String>> fields, String? message)
        validation,
    required TResult Function(int? retryAfter, String? message) rateLimited,
    required TResult Function(int status, String? message) server,
    required TResult Function(int serverTimeUtc, int driftMs, String? message)
        clockSkew,
    required TResult Function(String? message) cache,
    required TResult Function(String? message) unknown,
  }) {
    return unknown(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String? message)? network,
    TResult? Function(String? message)? timeout,
    TResult? Function(String? message)? unauthorized,
    TResult? Function(String? message)? forbidden,
    TResult? Function(String? message)? notFound,
    TResult? Function(String? message)? conflict,
    TResult? Function(Map<String, List<String>> fields, String? message)?
        validation,
    TResult? Function(int? retryAfter, String? message)? rateLimited,
    TResult? Function(int status, String? message)? server,
    TResult? Function(int serverTimeUtc, int driftMs, String? message)?
        clockSkew,
    TResult? Function(String? message)? cache,
    TResult? Function(String? message)? unknown,
  }) {
    return unknown?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String? message)? network,
    TResult Function(String? message)? timeout,
    TResult Function(String? message)? unauthorized,
    TResult Function(String? message)? forbidden,
    TResult Function(String? message)? notFound,
    TResult Function(String? message)? conflict,
    TResult Function(Map<String, List<String>> fields, String? message)?
        validation,
    TResult Function(int? retryAfter, String? message)? rateLimited,
    TResult Function(int status, String? message)? server,
    TResult Function(int serverTimeUtc, int driftMs, String? message)?
        clockSkew,
    TResult Function(String? message)? cache,
    TResult Function(String? message)? unknown,
    required TResult orElse(),
  }) {
    if (unknown != null) {
      return unknown(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NetworkFailure value) network,
    required TResult Function(TimeoutFailure value) timeout,
    required TResult Function(UnauthorizedFailure value) unauthorized,
    required TResult Function(ForbiddenFailure value) forbidden,
    required TResult Function(NotFoundFailure value) notFound,
    required TResult Function(ConflictFailure value) conflict,
    required TResult Function(ValidationFailure value) validation,
    required TResult Function(RateLimitedFailure value) rateLimited,
    required TResult Function(ServerFailure value) server,
    required TResult Function(ClockSkewFailure value) clockSkew,
    required TResult Function(CacheFailure value) cache,
    required TResult Function(UnknownFailure value) unknown,
  }) {
    return unknown(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NetworkFailure value)? network,
    TResult? Function(TimeoutFailure value)? timeout,
    TResult? Function(UnauthorizedFailure value)? unauthorized,
    TResult? Function(ForbiddenFailure value)? forbidden,
    TResult? Function(NotFoundFailure value)? notFound,
    TResult? Function(ConflictFailure value)? conflict,
    TResult? Function(ValidationFailure value)? validation,
    TResult? Function(RateLimitedFailure value)? rateLimited,
    TResult? Function(ServerFailure value)? server,
    TResult? Function(ClockSkewFailure value)? clockSkew,
    TResult? Function(CacheFailure value)? cache,
    TResult? Function(UnknownFailure value)? unknown,
  }) {
    return unknown?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NetworkFailure value)? network,
    TResult Function(TimeoutFailure value)? timeout,
    TResult Function(UnauthorizedFailure value)? unauthorized,
    TResult Function(ForbiddenFailure value)? forbidden,
    TResult Function(NotFoundFailure value)? notFound,
    TResult Function(ConflictFailure value)? conflict,
    TResult Function(ValidationFailure value)? validation,
    TResult Function(RateLimitedFailure value)? rateLimited,
    TResult Function(ServerFailure value)? server,
    TResult Function(ClockSkewFailure value)? clockSkew,
    TResult Function(CacheFailure value)? cache,
    TResult Function(UnknownFailure value)? unknown,
    required TResult orElse(),
  }) {
    if (unknown != null) {
      return unknown(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$UnknownFailureImplToJson(
      this,
    );
  }
}

abstract class UnknownFailure implements Failure {
  const factory UnknownFailure({final String? message}) = _$UnknownFailureImpl;

  factory UnknownFailure.fromJson(Map<String, dynamic> json) =
      _$UnknownFailureImpl.fromJson;

  @override
  String? get message;

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UnknownFailureImplCopyWith<_$UnknownFailureImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
