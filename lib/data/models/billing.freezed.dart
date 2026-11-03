// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'billing.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

PlusPlan _$PlusPlanFromJson(Map<String, dynamic> json) {
  return _PlusPlan.fromJson(json);
}

/// @nodoc
mixin _$PlusPlan {
  String get code => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'amount_cents')
  int get amountCents => throw _privateConstructorUsedError;
  String get currency => throw _privateConstructorUsedError;
  @JsonKey(name: 'interval_days')
  int get intervalDays => throw _privateConstructorUsedError;
  @JsonKey(name: 'terms_version')
  String get termsVersion => throw _privateConstructorUsedError;

  /// Serializes this PlusPlan to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PlusPlan
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlusPlanCopyWith<PlusPlan> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlusPlanCopyWith<$Res> {
  factory $PlusPlanCopyWith(PlusPlan value, $Res Function(PlusPlan) then) =
      _$PlusPlanCopyWithImpl<$Res, PlusPlan>;
  @useResult
  $Res call(
      {String code,
      String name,
      @JsonKey(name: 'amount_cents') int amountCents,
      String currency,
      @JsonKey(name: 'interval_days') int intervalDays,
      @JsonKey(name: 'terms_version') String termsVersion});
}

/// @nodoc
class _$PlusPlanCopyWithImpl<$Res, $Val extends PlusPlan>
    implements $PlusPlanCopyWith<$Res> {
  _$PlusPlanCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlusPlan
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? code = null,
    Object? name = null,
    Object? amountCents = null,
    Object? currency = null,
    Object? intervalDays = null,
    Object? termsVersion = null,
  }) {
    return _then(_value.copyWith(
      code: null == code
          ? _value.code
          : code // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      amountCents: null == amountCents
          ? _value.amountCents
          : amountCents // ignore: cast_nullable_to_non_nullable
              as int,
      currency: null == currency
          ? _value.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
      intervalDays: null == intervalDays
          ? _value.intervalDays
          : intervalDays // ignore: cast_nullable_to_non_nullable
              as int,
      termsVersion: null == termsVersion
          ? _value.termsVersion
          : termsVersion // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PlusPlanImplCopyWith<$Res>
    implements $PlusPlanCopyWith<$Res> {
  factory _$$PlusPlanImplCopyWith(
          _$PlusPlanImpl value, $Res Function(_$PlusPlanImpl) then) =
      __$$PlusPlanImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String code,
      String name,
      @JsonKey(name: 'amount_cents') int amountCents,
      String currency,
      @JsonKey(name: 'interval_days') int intervalDays,
      @JsonKey(name: 'terms_version') String termsVersion});
}

/// @nodoc
class __$$PlusPlanImplCopyWithImpl<$Res>
    extends _$PlusPlanCopyWithImpl<$Res, _$PlusPlanImpl>
    implements _$$PlusPlanImplCopyWith<$Res> {
  __$$PlusPlanImplCopyWithImpl(
      _$PlusPlanImpl _value, $Res Function(_$PlusPlanImpl) _then)
      : super(_value, _then);

  /// Create a copy of PlusPlan
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? code = null,
    Object? name = null,
    Object? amountCents = null,
    Object? currency = null,
    Object? intervalDays = null,
    Object? termsVersion = null,
  }) {
    return _then(_$PlusPlanImpl(
      code: null == code
          ? _value.code
          : code // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      amountCents: null == amountCents
          ? _value.amountCents
          : amountCents // ignore: cast_nullable_to_non_nullable
              as int,
      currency: null == currency
          ? _value.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
      intervalDays: null == intervalDays
          ? _value.intervalDays
          : intervalDays // ignore: cast_nullable_to_non_nullable
              as int,
      termsVersion: null == termsVersion
          ? _value.termsVersion
          : termsVersion // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PlusPlanImpl implements _PlusPlan {
  const _$PlusPlanImpl(
      {required this.code,
      this.name = 'FlixQuest Plus',
      @JsonKey(name: 'amount_cents') required this.amountCents,
      this.currency = 'USD',
      @JsonKey(name: 'interval_days') required this.intervalDays,
      @JsonKey(name: 'terms_version') required this.termsVersion});

  factory _$PlusPlanImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlusPlanImplFromJson(json);

  @override
  final String code;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey(name: 'amount_cents')
  final int amountCents;
  @override
  @JsonKey()
  final String currency;
  @override
  @JsonKey(name: 'interval_days')
  final int intervalDays;
  @override
  @JsonKey(name: 'terms_version')
  final String termsVersion;

  @override
  String toString() {
    return 'PlusPlan(code: $code, name: $name, amountCents: $amountCents, currency: $currency, intervalDays: $intervalDays, termsVersion: $termsVersion)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlusPlanImpl &&
            (identical(other.code, code) || other.code == code) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.amountCents, amountCents) ||
                other.amountCents == amountCents) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.intervalDays, intervalDays) ||
                other.intervalDays == intervalDays) &&
            (identical(other.termsVersion, termsVersion) ||
                other.termsVersion == termsVersion));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, code, name, amountCents,
      currency, intervalDays, termsVersion);

  /// Create a copy of PlusPlan
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlusPlanImplCopyWith<_$PlusPlanImpl> get copyWith =>
      __$$PlusPlanImplCopyWithImpl<_$PlusPlanImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PlusPlanImplToJson(
      this,
    );
  }
}

abstract class _PlusPlan implements PlusPlan {
  const factory _PlusPlan(
          {required final String code,
          final String name,
          @JsonKey(name: 'amount_cents') required final int amountCents,
          final String currency,
          @JsonKey(name: 'interval_days') required final int intervalDays,
          @JsonKey(name: 'terms_version') required final String termsVersion}) =
      _$PlusPlanImpl;

  factory _PlusPlan.fromJson(Map<String, dynamic> json) =
      _$PlusPlanImpl.fromJson;

  @override
  String get code;
  @override
  String get name;
  @override
  @JsonKey(name: 'amount_cents')
  int get amountCents;
  @override
  String get currency;
  @override
  @JsonKey(name: 'interval_days')
  int get intervalDays;
  @override
  @JsonKey(name: 'terms_version')
  String get termsVersion;

  /// Create a copy of PlusPlan
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlusPlanImplCopyWith<_$PlusPlanImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TopupLimits _$TopupLimitsFromJson(Map<String, dynamic> json) {
  return _TopupLimits.fromJson(json);
}

/// @nodoc
mixin _$TopupLimits {
  @JsonKey(name: 'topup_min_cents')
  int get minCents => throw _privateConstructorUsedError;
  @JsonKey(name: 'topup_max_cents')
  int get maxCents => throw _privateConstructorUsedError;
  @JsonKey(name: 'suggested_topups_cents')
  List<int> get suggestedCents => throw _privateConstructorUsedError;

  /// Serializes this TopupLimits to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TopupLimits
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TopupLimitsCopyWith<TopupLimits> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TopupLimitsCopyWith<$Res> {
  factory $TopupLimitsCopyWith(
          TopupLimits value, $Res Function(TopupLimits) then) =
      _$TopupLimitsCopyWithImpl<$Res, TopupLimits>;
  @useResult
  $Res call(
      {@JsonKey(name: 'topup_min_cents') int minCents,
      @JsonKey(name: 'topup_max_cents') int maxCents,
      @JsonKey(name: 'suggested_topups_cents') List<int> suggestedCents});
}

/// @nodoc
class _$TopupLimitsCopyWithImpl<$Res, $Val extends TopupLimits>
    implements $TopupLimitsCopyWith<$Res> {
  _$TopupLimitsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TopupLimits
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? minCents = null,
    Object? maxCents = null,
    Object? suggestedCents = null,
  }) {
    return _then(_value.copyWith(
      minCents: null == minCents
          ? _value.minCents
          : minCents // ignore: cast_nullable_to_non_nullable
              as int,
      maxCents: null == maxCents
          ? _value.maxCents
          : maxCents // ignore: cast_nullable_to_non_nullable
              as int,
      suggestedCents: null == suggestedCents
          ? _value.suggestedCents
          : suggestedCents // ignore: cast_nullable_to_non_nullable
              as List<int>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TopupLimitsImplCopyWith<$Res>
    implements $TopupLimitsCopyWith<$Res> {
  factory _$$TopupLimitsImplCopyWith(
          _$TopupLimitsImpl value, $Res Function(_$TopupLimitsImpl) then) =
      __$$TopupLimitsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'topup_min_cents') int minCents,
      @JsonKey(name: 'topup_max_cents') int maxCents,
      @JsonKey(name: 'suggested_topups_cents') List<int> suggestedCents});
}

/// @nodoc
class __$$TopupLimitsImplCopyWithImpl<$Res>
    extends _$TopupLimitsCopyWithImpl<$Res, _$TopupLimitsImpl>
    implements _$$TopupLimitsImplCopyWith<$Res> {
  __$$TopupLimitsImplCopyWithImpl(
      _$TopupLimitsImpl _value, $Res Function(_$TopupLimitsImpl) _then)
      : super(_value, _then);

  /// Create a copy of TopupLimits
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? minCents = null,
    Object? maxCents = null,
    Object? suggestedCents = null,
  }) {
    return _then(_$TopupLimitsImpl(
      minCents: null == minCents
          ? _value.minCents
          : minCents // ignore: cast_nullable_to_non_nullable
              as int,
      maxCents: null == maxCents
          ? _value.maxCents
          : maxCents // ignore: cast_nullable_to_non_nullable
              as int,
      suggestedCents: null == suggestedCents
          ? _value._suggestedCents
          : suggestedCents // ignore: cast_nullable_to_non_nullable
              as List<int>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TopupLimitsImpl extends _TopupLimits {
  const _$TopupLimitsImpl(
      {@JsonKey(name: 'topup_min_cents') this.minCents = 200,
      @JsonKey(name: 'topup_max_cents') this.maxCents = 50000,
      @JsonKey(name: 'suggested_topups_cents')
      final List<int> suggestedCents = const <int>[500, 1000, 2000]})
      : _suggestedCents = suggestedCents,
        super._();

  factory _$TopupLimitsImpl.fromJson(Map<String, dynamic> json) =>
      _$$TopupLimitsImplFromJson(json);

  @override
  @JsonKey(name: 'topup_min_cents')
  final int minCents;
  @override
  @JsonKey(name: 'topup_max_cents')
  final int maxCents;
  final List<int> _suggestedCents;
  @override
  @JsonKey(name: 'suggested_topups_cents')
  List<int> get suggestedCents {
    if (_suggestedCents is EqualUnmodifiableListView) return _suggestedCents;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_suggestedCents);
  }

  @override
  String toString() {
    return 'TopupLimits(minCents: $minCents, maxCents: $maxCents, suggestedCents: $suggestedCents)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TopupLimitsImpl &&
            (identical(other.minCents, minCents) ||
                other.minCents == minCents) &&
            (identical(other.maxCents, maxCents) ||
                other.maxCents == maxCents) &&
            const DeepCollectionEquality()
                .equals(other._suggestedCents, _suggestedCents));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, minCents, maxCents,
      const DeepCollectionEquality().hash(_suggestedCents));

  /// Create a copy of TopupLimits
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TopupLimitsImplCopyWith<_$TopupLimitsImpl> get copyWith =>
      __$$TopupLimitsImplCopyWithImpl<_$TopupLimitsImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TopupLimitsImplToJson(
      this,
    );
  }
}

abstract class _TopupLimits extends TopupLimits {
  const factory _TopupLimits(
      {@JsonKey(name: 'topup_min_cents') final int minCents,
      @JsonKey(name: 'topup_max_cents') final int maxCents,
      @JsonKey(name: 'suggested_topups_cents')
      final List<int> suggestedCents}) = _$TopupLimitsImpl;
  const _TopupLimits._() : super._();

  factory _TopupLimits.fromJson(Map<String, dynamic> json) =
      _$TopupLimitsImpl.fromJson;

  @override
  @JsonKey(name: 'topup_min_cents')
  int get minCents;
  @override
  @JsonKey(name: 'topup_max_cents')
  int get maxCents;
  @override
  @JsonKey(name: 'suggested_topups_cents')
  List<int> get suggestedCents;

  /// Create a copy of TopupLimits
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TopupLimitsImplCopyWith<_$TopupLimitsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PatreonOffer _$PatreonOfferFromJson(Map<String, dynamic> json) {
  return _PatreonOffer.fromJson(json);
}

/// @nodoc
mixin _$PatreonOffer {
  bool get enabled => throw _privateConstructorUsedError;
  @JsonKey(name: 'pledge_url')
  String? get pledgeUrl => throw _privateConstructorUsedError;

  /// The monthly pledge that pays for every Plus period on its own.
  @JsonKey(name: 'recommended_cents')
  int get recommendedCents => throw _privateConstructorUsedError;

  /// Serializes this PatreonOffer to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PatreonOffer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PatreonOfferCopyWith<PatreonOffer> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PatreonOfferCopyWith<$Res> {
  factory $PatreonOfferCopyWith(
          PatreonOffer value, $Res Function(PatreonOffer) then) =
      _$PatreonOfferCopyWithImpl<$Res, PatreonOffer>;
  @useResult
  $Res call(
      {bool enabled,
      @JsonKey(name: 'pledge_url') String? pledgeUrl,
      @JsonKey(name: 'recommended_cents') int recommendedCents});
}

/// @nodoc
class _$PatreonOfferCopyWithImpl<$Res, $Val extends PatreonOffer>
    implements $PatreonOfferCopyWith<$Res> {
  _$PatreonOfferCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PatreonOffer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? enabled = null,
    Object? pledgeUrl = freezed,
    Object? recommendedCents = null,
  }) {
    return _then(_value.copyWith(
      enabled: null == enabled
          ? _value.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      pledgeUrl: freezed == pledgeUrl
          ? _value.pledgeUrl
          : pledgeUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      recommendedCents: null == recommendedCents
          ? _value.recommendedCents
          : recommendedCents // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PatreonOfferImplCopyWith<$Res>
    implements $PatreonOfferCopyWith<$Res> {
  factory _$$PatreonOfferImplCopyWith(
          _$PatreonOfferImpl value, $Res Function(_$PatreonOfferImpl) then) =
      __$$PatreonOfferImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool enabled,
      @JsonKey(name: 'pledge_url') String? pledgeUrl,
      @JsonKey(name: 'recommended_cents') int recommendedCents});
}

/// @nodoc
class __$$PatreonOfferImplCopyWithImpl<$Res>
    extends _$PatreonOfferCopyWithImpl<$Res, _$PatreonOfferImpl>
    implements _$$PatreonOfferImplCopyWith<$Res> {
  __$$PatreonOfferImplCopyWithImpl(
      _$PatreonOfferImpl _value, $Res Function(_$PatreonOfferImpl) _then)
      : super(_value, _then);

  /// Create a copy of PatreonOffer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? enabled = null,
    Object? pledgeUrl = freezed,
    Object? recommendedCents = null,
  }) {
    return _then(_$PatreonOfferImpl(
      enabled: null == enabled
          ? _value.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      pledgeUrl: freezed == pledgeUrl
          ? _value.pledgeUrl
          : pledgeUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      recommendedCents: null == recommendedCents
          ? _value.recommendedCents
          : recommendedCents // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PatreonOfferImpl implements _PatreonOffer {
  const _$PatreonOfferImpl(
      {this.enabled = false,
      @JsonKey(name: 'pledge_url') this.pledgeUrl,
      @JsonKey(name: 'recommended_cents') this.recommendedCents = 200});

  factory _$PatreonOfferImpl.fromJson(Map<String, dynamic> json) =>
      _$$PatreonOfferImplFromJson(json);

  @override
  @JsonKey()
  final bool enabled;
  @override
  @JsonKey(name: 'pledge_url')
  final String? pledgeUrl;

  /// The monthly pledge that pays for every Plus period on its own.
  @override
  @JsonKey(name: 'recommended_cents')
  final int recommendedCents;

  @override
  String toString() {
    return 'PatreonOffer(enabled: $enabled, pledgeUrl: $pledgeUrl, recommendedCents: $recommendedCents)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PatreonOfferImpl &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            (identical(other.pledgeUrl, pledgeUrl) ||
                other.pledgeUrl == pledgeUrl) &&
            (identical(other.recommendedCents, recommendedCents) ||
                other.recommendedCents == recommendedCents));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, enabled, pledgeUrl, recommendedCents);

  /// Create a copy of PatreonOffer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PatreonOfferImplCopyWith<_$PatreonOfferImpl> get copyWith =>
      __$$PatreonOfferImplCopyWithImpl<_$PatreonOfferImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PatreonOfferImplToJson(
      this,
    );
  }
}

abstract class _PatreonOffer implements PatreonOffer {
  const factory _PatreonOffer(
          {final bool enabled,
          @JsonKey(name: 'pledge_url') final String? pledgeUrl,
          @JsonKey(name: 'recommended_cents') final int recommendedCents}) =
      _$PatreonOfferImpl;

  factory _PatreonOffer.fromJson(Map<String, dynamic> json) =
      _$PatreonOfferImpl.fromJson;

  @override
  bool get enabled;
  @override
  @JsonKey(name: 'pledge_url')
  String? get pledgeUrl;

  /// The monthly pledge that pays for every Plus period on its own.
  @override
  @JsonKey(name: 'recommended_cents')
  int get recommendedCents;

  /// Create a copy of PatreonOffer
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PatreonOfferImplCopyWith<_$PatreonOfferImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PlusCatalog _$PlusCatalogFromJson(Map<String, dynamic> json) {
  return _PlusCatalog.fromJson(json);
}

/// @nodoc
mixin _$PlusCatalog {
  @JsonKey(name: 'purchases_enabled')
  bool get purchasesEnabled => throw _privateConstructorUsedError;
  List<PlusPlan> get plans => throw _privateConstructorUsedError;
  TopupLimits get wallet => throw _privateConstructorUsedError;
  PatreonOffer get patreon => throw _privateConstructorUsedError;

  /// Serializes this PlusCatalog to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PlusCatalog
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlusCatalogCopyWith<PlusCatalog> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlusCatalogCopyWith<$Res> {
  factory $PlusCatalogCopyWith(
          PlusCatalog value, $Res Function(PlusCatalog) then) =
      _$PlusCatalogCopyWithImpl<$Res, PlusCatalog>;
  @useResult
  $Res call(
      {@JsonKey(name: 'purchases_enabled') bool purchasesEnabled,
      List<PlusPlan> plans,
      TopupLimits wallet,
      PatreonOffer patreon});

  $TopupLimitsCopyWith<$Res> get wallet;
  $PatreonOfferCopyWith<$Res> get patreon;
}

/// @nodoc
class _$PlusCatalogCopyWithImpl<$Res, $Val extends PlusCatalog>
    implements $PlusCatalogCopyWith<$Res> {
  _$PlusCatalogCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlusCatalog
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? purchasesEnabled = null,
    Object? plans = null,
    Object? wallet = null,
    Object? patreon = null,
  }) {
    return _then(_value.copyWith(
      purchasesEnabled: null == purchasesEnabled
          ? _value.purchasesEnabled
          : purchasesEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      plans: null == plans
          ? _value.plans
          : plans // ignore: cast_nullable_to_non_nullable
              as List<PlusPlan>,
      wallet: null == wallet
          ? _value.wallet
          : wallet // ignore: cast_nullable_to_non_nullable
              as TopupLimits,
      patreon: null == patreon
          ? _value.patreon
          : patreon // ignore: cast_nullable_to_non_nullable
              as PatreonOffer,
    ) as $Val);
  }

  /// Create a copy of PlusCatalog
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TopupLimitsCopyWith<$Res> get wallet {
    return $TopupLimitsCopyWith<$Res>(_value.wallet, (value) {
      return _then(_value.copyWith(wallet: value) as $Val);
    });
  }

  /// Create a copy of PlusCatalog
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PatreonOfferCopyWith<$Res> get patreon {
    return $PatreonOfferCopyWith<$Res>(_value.patreon, (value) {
      return _then(_value.copyWith(patreon: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$PlusCatalogImplCopyWith<$Res>
    implements $PlusCatalogCopyWith<$Res> {
  factory _$$PlusCatalogImplCopyWith(
          _$PlusCatalogImpl value, $Res Function(_$PlusCatalogImpl) then) =
      __$$PlusCatalogImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'purchases_enabled') bool purchasesEnabled,
      List<PlusPlan> plans,
      TopupLimits wallet,
      PatreonOffer patreon});

  @override
  $TopupLimitsCopyWith<$Res> get wallet;
  @override
  $PatreonOfferCopyWith<$Res> get patreon;
}

/// @nodoc
class __$$PlusCatalogImplCopyWithImpl<$Res>
    extends _$PlusCatalogCopyWithImpl<$Res, _$PlusCatalogImpl>
    implements _$$PlusCatalogImplCopyWith<$Res> {
  __$$PlusCatalogImplCopyWithImpl(
      _$PlusCatalogImpl _value, $Res Function(_$PlusCatalogImpl) _then)
      : super(_value, _then);

  /// Create a copy of PlusCatalog
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? purchasesEnabled = null,
    Object? plans = null,
    Object? wallet = null,
    Object? patreon = null,
  }) {
    return _then(_$PlusCatalogImpl(
      purchasesEnabled: null == purchasesEnabled
          ? _value.purchasesEnabled
          : purchasesEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      plans: null == plans
          ? _value._plans
          : plans // ignore: cast_nullable_to_non_nullable
              as List<PlusPlan>,
      wallet: null == wallet
          ? _value.wallet
          : wallet // ignore: cast_nullable_to_non_nullable
              as TopupLimits,
      patreon: null == patreon
          ? _value.patreon
          : patreon // ignore: cast_nullable_to_non_nullable
              as PatreonOffer,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PlusCatalogImpl extends _PlusCatalog {
  const _$PlusCatalogImpl(
      {@JsonKey(name: 'purchases_enabled') this.purchasesEnabled = false,
      final List<PlusPlan> plans = const <PlusPlan>[],
      this.wallet = const TopupLimits(),
      this.patreon = const PatreonOffer()})
      : _plans = plans,
        super._();

  factory _$PlusCatalogImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlusCatalogImplFromJson(json);

  @override
  @JsonKey(name: 'purchases_enabled')
  final bool purchasesEnabled;
  final List<PlusPlan> _plans;
  @override
  @JsonKey()
  List<PlusPlan> get plans {
    if (_plans is EqualUnmodifiableListView) return _plans;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_plans);
  }

  @override
  @JsonKey()
  final TopupLimits wallet;
  @override
  @JsonKey()
  final PatreonOffer patreon;

  @override
  String toString() {
    return 'PlusCatalog(purchasesEnabled: $purchasesEnabled, plans: $plans, wallet: $wallet, patreon: $patreon)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlusCatalogImpl &&
            (identical(other.purchasesEnabled, purchasesEnabled) ||
                other.purchasesEnabled == purchasesEnabled) &&
            const DeepCollectionEquality().equals(other._plans, _plans) &&
            (identical(other.wallet, wallet) || other.wallet == wallet) &&
            (identical(other.patreon, patreon) || other.patreon == patreon));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, purchasesEnabled,
      const DeepCollectionEquality().hash(_plans), wallet, patreon);

  /// Create a copy of PlusCatalog
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlusCatalogImplCopyWith<_$PlusCatalogImpl> get copyWith =>
      __$$PlusCatalogImplCopyWithImpl<_$PlusCatalogImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PlusCatalogImplToJson(
      this,
    );
  }
}

abstract class _PlusCatalog extends PlusCatalog {
  const factory _PlusCatalog(
      {@JsonKey(name: 'purchases_enabled') final bool purchasesEnabled,
      final List<PlusPlan> plans,
      final TopupLimits wallet,
      final PatreonOffer patreon}) = _$PlusCatalogImpl;
  const _PlusCatalog._() : super._();

  factory _PlusCatalog.fromJson(Map<String, dynamic> json) =
      _$PlusCatalogImpl.fromJson;

  @override
  @JsonKey(name: 'purchases_enabled')
  bool get purchasesEnabled;
  @override
  List<PlusPlan> get plans;
  @override
  TopupLimits get wallet;
  @override
  PatreonOffer get patreon;

  /// Create a copy of PlusCatalog
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlusCatalogImplCopyWith<_$PlusCatalogImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PlusEntitlement _$PlusEntitlementFromJson(Map<String, dynamic> json) {
  return _PlusEntitlement.fromJson(json);
}

/// @nodoc
mixin _$PlusEntitlement {
  @JsonKey(name: 'ad_free')
  bool get adFree => throw _privateConstructorUsedError;
  @JsonKey(name: 'starts_at')
  DateTime? get startsAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'expires_at')
  DateTime? get expiresAt => throw _privateConstructorUsedError;
  int get revision => throw _privateConstructorUsedError;

  /// Serializes this PlusEntitlement to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PlusEntitlement
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlusEntitlementCopyWith<PlusEntitlement> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlusEntitlementCopyWith<$Res> {
  factory $PlusEntitlementCopyWith(
          PlusEntitlement value, $Res Function(PlusEntitlement) then) =
      _$PlusEntitlementCopyWithImpl<$Res, PlusEntitlement>;
  @useResult
  $Res call(
      {@JsonKey(name: 'ad_free') bool adFree,
      @JsonKey(name: 'starts_at') DateTime? startsAt,
      @JsonKey(name: 'expires_at') DateTime? expiresAt,
      int revision});
}

/// @nodoc
class _$PlusEntitlementCopyWithImpl<$Res, $Val extends PlusEntitlement>
    implements $PlusEntitlementCopyWith<$Res> {
  _$PlusEntitlementCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlusEntitlement
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? adFree = null,
    Object? startsAt = freezed,
    Object? expiresAt = freezed,
    Object? revision = null,
  }) {
    return _then(_value.copyWith(
      adFree: null == adFree
          ? _value.adFree
          : adFree // ignore: cast_nullable_to_non_nullable
              as bool,
      startsAt: freezed == startsAt
          ? _value.startsAt
          : startsAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      expiresAt: freezed == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      revision: null == revision
          ? _value.revision
          : revision // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PlusEntitlementImplCopyWith<$Res>
    implements $PlusEntitlementCopyWith<$Res> {
  factory _$$PlusEntitlementImplCopyWith(_$PlusEntitlementImpl value,
          $Res Function(_$PlusEntitlementImpl) then) =
      __$$PlusEntitlementImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'ad_free') bool adFree,
      @JsonKey(name: 'starts_at') DateTime? startsAt,
      @JsonKey(name: 'expires_at') DateTime? expiresAt,
      int revision});
}

/// @nodoc
class __$$PlusEntitlementImplCopyWithImpl<$Res>
    extends _$PlusEntitlementCopyWithImpl<$Res, _$PlusEntitlementImpl>
    implements _$$PlusEntitlementImplCopyWith<$Res> {
  __$$PlusEntitlementImplCopyWithImpl(
      _$PlusEntitlementImpl _value, $Res Function(_$PlusEntitlementImpl) _then)
      : super(_value, _then);

  /// Create a copy of PlusEntitlement
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? adFree = null,
    Object? startsAt = freezed,
    Object? expiresAt = freezed,
    Object? revision = null,
  }) {
    return _then(_$PlusEntitlementImpl(
      adFree: null == adFree
          ? _value.adFree
          : adFree // ignore: cast_nullable_to_non_nullable
              as bool,
      startsAt: freezed == startsAt
          ? _value.startsAt
          : startsAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      expiresAt: freezed == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      revision: null == revision
          ? _value.revision
          : revision // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PlusEntitlementImpl implements _PlusEntitlement {
  const _$PlusEntitlementImpl(
      {@JsonKey(name: 'ad_free') this.adFree = false,
      @JsonKey(name: 'starts_at') this.startsAt,
      @JsonKey(name: 'expires_at') this.expiresAt,
      this.revision = 0});

  factory _$PlusEntitlementImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlusEntitlementImplFromJson(json);

  @override
  @JsonKey(name: 'ad_free')
  final bool adFree;
  @override
  @JsonKey(name: 'starts_at')
  final DateTime? startsAt;
  @override
  @JsonKey(name: 'expires_at')
  final DateTime? expiresAt;
  @override
  @JsonKey()
  final int revision;

  @override
  String toString() {
    return 'PlusEntitlement(adFree: $adFree, startsAt: $startsAt, expiresAt: $expiresAt, revision: $revision)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlusEntitlementImpl &&
            (identical(other.adFree, adFree) || other.adFree == adFree) &&
            (identical(other.startsAt, startsAt) ||
                other.startsAt == startsAt) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.revision, revision) ||
                other.revision == revision));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, adFree, startsAt, expiresAt, revision);

  /// Create a copy of PlusEntitlement
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlusEntitlementImplCopyWith<_$PlusEntitlementImpl> get copyWith =>
      __$$PlusEntitlementImplCopyWithImpl<_$PlusEntitlementImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PlusEntitlementImplToJson(
      this,
    );
  }
}

abstract class _PlusEntitlement implements PlusEntitlement {
  const factory _PlusEntitlement(
      {@JsonKey(name: 'ad_free') final bool adFree,
      @JsonKey(name: 'starts_at') final DateTime? startsAt,
      @JsonKey(name: 'expires_at') final DateTime? expiresAt,
      final int revision}) = _$PlusEntitlementImpl;

  factory _PlusEntitlement.fromJson(Map<String, dynamic> json) =
      _$PlusEntitlementImpl.fromJson;

  @override
  @JsonKey(name: 'ad_free')
  bool get adFree;
  @override
  @JsonKey(name: 'starts_at')
  DateTime? get startsAt;
  @override
  @JsonKey(name: 'expires_at')
  DateTime? get expiresAt;
  @override
  int get revision;

  /// Create a copy of PlusEntitlement
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlusEntitlementImplCopyWith<_$PlusEntitlementImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PlusDiscount _$PlusDiscountFromJson(Map<String, dynamic> json) {
  return _PlusDiscount.fromJson(json);
}

/// @nodoc
mixin _$PlusDiscount {
  String get type => throw _privateConstructorUsedError;
  @JsonKey(name: 'percent_off')
  int? get percentOff => throw _privateConstructorUsedError;
  @JsonKey(name: 'amount_off_cents')
  int? get amountOffCents => throw _privateConstructorUsedError;
  @JsonKey(name: 'periods_remaining')
  int get periodsRemaining => throw _privateConstructorUsedError;

  /// Serializes this PlusDiscount to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PlusDiscount
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlusDiscountCopyWith<PlusDiscount> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlusDiscountCopyWith<$Res> {
  factory $PlusDiscountCopyWith(
          PlusDiscount value, $Res Function(PlusDiscount) then) =
      _$PlusDiscountCopyWithImpl<$Res, PlusDiscount>;
  @useResult
  $Res call(
      {String type,
      @JsonKey(name: 'percent_off') int? percentOff,
      @JsonKey(name: 'amount_off_cents') int? amountOffCents,
      @JsonKey(name: 'periods_remaining') int periodsRemaining});
}

/// @nodoc
class _$PlusDiscountCopyWithImpl<$Res, $Val extends PlusDiscount>
    implements $PlusDiscountCopyWith<$Res> {
  _$PlusDiscountCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlusDiscount
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? percentOff = freezed,
    Object? amountOffCents = freezed,
    Object? periodsRemaining = null,
  }) {
    return _then(_value.copyWith(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      percentOff: freezed == percentOff
          ? _value.percentOff
          : percentOff // ignore: cast_nullable_to_non_nullable
              as int?,
      amountOffCents: freezed == amountOffCents
          ? _value.amountOffCents
          : amountOffCents // ignore: cast_nullable_to_non_nullable
              as int?,
      periodsRemaining: null == periodsRemaining
          ? _value.periodsRemaining
          : periodsRemaining // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PlusDiscountImplCopyWith<$Res>
    implements $PlusDiscountCopyWith<$Res> {
  factory _$$PlusDiscountImplCopyWith(
          _$PlusDiscountImpl value, $Res Function(_$PlusDiscountImpl) then) =
      __$$PlusDiscountImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String type,
      @JsonKey(name: 'percent_off') int? percentOff,
      @JsonKey(name: 'amount_off_cents') int? amountOffCents,
      @JsonKey(name: 'periods_remaining') int periodsRemaining});
}

/// @nodoc
class __$$PlusDiscountImplCopyWithImpl<$Res>
    extends _$PlusDiscountCopyWithImpl<$Res, _$PlusDiscountImpl>
    implements _$$PlusDiscountImplCopyWith<$Res> {
  __$$PlusDiscountImplCopyWithImpl(
      _$PlusDiscountImpl _value, $Res Function(_$PlusDiscountImpl) _then)
      : super(_value, _then);

  /// Create a copy of PlusDiscount
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? percentOff = freezed,
    Object? amountOffCents = freezed,
    Object? periodsRemaining = null,
  }) {
    return _then(_$PlusDiscountImpl(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      percentOff: freezed == percentOff
          ? _value.percentOff
          : percentOff // ignore: cast_nullable_to_non_nullable
              as int?,
      amountOffCents: freezed == amountOffCents
          ? _value.amountOffCents
          : amountOffCents // ignore: cast_nullable_to_non_nullable
              as int?,
      periodsRemaining: null == periodsRemaining
          ? _value.periodsRemaining
          : periodsRemaining // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PlusDiscountImpl implements _PlusDiscount {
  const _$PlusDiscountImpl(
      {required this.type,
      @JsonKey(name: 'percent_off') this.percentOff,
      @JsonKey(name: 'amount_off_cents') this.amountOffCents,
      @JsonKey(name: 'periods_remaining') this.periodsRemaining = 0});

  factory _$PlusDiscountImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlusDiscountImplFromJson(json);

  @override
  final String type;
  @override
  @JsonKey(name: 'percent_off')
  final int? percentOff;
  @override
  @JsonKey(name: 'amount_off_cents')
  final int? amountOffCents;
  @override
  @JsonKey(name: 'periods_remaining')
  final int periodsRemaining;

  @override
  String toString() {
    return 'PlusDiscount(type: $type, percentOff: $percentOff, amountOffCents: $amountOffCents, periodsRemaining: $periodsRemaining)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlusDiscountImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.percentOff, percentOff) ||
                other.percentOff == percentOff) &&
            (identical(other.amountOffCents, amountOffCents) ||
                other.amountOffCents == amountOffCents) &&
            (identical(other.periodsRemaining, periodsRemaining) ||
                other.periodsRemaining == periodsRemaining));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, type, percentOff, amountOffCents, periodsRemaining);

  /// Create a copy of PlusDiscount
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlusDiscountImplCopyWith<_$PlusDiscountImpl> get copyWith =>
      __$$PlusDiscountImplCopyWithImpl<_$PlusDiscountImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PlusDiscountImplToJson(
      this,
    );
  }
}

abstract class _PlusDiscount implements PlusDiscount {
  const factory _PlusDiscount(
          {required final String type,
          @JsonKey(name: 'percent_off') final int? percentOff,
          @JsonKey(name: 'amount_off_cents') final int? amountOffCents,
          @JsonKey(name: 'periods_remaining') final int periodsRemaining}) =
      _$PlusDiscountImpl;

  factory _PlusDiscount.fromJson(Map<String, dynamic> json) =
      _$PlusDiscountImpl.fromJson;

  @override
  String get type;
  @override
  @JsonKey(name: 'percent_off')
  int? get percentOff;
  @override
  @JsonKey(name: 'amount_off_cents')
  int? get amountOffCents;
  @override
  @JsonKey(name: 'periods_remaining')
  int get periodsRemaining;

  /// Create a copy of PlusDiscount
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlusDiscountImplCopyWith<_$PlusDiscountImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PlusRenewal _$PlusRenewalFromJson(Map<String, dynamic> json) {
  return _PlusRenewal.fromJson(json);
}

/// @nodoc
mixin _$PlusRenewal {
  String? get mode => throw _privateConstructorUsedError;
  @JsonKey(name: 'auto_renew')
  bool get autoRenew => throw _privateConstructorUsedError;
  @JsonKey(name: 'next_charge_cents')
  int? get nextChargeCents => throw _privateConstructorUsedError;
  @JsonKey(name: 'next_charge_at')
  DateTime? get nextChargeAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'lapsed_at')
  DateTime? get lapsedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'cancelled_at')
  DateTime? get cancelledAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'amount_cents')
  int get amountCents => throw _privateConstructorUsedError;
  @JsonKey(name: 'interval_days')
  int get intervalDays => throw _privateConstructorUsedError;
  @JsonKey(name: 'terms_version')
  String? get termsVersion => throw _privateConstructorUsedError;
  @JsonKey(name: 'current_terms_version')
  String? get currentTermsVersion => throw _privateConstructorUsedError;
  @JsonKey(name: 'terms_outdated')
  bool get termsOutdated => throw _privateConstructorUsedError;
  PlusDiscount? get discount => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_error_code')
  String? get lastErrorCode => throw _privateConstructorUsedError;

  /// Serializes this PlusRenewal to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PlusRenewal
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlusRenewalCopyWith<PlusRenewal> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlusRenewalCopyWith<$Res> {
  factory $PlusRenewalCopyWith(
          PlusRenewal value, $Res Function(PlusRenewal) then) =
      _$PlusRenewalCopyWithImpl<$Res, PlusRenewal>;
  @useResult
  $Res call(
      {String? mode,
      @JsonKey(name: 'auto_renew') bool autoRenew,
      @JsonKey(name: 'next_charge_cents') int? nextChargeCents,
      @JsonKey(name: 'next_charge_at') DateTime? nextChargeAt,
      @JsonKey(name: 'lapsed_at') DateTime? lapsedAt,
      @JsonKey(name: 'cancelled_at') DateTime? cancelledAt,
      @JsonKey(name: 'amount_cents') int amountCents,
      @JsonKey(name: 'interval_days') int intervalDays,
      @JsonKey(name: 'terms_version') String? termsVersion,
      @JsonKey(name: 'current_terms_version') String? currentTermsVersion,
      @JsonKey(name: 'terms_outdated') bool termsOutdated,
      PlusDiscount? discount,
      @JsonKey(name: 'last_error_code') String? lastErrorCode});

  $PlusDiscountCopyWith<$Res>? get discount;
}

/// @nodoc
class _$PlusRenewalCopyWithImpl<$Res, $Val extends PlusRenewal>
    implements $PlusRenewalCopyWith<$Res> {
  _$PlusRenewalCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlusRenewal
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mode = freezed,
    Object? autoRenew = null,
    Object? nextChargeCents = freezed,
    Object? nextChargeAt = freezed,
    Object? lapsedAt = freezed,
    Object? cancelledAt = freezed,
    Object? amountCents = null,
    Object? intervalDays = null,
    Object? termsVersion = freezed,
    Object? currentTermsVersion = freezed,
    Object? termsOutdated = null,
    Object? discount = freezed,
    Object? lastErrorCode = freezed,
  }) {
    return _then(_value.copyWith(
      mode: freezed == mode
          ? _value.mode
          : mode // ignore: cast_nullable_to_non_nullable
              as String?,
      autoRenew: null == autoRenew
          ? _value.autoRenew
          : autoRenew // ignore: cast_nullable_to_non_nullable
              as bool,
      nextChargeCents: freezed == nextChargeCents
          ? _value.nextChargeCents
          : nextChargeCents // ignore: cast_nullable_to_non_nullable
              as int?,
      nextChargeAt: freezed == nextChargeAt
          ? _value.nextChargeAt
          : nextChargeAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lapsedAt: freezed == lapsedAt
          ? _value.lapsedAt
          : lapsedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      cancelledAt: freezed == cancelledAt
          ? _value.cancelledAt
          : cancelledAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      amountCents: null == amountCents
          ? _value.amountCents
          : amountCents // ignore: cast_nullable_to_non_nullable
              as int,
      intervalDays: null == intervalDays
          ? _value.intervalDays
          : intervalDays // ignore: cast_nullable_to_non_nullable
              as int,
      termsVersion: freezed == termsVersion
          ? _value.termsVersion
          : termsVersion // ignore: cast_nullable_to_non_nullable
              as String?,
      currentTermsVersion: freezed == currentTermsVersion
          ? _value.currentTermsVersion
          : currentTermsVersion // ignore: cast_nullable_to_non_nullable
              as String?,
      termsOutdated: null == termsOutdated
          ? _value.termsOutdated
          : termsOutdated // ignore: cast_nullable_to_non_nullable
              as bool,
      discount: freezed == discount
          ? _value.discount
          : discount // ignore: cast_nullable_to_non_nullable
              as PlusDiscount?,
      lastErrorCode: freezed == lastErrorCode
          ? _value.lastErrorCode
          : lastErrorCode // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }

  /// Create a copy of PlusRenewal
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PlusDiscountCopyWith<$Res>? get discount {
    if (_value.discount == null) {
      return null;
    }

    return $PlusDiscountCopyWith<$Res>(_value.discount!, (value) {
      return _then(_value.copyWith(discount: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$PlusRenewalImplCopyWith<$Res>
    implements $PlusRenewalCopyWith<$Res> {
  factory _$$PlusRenewalImplCopyWith(
          _$PlusRenewalImpl value, $Res Function(_$PlusRenewalImpl) then) =
      __$$PlusRenewalImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String? mode,
      @JsonKey(name: 'auto_renew') bool autoRenew,
      @JsonKey(name: 'next_charge_cents') int? nextChargeCents,
      @JsonKey(name: 'next_charge_at') DateTime? nextChargeAt,
      @JsonKey(name: 'lapsed_at') DateTime? lapsedAt,
      @JsonKey(name: 'cancelled_at') DateTime? cancelledAt,
      @JsonKey(name: 'amount_cents') int amountCents,
      @JsonKey(name: 'interval_days') int intervalDays,
      @JsonKey(name: 'terms_version') String? termsVersion,
      @JsonKey(name: 'current_terms_version') String? currentTermsVersion,
      @JsonKey(name: 'terms_outdated') bool termsOutdated,
      PlusDiscount? discount,
      @JsonKey(name: 'last_error_code') String? lastErrorCode});

  @override
  $PlusDiscountCopyWith<$Res>? get discount;
}

/// @nodoc
class __$$PlusRenewalImplCopyWithImpl<$Res>
    extends _$PlusRenewalCopyWithImpl<$Res, _$PlusRenewalImpl>
    implements _$$PlusRenewalImplCopyWith<$Res> {
  __$$PlusRenewalImplCopyWithImpl(
      _$PlusRenewalImpl _value, $Res Function(_$PlusRenewalImpl) _then)
      : super(_value, _then);

  /// Create a copy of PlusRenewal
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mode = freezed,
    Object? autoRenew = null,
    Object? nextChargeCents = freezed,
    Object? nextChargeAt = freezed,
    Object? lapsedAt = freezed,
    Object? cancelledAt = freezed,
    Object? amountCents = null,
    Object? intervalDays = null,
    Object? termsVersion = freezed,
    Object? currentTermsVersion = freezed,
    Object? termsOutdated = null,
    Object? discount = freezed,
    Object? lastErrorCode = freezed,
  }) {
    return _then(_$PlusRenewalImpl(
      mode: freezed == mode
          ? _value.mode
          : mode // ignore: cast_nullable_to_non_nullable
              as String?,
      autoRenew: null == autoRenew
          ? _value.autoRenew
          : autoRenew // ignore: cast_nullable_to_non_nullable
              as bool,
      nextChargeCents: freezed == nextChargeCents
          ? _value.nextChargeCents
          : nextChargeCents // ignore: cast_nullable_to_non_nullable
              as int?,
      nextChargeAt: freezed == nextChargeAt
          ? _value.nextChargeAt
          : nextChargeAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lapsedAt: freezed == lapsedAt
          ? _value.lapsedAt
          : lapsedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      cancelledAt: freezed == cancelledAt
          ? _value.cancelledAt
          : cancelledAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      amountCents: null == amountCents
          ? _value.amountCents
          : amountCents // ignore: cast_nullable_to_non_nullable
              as int,
      intervalDays: null == intervalDays
          ? _value.intervalDays
          : intervalDays // ignore: cast_nullable_to_non_nullable
              as int,
      termsVersion: freezed == termsVersion
          ? _value.termsVersion
          : termsVersion // ignore: cast_nullable_to_non_nullable
              as String?,
      currentTermsVersion: freezed == currentTermsVersion
          ? _value.currentTermsVersion
          : currentTermsVersion // ignore: cast_nullable_to_non_nullable
              as String?,
      termsOutdated: null == termsOutdated
          ? _value.termsOutdated
          : termsOutdated // ignore: cast_nullable_to_non_nullable
              as bool,
      discount: freezed == discount
          ? _value.discount
          : discount // ignore: cast_nullable_to_non_nullable
              as PlusDiscount?,
      lastErrorCode: freezed == lastErrorCode
          ? _value.lastErrorCode
          : lastErrorCode // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PlusRenewalImpl extends _PlusRenewal {
  const _$PlusRenewalImpl(
      {this.mode,
      @JsonKey(name: 'auto_renew') this.autoRenew = false,
      @JsonKey(name: 'next_charge_cents') this.nextChargeCents,
      @JsonKey(name: 'next_charge_at') this.nextChargeAt,
      @JsonKey(name: 'lapsed_at') this.lapsedAt,
      @JsonKey(name: 'cancelled_at') this.cancelledAt,
      @JsonKey(name: 'amount_cents') this.amountCents = 200,
      @JsonKey(name: 'interval_days') this.intervalDays = 31,
      @JsonKey(name: 'terms_version') this.termsVersion,
      @JsonKey(name: 'current_terms_version') this.currentTermsVersion,
      @JsonKey(name: 'terms_outdated') this.termsOutdated = false,
      this.discount,
      @JsonKey(name: 'last_error_code') this.lastErrorCode})
      : super._();

  factory _$PlusRenewalImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlusRenewalImplFromJson(json);

  @override
  final String? mode;
  @override
  @JsonKey(name: 'auto_renew')
  final bool autoRenew;
  @override
  @JsonKey(name: 'next_charge_cents')
  final int? nextChargeCents;
  @override
  @JsonKey(name: 'next_charge_at')
  final DateTime? nextChargeAt;
  @override
  @JsonKey(name: 'lapsed_at')
  final DateTime? lapsedAt;
  @override
  @JsonKey(name: 'cancelled_at')
  final DateTime? cancelledAt;
  @override
  @JsonKey(name: 'amount_cents')
  final int amountCents;
  @override
  @JsonKey(name: 'interval_days')
  final int intervalDays;
  @override
  @JsonKey(name: 'terms_version')
  final String? termsVersion;
  @override
  @JsonKey(name: 'current_terms_version')
  final String? currentTermsVersion;
  @override
  @JsonKey(name: 'terms_outdated')
  final bool termsOutdated;
  @override
  final PlusDiscount? discount;
  @override
  @JsonKey(name: 'last_error_code')
  final String? lastErrorCode;

  @override
  String toString() {
    return 'PlusRenewal(mode: $mode, autoRenew: $autoRenew, nextChargeCents: $nextChargeCents, nextChargeAt: $nextChargeAt, lapsedAt: $lapsedAt, cancelledAt: $cancelledAt, amountCents: $amountCents, intervalDays: $intervalDays, termsVersion: $termsVersion, currentTermsVersion: $currentTermsVersion, termsOutdated: $termsOutdated, discount: $discount, lastErrorCode: $lastErrorCode)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlusRenewalImpl &&
            (identical(other.mode, mode) || other.mode == mode) &&
            (identical(other.autoRenew, autoRenew) ||
                other.autoRenew == autoRenew) &&
            (identical(other.nextChargeCents, nextChargeCents) ||
                other.nextChargeCents == nextChargeCents) &&
            (identical(other.nextChargeAt, nextChargeAt) ||
                other.nextChargeAt == nextChargeAt) &&
            (identical(other.lapsedAt, lapsedAt) ||
                other.lapsedAt == lapsedAt) &&
            (identical(other.cancelledAt, cancelledAt) ||
                other.cancelledAt == cancelledAt) &&
            (identical(other.amountCents, amountCents) ||
                other.amountCents == amountCents) &&
            (identical(other.intervalDays, intervalDays) ||
                other.intervalDays == intervalDays) &&
            (identical(other.termsVersion, termsVersion) ||
                other.termsVersion == termsVersion) &&
            (identical(other.currentTermsVersion, currentTermsVersion) ||
                other.currentTermsVersion == currentTermsVersion) &&
            (identical(other.termsOutdated, termsOutdated) ||
                other.termsOutdated == termsOutdated) &&
            (identical(other.discount, discount) ||
                other.discount == discount) &&
            (identical(other.lastErrorCode, lastErrorCode) ||
                other.lastErrorCode == lastErrorCode));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      mode,
      autoRenew,
      nextChargeCents,
      nextChargeAt,
      lapsedAt,
      cancelledAt,
      amountCents,
      intervalDays,
      termsVersion,
      currentTermsVersion,
      termsOutdated,
      discount,
      lastErrorCode);

  /// Create a copy of PlusRenewal
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlusRenewalImplCopyWith<_$PlusRenewalImpl> get copyWith =>
      __$$PlusRenewalImplCopyWithImpl<_$PlusRenewalImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PlusRenewalImplToJson(
      this,
    );
  }
}

abstract class _PlusRenewal extends PlusRenewal {
  const factory _PlusRenewal(
      {final String? mode,
      @JsonKey(name: 'auto_renew') final bool autoRenew,
      @JsonKey(name: 'next_charge_cents') final int? nextChargeCents,
      @JsonKey(name: 'next_charge_at') final DateTime? nextChargeAt,
      @JsonKey(name: 'lapsed_at') final DateTime? lapsedAt,
      @JsonKey(name: 'cancelled_at') final DateTime? cancelledAt,
      @JsonKey(name: 'amount_cents') final int amountCents,
      @JsonKey(name: 'interval_days') final int intervalDays,
      @JsonKey(name: 'terms_version') final String? termsVersion,
      @JsonKey(name: 'current_terms_version') final String? currentTermsVersion,
      @JsonKey(name: 'terms_outdated') final bool termsOutdated,
      final PlusDiscount? discount,
      @JsonKey(name: 'last_error_code')
      final String? lastErrorCode}) = _$PlusRenewalImpl;
  const _PlusRenewal._() : super._();

  factory _PlusRenewal.fromJson(Map<String, dynamic> json) =
      _$PlusRenewalImpl.fromJson;

  @override
  String? get mode;
  @override
  @JsonKey(name: 'auto_renew')
  bool get autoRenew;
  @override
  @JsonKey(name: 'next_charge_cents')
  int? get nextChargeCents;
  @override
  @JsonKey(name: 'next_charge_at')
  DateTime? get nextChargeAt;
  @override
  @JsonKey(name: 'lapsed_at')
  DateTime? get lapsedAt;
  @override
  @JsonKey(name: 'cancelled_at')
  DateTime? get cancelledAt;
  @override
  @JsonKey(name: 'amount_cents')
  int get amountCents;
  @override
  @JsonKey(name: 'interval_days')
  int get intervalDays;
  @override
  @JsonKey(name: 'terms_version')
  String? get termsVersion;
  @override
  @JsonKey(name: 'current_terms_version')
  String? get currentTermsVersion;
  @override
  @JsonKey(name: 'terms_outdated')
  bool get termsOutdated;
  @override
  PlusDiscount? get discount;
  @override
  @JsonKey(name: 'last_error_code')
  String? get lastErrorCode;

  /// Create a copy of PlusRenewal
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlusRenewalImplCopyWith<_$PlusRenewalImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

WalletBalance _$WalletBalanceFromJson(Map<String, dynamic> json) {
  return _WalletBalance.fromJson(json);
}

/// @nodoc
mixin _$WalletBalance {
  @JsonKey(fromJson: _id)
  String? get id => throw _privateConstructorUsedError;
  String get currency => throw _privateConstructorUsedError;
  @JsonKey(name: 'balance_cents')
  int get balanceCents => throw _privateConstructorUsedError;
  @JsonKey(name: 'spendable_cents')
  int get spendableCents => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  bool get frozen => throw _privateConstructorUsedError;
  int get revision => throw _privateConstructorUsedError;
  @JsonKey(name: 'periods_fundable')
  int get periodsFundable => throw _privateConstructorUsedError;

  /// Serializes this WalletBalance to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WalletBalance
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WalletBalanceCopyWith<WalletBalance> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WalletBalanceCopyWith<$Res> {
  factory $WalletBalanceCopyWith(
          WalletBalance value, $Res Function(WalletBalance) then) =
      _$WalletBalanceCopyWithImpl<$Res, WalletBalance>;
  @useResult
  $Res call(
      {@JsonKey(fromJson: _id) String? id,
      String currency,
      @JsonKey(name: 'balance_cents') int balanceCents,
      @JsonKey(name: 'spendable_cents') int spendableCents,
      String status,
      bool frozen,
      int revision,
      @JsonKey(name: 'periods_fundable') int periodsFundable});
}

/// @nodoc
class _$WalletBalanceCopyWithImpl<$Res, $Val extends WalletBalance>
    implements $WalletBalanceCopyWith<$Res> {
  _$WalletBalanceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WalletBalance
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? currency = null,
    Object? balanceCents = null,
    Object? spendableCents = null,
    Object? status = null,
    Object? frozen = null,
    Object? revision = null,
    Object? periodsFundable = null,
  }) {
    return _then(_value.copyWith(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      currency: null == currency
          ? _value.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
      balanceCents: null == balanceCents
          ? _value.balanceCents
          : balanceCents // ignore: cast_nullable_to_non_nullable
              as int,
      spendableCents: null == spendableCents
          ? _value.spendableCents
          : spendableCents // ignore: cast_nullable_to_non_nullable
              as int,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      frozen: null == frozen
          ? _value.frozen
          : frozen // ignore: cast_nullable_to_non_nullable
              as bool,
      revision: null == revision
          ? _value.revision
          : revision // ignore: cast_nullable_to_non_nullable
              as int,
      periodsFundable: null == periodsFundable
          ? _value.periodsFundable
          : periodsFundable // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$WalletBalanceImplCopyWith<$Res>
    implements $WalletBalanceCopyWith<$Res> {
  factory _$$WalletBalanceImplCopyWith(
          _$WalletBalanceImpl value, $Res Function(_$WalletBalanceImpl) then) =
      __$$WalletBalanceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(fromJson: _id) String? id,
      String currency,
      @JsonKey(name: 'balance_cents') int balanceCents,
      @JsonKey(name: 'spendable_cents') int spendableCents,
      String status,
      bool frozen,
      int revision,
      @JsonKey(name: 'periods_fundable') int periodsFundable});
}

/// @nodoc
class __$$WalletBalanceImplCopyWithImpl<$Res>
    extends _$WalletBalanceCopyWithImpl<$Res, _$WalletBalanceImpl>
    implements _$$WalletBalanceImplCopyWith<$Res> {
  __$$WalletBalanceImplCopyWithImpl(
      _$WalletBalanceImpl _value, $Res Function(_$WalletBalanceImpl) _then)
      : super(_value, _then);

  /// Create a copy of WalletBalance
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? currency = null,
    Object? balanceCents = null,
    Object? spendableCents = null,
    Object? status = null,
    Object? frozen = null,
    Object? revision = null,
    Object? periodsFundable = null,
  }) {
    return _then(_$WalletBalanceImpl(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      currency: null == currency
          ? _value.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
      balanceCents: null == balanceCents
          ? _value.balanceCents
          : balanceCents // ignore: cast_nullable_to_non_nullable
              as int,
      spendableCents: null == spendableCents
          ? _value.spendableCents
          : spendableCents // ignore: cast_nullable_to_non_nullable
              as int,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      frozen: null == frozen
          ? _value.frozen
          : frozen // ignore: cast_nullable_to_non_nullable
              as bool,
      revision: null == revision
          ? _value.revision
          : revision // ignore: cast_nullable_to_non_nullable
              as int,
      periodsFundable: null == periodsFundable
          ? _value.periodsFundable
          : periodsFundable // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$WalletBalanceImpl extends _WalletBalance {
  const _$WalletBalanceImpl(
      {@JsonKey(fromJson: _id) this.id,
      this.currency = 'USD',
      @JsonKey(name: 'balance_cents') this.balanceCents = 0,
      @JsonKey(name: 'spendable_cents') this.spendableCents = 0,
      this.status = 'active',
      this.frozen = false,
      this.revision = 0,
      @JsonKey(name: 'periods_fundable') this.periodsFundable = 0})
      : super._();

  factory _$WalletBalanceImpl.fromJson(Map<String, dynamic> json) =>
      _$$WalletBalanceImplFromJson(json);

  @override
  @JsonKey(fromJson: _id)
  final String? id;
  @override
  @JsonKey()
  final String currency;
  @override
  @JsonKey(name: 'balance_cents')
  final int balanceCents;
  @override
  @JsonKey(name: 'spendable_cents')
  final int spendableCents;
  @override
  @JsonKey()
  final String status;
  @override
  @JsonKey()
  final bool frozen;
  @override
  @JsonKey()
  final int revision;
  @override
  @JsonKey(name: 'periods_fundable')
  final int periodsFundable;

  @override
  String toString() {
    return 'WalletBalance(id: $id, currency: $currency, balanceCents: $balanceCents, spendableCents: $spendableCents, status: $status, frozen: $frozen, revision: $revision, periodsFundable: $periodsFundable)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WalletBalanceImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.balanceCents, balanceCents) ||
                other.balanceCents == balanceCents) &&
            (identical(other.spendableCents, spendableCents) ||
                other.spendableCents == spendableCents) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.frozen, frozen) || other.frozen == frozen) &&
            (identical(other.revision, revision) ||
                other.revision == revision) &&
            (identical(other.periodsFundable, periodsFundable) ||
                other.periodsFundable == periodsFundable));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, currency, balanceCents,
      spendableCents, status, frozen, revision, periodsFundable);

  /// Create a copy of WalletBalance
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WalletBalanceImplCopyWith<_$WalletBalanceImpl> get copyWith =>
      __$$WalletBalanceImplCopyWithImpl<_$WalletBalanceImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WalletBalanceImplToJson(
      this,
    );
  }
}

abstract class _WalletBalance extends WalletBalance {
  const factory _WalletBalance(
          {@JsonKey(fromJson: _id) final String? id,
          final String currency,
          @JsonKey(name: 'balance_cents') final int balanceCents,
          @JsonKey(name: 'spendable_cents') final int spendableCents,
          final String status,
          final bool frozen,
          final int revision,
          @JsonKey(name: 'periods_fundable') final int periodsFundable}) =
      _$WalletBalanceImpl;
  const _WalletBalance._() : super._();

  factory _WalletBalance.fromJson(Map<String, dynamic> json) =
      _$WalletBalanceImpl.fromJson;

  @override
  @JsonKey(fromJson: _id)
  String? get id;
  @override
  String get currency;
  @override
  @JsonKey(name: 'balance_cents')
  int get balanceCents;
  @override
  @JsonKey(name: 'spendable_cents')
  int get spendableCents;
  @override
  String get status;
  @override
  bool get frozen;
  @override
  int get revision;
  @override
  @JsonKey(name: 'periods_fundable')
  int get periodsFundable;

  /// Create a copy of WalletBalance
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WalletBalanceImplCopyWith<_$WalletBalanceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PayCoin _$PayCoinFromJson(Map<String, dynamic> json) {
  return _PayCoin.fromJson(json);
}

/// @nodoc
mixin _$PayCoin {
  String get code => throw _privateConstructorUsedError;
  String get ticker => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get network => throw _privateConstructorUsedError;
  @JsonKey(name: 'network_label')
  String get networkLabel => throw _privateConstructorUsedError;
  @JsonKey(name: 'logo_url')
  String? get logoUrl => throw _privateConstructorUsedError;

  /// `memo` or `destination_tag` when a deposit needs one to be matched.
  @JsonKey(name: 'extra_id')
  String? get extraId => throw _privateConstructorUsedError;
  bool get popular => throw _privateConstructorUsedError;

  /// Serializes this PayCoin to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PayCoin
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PayCoinCopyWith<PayCoin> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PayCoinCopyWith<$Res> {
  factory $PayCoinCopyWith(PayCoin value, $Res Function(PayCoin) then) =
      _$PayCoinCopyWithImpl<$Res, PayCoin>;
  @useResult
  $Res call(
      {String code,
      String ticker,
      String name,
      String network,
      @JsonKey(name: 'network_label') String networkLabel,
      @JsonKey(name: 'logo_url') String? logoUrl,
      @JsonKey(name: 'extra_id') String? extraId,
      bool popular});
}

/// @nodoc
class _$PayCoinCopyWithImpl<$Res, $Val extends PayCoin>
    implements $PayCoinCopyWith<$Res> {
  _$PayCoinCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PayCoin
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? code = null,
    Object? ticker = null,
    Object? name = null,
    Object? network = null,
    Object? networkLabel = null,
    Object? logoUrl = freezed,
    Object? extraId = freezed,
    Object? popular = null,
  }) {
    return _then(_value.copyWith(
      code: null == code
          ? _value.code
          : code // ignore: cast_nullable_to_non_nullable
              as String,
      ticker: null == ticker
          ? _value.ticker
          : ticker // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      network: null == network
          ? _value.network
          : network // ignore: cast_nullable_to_non_nullable
              as String,
      networkLabel: null == networkLabel
          ? _value.networkLabel
          : networkLabel // ignore: cast_nullable_to_non_nullable
              as String,
      logoUrl: freezed == logoUrl
          ? _value.logoUrl
          : logoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      extraId: freezed == extraId
          ? _value.extraId
          : extraId // ignore: cast_nullable_to_non_nullable
              as String?,
      popular: null == popular
          ? _value.popular
          : popular // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PayCoinImplCopyWith<$Res> implements $PayCoinCopyWith<$Res> {
  factory _$$PayCoinImplCopyWith(
          _$PayCoinImpl value, $Res Function(_$PayCoinImpl) then) =
      __$$PayCoinImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String code,
      String ticker,
      String name,
      String network,
      @JsonKey(name: 'network_label') String networkLabel,
      @JsonKey(name: 'logo_url') String? logoUrl,
      @JsonKey(name: 'extra_id') String? extraId,
      bool popular});
}

/// @nodoc
class __$$PayCoinImplCopyWithImpl<$Res>
    extends _$PayCoinCopyWithImpl<$Res, _$PayCoinImpl>
    implements _$$PayCoinImplCopyWith<$Res> {
  __$$PayCoinImplCopyWithImpl(
      _$PayCoinImpl _value, $Res Function(_$PayCoinImpl) _then)
      : super(_value, _then);

  /// Create a copy of PayCoin
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? code = null,
    Object? ticker = null,
    Object? name = null,
    Object? network = null,
    Object? networkLabel = null,
    Object? logoUrl = freezed,
    Object? extraId = freezed,
    Object? popular = null,
  }) {
    return _then(_$PayCoinImpl(
      code: null == code
          ? _value.code
          : code // ignore: cast_nullable_to_non_nullable
              as String,
      ticker: null == ticker
          ? _value.ticker
          : ticker // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      network: null == network
          ? _value.network
          : network // ignore: cast_nullable_to_non_nullable
              as String,
      networkLabel: null == networkLabel
          ? _value.networkLabel
          : networkLabel // ignore: cast_nullable_to_non_nullable
              as String,
      logoUrl: freezed == logoUrl
          ? _value.logoUrl
          : logoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      extraId: freezed == extraId
          ? _value.extraId
          : extraId // ignore: cast_nullable_to_non_nullable
              as String?,
      popular: null == popular
          ? _value.popular
          : popular // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PayCoinImpl extends _PayCoin {
  const _$PayCoinImpl(
      {required this.code,
      required this.ticker,
      required this.name,
      this.network = '',
      @JsonKey(name: 'network_label') this.networkLabel = '',
      @JsonKey(name: 'logo_url') this.logoUrl,
      @JsonKey(name: 'extra_id') this.extraId,
      this.popular = false})
      : super._();

  factory _$PayCoinImpl.fromJson(Map<String, dynamic> json) =>
      _$$PayCoinImplFromJson(json);

  @override
  final String code;
  @override
  final String ticker;
  @override
  final String name;
  @override
  @JsonKey()
  final String network;
  @override
  @JsonKey(name: 'network_label')
  final String networkLabel;
  @override
  @JsonKey(name: 'logo_url')
  final String? logoUrl;

  /// `memo` or `destination_tag` when a deposit needs one to be matched.
  @override
  @JsonKey(name: 'extra_id')
  final String? extraId;
  @override
  @JsonKey()
  final bool popular;

  @override
  String toString() {
    return 'PayCoin(code: $code, ticker: $ticker, name: $name, network: $network, networkLabel: $networkLabel, logoUrl: $logoUrl, extraId: $extraId, popular: $popular)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PayCoinImpl &&
            (identical(other.code, code) || other.code == code) &&
            (identical(other.ticker, ticker) || other.ticker == ticker) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.network, network) || other.network == network) &&
            (identical(other.networkLabel, networkLabel) ||
                other.networkLabel == networkLabel) &&
            (identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl) &&
            (identical(other.extraId, extraId) || other.extraId == extraId) &&
            (identical(other.popular, popular) || other.popular == popular));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, code, ticker, name, network,
      networkLabel, logoUrl, extraId, popular);

  /// Create a copy of PayCoin
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PayCoinImplCopyWith<_$PayCoinImpl> get copyWith =>
      __$$PayCoinImplCopyWithImpl<_$PayCoinImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PayCoinImplToJson(
      this,
    );
  }
}

abstract class _PayCoin extends PayCoin {
  const factory _PayCoin(
      {required final String code,
      required final String ticker,
      required final String name,
      final String network,
      @JsonKey(name: 'network_label') final String networkLabel,
      @JsonKey(name: 'logo_url') final String? logoUrl,
      @JsonKey(name: 'extra_id') final String? extraId,
      final bool popular}) = _$PayCoinImpl;
  const _PayCoin._() : super._();

  factory _PayCoin.fromJson(Map<String, dynamic> json) = _$PayCoinImpl.fromJson;

  @override
  String get code;
  @override
  String get ticker;
  @override
  String get name;
  @override
  String get network;
  @override
  @JsonKey(name: 'network_label')
  String get networkLabel;
  @override
  @JsonKey(name: 'logo_url')
  String? get logoUrl;

  /// `memo` or `destination_tag` when a deposit needs one to be matched.
  @override
  @JsonKey(name: 'extra_id')
  String? get extraId;
  @override
  bool get popular;

  /// Create a copy of PayCoin
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PayCoinImplCopyWith<_$PayCoinImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TopupPayment _$TopupPaymentFromJson(Map<String, dynamic> json) {
  return _TopupPayment.fromJson(json);
}

/// @nodoc
mixin _$TopupPayment {
  @JsonKey(fromJson: _id)
  String? get id => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  PayCoin get coin => throw _privateConstructorUsedError;
  String? get amount => throw _privateConstructorUsedError;
  String? get paid => throw _privateConstructorUsedError;
  String? get remaining => throw _privateConstructorUsedError;
  String? get address => throw _privateConstructorUsedError;
  @JsonKey(name: 'extra_id')
  String? get extraId => throw _privateConstructorUsedError;
  String? get uri => throw _privateConstructorUsedError;
  @JsonKey(name: 'expires_at')
  DateTime? get expiresAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this TopupPayment to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TopupPayment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TopupPaymentCopyWith<TopupPayment> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TopupPaymentCopyWith<$Res> {
  factory $TopupPaymentCopyWith(
          TopupPayment value, $Res Function(TopupPayment) then) =
      _$TopupPaymentCopyWithImpl<$Res, TopupPayment>;
  @useResult
  $Res call(
      {@JsonKey(fromJson: _id) String? id,
      String status,
      PayCoin coin,
      String? amount,
      String? paid,
      String? remaining,
      String? address,
      @JsonKey(name: 'extra_id') String? extraId,
      String? uri,
      @JsonKey(name: 'expires_at') DateTime? expiresAt,
      @JsonKey(name: 'created_at') DateTime? createdAt});

  $PayCoinCopyWith<$Res> get coin;
}

/// @nodoc
class _$TopupPaymentCopyWithImpl<$Res, $Val extends TopupPayment>
    implements $TopupPaymentCopyWith<$Res> {
  _$TopupPaymentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TopupPayment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? status = null,
    Object? coin = null,
    Object? amount = freezed,
    Object? paid = freezed,
    Object? remaining = freezed,
    Object? address = freezed,
    Object? extraId = freezed,
    Object? uri = freezed,
    Object? expiresAt = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      coin: null == coin
          ? _value.coin
          : coin // ignore: cast_nullable_to_non_nullable
              as PayCoin,
      amount: freezed == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as String?,
      paid: freezed == paid
          ? _value.paid
          : paid // ignore: cast_nullable_to_non_nullable
              as String?,
      remaining: freezed == remaining
          ? _value.remaining
          : remaining // ignore: cast_nullable_to_non_nullable
              as String?,
      address: freezed == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String?,
      extraId: freezed == extraId
          ? _value.extraId
          : extraId // ignore: cast_nullable_to_non_nullable
              as String?,
      uri: freezed == uri
          ? _value.uri
          : uri // ignore: cast_nullable_to_non_nullable
              as String?,
      expiresAt: freezed == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }

  /// Create a copy of TopupPayment
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PayCoinCopyWith<$Res> get coin {
    return $PayCoinCopyWith<$Res>(_value.coin, (value) {
      return _then(_value.copyWith(coin: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$TopupPaymentImplCopyWith<$Res>
    implements $TopupPaymentCopyWith<$Res> {
  factory _$$TopupPaymentImplCopyWith(
          _$TopupPaymentImpl value, $Res Function(_$TopupPaymentImpl) then) =
      __$$TopupPaymentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(fromJson: _id) String? id,
      String status,
      PayCoin coin,
      String? amount,
      String? paid,
      String? remaining,
      String? address,
      @JsonKey(name: 'extra_id') String? extraId,
      String? uri,
      @JsonKey(name: 'expires_at') DateTime? expiresAt,
      @JsonKey(name: 'created_at') DateTime? createdAt});

  @override
  $PayCoinCopyWith<$Res> get coin;
}

/// @nodoc
class __$$TopupPaymentImplCopyWithImpl<$Res>
    extends _$TopupPaymentCopyWithImpl<$Res, _$TopupPaymentImpl>
    implements _$$TopupPaymentImplCopyWith<$Res> {
  __$$TopupPaymentImplCopyWithImpl(
      _$TopupPaymentImpl _value, $Res Function(_$TopupPaymentImpl) _then)
      : super(_value, _then);

  /// Create a copy of TopupPayment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? status = null,
    Object? coin = null,
    Object? amount = freezed,
    Object? paid = freezed,
    Object? remaining = freezed,
    Object? address = freezed,
    Object? extraId = freezed,
    Object? uri = freezed,
    Object? expiresAt = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(_$TopupPaymentImpl(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      coin: null == coin
          ? _value.coin
          : coin // ignore: cast_nullable_to_non_nullable
              as PayCoin,
      amount: freezed == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as String?,
      paid: freezed == paid
          ? _value.paid
          : paid // ignore: cast_nullable_to_non_nullable
              as String?,
      remaining: freezed == remaining
          ? _value.remaining
          : remaining // ignore: cast_nullable_to_non_nullable
              as String?,
      address: freezed == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String?,
      extraId: freezed == extraId
          ? _value.extraId
          : extraId // ignore: cast_nullable_to_non_nullable
              as String?,
      uri: freezed == uri
          ? _value.uri
          : uri // ignore: cast_nullable_to_non_nullable
              as String?,
      expiresAt: freezed == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TopupPaymentImpl extends _TopupPayment {
  const _$TopupPaymentImpl(
      {@JsonKey(fromJson: _id) this.id,
      required this.status,
      required this.coin,
      this.amount,
      this.paid,
      this.remaining,
      this.address,
      @JsonKey(name: 'extra_id') this.extraId,
      this.uri,
      @JsonKey(name: 'expires_at') this.expiresAt,
      @JsonKey(name: 'created_at') this.createdAt})
      : super._();

  factory _$TopupPaymentImpl.fromJson(Map<String, dynamic> json) =>
      _$$TopupPaymentImplFromJson(json);

  @override
  @JsonKey(fromJson: _id)
  final String? id;
  @override
  final String status;
  @override
  final PayCoin coin;
  @override
  final String? amount;
  @override
  final String? paid;
  @override
  final String? remaining;
  @override
  final String? address;
  @override
  @JsonKey(name: 'extra_id')
  final String? extraId;
  @override
  final String? uri;
  @override
  @JsonKey(name: 'expires_at')
  final DateTime? expiresAt;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  @override
  String toString() {
    return 'TopupPayment(id: $id, status: $status, coin: $coin, amount: $amount, paid: $paid, remaining: $remaining, address: $address, extraId: $extraId, uri: $uri, expiresAt: $expiresAt, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TopupPaymentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.coin, coin) || other.coin == coin) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.paid, paid) || other.paid == paid) &&
            (identical(other.remaining, remaining) ||
                other.remaining == remaining) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.extraId, extraId) || other.extraId == extraId) &&
            (identical(other.uri, uri) || other.uri == uri) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, status, coin, amount, paid,
      remaining, address, extraId, uri, expiresAt, createdAt);

  /// Create a copy of TopupPayment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TopupPaymentImplCopyWith<_$TopupPaymentImpl> get copyWith =>
      __$$TopupPaymentImplCopyWithImpl<_$TopupPaymentImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TopupPaymentImplToJson(
      this,
    );
  }
}

abstract class _TopupPayment extends TopupPayment {
  const factory _TopupPayment(
          {@JsonKey(fromJson: _id) final String? id,
          required final String status,
          required final PayCoin coin,
          final String? amount,
          final String? paid,
          final String? remaining,
          final String? address,
          @JsonKey(name: 'extra_id') final String? extraId,
          final String? uri,
          @JsonKey(name: 'expires_at') final DateTime? expiresAt,
          @JsonKey(name: 'created_at') final DateTime? createdAt}) =
      _$TopupPaymentImpl;
  const _TopupPayment._() : super._();

  factory _TopupPayment.fromJson(Map<String, dynamic> json) =
      _$TopupPaymentImpl.fromJson;

  @override
  @JsonKey(fromJson: _id)
  String? get id;
  @override
  String get status;
  @override
  PayCoin get coin;
  @override
  String? get amount;
  @override
  String? get paid;
  @override
  String? get remaining;
  @override
  String? get address;
  @override
  @JsonKey(name: 'extra_id')
  String? get extraId;
  @override
  String? get uri;
  @override
  @JsonKey(name: 'expires_at')
  DateTime? get expiresAt;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;

  /// Create a copy of TopupPayment
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TopupPaymentImplCopyWith<_$TopupPaymentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

WalletTopup _$WalletTopupFromJson(Map<String, dynamic> json) {
  return _WalletTopup.fromJson(json);
}

/// @nodoc
mixin _$WalletTopup {
  String get id => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;

  /// `nowpayments` (crypto) or `patreon` (a credited pledge charge).
  String get provider => throw _privateConstructorUsedError;
  @JsonKey(name: 'amount_cents')
  int get amountCents => throw _privateConstructorUsedError;
  @JsonKey(name: 'credited_cents')
  int get creditedCents => throw _privateConstructorUsedError;
  String get currency => throw _privateConstructorUsedError;
  @JsonKey(name: 'activate_plus')
  bool get activatePlus => throw _privateConstructorUsedError;
  @JsonKey(name: 'next_action')
  String get nextAction => throw _privateConstructorUsedError;
  @JsonKey(name: 'checkout_url')
  String? get checkoutUrl => throw _privateConstructorUsedError;

  /// Where FlixQuest's own checkout is: `preparing`, `choose_coin`,
  /// `send`, `send_remaining`, `confirming`, `credited` or `closed`.
  @JsonKey(name: 'checkout_step')
  String? get checkoutStep => throw _privateConstructorUsedError;
  TopupPayment? get payment => throw _privateConstructorUsedError;
  @JsonKey(name: 'pay_currency')
  String? get payCurrency => throw _privateConstructorUsedError;
  @JsonKey(name: 'error_code')
  String? get errorCode => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'credited_at')
  DateTime? get creditedAt => throw _privateConstructorUsedError;

  /// Serializes this WalletTopup to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WalletTopup
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WalletTopupCopyWith<WalletTopup> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WalletTopupCopyWith<$Res> {
  factory $WalletTopupCopyWith(
          WalletTopup value, $Res Function(WalletTopup) then) =
      _$WalletTopupCopyWithImpl<$Res, WalletTopup>;
  @useResult
  $Res call(
      {String id,
      String status,
      String provider,
      @JsonKey(name: 'amount_cents') int amountCents,
      @JsonKey(name: 'credited_cents') int creditedCents,
      String currency,
      @JsonKey(name: 'activate_plus') bool activatePlus,
      @JsonKey(name: 'next_action') String nextAction,
      @JsonKey(name: 'checkout_url') String? checkoutUrl,
      @JsonKey(name: 'checkout_step') String? checkoutStep,
      TopupPayment? payment,
      @JsonKey(name: 'pay_currency') String? payCurrency,
      @JsonKey(name: 'error_code') String? errorCode,
      @JsonKey(name: 'created_at') DateTime? createdAt,
      @JsonKey(name: 'credited_at') DateTime? creditedAt});

  $TopupPaymentCopyWith<$Res>? get payment;
}

/// @nodoc
class _$WalletTopupCopyWithImpl<$Res, $Val extends WalletTopup>
    implements $WalletTopupCopyWith<$Res> {
  _$WalletTopupCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WalletTopup
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? status = null,
    Object? provider = null,
    Object? amountCents = null,
    Object? creditedCents = null,
    Object? currency = null,
    Object? activatePlus = null,
    Object? nextAction = null,
    Object? checkoutUrl = freezed,
    Object? checkoutStep = freezed,
    Object? payment = freezed,
    Object? payCurrency = freezed,
    Object? errorCode = freezed,
    Object? createdAt = freezed,
    Object? creditedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      provider: null == provider
          ? _value.provider
          : provider // ignore: cast_nullable_to_non_nullable
              as String,
      amountCents: null == amountCents
          ? _value.amountCents
          : amountCents // ignore: cast_nullable_to_non_nullable
              as int,
      creditedCents: null == creditedCents
          ? _value.creditedCents
          : creditedCents // ignore: cast_nullable_to_non_nullable
              as int,
      currency: null == currency
          ? _value.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
      activatePlus: null == activatePlus
          ? _value.activatePlus
          : activatePlus // ignore: cast_nullable_to_non_nullable
              as bool,
      nextAction: null == nextAction
          ? _value.nextAction
          : nextAction // ignore: cast_nullable_to_non_nullable
              as String,
      checkoutUrl: freezed == checkoutUrl
          ? _value.checkoutUrl
          : checkoutUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      checkoutStep: freezed == checkoutStep
          ? _value.checkoutStep
          : checkoutStep // ignore: cast_nullable_to_non_nullable
              as String?,
      payment: freezed == payment
          ? _value.payment
          : payment // ignore: cast_nullable_to_non_nullable
              as TopupPayment?,
      payCurrency: freezed == payCurrency
          ? _value.payCurrency
          : payCurrency // ignore: cast_nullable_to_non_nullable
              as String?,
      errorCode: freezed == errorCode
          ? _value.errorCode
          : errorCode // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      creditedAt: freezed == creditedAt
          ? _value.creditedAt
          : creditedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }

  /// Create a copy of WalletTopup
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TopupPaymentCopyWith<$Res>? get payment {
    if (_value.payment == null) {
      return null;
    }

    return $TopupPaymentCopyWith<$Res>(_value.payment!, (value) {
      return _then(_value.copyWith(payment: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$WalletTopupImplCopyWith<$Res>
    implements $WalletTopupCopyWith<$Res> {
  factory _$$WalletTopupImplCopyWith(
          _$WalletTopupImpl value, $Res Function(_$WalletTopupImpl) then) =
      __$$WalletTopupImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String status,
      String provider,
      @JsonKey(name: 'amount_cents') int amountCents,
      @JsonKey(name: 'credited_cents') int creditedCents,
      String currency,
      @JsonKey(name: 'activate_plus') bool activatePlus,
      @JsonKey(name: 'next_action') String nextAction,
      @JsonKey(name: 'checkout_url') String? checkoutUrl,
      @JsonKey(name: 'checkout_step') String? checkoutStep,
      TopupPayment? payment,
      @JsonKey(name: 'pay_currency') String? payCurrency,
      @JsonKey(name: 'error_code') String? errorCode,
      @JsonKey(name: 'created_at') DateTime? createdAt,
      @JsonKey(name: 'credited_at') DateTime? creditedAt});

  @override
  $TopupPaymentCopyWith<$Res>? get payment;
}

/// @nodoc
class __$$WalletTopupImplCopyWithImpl<$Res>
    extends _$WalletTopupCopyWithImpl<$Res, _$WalletTopupImpl>
    implements _$$WalletTopupImplCopyWith<$Res> {
  __$$WalletTopupImplCopyWithImpl(
      _$WalletTopupImpl _value, $Res Function(_$WalletTopupImpl) _then)
      : super(_value, _then);

  /// Create a copy of WalletTopup
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? status = null,
    Object? provider = null,
    Object? amountCents = null,
    Object? creditedCents = null,
    Object? currency = null,
    Object? activatePlus = null,
    Object? nextAction = null,
    Object? checkoutUrl = freezed,
    Object? checkoutStep = freezed,
    Object? payment = freezed,
    Object? payCurrency = freezed,
    Object? errorCode = freezed,
    Object? createdAt = freezed,
    Object? creditedAt = freezed,
  }) {
    return _then(_$WalletTopupImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      provider: null == provider
          ? _value.provider
          : provider // ignore: cast_nullable_to_non_nullable
              as String,
      amountCents: null == amountCents
          ? _value.amountCents
          : amountCents // ignore: cast_nullable_to_non_nullable
              as int,
      creditedCents: null == creditedCents
          ? _value.creditedCents
          : creditedCents // ignore: cast_nullable_to_non_nullable
              as int,
      currency: null == currency
          ? _value.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
      activatePlus: null == activatePlus
          ? _value.activatePlus
          : activatePlus // ignore: cast_nullable_to_non_nullable
              as bool,
      nextAction: null == nextAction
          ? _value.nextAction
          : nextAction // ignore: cast_nullable_to_non_nullable
              as String,
      checkoutUrl: freezed == checkoutUrl
          ? _value.checkoutUrl
          : checkoutUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      checkoutStep: freezed == checkoutStep
          ? _value.checkoutStep
          : checkoutStep // ignore: cast_nullable_to_non_nullable
              as String?,
      payment: freezed == payment
          ? _value.payment
          : payment // ignore: cast_nullable_to_non_nullable
              as TopupPayment?,
      payCurrency: freezed == payCurrency
          ? _value.payCurrency
          : payCurrency // ignore: cast_nullable_to_non_nullable
              as String?,
      errorCode: freezed == errorCode
          ? _value.errorCode
          : errorCode // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      creditedAt: freezed == creditedAt
          ? _value.creditedAt
          : creditedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$WalletTopupImpl extends _WalletTopup {
  const _$WalletTopupImpl(
      {required this.id,
      required this.status,
      this.provider = 'nowpayments',
      @JsonKey(name: 'amount_cents') required this.amountCents,
      @JsonKey(name: 'credited_cents') this.creditedCents = 0,
      this.currency = 'USD',
      @JsonKey(name: 'activate_plus') this.activatePlus = false,
      @JsonKey(name: 'next_action') this.nextAction = 'none',
      @JsonKey(name: 'checkout_url') this.checkoutUrl,
      @JsonKey(name: 'checkout_step') this.checkoutStep,
      this.payment,
      @JsonKey(name: 'pay_currency') this.payCurrency,
      @JsonKey(name: 'error_code') this.errorCode,
      @JsonKey(name: 'created_at') this.createdAt,
      @JsonKey(name: 'credited_at') this.creditedAt})
      : super._();

  factory _$WalletTopupImpl.fromJson(Map<String, dynamic> json) =>
      _$$WalletTopupImplFromJson(json);

  @override
  final String id;
  @override
  final String status;

  /// `nowpayments` (crypto) or `patreon` (a credited pledge charge).
  @override
  @JsonKey()
  final String provider;
  @override
  @JsonKey(name: 'amount_cents')
  final int amountCents;
  @override
  @JsonKey(name: 'credited_cents')
  final int creditedCents;
  @override
  @JsonKey()
  final String currency;
  @override
  @JsonKey(name: 'activate_plus')
  final bool activatePlus;
  @override
  @JsonKey(name: 'next_action')
  final String nextAction;
  @override
  @JsonKey(name: 'checkout_url')
  final String? checkoutUrl;

  /// Where FlixQuest's own checkout is: `preparing`, `choose_coin`,
  /// `send`, `send_remaining`, `confirming`, `credited` or `closed`.
  @override
  @JsonKey(name: 'checkout_step')
  final String? checkoutStep;
  @override
  final TopupPayment? payment;
  @override
  @JsonKey(name: 'pay_currency')
  final String? payCurrency;
  @override
  @JsonKey(name: 'error_code')
  final String? errorCode;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  @JsonKey(name: 'credited_at')
  final DateTime? creditedAt;

  @override
  String toString() {
    return 'WalletTopup(id: $id, status: $status, provider: $provider, amountCents: $amountCents, creditedCents: $creditedCents, currency: $currency, activatePlus: $activatePlus, nextAction: $nextAction, checkoutUrl: $checkoutUrl, checkoutStep: $checkoutStep, payment: $payment, payCurrency: $payCurrency, errorCode: $errorCode, createdAt: $createdAt, creditedAt: $creditedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WalletTopupImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.provider, provider) ||
                other.provider == provider) &&
            (identical(other.amountCents, amountCents) ||
                other.amountCents == amountCents) &&
            (identical(other.creditedCents, creditedCents) ||
                other.creditedCents == creditedCents) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.activatePlus, activatePlus) ||
                other.activatePlus == activatePlus) &&
            (identical(other.nextAction, nextAction) ||
                other.nextAction == nextAction) &&
            (identical(other.checkoutUrl, checkoutUrl) ||
                other.checkoutUrl == checkoutUrl) &&
            (identical(other.checkoutStep, checkoutStep) ||
                other.checkoutStep == checkoutStep) &&
            (identical(other.payment, payment) || other.payment == payment) &&
            (identical(other.payCurrency, payCurrency) ||
                other.payCurrency == payCurrency) &&
            (identical(other.errorCode, errorCode) ||
                other.errorCode == errorCode) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.creditedAt, creditedAt) ||
                other.creditedAt == creditedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      status,
      provider,
      amountCents,
      creditedCents,
      currency,
      activatePlus,
      nextAction,
      checkoutUrl,
      checkoutStep,
      payment,
      payCurrency,
      errorCode,
      createdAt,
      creditedAt);

  /// Create a copy of WalletTopup
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WalletTopupImplCopyWith<_$WalletTopupImpl> get copyWith =>
      __$$WalletTopupImplCopyWithImpl<_$WalletTopupImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WalletTopupImplToJson(
      this,
    );
  }
}

abstract class _WalletTopup extends WalletTopup {
  const factory _WalletTopup(
          {required final String id,
          required final String status,
          final String provider,
          @JsonKey(name: 'amount_cents') required final int amountCents,
          @JsonKey(name: 'credited_cents') final int creditedCents,
          final String currency,
          @JsonKey(name: 'activate_plus') final bool activatePlus,
          @JsonKey(name: 'next_action') final String nextAction,
          @JsonKey(name: 'checkout_url') final String? checkoutUrl,
          @JsonKey(name: 'checkout_step') final String? checkoutStep,
          final TopupPayment? payment,
          @JsonKey(name: 'pay_currency') final String? payCurrency,
          @JsonKey(name: 'error_code') final String? errorCode,
          @JsonKey(name: 'created_at') final DateTime? createdAt,
          @JsonKey(name: 'credited_at') final DateTime? creditedAt}) =
      _$WalletTopupImpl;
  const _WalletTopup._() : super._();

  factory _WalletTopup.fromJson(Map<String, dynamic> json) =
      _$WalletTopupImpl.fromJson;

  @override
  String get id;
  @override
  String get status;

  /// `nowpayments` (crypto) or `patreon` (a credited pledge charge).
  @override
  String get provider;
  @override
  @JsonKey(name: 'amount_cents')
  int get amountCents;
  @override
  @JsonKey(name: 'credited_cents')
  int get creditedCents;
  @override
  String get currency;
  @override
  @JsonKey(name: 'activate_plus')
  bool get activatePlus;
  @override
  @JsonKey(name: 'next_action')
  String get nextAction;
  @override
  @JsonKey(name: 'checkout_url')
  String? get checkoutUrl;

  /// Where FlixQuest's own checkout is: `preparing`, `choose_coin`,
  /// `send`, `send_remaining`, `confirming`, `credited` or `closed`.
  @override
  @JsonKey(name: 'checkout_step')
  String? get checkoutStep;
  @override
  TopupPayment? get payment;
  @override
  @JsonKey(name: 'pay_currency')
  String? get payCurrency;
  @override
  @JsonKey(name: 'error_code')
  String? get errorCode;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @override
  @JsonKey(name: 'credited_at')
  DateTime? get creditedAt;

  /// Create a copy of WalletTopup
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WalletTopupImplCopyWith<_$WalletTopupImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

WalletTransaction _$WalletTransactionFromJson(Map<String, dynamic> json) {
  return _WalletTransaction.fromJson(json);
}

/// @nodoc
mixin _$WalletTransaction {
  @JsonKey(fromJson: _id)
  String? get id => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  @JsonKey(name: 'amount_cents')
  int get amountCents => throw _privateConstructorUsedError;
  @JsonKey(name: 'balance_after_cents')
  int? get balanceAfterCents => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _id)
  String? get reference => throw _privateConstructorUsedError;

  /// Where a credit came from: `nowpayments` or `patreon`.
  String? get source => throw _privateConstructorUsedError;
  @JsonKey(name: 'period_starts_at')
  DateTime? get periodStartsAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'period_ends_at')
  DateTime? get periodEndsAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this WalletTransaction to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WalletTransaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WalletTransactionCopyWith<WalletTransaction> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WalletTransactionCopyWith<$Res> {
  factory $WalletTransactionCopyWith(
          WalletTransaction value, $Res Function(WalletTransaction) then) =
      _$WalletTransactionCopyWithImpl<$Res, WalletTransaction>;
  @useResult
  $Res call(
      {@JsonKey(fromJson: _id) String? id,
      String type,
      @JsonKey(name: 'amount_cents') int amountCents,
      @JsonKey(name: 'balance_after_cents') int? balanceAfterCents,
      @JsonKey(fromJson: _id) String? reference,
      String? source,
      @JsonKey(name: 'period_starts_at') DateTime? periodStartsAt,
      @JsonKey(name: 'period_ends_at') DateTime? periodEndsAt,
      @JsonKey(name: 'created_at') DateTime? createdAt});
}

/// @nodoc
class _$WalletTransactionCopyWithImpl<$Res, $Val extends WalletTransaction>
    implements $WalletTransactionCopyWith<$Res> {
  _$WalletTransactionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WalletTransaction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? type = null,
    Object? amountCents = null,
    Object? balanceAfterCents = freezed,
    Object? reference = freezed,
    Object? source = freezed,
    Object? periodStartsAt = freezed,
    Object? periodEndsAt = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      amountCents: null == amountCents
          ? _value.amountCents
          : amountCents // ignore: cast_nullable_to_non_nullable
              as int,
      balanceAfterCents: freezed == balanceAfterCents
          ? _value.balanceAfterCents
          : balanceAfterCents // ignore: cast_nullable_to_non_nullable
              as int?,
      reference: freezed == reference
          ? _value.reference
          : reference // ignore: cast_nullable_to_non_nullable
              as String?,
      source: freezed == source
          ? _value.source
          : source // ignore: cast_nullable_to_non_nullable
              as String?,
      periodStartsAt: freezed == periodStartsAt
          ? _value.periodStartsAt
          : periodStartsAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      periodEndsAt: freezed == periodEndsAt
          ? _value.periodEndsAt
          : periodEndsAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$WalletTransactionImplCopyWith<$Res>
    implements $WalletTransactionCopyWith<$Res> {
  factory _$$WalletTransactionImplCopyWith(_$WalletTransactionImpl value,
          $Res Function(_$WalletTransactionImpl) then) =
      __$$WalletTransactionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(fromJson: _id) String? id,
      String type,
      @JsonKey(name: 'amount_cents') int amountCents,
      @JsonKey(name: 'balance_after_cents') int? balanceAfterCents,
      @JsonKey(fromJson: _id) String? reference,
      String? source,
      @JsonKey(name: 'period_starts_at') DateTime? periodStartsAt,
      @JsonKey(name: 'period_ends_at') DateTime? periodEndsAt,
      @JsonKey(name: 'created_at') DateTime? createdAt});
}

/// @nodoc
class __$$WalletTransactionImplCopyWithImpl<$Res>
    extends _$WalletTransactionCopyWithImpl<$Res, _$WalletTransactionImpl>
    implements _$$WalletTransactionImplCopyWith<$Res> {
  __$$WalletTransactionImplCopyWithImpl(_$WalletTransactionImpl _value,
      $Res Function(_$WalletTransactionImpl) _then)
      : super(_value, _then);

  /// Create a copy of WalletTransaction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? type = null,
    Object? amountCents = null,
    Object? balanceAfterCents = freezed,
    Object? reference = freezed,
    Object? source = freezed,
    Object? periodStartsAt = freezed,
    Object? periodEndsAt = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(_$WalletTransactionImpl(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      amountCents: null == amountCents
          ? _value.amountCents
          : amountCents // ignore: cast_nullable_to_non_nullable
              as int,
      balanceAfterCents: freezed == balanceAfterCents
          ? _value.balanceAfterCents
          : balanceAfterCents // ignore: cast_nullable_to_non_nullable
              as int?,
      reference: freezed == reference
          ? _value.reference
          : reference // ignore: cast_nullable_to_non_nullable
              as String?,
      source: freezed == source
          ? _value.source
          : source // ignore: cast_nullable_to_non_nullable
              as String?,
      periodStartsAt: freezed == periodStartsAt
          ? _value.periodStartsAt
          : periodStartsAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      periodEndsAt: freezed == periodEndsAt
          ? _value.periodEndsAt
          : periodEndsAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$WalletTransactionImpl implements _WalletTransaction {
  const _$WalletTransactionImpl(
      {@JsonKey(fromJson: _id) this.id,
      required this.type,
      @JsonKey(name: 'amount_cents') required this.amountCents,
      @JsonKey(name: 'balance_after_cents') this.balanceAfterCents,
      @JsonKey(fromJson: _id) this.reference,
      this.source,
      @JsonKey(name: 'period_starts_at') this.periodStartsAt,
      @JsonKey(name: 'period_ends_at') this.periodEndsAt,
      @JsonKey(name: 'created_at') this.createdAt});

  factory _$WalletTransactionImpl.fromJson(Map<String, dynamic> json) =>
      _$$WalletTransactionImplFromJson(json);

  @override
  @JsonKey(fromJson: _id)
  final String? id;
  @override
  final String type;
  @override
  @JsonKey(name: 'amount_cents')
  final int amountCents;
  @override
  @JsonKey(name: 'balance_after_cents')
  final int? balanceAfterCents;
  @override
  @JsonKey(fromJson: _id)
  final String? reference;

  /// Where a credit came from: `nowpayments` or `patreon`.
  @override
  final String? source;
  @override
  @JsonKey(name: 'period_starts_at')
  final DateTime? periodStartsAt;
  @override
  @JsonKey(name: 'period_ends_at')
  final DateTime? periodEndsAt;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  @override
  String toString() {
    return 'WalletTransaction(id: $id, type: $type, amountCents: $amountCents, balanceAfterCents: $balanceAfterCents, reference: $reference, source: $source, periodStartsAt: $periodStartsAt, periodEndsAt: $periodEndsAt, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WalletTransactionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.amountCents, amountCents) ||
                other.amountCents == amountCents) &&
            (identical(other.balanceAfterCents, balanceAfterCents) ||
                other.balanceAfterCents == balanceAfterCents) &&
            (identical(other.reference, reference) ||
                other.reference == reference) &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.periodStartsAt, periodStartsAt) ||
                other.periodStartsAt == periodStartsAt) &&
            (identical(other.periodEndsAt, periodEndsAt) ||
                other.periodEndsAt == periodEndsAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      type,
      amountCents,
      balanceAfterCents,
      reference,
      source,
      periodStartsAt,
      periodEndsAt,
      createdAt);

  /// Create a copy of WalletTransaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WalletTransactionImplCopyWith<_$WalletTransactionImpl> get copyWith =>
      __$$WalletTransactionImplCopyWithImpl<_$WalletTransactionImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WalletTransactionImplToJson(
      this,
    );
  }
}

abstract class _WalletTransaction implements WalletTransaction {
  const factory _WalletTransaction(
          {@JsonKey(fromJson: _id) final String? id,
          required final String type,
          @JsonKey(name: 'amount_cents') required final int amountCents,
          @JsonKey(name: 'balance_after_cents') final int? balanceAfterCents,
          @JsonKey(fromJson: _id) final String? reference,
          final String? source,
          @JsonKey(name: 'period_starts_at') final DateTime? periodStartsAt,
          @JsonKey(name: 'period_ends_at') final DateTime? periodEndsAt,
          @JsonKey(name: 'created_at') final DateTime? createdAt}) =
      _$WalletTransactionImpl;

  factory _WalletTransaction.fromJson(Map<String, dynamic> json) =
      _$WalletTransactionImpl.fromJson;

  @override
  @JsonKey(fromJson: _id)
  String? get id;
  @override
  String get type;
  @override
  @JsonKey(name: 'amount_cents')
  int get amountCents;
  @override
  @JsonKey(name: 'balance_after_cents')
  int? get balanceAfterCents;
  @override
  @JsonKey(fromJson: _id)
  String? get reference;

  /// Where a credit came from: `nowpayments` or `patreon`.
  @override
  String? get source;
  @override
  @JsonKey(name: 'period_starts_at')
  DateTime? get periodStartsAt;
  @override
  @JsonKey(name: 'period_ends_at')
  DateTime? get periodEndsAt;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;

  /// Create a copy of WalletTransaction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WalletTransactionImplCopyWith<_$WalletTransactionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PatreonLink _$PatreonLinkFromJson(Map<String, dynamic> json) {
  return _PatreonLink.fromJson(json);
}

/// @nodoc
mixin _$PatreonLink {
  String get id => throw _privateConstructorUsedError;

  /// `pending`, `authorized`, `linked`, `failed`, `cancelled` or `expired`.
  String get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'error_code')
  String? get errorCode => throw _privateConstructorUsedError;
  @JsonKey(name: 'expires_at')
  DateTime? get expiresAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'completed_at')
  DateTime? get completedAt => throw _privateConstructorUsedError;
  String? get url => throw _privateConstructorUsedError;

  /// Serializes this PatreonLink to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PatreonLink
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PatreonLinkCopyWith<PatreonLink> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PatreonLinkCopyWith<$Res> {
  factory $PatreonLinkCopyWith(
          PatreonLink value, $Res Function(PatreonLink) then) =
      _$PatreonLinkCopyWithImpl<$Res, PatreonLink>;
  @useResult
  $Res call(
      {String id,
      String status,
      @JsonKey(name: 'error_code') String? errorCode,
      @JsonKey(name: 'expires_at') DateTime? expiresAt,
      @JsonKey(name: 'completed_at') DateTime? completedAt,
      String? url});
}

/// @nodoc
class _$PatreonLinkCopyWithImpl<$Res, $Val extends PatreonLink>
    implements $PatreonLinkCopyWith<$Res> {
  _$PatreonLinkCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PatreonLink
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? status = null,
    Object? errorCode = freezed,
    Object? expiresAt = freezed,
    Object? completedAt = freezed,
    Object? url = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      errorCode: freezed == errorCode
          ? _value.errorCode
          : errorCode // ignore: cast_nullable_to_non_nullable
              as String?,
      expiresAt: freezed == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      url: freezed == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PatreonLinkImplCopyWith<$Res>
    implements $PatreonLinkCopyWith<$Res> {
  factory _$$PatreonLinkImplCopyWith(
          _$PatreonLinkImpl value, $Res Function(_$PatreonLinkImpl) then) =
      __$$PatreonLinkImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String status,
      @JsonKey(name: 'error_code') String? errorCode,
      @JsonKey(name: 'expires_at') DateTime? expiresAt,
      @JsonKey(name: 'completed_at') DateTime? completedAt,
      String? url});
}

/// @nodoc
class __$$PatreonLinkImplCopyWithImpl<$Res>
    extends _$PatreonLinkCopyWithImpl<$Res, _$PatreonLinkImpl>
    implements _$$PatreonLinkImplCopyWith<$Res> {
  __$$PatreonLinkImplCopyWithImpl(
      _$PatreonLinkImpl _value, $Res Function(_$PatreonLinkImpl) _then)
      : super(_value, _then);

  /// Create a copy of PatreonLink
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? status = null,
    Object? errorCode = freezed,
    Object? expiresAt = freezed,
    Object? completedAt = freezed,
    Object? url = freezed,
  }) {
    return _then(_$PatreonLinkImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      errorCode: freezed == errorCode
          ? _value.errorCode
          : errorCode // ignore: cast_nullable_to_non_nullable
              as String?,
      expiresAt: freezed == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      url: freezed == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PatreonLinkImpl extends _PatreonLink {
  const _$PatreonLinkImpl(
      {required this.id,
      required this.status,
      @JsonKey(name: 'error_code') this.errorCode,
      @JsonKey(name: 'expires_at') this.expiresAt,
      @JsonKey(name: 'completed_at') this.completedAt,
      this.url})
      : super._();

  factory _$PatreonLinkImpl.fromJson(Map<String, dynamic> json) =>
      _$$PatreonLinkImplFromJson(json);

  @override
  final String id;

  /// `pending`, `authorized`, `linked`, `failed`, `cancelled` or `expired`.
  @override
  final String status;
  @override
  @JsonKey(name: 'error_code')
  final String? errorCode;
  @override
  @JsonKey(name: 'expires_at')
  final DateTime? expiresAt;
  @override
  @JsonKey(name: 'completed_at')
  final DateTime? completedAt;
  @override
  final String? url;

  @override
  String toString() {
    return 'PatreonLink(id: $id, status: $status, errorCode: $errorCode, expiresAt: $expiresAt, completedAt: $completedAt, url: $url)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PatreonLinkImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.errorCode, errorCode) ||
                other.errorCode == errorCode) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.url, url) || other.url == url));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, status, errorCode, expiresAt, completedAt, url);

  /// Create a copy of PatreonLink
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PatreonLinkImplCopyWith<_$PatreonLinkImpl> get copyWith =>
      __$$PatreonLinkImplCopyWithImpl<_$PatreonLinkImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PatreonLinkImplToJson(
      this,
    );
  }
}

abstract class _PatreonLink extends PatreonLink {
  const factory _PatreonLink(
      {required final String id,
      required final String status,
      @JsonKey(name: 'error_code') final String? errorCode,
      @JsonKey(name: 'expires_at') final DateTime? expiresAt,
      @JsonKey(name: 'completed_at') final DateTime? completedAt,
      final String? url}) = _$PatreonLinkImpl;
  const _PatreonLink._() : super._();

  factory _PatreonLink.fromJson(Map<String, dynamic> json) =
      _$PatreonLinkImpl.fromJson;

  @override
  String get id;

  /// `pending`, `authorized`, `linked`, `failed`, `cancelled` or `expired`.
  @override
  String get status;
  @override
  @JsonKey(name: 'error_code')
  String? get errorCode;
  @override
  @JsonKey(name: 'expires_at')
  DateTime? get expiresAt;
  @override
  @JsonKey(name: 'completed_at')
  DateTime? get completedAt;
  @override
  String? get url;

  /// Create a copy of PatreonLink
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PatreonLinkImplCopyWith<_$PatreonLinkImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PatreonMembership _$PatreonMembershipFromJson(Map<String, dynamic> json) {
  return _PatreonMembership.fromJson(json);
}

/// @nodoc
mixin _$PatreonMembership {
  bool get enabled => throw _privateConstructorUsedError;
  @JsonKey(name: 'pledge_url')
  String? get pledgeUrl => throw _privateConstructorUsedError;
  bool get linked => throw _privateConstructorUsedError;
  @JsonKey(name: 'full_name')
  String? get fullName => throw _privateConstructorUsedError;
  String? get email => throw _privateConstructorUsedError;
  @JsonKey(name: 'patron_status')
  String? get patronStatus => throw _privateConstructorUsedError;
  @JsonKey(name: 'active_patron')
  bool get activePatron => throw _privateConstructorUsedError;
  @JsonKey(name: 'pledge_cents')
  int get pledgeCents => throw _privateConstructorUsedError;
  @JsonKey(name: 'will_pay_cents')
  int get willPayCents => throw _privateConstructorUsedError;
  @JsonKey(name: 'pledge_cadence_months')
  int? get cadenceMonths => throw _privateConstructorUsedError;

  /// The pledge alone pays for every Plus period.
  @JsonKey(name: 'covers_plus')
  bool get coversPlus => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_charge_at')
  DateTime? get lastChargeAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_charge_status')
  String? get lastChargeStatus => throw _privateConstructorUsedError;
  @JsonKey(name: 'next_charge_at')
  DateTime? get nextChargeAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'free_trial')
  bool get freeTrial => throw _privateConstructorUsedError;
  @JsonKey(name: 'credited_cents')
  int get creditedCents => throw _privateConstructorUsedError;

  /// Plus starts from the balance once a charge covers a period.
  @JsonKey(name: 'plus_pending')
  bool get plusPending => throw _privateConstructorUsedError;
  @JsonKey(name: 'needs_reauthorization')
  bool get needsReauthorization => throw _privateConstructorUsedError;
  @JsonKey(name: 'linked_at')
  DateTime? get linkedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_synced_at')
  DateTime? get lastSyncedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_error_code')
  String? get lastErrorCode => throw _privateConstructorUsedError;
  PatreonLink? get link => throw _privateConstructorUsedError;

  /// Serializes this PatreonMembership to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PatreonMembership
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PatreonMembershipCopyWith<PatreonMembership> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PatreonMembershipCopyWith<$Res> {
  factory $PatreonMembershipCopyWith(
          PatreonMembership value, $Res Function(PatreonMembership) then) =
      _$PatreonMembershipCopyWithImpl<$Res, PatreonMembership>;
  @useResult
  $Res call(
      {bool enabled,
      @JsonKey(name: 'pledge_url') String? pledgeUrl,
      bool linked,
      @JsonKey(name: 'full_name') String? fullName,
      String? email,
      @JsonKey(name: 'patron_status') String? patronStatus,
      @JsonKey(name: 'active_patron') bool activePatron,
      @JsonKey(name: 'pledge_cents') int pledgeCents,
      @JsonKey(name: 'will_pay_cents') int willPayCents,
      @JsonKey(name: 'pledge_cadence_months') int? cadenceMonths,
      @JsonKey(name: 'covers_plus') bool coversPlus,
      @JsonKey(name: 'last_charge_at') DateTime? lastChargeAt,
      @JsonKey(name: 'last_charge_status') String? lastChargeStatus,
      @JsonKey(name: 'next_charge_at') DateTime? nextChargeAt,
      @JsonKey(name: 'free_trial') bool freeTrial,
      @JsonKey(name: 'credited_cents') int creditedCents,
      @JsonKey(name: 'plus_pending') bool plusPending,
      @JsonKey(name: 'needs_reauthorization') bool needsReauthorization,
      @JsonKey(name: 'linked_at') DateTime? linkedAt,
      @JsonKey(name: 'last_synced_at') DateTime? lastSyncedAt,
      @JsonKey(name: 'last_error_code') String? lastErrorCode,
      PatreonLink? link});

  $PatreonLinkCopyWith<$Res>? get link;
}

/// @nodoc
class _$PatreonMembershipCopyWithImpl<$Res, $Val extends PatreonMembership>
    implements $PatreonMembershipCopyWith<$Res> {
  _$PatreonMembershipCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PatreonMembership
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? enabled = null,
    Object? pledgeUrl = freezed,
    Object? linked = null,
    Object? fullName = freezed,
    Object? email = freezed,
    Object? patronStatus = freezed,
    Object? activePatron = null,
    Object? pledgeCents = null,
    Object? willPayCents = null,
    Object? cadenceMonths = freezed,
    Object? coversPlus = null,
    Object? lastChargeAt = freezed,
    Object? lastChargeStatus = freezed,
    Object? nextChargeAt = freezed,
    Object? freeTrial = null,
    Object? creditedCents = null,
    Object? plusPending = null,
    Object? needsReauthorization = null,
    Object? linkedAt = freezed,
    Object? lastSyncedAt = freezed,
    Object? lastErrorCode = freezed,
    Object? link = freezed,
  }) {
    return _then(_value.copyWith(
      enabled: null == enabled
          ? _value.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      pledgeUrl: freezed == pledgeUrl
          ? _value.pledgeUrl
          : pledgeUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      linked: null == linked
          ? _value.linked
          : linked // ignore: cast_nullable_to_non_nullable
              as bool,
      fullName: freezed == fullName
          ? _value.fullName
          : fullName // ignore: cast_nullable_to_non_nullable
              as String?,
      email: freezed == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String?,
      patronStatus: freezed == patronStatus
          ? _value.patronStatus
          : patronStatus // ignore: cast_nullable_to_non_nullable
              as String?,
      activePatron: null == activePatron
          ? _value.activePatron
          : activePatron // ignore: cast_nullable_to_non_nullable
              as bool,
      pledgeCents: null == pledgeCents
          ? _value.pledgeCents
          : pledgeCents // ignore: cast_nullable_to_non_nullable
              as int,
      willPayCents: null == willPayCents
          ? _value.willPayCents
          : willPayCents // ignore: cast_nullable_to_non_nullable
              as int,
      cadenceMonths: freezed == cadenceMonths
          ? _value.cadenceMonths
          : cadenceMonths // ignore: cast_nullable_to_non_nullable
              as int?,
      coversPlus: null == coversPlus
          ? _value.coversPlus
          : coversPlus // ignore: cast_nullable_to_non_nullable
              as bool,
      lastChargeAt: freezed == lastChargeAt
          ? _value.lastChargeAt
          : lastChargeAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastChargeStatus: freezed == lastChargeStatus
          ? _value.lastChargeStatus
          : lastChargeStatus // ignore: cast_nullable_to_non_nullable
              as String?,
      nextChargeAt: freezed == nextChargeAt
          ? _value.nextChargeAt
          : nextChargeAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      freeTrial: null == freeTrial
          ? _value.freeTrial
          : freeTrial // ignore: cast_nullable_to_non_nullable
              as bool,
      creditedCents: null == creditedCents
          ? _value.creditedCents
          : creditedCents // ignore: cast_nullable_to_non_nullable
              as int,
      plusPending: null == plusPending
          ? _value.plusPending
          : plusPending // ignore: cast_nullable_to_non_nullable
              as bool,
      needsReauthorization: null == needsReauthorization
          ? _value.needsReauthorization
          : needsReauthorization // ignore: cast_nullable_to_non_nullable
              as bool,
      linkedAt: freezed == linkedAt
          ? _value.linkedAt
          : linkedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastSyncedAt: freezed == lastSyncedAt
          ? _value.lastSyncedAt
          : lastSyncedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastErrorCode: freezed == lastErrorCode
          ? _value.lastErrorCode
          : lastErrorCode // ignore: cast_nullable_to_non_nullable
              as String?,
      link: freezed == link
          ? _value.link
          : link // ignore: cast_nullable_to_non_nullable
              as PatreonLink?,
    ) as $Val);
  }

  /// Create a copy of PatreonMembership
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PatreonLinkCopyWith<$Res>? get link {
    if (_value.link == null) {
      return null;
    }

    return $PatreonLinkCopyWith<$Res>(_value.link!, (value) {
      return _then(_value.copyWith(link: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$PatreonMembershipImplCopyWith<$Res>
    implements $PatreonMembershipCopyWith<$Res> {
  factory _$$PatreonMembershipImplCopyWith(_$PatreonMembershipImpl value,
          $Res Function(_$PatreonMembershipImpl) then) =
      __$$PatreonMembershipImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool enabled,
      @JsonKey(name: 'pledge_url') String? pledgeUrl,
      bool linked,
      @JsonKey(name: 'full_name') String? fullName,
      String? email,
      @JsonKey(name: 'patron_status') String? patronStatus,
      @JsonKey(name: 'active_patron') bool activePatron,
      @JsonKey(name: 'pledge_cents') int pledgeCents,
      @JsonKey(name: 'will_pay_cents') int willPayCents,
      @JsonKey(name: 'pledge_cadence_months') int? cadenceMonths,
      @JsonKey(name: 'covers_plus') bool coversPlus,
      @JsonKey(name: 'last_charge_at') DateTime? lastChargeAt,
      @JsonKey(name: 'last_charge_status') String? lastChargeStatus,
      @JsonKey(name: 'next_charge_at') DateTime? nextChargeAt,
      @JsonKey(name: 'free_trial') bool freeTrial,
      @JsonKey(name: 'credited_cents') int creditedCents,
      @JsonKey(name: 'plus_pending') bool plusPending,
      @JsonKey(name: 'needs_reauthorization') bool needsReauthorization,
      @JsonKey(name: 'linked_at') DateTime? linkedAt,
      @JsonKey(name: 'last_synced_at') DateTime? lastSyncedAt,
      @JsonKey(name: 'last_error_code') String? lastErrorCode,
      PatreonLink? link});

  @override
  $PatreonLinkCopyWith<$Res>? get link;
}

/// @nodoc
class __$$PatreonMembershipImplCopyWithImpl<$Res>
    extends _$PatreonMembershipCopyWithImpl<$Res, _$PatreonMembershipImpl>
    implements _$$PatreonMembershipImplCopyWith<$Res> {
  __$$PatreonMembershipImplCopyWithImpl(_$PatreonMembershipImpl _value,
      $Res Function(_$PatreonMembershipImpl) _then)
      : super(_value, _then);

  /// Create a copy of PatreonMembership
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? enabled = null,
    Object? pledgeUrl = freezed,
    Object? linked = null,
    Object? fullName = freezed,
    Object? email = freezed,
    Object? patronStatus = freezed,
    Object? activePatron = null,
    Object? pledgeCents = null,
    Object? willPayCents = null,
    Object? cadenceMonths = freezed,
    Object? coversPlus = null,
    Object? lastChargeAt = freezed,
    Object? lastChargeStatus = freezed,
    Object? nextChargeAt = freezed,
    Object? freeTrial = null,
    Object? creditedCents = null,
    Object? plusPending = null,
    Object? needsReauthorization = null,
    Object? linkedAt = freezed,
    Object? lastSyncedAt = freezed,
    Object? lastErrorCode = freezed,
    Object? link = freezed,
  }) {
    return _then(_$PatreonMembershipImpl(
      enabled: null == enabled
          ? _value.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      pledgeUrl: freezed == pledgeUrl
          ? _value.pledgeUrl
          : pledgeUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      linked: null == linked
          ? _value.linked
          : linked // ignore: cast_nullable_to_non_nullable
              as bool,
      fullName: freezed == fullName
          ? _value.fullName
          : fullName // ignore: cast_nullable_to_non_nullable
              as String?,
      email: freezed == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String?,
      patronStatus: freezed == patronStatus
          ? _value.patronStatus
          : patronStatus // ignore: cast_nullable_to_non_nullable
              as String?,
      activePatron: null == activePatron
          ? _value.activePatron
          : activePatron // ignore: cast_nullable_to_non_nullable
              as bool,
      pledgeCents: null == pledgeCents
          ? _value.pledgeCents
          : pledgeCents // ignore: cast_nullable_to_non_nullable
              as int,
      willPayCents: null == willPayCents
          ? _value.willPayCents
          : willPayCents // ignore: cast_nullable_to_non_nullable
              as int,
      cadenceMonths: freezed == cadenceMonths
          ? _value.cadenceMonths
          : cadenceMonths // ignore: cast_nullable_to_non_nullable
              as int?,
      coversPlus: null == coversPlus
          ? _value.coversPlus
          : coversPlus // ignore: cast_nullable_to_non_nullable
              as bool,
      lastChargeAt: freezed == lastChargeAt
          ? _value.lastChargeAt
          : lastChargeAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastChargeStatus: freezed == lastChargeStatus
          ? _value.lastChargeStatus
          : lastChargeStatus // ignore: cast_nullable_to_non_nullable
              as String?,
      nextChargeAt: freezed == nextChargeAt
          ? _value.nextChargeAt
          : nextChargeAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      freeTrial: null == freeTrial
          ? _value.freeTrial
          : freeTrial // ignore: cast_nullable_to_non_nullable
              as bool,
      creditedCents: null == creditedCents
          ? _value.creditedCents
          : creditedCents // ignore: cast_nullable_to_non_nullable
              as int,
      plusPending: null == plusPending
          ? _value.plusPending
          : plusPending // ignore: cast_nullable_to_non_nullable
              as bool,
      needsReauthorization: null == needsReauthorization
          ? _value.needsReauthorization
          : needsReauthorization // ignore: cast_nullable_to_non_nullable
              as bool,
      linkedAt: freezed == linkedAt
          ? _value.linkedAt
          : linkedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastSyncedAt: freezed == lastSyncedAt
          ? _value.lastSyncedAt
          : lastSyncedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastErrorCode: freezed == lastErrorCode
          ? _value.lastErrorCode
          : lastErrorCode // ignore: cast_nullable_to_non_nullable
              as String?,
      link: freezed == link
          ? _value.link
          : link // ignore: cast_nullable_to_non_nullable
              as PatreonLink?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PatreonMembershipImpl extends _PatreonMembership {
  const _$PatreonMembershipImpl(
      {this.enabled = false,
      @JsonKey(name: 'pledge_url') this.pledgeUrl,
      this.linked = false,
      @JsonKey(name: 'full_name') this.fullName,
      this.email,
      @JsonKey(name: 'patron_status') this.patronStatus,
      @JsonKey(name: 'active_patron') this.activePatron = false,
      @JsonKey(name: 'pledge_cents') this.pledgeCents = 0,
      @JsonKey(name: 'will_pay_cents') this.willPayCents = 0,
      @JsonKey(name: 'pledge_cadence_months') this.cadenceMonths,
      @JsonKey(name: 'covers_plus') this.coversPlus = false,
      @JsonKey(name: 'last_charge_at') this.lastChargeAt,
      @JsonKey(name: 'last_charge_status') this.lastChargeStatus,
      @JsonKey(name: 'next_charge_at') this.nextChargeAt,
      @JsonKey(name: 'free_trial') this.freeTrial = false,
      @JsonKey(name: 'credited_cents') this.creditedCents = 0,
      @JsonKey(name: 'plus_pending') this.plusPending = false,
      @JsonKey(name: 'needs_reauthorization') this.needsReauthorization = false,
      @JsonKey(name: 'linked_at') this.linkedAt,
      @JsonKey(name: 'last_synced_at') this.lastSyncedAt,
      @JsonKey(name: 'last_error_code') this.lastErrorCode,
      this.link})
      : super._();

  factory _$PatreonMembershipImpl.fromJson(Map<String, dynamic> json) =>
      _$$PatreonMembershipImplFromJson(json);

  @override
  @JsonKey()
  final bool enabled;
  @override
  @JsonKey(name: 'pledge_url')
  final String? pledgeUrl;
  @override
  @JsonKey()
  final bool linked;
  @override
  @JsonKey(name: 'full_name')
  final String? fullName;
  @override
  final String? email;
  @override
  @JsonKey(name: 'patron_status')
  final String? patronStatus;
  @override
  @JsonKey(name: 'active_patron')
  final bool activePatron;
  @override
  @JsonKey(name: 'pledge_cents')
  final int pledgeCents;
  @override
  @JsonKey(name: 'will_pay_cents')
  final int willPayCents;
  @override
  @JsonKey(name: 'pledge_cadence_months')
  final int? cadenceMonths;

  /// The pledge alone pays for every Plus period.
  @override
  @JsonKey(name: 'covers_plus')
  final bool coversPlus;
  @override
  @JsonKey(name: 'last_charge_at')
  final DateTime? lastChargeAt;
  @override
  @JsonKey(name: 'last_charge_status')
  final String? lastChargeStatus;
  @override
  @JsonKey(name: 'next_charge_at')
  final DateTime? nextChargeAt;
  @override
  @JsonKey(name: 'free_trial')
  final bool freeTrial;
  @override
  @JsonKey(name: 'credited_cents')
  final int creditedCents;

  /// Plus starts from the balance once a charge covers a period.
  @override
  @JsonKey(name: 'plus_pending')
  final bool plusPending;
  @override
  @JsonKey(name: 'needs_reauthorization')
  final bool needsReauthorization;
  @override
  @JsonKey(name: 'linked_at')
  final DateTime? linkedAt;
  @override
  @JsonKey(name: 'last_synced_at')
  final DateTime? lastSyncedAt;
  @override
  @JsonKey(name: 'last_error_code')
  final String? lastErrorCode;
  @override
  final PatreonLink? link;

  @override
  String toString() {
    return 'PatreonMembership(enabled: $enabled, pledgeUrl: $pledgeUrl, linked: $linked, fullName: $fullName, email: $email, patronStatus: $patronStatus, activePatron: $activePatron, pledgeCents: $pledgeCents, willPayCents: $willPayCents, cadenceMonths: $cadenceMonths, coversPlus: $coversPlus, lastChargeAt: $lastChargeAt, lastChargeStatus: $lastChargeStatus, nextChargeAt: $nextChargeAt, freeTrial: $freeTrial, creditedCents: $creditedCents, plusPending: $plusPending, needsReauthorization: $needsReauthorization, linkedAt: $linkedAt, lastSyncedAt: $lastSyncedAt, lastErrorCode: $lastErrorCode, link: $link)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PatreonMembershipImpl &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            (identical(other.pledgeUrl, pledgeUrl) ||
                other.pledgeUrl == pledgeUrl) &&
            (identical(other.linked, linked) || other.linked == linked) &&
            (identical(other.fullName, fullName) ||
                other.fullName == fullName) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.patronStatus, patronStatus) ||
                other.patronStatus == patronStatus) &&
            (identical(other.activePatron, activePatron) ||
                other.activePatron == activePatron) &&
            (identical(other.pledgeCents, pledgeCents) ||
                other.pledgeCents == pledgeCents) &&
            (identical(other.willPayCents, willPayCents) ||
                other.willPayCents == willPayCents) &&
            (identical(other.cadenceMonths, cadenceMonths) ||
                other.cadenceMonths == cadenceMonths) &&
            (identical(other.coversPlus, coversPlus) ||
                other.coversPlus == coversPlus) &&
            (identical(other.lastChargeAt, lastChargeAt) ||
                other.lastChargeAt == lastChargeAt) &&
            (identical(other.lastChargeStatus, lastChargeStatus) ||
                other.lastChargeStatus == lastChargeStatus) &&
            (identical(other.nextChargeAt, nextChargeAt) ||
                other.nextChargeAt == nextChargeAt) &&
            (identical(other.freeTrial, freeTrial) ||
                other.freeTrial == freeTrial) &&
            (identical(other.creditedCents, creditedCents) ||
                other.creditedCents == creditedCents) &&
            (identical(other.plusPending, plusPending) ||
                other.plusPending == plusPending) &&
            (identical(other.needsReauthorization, needsReauthorization) ||
                other.needsReauthorization == needsReauthorization) &&
            (identical(other.linkedAt, linkedAt) ||
                other.linkedAt == linkedAt) &&
            (identical(other.lastSyncedAt, lastSyncedAt) ||
                other.lastSyncedAt == lastSyncedAt) &&
            (identical(other.lastErrorCode, lastErrorCode) ||
                other.lastErrorCode == lastErrorCode) &&
            (identical(other.link, link) || other.link == link));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        enabled,
        pledgeUrl,
        linked,
        fullName,
        email,
        patronStatus,
        activePatron,
        pledgeCents,
        willPayCents,
        cadenceMonths,
        coversPlus,
        lastChargeAt,
        lastChargeStatus,
        nextChargeAt,
        freeTrial,
        creditedCents,
        plusPending,
        needsReauthorization,
        linkedAt,
        lastSyncedAt,
        lastErrorCode,
        link
      ]);

  /// Create a copy of PatreonMembership
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PatreonMembershipImplCopyWith<_$PatreonMembershipImpl> get copyWith =>
      __$$PatreonMembershipImplCopyWithImpl<_$PatreonMembershipImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PatreonMembershipImplToJson(
      this,
    );
  }
}

abstract class _PatreonMembership extends PatreonMembership {
  const factory _PatreonMembership(
      {final bool enabled,
      @JsonKey(name: 'pledge_url') final String? pledgeUrl,
      final bool linked,
      @JsonKey(name: 'full_name') final String? fullName,
      final String? email,
      @JsonKey(name: 'patron_status') final String? patronStatus,
      @JsonKey(name: 'active_patron') final bool activePatron,
      @JsonKey(name: 'pledge_cents') final int pledgeCents,
      @JsonKey(name: 'will_pay_cents') final int willPayCents,
      @JsonKey(name: 'pledge_cadence_months') final int? cadenceMonths,
      @JsonKey(name: 'covers_plus') final bool coversPlus,
      @JsonKey(name: 'last_charge_at') final DateTime? lastChargeAt,
      @JsonKey(name: 'last_charge_status') final String? lastChargeStatus,
      @JsonKey(name: 'next_charge_at') final DateTime? nextChargeAt,
      @JsonKey(name: 'free_trial') final bool freeTrial,
      @JsonKey(name: 'credited_cents') final int creditedCents,
      @JsonKey(name: 'plus_pending') final bool plusPending,
      @JsonKey(name: 'needs_reauthorization') final bool needsReauthorization,
      @JsonKey(name: 'linked_at') final DateTime? linkedAt,
      @JsonKey(name: 'last_synced_at') final DateTime? lastSyncedAt,
      @JsonKey(name: 'last_error_code') final String? lastErrorCode,
      final PatreonLink? link}) = _$PatreonMembershipImpl;
  const _PatreonMembership._() : super._();

  factory _PatreonMembership.fromJson(Map<String, dynamic> json) =
      _$PatreonMembershipImpl.fromJson;

  @override
  bool get enabled;
  @override
  @JsonKey(name: 'pledge_url')
  String? get pledgeUrl;
  @override
  bool get linked;
  @override
  @JsonKey(name: 'full_name')
  String? get fullName;
  @override
  String? get email;
  @override
  @JsonKey(name: 'patron_status')
  String? get patronStatus;
  @override
  @JsonKey(name: 'active_patron')
  bool get activePatron;
  @override
  @JsonKey(name: 'pledge_cents')
  int get pledgeCents;
  @override
  @JsonKey(name: 'will_pay_cents')
  int get willPayCents;
  @override
  @JsonKey(name: 'pledge_cadence_months')
  int? get cadenceMonths;

  /// The pledge alone pays for every Plus period.
  @override
  @JsonKey(name: 'covers_plus')
  bool get coversPlus;
  @override
  @JsonKey(name: 'last_charge_at')
  DateTime? get lastChargeAt;
  @override
  @JsonKey(name: 'last_charge_status')
  String? get lastChargeStatus;
  @override
  @JsonKey(name: 'next_charge_at')
  DateTime? get nextChargeAt;
  @override
  @JsonKey(name: 'free_trial')
  bool get freeTrial;
  @override
  @JsonKey(name: 'credited_cents')
  int get creditedCents;

  /// Plus starts from the balance once a charge covers a period.
  @override
  @JsonKey(name: 'plus_pending')
  bool get plusPending;
  @override
  @JsonKey(name: 'needs_reauthorization')
  bool get needsReauthorization;
  @override
  @JsonKey(name: 'linked_at')
  DateTime? get linkedAt;
  @override
  @JsonKey(name: 'last_synced_at')
  DateTime? get lastSyncedAt;
  @override
  @JsonKey(name: 'last_error_code')
  String? get lastErrorCode;
  @override
  PatreonLink? get link;

  /// Create a copy of PatreonMembership
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PatreonMembershipImplCopyWith<_$PatreonMembershipImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PlusAccount _$PlusAccountFromJson(Map<String, dynamic> json) {
  return _PlusAccount.fromJson(json);
}

/// @nodoc
mixin _$PlusAccount {
  PlusEntitlement get entitlements => throw _privateConstructorUsedError;
  @JsonKey(name: 'server_time')
  DateTime? get serverTime => throw _privateConstructorUsedError;
  @JsonKey(name: 'refresh_after_seconds')
  int get refreshAfterSeconds => throw _privateConstructorUsedError;
  @JsonKey(name: 'subscription')
  PlusRenewal? get renewal => throw _privateConstructorUsedError;
  WalletBalance? get wallet => throw _privateConstructorUsedError;
  @JsonKey(name: 'pending_topups')
  List<WalletTopup> get pendingTopups => throw _privateConstructorUsedError;
  PatreonMembership? get patreon => throw _privateConstructorUsedError;

  /// Serializes this PlusAccount to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PlusAccount
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlusAccountCopyWith<PlusAccount> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlusAccountCopyWith<$Res> {
  factory $PlusAccountCopyWith(
          PlusAccount value, $Res Function(PlusAccount) then) =
      _$PlusAccountCopyWithImpl<$Res, PlusAccount>;
  @useResult
  $Res call(
      {PlusEntitlement entitlements,
      @JsonKey(name: 'server_time') DateTime? serverTime,
      @JsonKey(name: 'refresh_after_seconds') int refreshAfterSeconds,
      @JsonKey(name: 'subscription') PlusRenewal? renewal,
      WalletBalance? wallet,
      @JsonKey(name: 'pending_topups') List<WalletTopup> pendingTopups,
      PatreonMembership? patreon});

  $PlusEntitlementCopyWith<$Res> get entitlements;
  $PlusRenewalCopyWith<$Res>? get renewal;
  $WalletBalanceCopyWith<$Res>? get wallet;
  $PatreonMembershipCopyWith<$Res>? get patreon;
}

/// @nodoc
class _$PlusAccountCopyWithImpl<$Res, $Val extends PlusAccount>
    implements $PlusAccountCopyWith<$Res> {
  _$PlusAccountCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlusAccount
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? entitlements = null,
    Object? serverTime = freezed,
    Object? refreshAfterSeconds = null,
    Object? renewal = freezed,
    Object? wallet = freezed,
    Object? pendingTopups = null,
    Object? patreon = freezed,
  }) {
    return _then(_value.copyWith(
      entitlements: null == entitlements
          ? _value.entitlements
          : entitlements // ignore: cast_nullable_to_non_nullable
              as PlusEntitlement,
      serverTime: freezed == serverTime
          ? _value.serverTime
          : serverTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      refreshAfterSeconds: null == refreshAfterSeconds
          ? _value.refreshAfterSeconds
          : refreshAfterSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      renewal: freezed == renewal
          ? _value.renewal
          : renewal // ignore: cast_nullable_to_non_nullable
              as PlusRenewal?,
      wallet: freezed == wallet
          ? _value.wallet
          : wallet // ignore: cast_nullable_to_non_nullable
              as WalletBalance?,
      pendingTopups: null == pendingTopups
          ? _value.pendingTopups
          : pendingTopups // ignore: cast_nullable_to_non_nullable
              as List<WalletTopup>,
      patreon: freezed == patreon
          ? _value.patreon
          : patreon // ignore: cast_nullable_to_non_nullable
              as PatreonMembership?,
    ) as $Val);
  }

  /// Create a copy of PlusAccount
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PlusEntitlementCopyWith<$Res> get entitlements {
    return $PlusEntitlementCopyWith<$Res>(_value.entitlements, (value) {
      return _then(_value.copyWith(entitlements: value) as $Val);
    });
  }

  /// Create a copy of PlusAccount
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PlusRenewalCopyWith<$Res>? get renewal {
    if (_value.renewal == null) {
      return null;
    }

    return $PlusRenewalCopyWith<$Res>(_value.renewal!, (value) {
      return _then(_value.copyWith(renewal: value) as $Val);
    });
  }

  /// Create a copy of PlusAccount
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $WalletBalanceCopyWith<$Res>? get wallet {
    if (_value.wallet == null) {
      return null;
    }

    return $WalletBalanceCopyWith<$Res>(_value.wallet!, (value) {
      return _then(_value.copyWith(wallet: value) as $Val);
    });
  }

  /// Create a copy of PlusAccount
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PatreonMembershipCopyWith<$Res>? get patreon {
    if (_value.patreon == null) {
      return null;
    }

    return $PatreonMembershipCopyWith<$Res>(_value.patreon!, (value) {
      return _then(_value.copyWith(patreon: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$PlusAccountImplCopyWith<$Res>
    implements $PlusAccountCopyWith<$Res> {
  factory _$$PlusAccountImplCopyWith(
          _$PlusAccountImpl value, $Res Function(_$PlusAccountImpl) then) =
      __$$PlusAccountImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {PlusEntitlement entitlements,
      @JsonKey(name: 'server_time') DateTime? serverTime,
      @JsonKey(name: 'refresh_after_seconds') int refreshAfterSeconds,
      @JsonKey(name: 'subscription') PlusRenewal? renewal,
      WalletBalance? wallet,
      @JsonKey(name: 'pending_topups') List<WalletTopup> pendingTopups,
      PatreonMembership? patreon});

  @override
  $PlusEntitlementCopyWith<$Res> get entitlements;
  @override
  $PlusRenewalCopyWith<$Res>? get renewal;
  @override
  $WalletBalanceCopyWith<$Res>? get wallet;
  @override
  $PatreonMembershipCopyWith<$Res>? get patreon;
}

/// @nodoc
class __$$PlusAccountImplCopyWithImpl<$Res>
    extends _$PlusAccountCopyWithImpl<$Res, _$PlusAccountImpl>
    implements _$$PlusAccountImplCopyWith<$Res> {
  __$$PlusAccountImplCopyWithImpl(
      _$PlusAccountImpl _value, $Res Function(_$PlusAccountImpl) _then)
      : super(_value, _then);

  /// Create a copy of PlusAccount
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? entitlements = null,
    Object? serverTime = freezed,
    Object? refreshAfterSeconds = null,
    Object? renewal = freezed,
    Object? wallet = freezed,
    Object? pendingTopups = null,
    Object? patreon = freezed,
  }) {
    return _then(_$PlusAccountImpl(
      entitlements: null == entitlements
          ? _value.entitlements
          : entitlements // ignore: cast_nullable_to_non_nullable
              as PlusEntitlement,
      serverTime: freezed == serverTime
          ? _value.serverTime
          : serverTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      refreshAfterSeconds: null == refreshAfterSeconds
          ? _value.refreshAfterSeconds
          : refreshAfterSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      renewal: freezed == renewal
          ? _value.renewal
          : renewal // ignore: cast_nullable_to_non_nullable
              as PlusRenewal?,
      wallet: freezed == wallet
          ? _value.wallet
          : wallet // ignore: cast_nullable_to_non_nullable
              as WalletBalance?,
      pendingTopups: null == pendingTopups
          ? _value._pendingTopups
          : pendingTopups // ignore: cast_nullable_to_non_nullable
              as List<WalletTopup>,
      patreon: freezed == patreon
          ? _value.patreon
          : patreon // ignore: cast_nullable_to_non_nullable
              as PatreonMembership?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PlusAccountImpl implements _PlusAccount {
  const _$PlusAccountImpl(
      {this.entitlements = const PlusEntitlement(),
      @JsonKey(name: 'server_time') this.serverTime,
      @JsonKey(name: 'refresh_after_seconds') this.refreshAfterSeconds = 300,
      @JsonKey(name: 'subscription') this.renewal,
      this.wallet,
      @JsonKey(name: 'pending_topups')
      final List<WalletTopup> pendingTopups = const <WalletTopup>[],
      this.patreon})
      : _pendingTopups = pendingTopups;

  factory _$PlusAccountImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlusAccountImplFromJson(json);

  @override
  @JsonKey()
  final PlusEntitlement entitlements;
  @override
  @JsonKey(name: 'server_time')
  final DateTime? serverTime;
  @override
  @JsonKey(name: 'refresh_after_seconds')
  final int refreshAfterSeconds;
  @override
  @JsonKey(name: 'subscription')
  final PlusRenewal? renewal;
  @override
  final WalletBalance? wallet;
  final List<WalletTopup> _pendingTopups;
  @override
  @JsonKey(name: 'pending_topups')
  List<WalletTopup> get pendingTopups {
    if (_pendingTopups is EqualUnmodifiableListView) return _pendingTopups;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_pendingTopups);
  }

  @override
  final PatreonMembership? patreon;

  @override
  String toString() {
    return 'PlusAccount(entitlements: $entitlements, serverTime: $serverTime, refreshAfterSeconds: $refreshAfterSeconds, renewal: $renewal, wallet: $wallet, pendingTopups: $pendingTopups, patreon: $patreon)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlusAccountImpl &&
            (identical(other.entitlements, entitlements) ||
                other.entitlements == entitlements) &&
            (identical(other.serverTime, serverTime) ||
                other.serverTime == serverTime) &&
            (identical(other.refreshAfterSeconds, refreshAfterSeconds) ||
                other.refreshAfterSeconds == refreshAfterSeconds) &&
            (identical(other.renewal, renewal) || other.renewal == renewal) &&
            (identical(other.wallet, wallet) || other.wallet == wallet) &&
            const DeepCollectionEquality()
                .equals(other._pendingTopups, _pendingTopups) &&
            (identical(other.patreon, patreon) || other.patreon == patreon));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      entitlements,
      serverTime,
      refreshAfterSeconds,
      renewal,
      wallet,
      const DeepCollectionEquality().hash(_pendingTopups),
      patreon);

  /// Create a copy of PlusAccount
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlusAccountImplCopyWith<_$PlusAccountImpl> get copyWith =>
      __$$PlusAccountImplCopyWithImpl<_$PlusAccountImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PlusAccountImplToJson(
      this,
    );
  }
}

abstract class _PlusAccount implements PlusAccount {
  const factory _PlusAccount(
      {final PlusEntitlement entitlements,
      @JsonKey(name: 'server_time') final DateTime? serverTime,
      @JsonKey(name: 'refresh_after_seconds') final int refreshAfterSeconds,
      @JsonKey(name: 'subscription') final PlusRenewal? renewal,
      final WalletBalance? wallet,
      @JsonKey(name: 'pending_topups') final List<WalletTopup> pendingTopups,
      final PatreonMembership? patreon}) = _$PlusAccountImpl;

  factory _PlusAccount.fromJson(Map<String, dynamic> json) =
      _$PlusAccountImpl.fromJson;

  @override
  PlusEntitlement get entitlements;
  @override
  @JsonKey(name: 'server_time')
  DateTime? get serverTime;
  @override
  @JsonKey(name: 'refresh_after_seconds')
  int get refreshAfterSeconds;
  @override
  @JsonKey(name: 'subscription')
  PlusRenewal? get renewal;
  @override
  WalletBalance? get wallet;
  @override
  @JsonKey(name: 'pending_topups')
  List<WalletTopup> get pendingTopups;
  @override
  PatreonMembership? get patreon;

  /// Create a copy of PlusAccount
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlusAccountImplCopyWith<_$PlusAccountImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CouponRedemption _$CouponRedemptionFromJson(Map<String, dynamic> json) {
  return _CouponRedemption.fromJson(json);
}

/// @nodoc
mixin _$CouponRedemption {
  String get type => throw _privateConstructorUsedError;
  @JsonKey(name: 'free_days')
  int? get freeDays => throw _privateConstructorUsedError;
  @JsonKey(name: 'percent_off')
  int? get percentOff => throw _privateConstructorUsedError;
  @JsonKey(name: 'amount_off_cents')
  int? get amountOffCents => throw _privateConstructorUsedError;
  @JsonKey(name: 'discount_periods')
  int? get discountPeriods => throw _privateConstructorUsedError;
  String? get summary => throw _privateConstructorUsedError;

  /// Serializes this CouponRedemption to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CouponRedemption
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CouponRedemptionCopyWith<CouponRedemption> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CouponRedemptionCopyWith<$Res> {
  factory $CouponRedemptionCopyWith(
          CouponRedemption value, $Res Function(CouponRedemption) then) =
      _$CouponRedemptionCopyWithImpl<$Res, CouponRedemption>;
  @useResult
  $Res call(
      {String type,
      @JsonKey(name: 'free_days') int? freeDays,
      @JsonKey(name: 'percent_off') int? percentOff,
      @JsonKey(name: 'amount_off_cents') int? amountOffCents,
      @JsonKey(name: 'discount_periods') int? discountPeriods,
      String? summary});
}

/// @nodoc
class _$CouponRedemptionCopyWithImpl<$Res, $Val extends CouponRedemption>
    implements $CouponRedemptionCopyWith<$Res> {
  _$CouponRedemptionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CouponRedemption
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? freeDays = freezed,
    Object? percentOff = freezed,
    Object? amountOffCents = freezed,
    Object? discountPeriods = freezed,
    Object? summary = freezed,
  }) {
    return _then(_value.copyWith(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      freeDays: freezed == freeDays
          ? _value.freeDays
          : freeDays // ignore: cast_nullable_to_non_nullable
              as int?,
      percentOff: freezed == percentOff
          ? _value.percentOff
          : percentOff // ignore: cast_nullable_to_non_nullable
              as int?,
      amountOffCents: freezed == amountOffCents
          ? _value.amountOffCents
          : amountOffCents // ignore: cast_nullable_to_non_nullable
              as int?,
      discountPeriods: freezed == discountPeriods
          ? _value.discountPeriods
          : discountPeriods // ignore: cast_nullable_to_non_nullable
              as int?,
      summary: freezed == summary
          ? _value.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CouponRedemptionImplCopyWith<$Res>
    implements $CouponRedemptionCopyWith<$Res> {
  factory _$$CouponRedemptionImplCopyWith(_$CouponRedemptionImpl value,
          $Res Function(_$CouponRedemptionImpl) then) =
      __$$CouponRedemptionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String type,
      @JsonKey(name: 'free_days') int? freeDays,
      @JsonKey(name: 'percent_off') int? percentOff,
      @JsonKey(name: 'amount_off_cents') int? amountOffCents,
      @JsonKey(name: 'discount_periods') int? discountPeriods,
      String? summary});
}

/// @nodoc
class __$$CouponRedemptionImplCopyWithImpl<$Res>
    extends _$CouponRedemptionCopyWithImpl<$Res, _$CouponRedemptionImpl>
    implements _$$CouponRedemptionImplCopyWith<$Res> {
  __$$CouponRedemptionImplCopyWithImpl(_$CouponRedemptionImpl _value,
      $Res Function(_$CouponRedemptionImpl) _then)
      : super(_value, _then);

  /// Create a copy of CouponRedemption
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? freeDays = freezed,
    Object? percentOff = freezed,
    Object? amountOffCents = freezed,
    Object? discountPeriods = freezed,
    Object? summary = freezed,
  }) {
    return _then(_$CouponRedemptionImpl(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      freeDays: freezed == freeDays
          ? _value.freeDays
          : freeDays // ignore: cast_nullable_to_non_nullable
              as int?,
      percentOff: freezed == percentOff
          ? _value.percentOff
          : percentOff // ignore: cast_nullable_to_non_nullable
              as int?,
      amountOffCents: freezed == amountOffCents
          ? _value.amountOffCents
          : amountOffCents // ignore: cast_nullable_to_non_nullable
              as int?,
      discountPeriods: freezed == discountPeriods
          ? _value.discountPeriods
          : discountPeriods // ignore: cast_nullable_to_non_nullable
              as int?,
      summary: freezed == summary
          ? _value.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CouponRedemptionImpl implements _CouponRedemption {
  const _$CouponRedemptionImpl(
      {required this.type,
      @JsonKey(name: 'free_days') this.freeDays,
      @JsonKey(name: 'percent_off') this.percentOff,
      @JsonKey(name: 'amount_off_cents') this.amountOffCents,
      @JsonKey(name: 'discount_periods') this.discountPeriods,
      this.summary});

  factory _$CouponRedemptionImpl.fromJson(Map<String, dynamic> json) =>
      _$$CouponRedemptionImplFromJson(json);

  @override
  final String type;
  @override
  @JsonKey(name: 'free_days')
  final int? freeDays;
  @override
  @JsonKey(name: 'percent_off')
  final int? percentOff;
  @override
  @JsonKey(name: 'amount_off_cents')
  final int? amountOffCents;
  @override
  @JsonKey(name: 'discount_periods')
  final int? discountPeriods;
  @override
  final String? summary;

  @override
  String toString() {
    return 'CouponRedemption(type: $type, freeDays: $freeDays, percentOff: $percentOff, amountOffCents: $amountOffCents, discountPeriods: $discountPeriods, summary: $summary)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CouponRedemptionImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.freeDays, freeDays) ||
                other.freeDays == freeDays) &&
            (identical(other.percentOff, percentOff) ||
                other.percentOff == percentOff) &&
            (identical(other.amountOffCents, amountOffCents) ||
                other.amountOffCents == amountOffCents) &&
            (identical(other.discountPeriods, discountPeriods) ||
                other.discountPeriods == discountPeriods) &&
            (identical(other.summary, summary) || other.summary == summary));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, type, freeDays, percentOff,
      amountOffCents, discountPeriods, summary);

  /// Create a copy of CouponRedemption
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CouponRedemptionImplCopyWith<_$CouponRedemptionImpl> get copyWith =>
      __$$CouponRedemptionImplCopyWithImpl<_$CouponRedemptionImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CouponRedemptionImplToJson(
      this,
    );
  }
}

abstract class _CouponRedemption implements CouponRedemption {
  const factory _CouponRedemption(
      {required final String type,
      @JsonKey(name: 'free_days') final int? freeDays,
      @JsonKey(name: 'percent_off') final int? percentOff,
      @JsonKey(name: 'amount_off_cents') final int? amountOffCents,
      @JsonKey(name: 'discount_periods') final int? discountPeriods,
      final String? summary}) = _$CouponRedemptionImpl;

  factory _CouponRedemption.fromJson(Map<String, dynamic> json) =
      _$CouponRedemptionImpl.fromJson;

  @override
  String get type;
  @override
  @JsonKey(name: 'free_days')
  int? get freeDays;
  @override
  @JsonKey(name: 'percent_off')
  int? get percentOff;
  @override
  @JsonKey(name: 'amount_off_cents')
  int? get amountOffCents;
  @override
  @JsonKey(name: 'discount_periods')
  int? get discountPeriods;
  @override
  String? get summary;

  /// Create a copy of CouponRedemption
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CouponRedemptionImplCopyWith<_$CouponRedemptionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
