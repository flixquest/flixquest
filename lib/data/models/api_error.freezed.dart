// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'api_error.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ApiError _$ApiErrorFromJson(Map<String, dynamic> json) {
  return _ApiError.fromJson(json);
}

/// @nodoc
mixin _$ApiError {
  String? get code => throw _privateConstructorUsedError;
  String get message => throw _privateConstructorUsedError;
  Map<String, List<String>> get errors => throw _privateConstructorUsedError;
  int? get retryAfter => throw _privateConstructorUsedError;
  ClockSkewDetails? get clockSkew => throw _privateConstructorUsedError;

  /// Serializes this ApiError to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ApiError
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ApiErrorCopyWith<ApiError> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ApiErrorCopyWith<$Res> {
  factory $ApiErrorCopyWith(ApiError value, $Res Function(ApiError) then) =
      _$ApiErrorCopyWithImpl<$Res, ApiError>;
  @useResult
  $Res call(
      {String? code,
      String message,
      Map<String, List<String>> errors,
      int? retryAfter,
      ClockSkewDetails? clockSkew});

  $ClockSkewDetailsCopyWith<$Res>? get clockSkew;
}

/// @nodoc
class _$ApiErrorCopyWithImpl<$Res, $Val extends ApiError>
    implements $ApiErrorCopyWith<$Res> {
  _$ApiErrorCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ApiError
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? code = freezed,
    Object? message = null,
    Object? errors = null,
    Object? retryAfter = freezed,
    Object? clockSkew = freezed,
  }) {
    return _then(_value.copyWith(
      code: freezed == code
          ? _value.code
          : code // ignore: cast_nullable_to_non_nullable
              as String?,
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
      errors: null == errors
          ? _value.errors
          : errors // ignore: cast_nullable_to_non_nullable
              as Map<String, List<String>>,
      retryAfter: freezed == retryAfter
          ? _value.retryAfter
          : retryAfter // ignore: cast_nullable_to_non_nullable
              as int?,
      clockSkew: freezed == clockSkew
          ? _value.clockSkew
          : clockSkew // ignore: cast_nullable_to_non_nullable
              as ClockSkewDetails?,
    ) as $Val);
  }

  /// Create a copy of ApiError
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ClockSkewDetailsCopyWith<$Res>? get clockSkew {
    if (_value.clockSkew == null) {
      return null;
    }

    return $ClockSkewDetailsCopyWith<$Res>(_value.clockSkew!, (value) {
      return _then(_value.copyWith(clockSkew: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ApiErrorImplCopyWith<$Res>
    implements $ApiErrorCopyWith<$Res> {
  factory _$$ApiErrorImplCopyWith(
          _$ApiErrorImpl value, $Res Function(_$ApiErrorImpl) then) =
      __$$ApiErrorImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String? code,
      String message,
      Map<String, List<String>> errors,
      int? retryAfter,
      ClockSkewDetails? clockSkew});

  @override
  $ClockSkewDetailsCopyWith<$Res>? get clockSkew;
}

/// @nodoc
class __$$ApiErrorImplCopyWithImpl<$Res>
    extends _$ApiErrorCopyWithImpl<$Res, _$ApiErrorImpl>
    implements _$$ApiErrorImplCopyWith<$Res> {
  __$$ApiErrorImplCopyWithImpl(
      _$ApiErrorImpl _value, $Res Function(_$ApiErrorImpl) _then)
      : super(_value, _then);

  /// Create a copy of ApiError
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? code = freezed,
    Object? message = null,
    Object? errors = null,
    Object? retryAfter = freezed,
    Object? clockSkew = freezed,
  }) {
    return _then(_$ApiErrorImpl(
      code: freezed == code
          ? _value.code
          : code // ignore: cast_nullable_to_non_nullable
              as String?,
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
      errors: null == errors
          ? _value._errors
          : errors // ignore: cast_nullable_to_non_nullable
              as Map<String, List<String>>,
      retryAfter: freezed == retryAfter
          ? _value.retryAfter
          : retryAfter // ignore: cast_nullable_to_non_nullable
              as int?,
      clockSkew: freezed == clockSkew
          ? _value.clockSkew
          : clockSkew // ignore: cast_nullable_to_non_nullable
              as ClockSkewDetails?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ApiErrorImpl implements _ApiError {
  const _$ApiErrorImpl(
      {this.code,
      this.message = 'Request failed.',
      final Map<String, List<String>> errors = const {},
      this.retryAfter,
      this.clockSkew})
      : _errors = errors;

  factory _$ApiErrorImpl.fromJson(Map<String, dynamic> json) =>
      _$$ApiErrorImplFromJson(json);

  @override
  final String? code;
  @override
  @JsonKey()
  final String message;
  final Map<String, List<String>> _errors;
  @override
  @JsonKey()
  Map<String, List<String>> get errors {
    if (_errors is EqualUnmodifiableMapView) return _errors;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_errors);
  }

  @override
  final int? retryAfter;
  @override
  final ClockSkewDetails? clockSkew;

  @override
  String toString() {
    return 'ApiError(code: $code, message: $message, errors: $errors, retryAfter: $retryAfter, clockSkew: $clockSkew)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ApiErrorImpl &&
            (identical(other.code, code) || other.code == code) &&
            (identical(other.message, message) || other.message == message) &&
            const DeepCollectionEquality().equals(other._errors, _errors) &&
            (identical(other.retryAfter, retryAfter) ||
                other.retryAfter == retryAfter) &&
            (identical(other.clockSkew, clockSkew) ||
                other.clockSkew == clockSkew));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, code, message,
      const DeepCollectionEquality().hash(_errors), retryAfter, clockSkew);

  /// Create a copy of ApiError
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ApiErrorImplCopyWith<_$ApiErrorImpl> get copyWith =>
      __$$ApiErrorImplCopyWithImpl<_$ApiErrorImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ApiErrorImplToJson(
      this,
    );
  }
}

abstract class _ApiError implements ApiError {
  const factory _ApiError(
      {final String? code,
      final String message,
      final Map<String, List<String>> errors,
      final int? retryAfter,
      final ClockSkewDetails? clockSkew}) = _$ApiErrorImpl;

  factory _ApiError.fromJson(Map<String, dynamic> json) =
      _$ApiErrorImpl.fromJson;

  @override
  String? get code;
  @override
  String get message;
  @override
  Map<String, List<String>> get errors;
  @override
  int? get retryAfter;
  @override
  ClockSkewDetails? get clockSkew;

  /// Create a copy of ApiError
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ApiErrorImplCopyWith<_$ApiErrorImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ClockSkewDetails _$ClockSkewDetailsFromJson(Map<String, dynamic> json) {
  return _ClockSkewDetails.fromJson(json);
}

/// @nodoc
mixin _$ClockSkewDetails {
  int get serverTimeUtc => throw _privateConstructorUsedError;
  int get maxDriftMs => throw _privateConstructorUsedError;

  /// Serializes this ClockSkewDetails to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ClockSkewDetails
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ClockSkewDetailsCopyWith<ClockSkewDetails> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ClockSkewDetailsCopyWith<$Res> {
  factory $ClockSkewDetailsCopyWith(
          ClockSkewDetails value, $Res Function(ClockSkewDetails) then) =
      _$ClockSkewDetailsCopyWithImpl<$Res, ClockSkewDetails>;
  @useResult
  $Res call({int serverTimeUtc, int maxDriftMs});
}

/// @nodoc
class _$ClockSkewDetailsCopyWithImpl<$Res, $Val extends ClockSkewDetails>
    implements $ClockSkewDetailsCopyWith<$Res> {
  _$ClockSkewDetailsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ClockSkewDetails
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? serverTimeUtc = null,
    Object? maxDriftMs = null,
  }) {
    return _then(_value.copyWith(
      serverTimeUtc: null == serverTimeUtc
          ? _value.serverTimeUtc
          : serverTimeUtc // ignore: cast_nullable_to_non_nullable
              as int,
      maxDriftMs: null == maxDriftMs
          ? _value.maxDriftMs
          : maxDriftMs // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ClockSkewDetailsImplCopyWith<$Res>
    implements $ClockSkewDetailsCopyWith<$Res> {
  factory _$$ClockSkewDetailsImplCopyWith(_$ClockSkewDetailsImpl value,
          $Res Function(_$ClockSkewDetailsImpl) then) =
      __$$ClockSkewDetailsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int serverTimeUtc, int maxDriftMs});
}

/// @nodoc
class __$$ClockSkewDetailsImplCopyWithImpl<$Res>
    extends _$ClockSkewDetailsCopyWithImpl<$Res, _$ClockSkewDetailsImpl>
    implements _$$ClockSkewDetailsImplCopyWith<$Res> {
  __$$ClockSkewDetailsImplCopyWithImpl(_$ClockSkewDetailsImpl _value,
      $Res Function(_$ClockSkewDetailsImpl) _then)
      : super(_value, _then);

  /// Create a copy of ClockSkewDetails
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? serverTimeUtc = null,
    Object? maxDriftMs = null,
  }) {
    return _then(_$ClockSkewDetailsImpl(
      serverTimeUtc: null == serverTimeUtc
          ? _value.serverTimeUtc
          : serverTimeUtc // ignore: cast_nullable_to_non_nullable
              as int,
      maxDriftMs: null == maxDriftMs
          ? _value.maxDriftMs
          : maxDriftMs // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ClockSkewDetailsImpl implements _ClockSkewDetails {
  const _$ClockSkewDetailsImpl(
      {required this.serverTimeUtc, required this.maxDriftMs});

  factory _$ClockSkewDetailsImpl.fromJson(Map<String, dynamic> json) =>
      _$$ClockSkewDetailsImplFromJson(json);

  @override
  final int serverTimeUtc;
  @override
  final int maxDriftMs;

  @override
  String toString() {
    return 'ClockSkewDetails(serverTimeUtc: $serverTimeUtc, maxDriftMs: $maxDriftMs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ClockSkewDetailsImpl &&
            (identical(other.serverTimeUtc, serverTimeUtc) ||
                other.serverTimeUtc == serverTimeUtc) &&
            (identical(other.maxDriftMs, maxDriftMs) ||
                other.maxDriftMs == maxDriftMs));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, serverTimeUtc, maxDriftMs);

  /// Create a copy of ClockSkewDetails
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ClockSkewDetailsImplCopyWith<_$ClockSkewDetailsImpl> get copyWith =>
      __$$ClockSkewDetailsImplCopyWithImpl<_$ClockSkewDetailsImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ClockSkewDetailsImplToJson(
      this,
    );
  }
}

abstract class _ClockSkewDetails implements ClockSkewDetails {
  const factory _ClockSkewDetails(
      {required final int serverTimeUtc,
      required final int maxDriftMs}) = _$ClockSkewDetailsImpl;

  factory _ClockSkewDetails.fromJson(Map<String, dynamic> json) =
      _$ClockSkewDetailsImpl.fromJson;

  @override
  int get serverTimeUtc;
  @override
  int get maxDriftMs;

  /// Create a copy of ClockSkewDetails
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ClockSkewDetailsImplCopyWith<_$ClockSkewDetailsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
