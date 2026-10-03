import 'package:flixquest/core/error/failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'result.freezed.dart';
part 'result.g.dart';

@Freezed(genericArgumentFactories: true, map: FreezedMapOptions.none)
sealed class Result<T> with _$Result<T> {
  const Result._();
  const factory Result.ok(T value) = Ok<T>;
  const factory Result.err(Failure failure) = Err<T>;

  factory Result.fromJson(
    Map<String, dynamic> json,
    T Function(Object?) fromJsonT,
  ) =>
      _$ResultFromJson(json, fromJsonT);

  Result<R> map<R>(R Function(T) transform) => when(
        ok: (value) => Result<R>.ok(transform(value)),
        err: (failure) => Result<R>.err(failure),
      );

  T getOrElse(T Function(Failure) fallback) => when(
        ok: (value) => value,
        err: fallback,
      );
}
