// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Result<T> _$ResultFromJson<T>(
    Map<String, dynamic> json, T Function(Object?) fromJsonT) {
  switch (json['runtimeType']) {
    case 'ok':
      return Ok<T>.fromJson(json, fromJsonT);
    case 'err':
      return Err<T>.fromJson(json, fromJsonT);

    default:
      throw CheckedFromJsonException(json, 'runtimeType', 'Result',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$Result<T> {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(T value) ok,
    required TResult Function(Failure failure) err,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(T value)? ok,
    TResult? Function(Failure failure)? err,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(T value)? ok,
    TResult Function(Failure failure)? err,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  /// Serializes this Result to a JSON map.
  Map<String, dynamic> toJson(Object? Function(T) toJsonT) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ResultCopyWith<T, $Res> {
  factory $ResultCopyWith(Result<T> value, $Res Function(Result<T>) then) =
      _$ResultCopyWithImpl<T, $Res, Result<T>>;
}

/// @nodoc
class _$ResultCopyWithImpl<T, $Res, $Val extends Result<T>>
    implements $ResultCopyWith<T, $Res> {
  _$ResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Result
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$OkImplCopyWith<T, $Res> {
  factory _$$OkImplCopyWith(
          _$OkImpl<T> value, $Res Function(_$OkImpl<T>) then) =
      __$$OkImplCopyWithImpl<T, $Res>;
  @useResult
  $Res call({T value});
}

/// @nodoc
class __$$OkImplCopyWithImpl<T, $Res>
    extends _$ResultCopyWithImpl<T, $Res, _$OkImpl<T>>
    implements _$$OkImplCopyWith<T, $Res> {
  __$$OkImplCopyWithImpl(_$OkImpl<T> _value, $Res Function(_$OkImpl<T>) _then)
      : super(_value, _then);

  /// Create a copy of Result
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? value = freezed,
  }) {
    return _then(_$OkImpl<T>(
      freezed == value
          ? _value.value
          : value // ignore: cast_nullable_to_non_nullable
              as T,
    ));
  }
}

/// @nodoc
@JsonSerializable(genericArgumentFactories: true)
class _$OkImpl<T> extends Ok<T> {
  const _$OkImpl(this.value, {final String? $type})
      : $type = $type ?? 'ok',
        super._();

  factory _$OkImpl.fromJson(
          Map<String, dynamic> json, T Function(Object?) fromJsonT) =>
      _$$OkImplFromJson(json, fromJsonT);

  @override
  final T value;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'Result<$T>.ok(value: $value)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OkImpl<T> &&
            const DeepCollectionEquality().equals(other.value, value));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(value));

  /// Create a copy of Result
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OkImplCopyWith<T, _$OkImpl<T>> get copyWith =>
      __$$OkImplCopyWithImpl<T, _$OkImpl<T>>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(T value) ok,
    required TResult Function(Failure failure) err,
  }) {
    return ok(value);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(T value)? ok,
    TResult? Function(Failure failure)? err,
  }) {
    return ok?.call(value);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(T value)? ok,
    TResult Function(Failure failure)? err,
    required TResult orElse(),
  }) {
    if (ok != null) {
      return ok(value);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson(Object? Function(T) toJsonT) {
    return _$$OkImplToJson<T>(this, toJsonT);
  }
}

abstract class Ok<T> extends Result<T> {
  const factory Ok(final T value) = _$OkImpl<T>;
  const Ok._() : super._();

  factory Ok.fromJson(
          Map<String, dynamic> json, T Function(Object?) fromJsonT) =
      _$OkImpl<T>.fromJson;

  T get value;

  /// Create a copy of Result
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OkImplCopyWith<T, _$OkImpl<T>> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ErrImplCopyWith<T, $Res> {
  factory _$$ErrImplCopyWith(
          _$ErrImpl<T> value, $Res Function(_$ErrImpl<T>) then) =
      __$$ErrImplCopyWithImpl<T, $Res>;
  @useResult
  $Res call({Failure failure});

  $FailureCopyWith<$Res> get failure;
}

/// @nodoc
class __$$ErrImplCopyWithImpl<T, $Res>
    extends _$ResultCopyWithImpl<T, $Res, _$ErrImpl<T>>
    implements _$$ErrImplCopyWith<T, $Res> {
  __$$ErrImplCopyWithImpl(
      _$ErrImpl<T> _value, $Res Function(_$ErrImpl<T>) _then)
      : super(_value, _then);

  /// Create a copy of Result
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? failure = null,
  }) {
    return _then(_$ErrImpl<T>(
      null == failure
          ? _value.failure
          : failure // ignore: cast_nullable_to_non_nullable
              as Failure,
    ));
  }

  /// Create a copy of Result
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FailureCopyWith<$Res> get failure {
    return $FailureCopyWith<$Res>(_value.failure, (value) {
      return _then(_value.copyWith(failure: value));
    });
  }
}

/// @nodoc
@JsonSerializable(genericArgumentFactories: true)
class _$ErrImpl<T> extends Err<T> {
  const _$ErrImpl(this.failure, {final String? $type})
      : $type = $type ?? 'err',
        super._();

  factory _$ErrImpl.fromJson(
          Map<String, dynamic> json, T Function(Object?) fromJsonT) =>
      _$$ErrImplFromJson(json, fromJsonT);

  @override
  final Failure failure;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'Result<$T>.err(failure: $failure)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ErrImpl<T> &&
            (identical(other.failure, failure) || other.failure == failure));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, failure);

  /// Create a copy of Result
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ErrImplCopyWith<T, _$ErrImpl<T>> get copyWith =>
      __$$ErrImplCopyWithImpl<T, _$ErrImpl<T>>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(T value) ok,
    required TResult Function(Failure failure) err,
  }) {
    return err(failure);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(T value)? ok,
    TResult? Function(Failure failure)? err,
  }) {
    return err?.call(failure);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(T value)? ok,
    TResult Function(Failure failure)? err,
    required TResult orElse(),
  }) {
    if (err != null) {
      return err(failure);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson(Object? Function(T) toJsonT) {
    return _$$ErrImplToJson<T>(this, toJsonT);
  }
}

abstract class Err<T> extends Result<T> {
  const factory Err(final Failure failure) = _$ErrImpl<T>;
  const Err._() : super._();

  factory Err.fromJson(
          Map<String, dynamic> json, T Function(Object?) fromJsonT) =
      _$ErrImpl<T>.fromJson;

  Failure get failure;

  /// Create a copy of Result
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ErrImplCopyWith<T, _$ErrImpl<T>> get copyWith =>
      throw _privateConstructorUsedError;
}
