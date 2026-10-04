// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bootstrap_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

FeaturesConfig _$FeaturesConfigFromJson(Map<String, dynamic> json) {
  return _FeaturesConfig.fromJson(json);
}

/// @nodoc
mixin _$FeaturesConfig {
  @JsonKey(name: 'enable_stream')
  bool get enableStream => throw _privateConstructorUsedError;
  @JsonKey(name: 'enable_download')
  bool get enableDownload => throw _privateConstructorUsedError;
  @JsonKey(name: 'enable_live_tv')
  bool get enableLiveTv => throw _privateConstructorUsedError;
  @JsonKey(name: 'enable_ott')
  bool get enableOtt => throw _privateConstructorUsedError;

  /// Serializes this FeaturesConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FeaturesConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FeaturesConfigCopyWith<FeaturesConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FeaturesConfigCopyWith<$Res> {
  factory $FeaturesConfigCopyWith(
          FeaturesConfig value, $Res Function(FeaturesConfig) then) =
      _$FeaturesConfigCopyWithImpl<$Res, FeaturesConfig>;
  @useResult
  $Res call(
      {@JsonKey(name: 'enable_stream') bool enableStream,
      @JsonKey(name: 'enable_download') bool enableDownload,
      @JsonKey(name: 'enable_live_tv') bool enableLiveTv,
      @JsonKey(name: 'enable_ott') bool enableOtt});
}

/// @nodoc
class _$FeaturesConfigCopyWithImpl<$Res, $Val extends FeaturesConfig>
    implements $FeaturesConfigCopyWith<$Res> {
  _$FeaturesConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FeaturesConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? enableStream = null,
    Object? enableDownload = null,
    Object? enableLiveTv = null,
    Object? enableOtt = null,
  }) {
    return _then(_value.copyWith(
      enableStream: null == enableStream
          ? _value.enableStream
          : enableStream // ignore: cast_nullable_to_non_nullable
              as bool,
      enableDownload: null == enableDownload
          ? _value.enableDownload
          : enableDownload // ignore: cast_nullable_to_non_nullable
              as bool,
      enableLiveTv: null == enableLiveTv
          ? _value.enableLiveTv
          : enableLiveTv // ignore: cast_nullable_to_non_nullable
              as bool,
      enableOtt: null == enableOtt
          ? _value.enableOtt
          : enableOtt // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FeaturesConfigImplCopyWith<$Res>
    implements $FeaturesConfigCopyWith<$Res> {
  factory _$$FeaturesConfigImplCopyWith(_$FeaturesConfigImpl value,
          $Res Function(_$FeaturesConfigImpl) then) =
      __$$FeaturesConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'enable_stream') bool enableStream,
      @JsonKey(name: 'enable_download') bool enableDownload,
      @JsonKey(name: 'enable_live_tv') bool enableLiveTv,
      @JsonKey(name: 'enable_ott') bool enableOtt});
}

/// @nodoc
class __$$FeaturesConfigImplCopyWithImpl<$Res>
    extends _$FeaturesConfigCopyWithImpl<$Res, _$FeaturesConfigImpl>
    implements _$$FeaturesConfigImplCopyWith<$Res> {
  __$$FeaturesConfigImplCopyWithImpl(
      _$FeaturesConfigImpl _value, $Res Function(_$FeaturesConfigImpl) _then)
      : super(_value, _then);

  /// Create a copy of FeaturesConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? enableStream = null,
    Object? enableDownload = null,
    Object? enableLiveTv = null,
    Object? enableOtt = null,
  }) {
    return _then(_$FeaturesConfigImpl(
      enableStream: null == enableStream
          ? _value.enableStream
          : enableStream // ignore: cast_nullable_to_non_nullable
              as bool,
      enableDownload: null == enableDownload
          ? _value.enableDownload
          : enableDownload // ignore: cast_nullable_to_non_nullable
              as bool,
      enableLiveTv: null == enableLiveTv
          ? _value.enableLiveTv
          : enableLiveTv // ignore: cast_nullable_to_non_nullable
              as bool,
      enableOtt: null == enableOtt
          ? _value.enableOtt
          : enableOtt // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FeaturesConfigImpl implements _FeaturesConfig {
  const _$FeaturesConfigImpl(
      {@JsonKey(name: 'enable_stream') this.enableStream = true,
      @JsonKey(name: 'enable_download') this.enableDownload = true,
      @JsonKey(name: 'enable_live_tv') this.enableLiveTv = true,
      @JsonKey(name: 'enable_ott') this.enableOtt = true});

  factory _$FeaturesConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$FeaturesConfigImplFromJson(json);

  @override
  @JsonKey(name: 'enable_stream')
  final bool enableStream;
  @override
  @JsonKey(name: 'enable_download')
  final bool enableDownload;
  @override
  @JsonKey(name: 'enable_live_tv')
  final bool enableLiveTv;
  @override
  @JsonKey(name: 'enable_ott')
  final bool enableOtt;

  @override
  String toString() {
    return 'FeaturesConfig(enableStream: $enableStream, enableDownload: $enableDownload, enableLiveTv: $enableLiveTv, enableOtt: $enableOtt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FeaturesConfigImpl &&
            (identical(other.enableStream, enableStream) ||
                other.enableStream == enableStream) &&
            (identical(other.enableDownload, enableDownload) ||
                other.enableDownload == enableDownload) &&
            (identical(other.enableLiveTv, enableLiveTv) ||
                other.enableLiveTv == enableLiveTv) &&
            (identical(other.enableOtt, enableOtt) ||
                other.enableOtt == enableOtt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, enableStream, enableDownload, enableLiveTv, enableOtt);

  /// Create a copy of FeaturesConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FeaturesConfigImplCopyWith<_$FeaturesConfigImpl> get copyWith =>
      __$$FeaturesConfigImplCopyWithImpl<_$FeaturesConfigImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FeaturesConfigImplToJson(
      this,
    );
  }
}

abstract class _FeaturesConfig implements FeaturesConfig {
  const factory _FeaturesConfig(
          {@JsonKey(name: 'enable_stream') final bool enableStream,
          @JsonKey(name: 'enable_download') final bool enableDownload,
          @JsonKey(name: 'enable_live_tv') final bool enableLiveTv,
          @JsonKey(name: 'enable_ott') final bool enableOtt}) =
      _$FeaturesConfigImpl;

  factory _FeaturesConfig.fromJson(Map<String, dynamic> json) =
      _$FeaturesConfigImpl.fromJson;

  @override
  @JsonKey(name: 'enable_stream')
  bool get enableStream;
  @override
  @JsonKey(name: 'enable_download')
  bool get enableDownload;
  @override
  @JsonKey(name: 'enable_live_tv')
  bool get enableLiveTv;
  @override
  @JsonKey(name: 'enable_ott')
  bool get enableOtt;

  /// Create a copy of FeaturesConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FeaturesConfigImplCopyWith<_$FeaturesConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

BrandingConfig _$BrandingConfigFromJson(Map<String, dynamic> json) {
  return _BrandingConfig.fromJson(json);
}

/// @nodoc
mixin _$BrandingConfig {
  @JsonKey(name: 'app_logo_url')
  String get appLogoUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'cinemax_logo')
  String get cinemaxLogo => throw _privateConstructorUsedError;

  /// Serializes this BrandingConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BrandingConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BrandingConfigCopyWith<BrandingConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BrandingConfigCopyWith<$Res> {
  factory $BrandingConfigCopyWith(
          BrandingConfig value, $Res Function(BrandingConfig) then) =
      _$BrandingConfigCopyWithImpl<$Res, BrandingConfig>;
  @useResult
  $Res call(
      {@JsonKey(name: 'app_logo_url') String appLogoUrl,
      @JsonKey(name: 'cinemax_logo') String cinemaxLogo});
}

/// @nodoc
class _$BrandingConfigCopyWithImpl<$Res, $Val extends BrandingConfig>
    implements $BrandingConfigCopyWith<$Res> {
  _$BrandingConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BrandingConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? appLogoUrl = null,
    Object? cinemaxLogo = null,
  }) {
    return _then(_value.copyWith(
      appLogoUrl: null == appLogoUrl
          ? _value.appLogoUrl
          : appLogoUrl // ignore: cast_nullable_to_non_nullable
              as String,
      cinemaxLogo: null == cinemaxLogo
          ? _value.cinemaxLogo
          : cinemaxLogo // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BrandingConfigImplCopyWith<$Res>
    implements $BrandingConfigCopyWith<$Res> {
  factory _$$BrandingConfigImplCopyWith(_$BrandingConfigImpl value,
          $Res Function(_$BrandingConfigImpl) then) =
      __$$BrandingConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'app_logo_url') String appLogoUrl,
      @JsonKey(name: 'cinemax_logo') String cinemaxLogo});
}

/// @nodoc
class __$$BrandingConfigImplCopyWithImpl<$Res>
    extends _$BrandingConfigCopyWithImpl<$Res, _$BrandingConfigImpl>
    implements _$$BrandingConfigImplCopyWith<$Res> {
  __$$BrandingConfigImplCopyWithImpl(
      _$BrandingConfigImpl _value, $Res Function(_$BrandingConfigImpl) _then)
      : super(_value, _then);

  /// Create a copy of BrandingConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? appLogoUrl = null,
    Object? cinemaxLogo = null,
  }) {
    return _then(_$BrandingConfigImpl(
      appLogoUrl: null == appLogoUrl
          ? _value.appLogoUrl
          : appLogoUrl // ignore: cast_nullable_to_non_nullable
              as String,
      cinemaxLogo: null == cinemaxLogo
          ? _value.cinemaxLogo
          : cinemaxLogo // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BrandingConfigImpl implements _BrandingConfig {
  const _$BrandingConfigImpl(
      {@JsonKey(name: 'app_logo_url') this.appLogoUrl = '',
      @JsonKey(name: 'cinemax_logo') this.cinemaxLogo = 'default'});

  factory _$BrandingConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$BrandingConfigImplFromJson(json);

  @override
  @JsonKey(name: 'app_logo_url')
  final String appLogoUrl;
  @override
  @JsonKey(name: 'cinemax_logo')
  final String cinemaxLogo;

  @override
  String toString() {
    return 'BrandingConfig(appLogoUrl: $appLogoUrl, cinemaxLogo: $cinemaxLogo)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BrandingConfigImpl &&
            (identical(other.appLogoUrl, appLogoUrl) ||
                other.appLogoUrl == appLogoUrl) &&
            (identical(other.cinemaxLogo, cinemaxLogo) ||
                other.cinemaxLogo == cinemaxLogo));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, appLogoUrl, cinemaxLogo);

  /// Create a copy of BrandingConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BrandingConfigImplCopyWith<_$BrandingConfigImpl> get copyWith =>
      __$$BrandingConfigImplCopyWithImpl<_$BrandingConfigImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BrandingConfigImplToJson(
      this,
    );
  }
}

abstract class _BrandingConfig implements BrandingConfig {
  const factory _BrandingConfig(
          {@JsonKey(name: 'app_logo_url') final String appLogoUrl,
          @JsonKey(name: 'cinemax_logo') final String cinemaxLogo}) =
      _$BrandingConfigImpl;

  factory _BrandingConfig.fromJson(Map<String, dynamic> json) =
      _$BrandingConfigImpl.fromJson;

  @override
  @JsonKey(name: 'app_logo_url')
  String get appLogoUrl;
  @override
  @JsonKey(name: 'cinemax_logo')
  String get cinemaxLogo;

  /// Create a copy of BrandingConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BrandingConfigImplCopyWith<_$BrandingConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

UpdateConfig _$UpdateConfigFromJson(Map<String, dynamic> json) {
  return _UpdateConfig.fromJson(json);
}

/// @nodoc
mixin _$UpdateConfig {
  @JsonKey(name: 'forced_update')
  bool get forcedUpdate => throw _privateConstructorUsedError;
  @JsonKey(name: 'latest_version')
  String get latestVersion => throw _privateConstructorUsedError;
  @JsonKey(name: 'latest_build_number')
  int get latestBuildNumber => throw _privateConstructorUsedError;
  @JsonKey(name: 'min_build_number')
  int get minBuildNumber => throw _privateConstructorUsedError;
  @JsonKey(name: 'app_download_url')
  String get appDownloadUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'change_log')
  String get changeLog => throw _privateConstructorUsedError;

  /// Serializes this UpdateConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of UpdateConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UpdateConfigCopyWith<UpdateConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UpdateConfigCopyWith<$Res> {
  factory $UpdateConfigCopyWith(
          UpdateConfig value, $Res Function(UpdateConfig) then) =
      _$UpdateConfigCopyWithImpl<$Res, UpdateConfig>;
  @useResult
  $Res call(
      {@JsonKey(name: 'forced_update') bool forcedUpdate,
      @JsonKey(name: 'latest_version') String latestVersion,
      @JsonKey(name: 'latest_build_number') int latestBuildNumber,
      @JsonKey(name: 'min_build_number') int minBuildNumber,
      @JsonKey(name: 'app_download_url') String appDownloadUrl,
      @JsonKey(name: 'change_log') String changeLog});
}

/// @nodoc
class _$UpdateConfigCopyWithImpl<$Res, $Val extends UpdateConfig>
    implements $UpdateConfigCopyWith<$Res> {
  _$UpdateConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UpdateConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? forcedUpdate = null,
    Object? latestVersion = null,
    Object? latestBuildNumber = null,
    Object? minBuildNumber = null,
    Object? appDownloadUrl = null,
    Object? changeLog = null,
  }) {
    return _then(_value.copyWith(
      forcedUpdate: null == forcedUpdate
          ? _value.forcedUpdate
          : forcedUpdate // ignore: cast_nullable_to_non_nullable
              as bool,
      latestVersion: null == latestVersion
          ? _value.latestVersion
          : latestVersion // ignore: cast_nullable_to_non_nullable
              as String,
      latestBuildNumber: null == latestBuildNumber
          ? _value.latestBuildNumber
          : latestBuildNumber // ignore: cast_nullable_to_non_nullable
              as int,
      minBuildNumber: null == minBuildNumber
          ? _value.minBuildNumber
          : minBuildNumber // ignore: cast_nullable_to_non_nullable
              as int,
      appDownloadUrl: null == appDownloadUrl
          ? _value.appDownloadUrl
          : appDownloadUrl // ignore: cast_nullable_to_non_nullable
              as String,
      changeLog: null == changeLog
          ? _value.changeLog
          : changeLog // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UpdateConfigImplCopyWith<$Res>
    implements $UpdateConfigCopyWith<$Res> {
  factory _$$UpdateConfigImplCopyWith(
          _$UpdateConfigImpl value, $Res Function(_$UpdateConfigImpl) then) =
      __$$UpdateConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'forced_update') bool forcedUpdate,
      @JsonKey(name: 'latest_version') String latestVersion,
      @JsonKey(name: 'latest_build_number') int latestBuildNumber,
      @JsonKey(name: 'min_build_number') int minBuildNumber,
      @JsonKey(name: 'app_download_url') String appDownloadUrl,
      @JsonKey(name: 'change_log') String changeLog});
}

/// @nodoc
class __$$UpdateConfigImplCopyWithImpl<$Res>
    extends _$UpdateConfigCopyWithImpl<$Res, _$UpdateConfigImpl>
    implements _$$UpdateConfigImplCopyWith<$Res> {
  __$$UpdateConfigImplCopyWithImpl(
      _$UpdateConfigImpl _value, $Res Function(_$UpdateConfigImpl) _then)
      : super(_value, _then);

  /// Create a copy of UpdateConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? forcedUpdate = null,
    Object? latestVersion = null,
    Object? latestBuildNumber = null,
    Object? minBuildNumber = null,
    Object? appDownloadUrl = null,
    Object? changeLog = null,
  }) {
    return _then(_$UpdateConfigImpl(
      forcedUpdate: null == forcedUpdate
          ? _value.forcedUpdate
          : forcedUpdate // ignore: cast_nullable_to_non_nullable
              as bool,
      latestVersion: null == latestVersion
          ? _value.latestVersion
          : latestVersion // ignore: cast_nullable_to_non_nullable
              as String,
      latestBuildNumber: null == latestBuildNumber
          ? _value.latestBuildNumber
          : latestBuildNumber // ignore: cast_nullable_to_non_nullable
              as int,
      minBuildNumber: null == minBuildNumber
          ? _value.minBuildNumber
          : minBuildNumber // ignore: cast_nullable_to_non_nullable
              as int,
      appDownloadUrl: null == appDownloadUrl
          ? _value.appDownloadUrl
          : appDownloadUrl // ignore: cast_nullable_to_non_nullable
              as String,
      changeLog: null == changeLog
          ? _value.changeLog
          : changeLog // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UpdateConfigImpl implements _UpdateConfig {
  const _$UpdateConfigImpl(
      {@JsonKey(name: 'forced_update') this.forcedUpdate = false,
      @JsonKey(name: 'latest_version') this.latestVersion = '',
      @JsonKey(name: 'latest_build_number') this.latestBuildNumber = 0,
      @JsonKey(name: 'min_build_number') this.minBuildNumber = 0,
      @JsonKey(name: 'app_download_url') this.appDownloadUrl = '',
      @JsonKey(name: 'change_log') this.changeLog = ''});

  factory _$UpdateConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$UpdateConfigImplFromJson(json);

  @override
  @JsonKey(name: 'forced_update')
  final bool forcedUpdate;
  @override
  @JsonKey(name: 'latest_version')
  final String latestVersion;
  @override
  @JsonKey(name: 'latest_build_number')
  final int latestBuildNumber;
  @override
  @JsonKey(name: 'min_build_number')
  final int minBuildNumber;
  @override
  @JsonKey(name: 'app_download_url')
  final String appDownloadUrl;
  @override
  @JsonKey(name: 'change_log')
  final String changeLog;

  @override
  String toString() {
    return 'UpdateConfig(forcedUpdate: $forcedUpdate, latestVersion: $latestVersion, latestBuildNumber: $latestBuildNumber, minBuildNumber: $minBuildNumber, appDownloadUrl: $appDownloadUrl, changeLog: $changeLog)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UpdateConfigImpl &&
            (identical(other.forcedUpdate, forcedUpdate) ||
                other.forcedUpdate == forcedUpdate) &&
            (identical(other.latestVersion, latestVersion) ||
                other.latestVersion == latestVersion) &&
            (identical(other.latestBuildNumber, latestBuildNumber) ||
                other.latestBuildNumber == latestBuildNumber) &&
            (identical(other.minBuildNumber, minBuildNumber) ||
                other.minBuildNumber == minBuildNumber) &&
            (identical(other.appDownloadUrl, appDownloadUrl) ||
                other.appDownloadUrl == appDownloadUrl) &&
            (identical(other.changeLog, changeLog) ||
                other.changeLog == changeLog));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, forcedUpdate, latestVersion,
      latestBuildNumber, minBuildNumber, appDownloadUrl, changeLog);

  /// Create a copy of UpdateConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UpdateConfigImplCopyWith<_$UpdateConfigImpl> get copyWith =>
      __$$UpdateConfigImplCopyWithImpl<_$UpdateConfigImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UpdateConfigImplToJson(
      this,
    );
  }
}

abstract class _UpdateConfig implements UpdateConfig {
  const factory _UpdateConfig(
          {@JsonKey(name: 'forced_update') final bool forcedUpdate,
          @JsonKey(name: 'latest_version') final String latestVersion,
          @JsonKey(name: 'latest_build_number') final int latestBuildNumber,
          @JsonKey(name: 'min_build_number') final int minBuildNumber,
          @JsonKey(name: 'app_download_url') final String appDownloadUrl,
          @JsonKey(name: 'change_log') final String changeLog}) =
      _$UpdateConfigImpl;

  factory _UpdateConfig.fromJson(Map<String, dynamic> json) =
      _$UpdateConfigImpl.fromJson;

  @override
  @JsonKey(name: 'forced_update')
  bool get forcedUpdate;
  @override
  @JsonKey(name: 'latest_version')
  String get latestVersion;
  @override
  @JsonKey(name: 'latest_build_number')
  int get latestBuildNumber;
  @override
  @JsonKey(name: 'min_build_number')
  int get minBuildNumber;
  @override
  @JsonKey(name: 'app_download_url')
  String get appDownloadUrl;
  @override
  @JsonKey(name: 'change_log')
  String get changeLog;

  /// Create a copy of UpdateConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UpdateConfigImplCopyWith<_$UpdateConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

NetworkConfig _$NetworkConfigFromJson(Map<String, dynamic> json) {
  return _NetworkConfig.fromJson(json);
}

/// @nodoc
mixin _$NetworkConfig {
  @JsonKey(name: 'flixquest_api_instances')
  List<String> get flixquestApiInstances => throw _privateConstructorUsedError;
  @JsonKey(name: 'flixquest_api_url_v2')
  String get flixquestApiUrlV2 => throw _privateConstructorUsedError;
  @JsonKey(name: 'tmdb_api_key')
  String get tmdbApiKey => throw _privateConstructorUsedError;
  @JsonKey(name: 'tmdb_proxy')
  String get tmdbProxy => throw _privateConstructorUsedError;

  /// Serializes this NetworkConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NetworkConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NetworkConfigCopyWith<NetworkConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NetworkConfigCopyWith<$Res> {
  factory $NetworkConfigCopyWith(
          NetworkConfig value, $Res Function(NetworkConfig) then) =
      _$NetworkConfigCopyWithImpl<$Res, NetworkConfig>;
  @useResult
  $Res call(
      {@JsonKey(name: 'flixquest_api_instances')
      List<String> flixquestApiInstances,
      @JsonKey(name: 'flixquest_api_url_v2') String flixquestApiUrlV2,
      @JsonKey(name: 'tmdb_api_key') String tmdbApiKey,
      @JsonKey(name: 'tmdb_proxy') String tmdbProxy});
}

/// @nodoc
class _$NetworkConfigCopyWithImpl<$Res, $Val extends NetworkConfig>
    implements $NetworkConfigCopyWith<$Res> {
  _$NetworkConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NetworkConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? flixquestApiInstances = null,
    Object? flixquestApiUrlV2 = null,
    Object? tmdbApiKey = null,
    Object? tmdbProxy = null,
  }) {
    return _then(_value.copyWith(
      flixquestApiInstances: null == flixquestApiInstances
          ? _value.flixquestApiInstances
          : flixquestApiInstances // ignore: cast_nullable_to_non_nullable
              as List<String>,
      flixquestApiUrlV2: null == flixquestApiUrlV2
          ? _value.flixquestApiUrlV2
          : flixquestApiUrlV2 // ignore: cast_nullable_to_non_nullable
              as String,
      tmdbApiKey: null == tmdbApiKey
          ? _value.tmdbApiKey
          : tmdbApiKey // ignore: cast_nullable_to_non_nullable
              as String,
      tmdbProxy: null == tmdbProxy
          ? _value.tmdbProxy
          : tmdbProxy // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$NetworkConfigImplCopyWith<$Res>
    implements $NetworkConfigCopyWith<$Res> {
  factory _$$NetworkConfigImplCopyWith(
          _$NetworkConfigImpl value, $Res Function(_$NetworkConfigImpl) then) =
      __$$NetworkConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'flixquest_api_instances')
      List<String> flixquestApiInstances,
      @JsonKey(name: 'flixquest_api_url_v2') String flixquestApiUrlV2,
      @JsonKey(name: 'tmdb_api_key') String tmdbApiKey,
      @JsonKey(name: 'tmdb_proxy') String tmdbProxy});
}

/// @nodoc
class __$$NetworkConfigImplCopyWithImpl<$Res>
    extends _$NetworkConfigCopyWithImpl<$Res, _$NetworkConfigImpl>
    implements _$$NetworkConfigImplCopyWith<$Res> {
  __$$NetworkConfigImplCopyWithImpl(
      _$NetworkConfigImpl _value, $Res Function(_$NetworkConfigImpl) _then)
      : super(_value, _then);

  /// Create a copy of NetworkConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? flixquestApiInstances = null,
    Object? flixquestApiUrlV2 = null,
    Object? tmdbApiKey = null,
    Object? tmdbProxy = null,
  }) {
    return _then(_$NetworkConfigImpl(
      flixquestApiInstances: null == flixquestApiInstances
          ? _value._flixquestApiInstances
          : flixquestApiInstances // ignore: cast_nullable_to_non_nullable
              as List<String>,
      flixquestApiUrlV2: null == flixquestApiUrlV2
          ? _value.flixquestApiUrlV2
          : flixquestApiUrlV2 // ignore: cast_nullable_to_non_nullable
              as String,
      tmdbApiKey: null == tmdbApiKey
          ? _value.tmdbApiKey
          : tmdbApiKey // ignore: cast_nullable_to_non_nullable
              as String,
      tmdbProxy: null == tmdbProxy
          ? _value.tmdbProxy
          : tmdbProxy // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$NetworkConfigImpl implements _NetworkConfig {
  const _$NetworkConfigImpl(
      {@JsonKey(name: 'flixquest_api_instances')
      final List<String> flixquestApiInstances = const [],
      @JsonKey(name: 'flixquest_api_url_v2') this.flixquestApiUrlV2 = '',
      @JsonKey(name: 'tmdb_api_key') this.tmdbApiKey = '',
      @JsonKey(name: 'tmdb_proxy') this.tmdbProxy = ''})
      : _flixquestApiInstances = flixquestApiInstances;

  factory _$NetworkConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$NetworkConfigImplFromJson(json);

  final List<String> _flixquestApiInstances;
  @override
  @JsonKey(name: 'flixquest_api_instances')
  List<String> get flixquestApiInstances {
    if (_flixquestApiInstances is EqualUnmodifiableListView)
      return _flixquestApiInstances;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_flixquestApiInstances);
  }

  @override
  @JsonKey(name: 'flixquest_api_url_v2')
  final String flixquestApiUrlV2;
  @override
  @JsonKey(name: 'tmdb_api_key')
  final String tmdbApiKey;
  @override
  @JsonKey(name: 'tmdb_proxy')
  final String tmdbProxy;

  @override
  String toString() {
    return 'NetworkConfig(flixquestApiInstances: $flixquestApiInstances, flixquestApiUrlV2: $flixquestApiUrlV2, tmdbApiKey: $tmdbApiKey, tmdbProxy: $tmdbProxy)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NetworkConfigImpl &&
            const DeepCollectionEquality()
                .equals(other._flixquestApiInstances, _flixquestApiInstances) &&
            (identical(other.flixquestApiUrlV2, flixquestApiUrlV2) ||
                other.flixquestApiUrlV2 == flixquestApiUrlV2) &&
            (identical(other.tmdbApiKey, tmdbApiKey) ||
                other.tmdbApiKey == tmdbApiKey) &&
            (identical(other.tmdbProxy, tmdbProxy) ||
                other.tmdbProxy == tmdbProxy));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_flixquestApiInstances),
      flixquestApiUrlV2,
      tmdbApiKey,
      tmdbProxy);

  /// Create a copy of NetworkConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NetworkConfigImplCopyWith<_$NetworkConfigImpl> get copyWith =>
      __$$NetworkConfigImplCopyWithImpl<_$NetworkConfigImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NetworkConfigImplToJson(
      this,
    );
  }
}

abstract class _NetworkConfig implements NetworkConfig {
  const factory _NetworkConfig(
          {@JsonKey(name: 'flixquest_api_instances')
          final List<String> flixquestApiInstances,
          @JsonKey(name: 'flixquest_api_url_v2') final String flixquestApiUrlV2,
          @JsonKey(name: 'tmdb_api_key') final String tmdbApiKey,
          @JsonKey(name: 'tmdb_proxy') final String tmdbProxy}) =
      _$NetworkConfigImpl;

  factory _NetworkConfig.fromJson(Map<String, dynamic> json) =
      _$NetworkConfigImpl.fromJson;

  @override
  @JsonKey(name: 'flixquest_api_instances')
  List<String> get flixquestApiInstances;
  @override
  @JsonKey(name: 'flixquest_api_url_v2')
  String get flixquestApiUrlV2;
  @override
  @JsonKey(name: 'tmdb_api_key')
  String get tmdbApiKey;
  @override
  @JsonKey(name: 'tmdb_proxy')
  String get tmdbProxy;

  /// Create a copy of NetworkConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NetworkConfigImplCopyWith<_$NetworkConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AdsConfig _$AdsConfigFromJson(Map<String, dynamic> json) {
  return _AdsConfig.fromJson(json);
}

/// @nodoc
mixin _$AdsConfig {
  @JsonKey(name: 'banner_ad_network')
  String get bannerAdNetwork => throw _privateConstructorUsedError;
  @JsonKey(name: 'hosted_banner_mode')
  String get hostedBannerMode => throw _privateConstructorUsedError;
  @JsonKey(name: 'unity_game_id_android')
  String get unityGameIdAndroid => throw _privateConstructorUsedError;
  @JsonKey(name: 'unity_banner_placement_id')
  String get unityBannerPlacementId => throw _privateConstructorUsedError;
  @JsonKey(name: 'unity_test_mode')
  bool get unityTestMode => throw _privateConstructorUsedError;
  @JsonKey(name: 'startio_banner_enabled')
  bool get startioBannerEnabled => throw _privateConstructorUsedError;
  @JsonKey(name: 'startio_interstitial_enabled')
  bool get startioInterstitialEnabled => throw _privateConstructorUsedError;
  @JsonKey(name: 'startio_interstitial_interval_seconds')
  int get startioInterstitialIntervalSeconds =>
      throw _privateConstructorUsedError;
  @JsonKey(name: 'startio_tv_interstitial_mode')
  String get startioTvInterstitialMode => throw _privateConstructorUsedError;

  /// Serializes this AdsConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AdsConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AdsConfigCopyWith<AdsConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AdsConfigCopyWith<$Res> {
  factory $AdsConfigCopyWith(AdsConfig value, $Res Function(AdsConfig) then) =
      _$AdsConfigCopyWithImpl<$Res, AdsConfig>;
  @useResult
  $Res call(
      {@JsonKey(name: 'banner_ad_network') String bannerAdNetwork,
      @JsonKey(name: 'hosted_banner_mode') String hostedBannerMode,
      @JsonKey(name: 'unity_game_id_android') String unityGameIdAndroid,
      @JsonKey(name: 'unity_banner_placement_id') String unityBannerPlacementId,
      @JsonKey(name: 'unity_test_mode') bool unityTestMode,
      @JsonKey(name: 'startio_banner_enabled') bool startioBannerEnabled,
      @JsonKey(name: 'startio_interstitial_enabled')
      bool startioInterstitialEnabled,
      @JsonKey(name: 'startio_interstitial_interval_seconds')
      int startioInterstitialIntervalSeconds,
      @JsonKey(name: 'startio_tv_interstitial_mode')
      String startioTvInterstitialMode});
}

/// @nodoc
class _$AdsConfigCopyWithImpl<$Res, $Val extends AdsConfig>
    implements $AdsConfigCopyWith<$Res> {
  _$AdsConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AdsConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bannerAdNetwork = null,
    Object? hostedBannerMode = null,
    Object? unityGameIdAndroid = null,
    Object? unityBannerPlacementId = null,
    Object? unityTestMode = null,
    Object? startioBannerEnabled = null,
    Object? startioInterstitialEnabled = null,
    Object? startioInterstitialIntervalSeconds = null,
    Object? startioTvInterstitialMode = null,
  }) {
    return _then(_value.copyWith(
      bannerAdNetwork: null == bannerAdNetwork
          ? _value.bannerAdNetwork
          : bannerAdNetwork // ignore: cast_nullable_to_non_nullable
              as String,
      hostedBannerMode: null == hostedBannerMode
          ? _value.hostedBannerMode
          : hostedBannerMode // ignore: cast_nullable_to_non_nullable
              as String,
      unityGameIdAndroid: null == unityGameIdAndroid
          ? _value.unityGameIdAndroid
          : unityGameIdAndroid // ignore: cast_nullable_to_non_nullable
              as String,
      unityBannerPlacementId: null == unityBannerPlacementId
          ? _value.unityBannerPlacementId
          : unityBannerPlacementId // ignore: cast_nullable_to_non_nullable
              as String,
      unityTestMode: null == unityTestMode
          ? _value.unityTestMode
          : unityTestMode // ignore: cast_nullable_to_non_nullable
              as bool,
      startioBannerEnabled: null == startioBannerEnabled
          ? _value.startioBannerEnabled
          : startioBannerEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      startioInterstitialEnabled: null == startioInterstitialEnabled
          ? _value.startioInterstitialEnabled
          : startioInterstitialEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      startioInterstitialIntervalSeconds: null ==
              startioInterstitialIntervalSeconds
          ? _value.startioInterstitialIntervalSeconds
          : startioInterstitialIntervalSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      startioTvInterstitialMode: null == startioTvInterstitialMode
          ? _value.startioTvInterstitialMode
          : startioTvInterstitialMode // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AdsConfigImplCopyWith<$Res>
    implements $AdsConfigCopyWith<$Res> {
  factory _$$AdsConfigImplCopyWith(
          _$AdsConfigImpl value, $Res Function(_$AdsConfigImpl) then) =
      __$$AdsConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'banner_ad_network') String bannerAdNetwork,
      @JsonKey(name: 'hosted_banner_mode') String hostedBannerMode,
      @JsonKey(name: 'unity_game_id_android') String unityGameIdAndroid,
      @JsonKey(name: 'unity_banner_placement_id') String unityBannerPlacementId,
      @JsonKey(name: 'unity_test_mode') bool unityTestMode,
      @JsonKey(name: 'startio_banner_enabled') bool startioBannerEnabled,
      @JsonKey(name: 'startio_interstitial_enabled')
      bool startioInterstitialEnabled,
      @JsonKey(name: 'startio_interstitial_interval_seconds')
      int startioInterstitialIntervalSeconds,
      @JsonKey(name: 'startio_tv_interstitial_mode')
      String startioTvInterstitialMode});
}

/// @nodoc
class __$$AdsConfigImplCopyWithImpl<$Res>
    extends _$AdsConfigCopyWithImpl<$Res, _$AdsConfigImpl>
    implements _$$AdsConfigImplCopyWith<$Res> {
  __$$AdsConfigImplCopyWithImpl(
      _$AdsConfigImpl _value, $Res Function(_$AdsConfigImpl) _then)
      : super(_value, _then);

  /// Create a copy of AdsConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bannerAdNetwork = null,
    Object? hostedBannerMode = null,
    Object? unityGameIdAndroid = null,
    Object? unityBannerPlacementId = null,
    Object? unityTestMode = null,
    Object? startioBannerEnabled = null,
    Object? startioInterstitialEnabled = null,
    Object? startioInterstitialIntervalSeconds = null,
    Object? startioTvInterstitialMode = null,
  }) {
    return _then(_$AdsConfigImpl(
      bannerAdNetwork: null == bannerAdNetwork
          ? _value.bannerAdNetwork
          : bannerAdNetwork // ignore: cast_nullable_to_non_nullable
              as String,
      hostedBannerMode: null == hostedBannerMode
          ? _value.hostedBannerMode
          : hostedBannerMode // ignore: cast_nullable_to_non_nullable
              as String,
      unityGameIdAndroid: null == unityGameIdAndroid
          ? _value.unityGameIdAndroid
          : unityGameIdAndroid // ignore: cast_nullable_to_non_nullable
              as String,
      unityBannerPlacementId: null == unityBannerPlacementId
          ? _value.unityBannerPlacementId
          : unityBannerPlacementId // ignore: cast_nullable_to_non_nullable
              as String,
      unityTestMode: null == unityTestMode
          ? _value.unityTestMode
          : unityTestMode // ignore: cast_nullable_to_non_nullable
              as bool,
      startioBannerEnabled: null == startioBannerEnabled
          ? _value.startioBannerEnabled
          : startioBannerEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      startioInterstitialEnabled: null == startioInterstitialEnabled
          ? _value.startioInterstitialEnabled
          : startioInterstitialEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      startioInterstitialIntervalSeconds: null ==
              startioInterstitialIntervalSeconds
          ? _value.startioInterstitialIntervalSeconds
          : startioInterstitialIntervalSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      startioTvInterstitialMode: null == startioTvInterstitialMode
          ? _value.startioTvInterstitialMode
          : startioTvInterstitialMode // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AdsConfigImpl implements _AdsConfig {
  const _$AdsConfigImpl(
      {@JsonKey(name: 'banner_ad_network') this.bannerAdNetwork = 'native',
      @JsonKey(name: 'hosted_banner_mode') this.hostedBannerMode = 'stack',
      @JsonKey(name: 'unity_game_id_android')
      this.unityGameIdAndroid = '5445375',
      @JsonKey(name: 'unity_banner_placement_id')
      this.unityBannerPlacementId = 'Banner_Android',
      @JsonKey(name: 'unity_test_mode') this.unityTestMode = false,
      @JsonKey(name: 'startio_banner_enabled')
      this.startioBannerEnabled = false,
      @JsonKey(name: 'startio_interstitial_enabled')
      this.startioInterstitialEnabled = false,
      @JsonKey(name: 'startio_interstitial_interval_seconds')
      this.startioInterstitialIntervalSeconds = 600,
      @JsonKey(name: 'startio_tv_interstitial_mode')
      this.startioTvInterstitialMode = 'video'});

  factory _$AdsConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$AdsConfigImplFromJson(json);

  @override
  @JsonKey(name: 'banner_ad_network')
  final String bannerAdNetwork;
  @override
  @JsonKey(name: 'hosted_banner_mode')
  final String hostedBannerMode;
  @override
  @JsonKey(name: 'unity_game_id_android')
  final String unityGameIdAndroid;
  @override
  @JsonKey(name: 'unity_banner_placement_id')
  final String unityBannerPlacementId;
  @override
  @JsonKey(name: 'unity_test_mode')
  final bool unityTestMode;
  @override
  @JsonKey(name: 'startio_banner_enabled')
  final bool startioBannerEnabled;
  @override
  @JsonKey(name: 'startio_interstitial_enabled')
  final bool startioInterstitialEnabled;
  @override
  @JsonKey(name: 'startio_interstitial_interval_seconds')
  final int startioInterstitialIntervalSeconds;
  @override
  @JsonKey(name: 'startio_tv_interstitial_mode')
  final String startioTvInterstitialMode;

  @override
  String toString() {
    return 'AdsConfig(bannerAdNetwork: $bannerAdNetwork, hostedBannerMode: $hostedBannerMode, unityGameIdAndroid: $unityGameIdAndroid, unityBannerPlacementId: $unityBannerPlacementId, unityTestMode: $unityTestMode, startioBannerEnabled: $startioBannerEnabled, startioInterstitialEnabled: $startioInterstitialEnabled, startioInterstitialIntervalSeconds: $startioInterstitialIntervalSeconds, startioTvInterstitialMode: $startioTvInterstitialMode)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AdsConfigImpl &&
            (identical(other.bannerAdNetwork, bannerAdNetwork) ||
                other.bannerAdNetwork == bannerAdNetwork) &&
            (identical(other.hostedBannerMode, hostedBannerMode) ||
                other.hostedBannerMode == hostedBannerMode) &&
            (identical(other.unityGameIdAndroid, unityGameIdAndroid) ||
                other.unityGameIdAndroid == unityGameIdAndroid) &&
            (identical(other.unityBannerPlacementId, unityBannerPlacementId) ||
                other.unityBannerPlacementId == unityBannerPlacementId) &&
            (identical(other.unityTestMode, unityTestMode) ||
                other.unityTestMode == unityTestMode) &&
            (identical(other.startioBannerEnabled, startioBannerEnabled) ||
                other.startioBannerEnabled == startioBannerEnabled) &&
            (identical(other.startioInterstitialEnabled,
                    startioInterstitialEnabled) ||
                other.startioInterstitialEnabled ==
                    startioInterstitialEnabled) &&
            (identical(other.startioInterstitialIntervalSeconds,
                    startioInterstitialIntervalSeconds) ||
                other.startioInterstitialIntervalSeconds ==
                    startioInterstitialIntervalSeconds) &&
            (identical(other.startioTvInterstitialMode,
                    startioTvInterstitialMode) ||
                other.startioTvInterstitialMode == startioTvInterstitialMode));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      bannerAdNetwork,
      hostedBannerMode,
      unityGameIdAndroid,
      unityBannerPlacementId,
      unityTestMode,
      startioBannerEnabled,
      startioInterstitialEnabled,
      startioInterstitialIntervalSeconds,
      startioTvInterstitialMode);

  /// Create a copy of AdsConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AdsConfigImplCopyWith<_$AdsConfigImpl> get copyWith =>
      __$$AdsConfigImplCopyWithImpl<_$AdsConfigImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AdsConfigImplToJson(
      this,
    );
  }
}

abstract class _AdsConfig implements AdsConfig {
  const factory _AdsConfig(
      {@JsonKey(name: 'banner_ad_network') final String bannerAdNetwork,
      @JsonKey(name: 'hosted_banner_mode') final String hostedBannerMode,
      @JsonKey(name: 'unity_game_id_android') final String unityGameIdAndroid,
      @JsonKey(name: 'unity_banner_placement_id')
      final String unityBannerPlacementId,
      @JsonKey(name: 'unity_test_mode') final bool unityTestMode,
      @JsonKey(name: 'startio_banner_enabled') final bool startioBannerEnabled,
      @JsonKey(name: 'startio_interstitial_enabled')
      final bool startioInterstitialEnabled,
      @JsonKey(name: 'startio_interstitial_interval_seconds')
      final int startioInterstitialIntervalSeconds,
      @JsonKey(name: 'startio_tv_interstitial_mode')
      final String startioTvInterstitialMode}) = _$AdsConfigImpl;

  factory _AdsConfig.fromJson(Map<String, dynamic> json) =
      _$AdsConfigImpl.fromJson;

  @override
  @JsonKey(name: 'banner_ad_network')
  String get bannerAdNetwork;
  @override
  @JsonKey(name: 'hosted_banner_mode')
  String get hostedBannerMode;
  @override
  @JsonKey(name: 'unity_game_id_android')
  String get unityGameIdAndroid;
  @override
  @JsonKey(name: 'unity_banner_placement_id')
  String get unityBannerPlacementId;
  @override
  @JsonKey(name: 'unity_test_mode')
  bool get unityTestMode;
  @override
  @JsonKey(name: 'startio_banner_enabled')
  bool get startioBannerEnabled;
  @override
  @JsonKey(name: 'startio_interstitial_enabled')
  bool get startioInterstitialEnabled;
  @override
  @JsonKey(name: 'startio_interstitial_interval_seconds')
  int get startioInterstitialIntervalSeconds;
  @override
  @JsonKey(name: 'startio_tv_interstitial_mode')
  String get startioTvInterstitialMode;

  /// Create a copy of AdsConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AdsConfigImplCopyWith<_$AdsConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ThemeEffect _$ThemeEffectFromJson(Map<String, dynamic> json) {
  return _ThemeEffect.fromJson(json);
}

/// @nodoc
mixin _$ThemeEffect {
  bool get enabled => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  int get density => throw _privateConstructorUsedError;
  double get speed => throw _privateConstructorUsedError;
  double get opacity => throw _privateConstructorUsedError;
  List<String> get colors => throw _privateConstructorUsedError;

  /// Serializes this ThemeEffect to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ThemeEffect
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ThemeEffectCopyWith<ThemeEffect> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ThemeEffectCopyWith<$Res> {
  factory $ThemeEffectCopyWith(
          ThemeEffect value, $Res Function(ThemeEffect) then) =
      _$ThemeEffectCopyWithImpl<$Res, ThemeEffect>;
  @useResult
  $Res call(
      {bool enabled,
      String type,
      int density,
      double speed,
      double opacity,
      List<String> colors});
}

/// @nodoc
class _$ThemeEffectCopyWithImpl<$Res, $Val extends ThemeEffect>
    implements $ThemeEffectCopyWith<$Res> {
  _$ThemeEffectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ThemeEffect
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? enabled = null,
    Object? type = null,
    Object? density = null,
    Object? speed = null,
    Object? opacity = null,
    Object? colors = null,
  }) {
    return _then(_value.copyWith(
      enabled: null == enabled
          ? _value.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      density: null == density
          ? _value.density
          : density // ignore: cast_nullable_to_non_nullable
              as int,
      speed: null == speed
          ? _value.speed
          : speed // ignore: cast_nullable_to_non_nullable
              as double,
      opacity: null == opacity
          ? _value.opacity
          : opacity // ignore: cast_nullable_to_non_nullable
              as double,
      colors: null == colors
          ? _value.colors
          : colors // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ThemeEffectImplCopyWith<$Res>
    implements $ThemeEffectCopyWith<$Res> {
  factory _$$ThemeEffectImplCopyWith(
          _$ThemeEffectImpl value, $Res Function(_$ThemeEffectImpl) then) =
      __$$ThemeEffectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool enabled,
      String type,
      int density,
      double speed,
      double opacity,
      List<String> colors});
}

/// @nodoc
class __$$ThemeEffectImplCopyWithImpl<$Res>
    extends _$ThemeEffectCopyWithImpl<$Res, _$ThemeEffectImpl>
    implements _$$ThemeEffectImplCopyWith<$Res> {
  __$$ThemeEffectImplCopyWithImpl(
      _$ThemeEffectImpl _value, $Res Function(_$ThemeEffectImpl) _then)
      : super(_value, _then);

  /// Create a copy of ThemeEffect
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? enabled = null,
    Object? type = null,
    Object? density = null,
    Object? speed = null,
    Object? opacity = null,
    Object? colors = null,
  }) {
    return _then(_$ThemeEffectImpl(
      enabled: null == enabled
          ? _value.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      density: null == density
          ? _value.density
          : density // ignore: cast_nullable_to_non_nullable
              as int,
      speed: null == speed
          ? _value.speed
          : speed // ignore: cast_nullable_to_non_nullable
              as double,
      opacity: null == opacity
          ? _value.opacity
          : opacity // ignore: cast_nullable_to_non_nullable
              as double,
      colors: null == colors
          ? _value._colors
          : colors // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ThemeEffectImpl implements _ThemeEffect {
  const _$ThemeEffectImpl(
      {this.enabled = false,
      this.type = 'none',
      this.density = 28,
      this.speed = 1.0,
      this.opacity = .65,
      final List<String> colors = const []})
      : _colors = colors;

  factory _$ThemeEffectImpl.fromJson(Map<String, dynamic> json) =>
      _$$ThemeEffectImplFromJson(json);

  @override
  @JsonKey()
  final bool enabled;
  @override
  @JsonKey()
  final String type;
  @override
  @JsonKey()
  final int density;
  @override
  @JsonKey()
  final double speed;
  @override
  @JsonKey()
  final double opacity;
  final List<String> _colors;
  @override
  @JsonKey()
  List<String> get colors {
    if (_colors is EqualUnmodifiableListView) return _colors;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_colors);
  }

  @override
  String toString() {
    return 'ThemeEffect(enabled: $enabled, type: $type, density: $density, speed: $speed, opacity: $opacity, colors: $colors)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ThemeEffectImpl &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.density, density) || other.density == density) &&
            (identical(other.speed, speed) || other.speed == speed) &&
            (identical(other.opacity, opacity) || other.opacity == opacity) &&
            const DeepCollectionEquality().equals(other._colors, _colors));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, enabled, type, density, speed,
      opacity, const DeepCollectionEquality().hash(_colors));

  /// Create a copy of ThemeEffect
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ThemeEffectImplCopyWith<_$ThemeEffectImpl> get copyWith =>
      __$$ThemeEffectImplCopyWithImpl<_$ThemeEffectImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ThemeEffectImplToJson(
      this,
    );
  }
}

abstract class _ThemeEffect implements ThemeEffect {
  const factory _ThemeEffect(
      {final bool enabled,
      final String type,
      final int density,
      final double speed,
      final double opacity,
      final List<String> colors}) = _$ThemeEffectImpl;

  factory _ThemeEffect.fromJson(Map<String, dynamic> json) =
      _$ThemeEffectImpl.fromJson;

  @override
  bool get enabled;
  @override
  String get type;
  @override
  int get density;
  @override
  double get speed;
  @override
  double get opacity;
  @override
  List<String> get colors;

  /// Create a copy of ThemeEffect
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ThemeEffectImplCopyWith<_$ThemeEffectImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

OccasionalTheme _$OccasionalThemeFromJson(Map<String, dynamic> json) {
  return _OccasionalTheme.fromJson(json);
}

/// @nodoc
mixin _$OccasionalTheme {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'display_name')
  String get displayName => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  bool get enabled => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_selectable')
  bool get userSelectable => throw _privateConstructorUsedError;
  int get priority => throw _privateConstructorUsedError;
  @JsonKey(name: 'primary_color')
  String get primaryColor => throw _privateConstructorUsedError;
  @JsonKey(name: 'secondary_color')
  String get secondaryColor => throw _privateConstructorUsedError;
  @JsonKey(name: 'tertiary_color')
  String get tertiaryColor => throw _privateConstructorUsedError;
  @JsonKey(name: 'logo_url')
  String get logoUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'light_background_color')
  String? get lightBackgroundColor => throw _privateConstructorUsedError;
  @JsonKey(name: 'dark_background_color')
  String? get darkBackgroundColor => throw _privateConstructorUsedError;
  @JsonKey(name: 'starts_at')
  DateTime? get startsAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'ends_at')
  DateTime? get endsAt => throw _privateConstructorUsedError;
  ThemeEffect get effect => throw _privateConstructorUsedError;

  /// Serializes this OccasionalTheme to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OccasionalTheme
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OccasionalThemeCopyWith<OccasionalTheme> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OccasionalThemeCopyWith<$Res> {
  factory $OccasionalThemeCopyWith(
          OccasionalTheme value, $Res Function(OccasionalTheme) then) =
      _$OccasionalThemeCopyWithImpl<$Res, OccasionalTheme>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'display_name') String displayName,
      String description,
      bool enabled,
      @JsonKey(name: 'user_selectable') bool userSelectable,
      int priority,
      @JsonKey(name: 'primary_color') String primaryColor,
      @JsonKey(name: 'secondary_color') String secondaryColor,
      @JsonKey(name: 'tertiary_color') String tertiaryColor,
      @JsonKey(name: 'logo_url') String logoUrl,
      @JsonKey(name: 'light_background_color') String? lightBackgroundColor,
      @JsonKey(name: 'dark_background_color') String? darkBackgroundColor,
      @JsonKey(name: 'starts_at') DateTime? startsAt,
      @JsonKey(name: 'ends_at') DateTime? endsAt,
      ThemeEffect effect});

  $ThemeEffectCopyWith<$Res> get effect;
}

/// @nodoc
class _$OccasionalThemeCopyWithImpl<$Res, $Val extends OccasionalTheme>
    implements $OccasionalThemeCopyWith<$Res> {
  _$OccasionalThemeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OccasionalTheme
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? displayName = null,
    Object? description = null,
    Object? enabled = null,
    Object? userSelectable = null,
    Object? priority = null,
    Object? primaryColor = null,
    Object? secondaryColor = null,
    Object? tertiaryColor = null,
    Object? logoUrl = null,
    Object? lightBackgroundColor = freezed,
    Object? darkBackgroundColor = freezed,
    Object? startsAt = freezed,
    Object? endsAt = freezed,
    Object? effect = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      enabled: null == enabled
          ? _value.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      userSelectable: null == userSelectable
          ? _value.userSelectable
          : userSelectable // ignore: cast_nullable_to_non_nullable
              as bool,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as int,
      primaryColor: null == primaryColor
          ? _value.primaryColor
          : primaryColor // ignore: cast_nullable_to_non_nullable
              as String,
      secondaryColor: null == secondaryColor
          ? _value.secondaryColor
          : secondaryColor // ignore: cast_nullable_to_non_nullable
              as String,
      tertiaryColor: null == tertiaryColor
          ? _value.tertiaryColor
          : tertiaryColor // ignore: cast_nullable_to_non_nullable
              as String,
      logoUrl: null == logoUrl
          ? _value.logoUrl
          : logoUrl // ignore: cast_nullable_to_non_nullable
              as String,
      lightBackgroundColor: freezed == lightBackgroundColor
          ? _value.lightBackgroundColor
          : lightBackgroundColor // ignore: cast_nullable_to_non_nullable
              as String?,
      darkBackgroundColor: freezed == darkBackgroundColor
          ? _value.darkBackgroundColor
          : darkBackgroundColor // ignore: cast_nullable_to_non_nullable
              as String?,
      startsAt: freezed == startsAt
          ? _value.startsAt
          : startsAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      endsAt: freezed == endsAt
          ? _value.endsAt
          : endsAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      effect: null == effect
          ? _value.effect
          : effect // ignore: cast_nullable_to_non_nullable
              as ThemeEffect,
    ) as $Val);
  }

  /// Create a copy of OccasionalTheme
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ThemeEffectCopyWith<$Res> get effect {
    return $ThemeEffectCopyWith<$Res>(_value.effect, (value) {
      return _then(_value.copyWith(effect: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$OccasionalThemeImplCopyWith<$Res>
    implements $OccasionalThemeCopyWith<$Res> {
  factory _$$OccasionalThemeImplCopyWith(_$OccasionalThemeImpl value,
          $Res Function(_$OccasionalThemeImpl) then) =
      __$$OccasionalThemeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'display_name') String displayName,
      String description,
      bool enabled,
      @JsonKey(name: 'user_selectable') bool userSelectable,
      int priority,
      @JsonKey(name: 'primary_color') String primaryColor,
      @JsonKey(name: 'secondary_color') String secondaryColor,
      @JsonKey(name: 'tertiary_color') String tertiaryColor,
      @JsonKey(name: 'logo_url') String logoUrl,
      @JsonKey(name: 'light_background_color') String? lightBackgroundColor,
      @JsonKey(name: 'dark_background_color') String? darkBackgroundColor,
      @JsonKey(name: 'starts_at') DateTime? startsAt,
      @JsonKey(name: 'ends_at') DateTime? endsAt,
      ThemeEffect effect});

  @override
  $ThemeEffectCopyWith<$Res> get effect;
}

/// @nodoc
class __$$OccasionalThemeImplCopyWithImpl<$Res>
    extends _$OccasionalThemeCopyWithImpl<$Res, _$OccasionalThemeImpl>
    implements _$$OccasionalThemeImplCopyWith<$Res> {
  __$$OccasionalThemeImplCopyWithImpl(
      _$OccasionalThemeImpl _value, $Res Function(_$OccasionalThemeImpl) _then)
      : super(_value, _then);

  /// Create a copy of OccasionalTheme
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? displayName = null,
    Object? description = null,
    Object? enabled = null,
    Object? userSelectable = null,
    Object? priority = null,
    Object? primaryColor = null,
    Object? secondaryColor = null,
    Object? tertiaryColor = null,
    Object? logoUrl = null,
    Object? lightBackgroundColor = freezed,
    Object? darkBackgroundColor = freezed,
    Object? startsAt = freezed,
    Object? endsAt = freezed,
    Object? effect = null,
  }) {
    return _then(_$OccasionalThemeImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      enabled: null == enabled
          ? _value.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      userSelectable: null == userSelectable
          ? _value.userSelectable
          : userSelectable // ignore: cast_nullable_to_non_nullable
              as bool,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as int,
      primaryColor: null == primaryColor
          ? _value.primaryColor
          : primaryColor // ignore: cast_nullable_to_non_nullable
              as String,
      secondaryColor: null == secondaryColor
          ? _value.secondaryColor
          : secondaryColor // ignore: cast_nullable_to_non_nullable
              as String,
      tertiaryColor: null == tertiaryColor
          ? _value.tertiaryColor
          : tertiaryColor // ignore: cast_nullable_to_non_nullable
              as String,
      logoUrl: null == logoUrl
          ? _value.logoUrl
          : logoUrl // ignore: cast_nullable_to_non_nullable
              as String,
      lightBackgroundColor: freezed == lightBackgroundColor
          ? _value.lightBackgroundColor
          : lightBackgroundColor // ignore: cast_nullable_to_non_nullable
              as String?,
      darkBackgroundColor: freezed == darkBackgroundColor
          ? _value.darkBackgroundColor
          : darkBackgroundColor // ignore: cast_nullable_to_non_nullable
              as String?,
      startsAt: freezed == startsAt
          ? _value.startsAt
          : startsAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      endsAt: freezed == endsAt
          ? _value.endsAt
          : endsAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      effect: null == effect
          ? _value.effect
          : effect // ignore: cast_nullable_to_non_nullable
              as ThemeEffect,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$OccasionalThemeImpl extends _OccasionalTheme {
  const _$OccasionalThemeImpl(
      {required this.id,
      @JsonKey(name: 'display_name') required this.displayName,
      this.description = '',
      required this.enabled,
      @JsonKey(name: 'user_selectable') required this.userSelectable,
      required this.priority,
      @JsonKey(name: 'primary_color') required this.primaryColor,
      @JsonKey(name: 'secondary_color') required this.secondaryColor,
      @JsonKey(name: 'tertiary_color') required this.tertiaryColor,
      @JsonKey(name: 'logo_url') this.logoUrl = '',
      @JsonKey(name: 'light_background_color') this.lightBackgroundColor,
      @JsonKey(name: 'dark_background_color') this.darkBackgroundColor,
      @JsonKey(name: 'starts_at') this.startsAt,
      @JsonKey(name: 'ends_at') this.endsAt,
      required this.effect})
      : super._();

  factory _$OccasionalThemeImpl.fromJson(Map<String, dynamic> json) =>
      _$$OccasionalThemeImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'display_name')
  final String displayName;
  @override
  @JsonKey()
  final String description;
  @override
  final bool enabled;
  @override
  @JsonKey(name: 'user_selectable')
  final bool userSelectable;
  @override
  final int priority;
  @override
  @JsonKey(name: 'primary_color')
  final String primaryColor;
  @override
  @JsonKey(name: 'secondary_color')
  final String secondaryColor;
  @override
  @JsonKey(name: 'tertiary_color')
  final String tertiaryColor;
  @override
  @JsonKey(name: 'logo_url')
  final String logoUrl;
  @override
  @JsonKey(name: 'light_background_color')
  final String? lightBackgroundColor;
  @override
  @JsonKey(name: 'dark_background_color')
  final String? darkBackgroundColor;
  @override
  @JsonKey(name: 'starts_at')
  final DateTime? startsAt;
  @override
  @JsonKey(name: 'ends_at')
  final DateTime? endsAt;
  @override
  final ThemeEffect effect;

  @override
  String toString() {
    return 'OccasionalTheme(id: $id, displayName: $displayName, description: $description, enabled: $enabled, userSelectable: $userSelectable, priority: $priority, primaryColor: $primaryColor, secondaryColor: $secondaryColor, tertiaryColor: $tertiaryColor, logoUrl: $logoUrl, lightBackgroundColor: $lightBackgroundColor, darkBackgroundColor: $darkBackgroundColor, startsAt: $startsAt, endsAt: $endsAt, effect: $effect)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OccasionalThemeImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            (identical(other.userSelectable, userSelectable) ||
                other.userSelectable == userSelectable) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.primaryColor, primaryColor) ||
                other.primaryColor == primaryColor) &&
            (identical(other.secondaryColor, secondaryColor) ||
                other.secondaryColor == secondaryColor) &&
            (identical(other.tertiaryColor, tertiaryColor) ||
                other.tertiaryColor == tertiaryColor) &&
            (identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl) &&
            (identical(other.lightBackgroundColor, lightBackgroundColor) ||
                other.lightBackgroundColor == lightBackgroundColor) &&
            (identical(other.darkBackgroundColor, darkBackgroundColor) ||
                other.darkBackgroundColor == darkBackgroundColor) &&
            (identical(other.startsAt, startsAt) ||
                other.startsAt == startsAt) &&
            (identical(other.endsAt, endsAt) || other.endsAt == endsAt) &&
            (identical(other.effect, effect) || other.effect == effect));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      displayName,
      description,
      enabled,
      userSelectable,
      priority,
      primaryColor,
      secondaryColor,
      tertiaryColor,
      logoUrl,
      lightBackgroundColor,
      darkBackgroundColor,
      startsAt,
      endsAt,
      effect);

  /// Create a copy of OccasionalTheme
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OccasionalThemeImplCopyWith<_$OccasionalThemeImpl> get copyWith =>
      __$$OccasionalThemeImplCopyWithImpl<_$OccasionalThemeImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OccasionalThemeImplToJson(
      this,
    );
  }
}

abstract class _OccasionalTheme extends OccasionalTheme {
  const factory _OccasionalTheme(
      {required final String id,
      @JsonKey(name: 'display_name') required final String displayName,
      final String description,
      required final bool enabled,
      @JsonKey(name: 'user_selectable') required final bool userSelectable,
      required final int priority,
      @JsonKey(name: 'primary_color') required final String primaryColor,
      @JsonKey(name: 'secondary_color') required final String secondaryColor,
      @JsonKey(name: 'tertiary_color') required final String tertiaryColor,
      @JsonKey(name: 'logo_url') final String logoUrl,
      @JsonKey(name: 'light_background_color')
      final String? lightBackgroundColor,
      @JsonKey(name: 'dark_background_color') final String? darkBackgroundColor,
      @JsonKey(name: 'starts_at') final DateTime? startsAt,
      @JsonKey(name: 'ends_at') final DateTime? endsAt,
      required final ThemeEffect effect}) = _$OccasionalThemeImpl;
  const _OccasionalTheme._() : super._();

  factory _OccasionalTheme.fromJson(Map<String, dynamic> json) =
      _$OccasionalThemeImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'display_name')
  String get displayName;
  @override
  String get description;
  @override
  bool get enabled;
  @override
  @JsonKey(name: 'user_selectable')
  bool get userSelectable;
  @override
  int get priority;
  @override
  @JsonKey(name: 'primary_color')
  String get primaryColor;
  @override
  @JsonKey(name: 'secondary_color')
  String get secondaryColor;
  @override
  @JsonKey(name: 'tertiary_color')
  String get tertiaryColor;
  @override
  @JsonKey(name: 'logo_url')
  String get logoUrl;
  @override
  @JsonKey(name: 'light_background_color')
  String? get lightBackgroundColor;
  @override
  @JsonKey(name: 'dark_background_color')
  String? get darkBackgroundColor;
  @override
  @JsonKey(name: 'starts_at')
  DateTime? get startsAt;
  @override
  @JsonKey(name: 'ends_at')
  DateTime? get endsAt;
  @override
  ThemeEffect get effect;

  /// Create a copy of OccasionalTheme
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OccasionalThemeImplCopyWith<_$OccasionalThemeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

OccasionalThemeCatalog _$OccasionalThemeCatalogFromJson(
    Map<String, dynamic> json) {
  return _OccasionalThemeCatalog.fromJson(json);
}

/// @nodoc
mixin _$OccasionalThemeCatalog {
  @JsonKey(name: 'schema_version')
  int get schemaVersion => throw _privateConstructorUsedError;
  bool get enabled => throw _privateConstructorUsedError;
  @JsonKey(name: 'allow_user_selection')
  bool get allowUserSelection => throw _privateConstructorUsedError;
  @JsonKey(name: 'effects_enabled')
  bool get effectsEnabled => throw _privateConstructorUsedError;
  @JsonKey(name: 'allow_user_effects_toggle')
  bool get allowUserEffectsToggle => throw _privateConstructorUsedError;
  @JsonKey(name: 'default_theme_id')
  String get defaultThemeId => throw _privateConstructorUsedError;
  @JsonKey(name: 'active_theme_id')
  String get activeThemeId => throw _privateConstructorUsedError;
  List<OccasionalTheme> get themes => throw _privateConstructorUsedError;

  /// Serializes this OccasionalThemeCatalog to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OccasionalThemeCatalog
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OccasionalThemeCatalogCopyWith<OccasionalThemeCatalog> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OccasionalThemeCatalogCopyWith<$Res> {
  factory $OccasionalThemeCatalogCopyWith(OccasionalThemeCatalog value,
          $Res Function(OccasionalThemeCatalog) then) =
      _$OccasionalThemeCatalogCopyWithImpl<$Res, OccasionalThemeCatalog>;
  @useResult
  $Res call(
      {@JsonKey(name: 'schema_version') int schemaVersion,
      bool enabled,
      @JsonKey(name: 'allow_user_selection') bool allowUserSelection,
      @JsonKey(name: 'effects_enabled') bool effectsEnabled,
      @JsonKey(name: 'allow_user_effects_toggle') bool allowUserEffectsToggle,
      @JsonKey(name: 'default_theme_id') String defaultThemeId,
      @JsonKey(name: 'active_theme_id') String activeThemeId,
      List<OccasionalTheme> themes});
}

/// @nodoc
class _$OccasionalThemeCatalogCopyWithImpl<$Res,
        $Val extends OccasionalThemeCatalog>
    implements $OccasionalThemeCatalogCopyWith<$Res> {
  _$OccasionalThemeCatalogCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OccasionalThemeCatalog
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? schemaVersion = null,
    Object? enabled = null,
    Object? allowUserSelection = null,
    Object? effectsEnabled = null,
    Object? allowUserEffectsToggle = null,
    Object? defaultThemeId = null,
    Object? activeThemeId = null,
    Object? themes = null,
  }) {
    return _then(_value.copyWith(
      schemaVersion: null == schemaVersion
          ? _value.schemaVersion
          : schemaVersion // ignore: cast_nullable_to_non_nullable
              as int,
      enabled: null == enabled
          ? _value.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      allowUserSelection: null == allowUserSelection
          ? _value.allowUserSelection
          : allowUserSelection // ignore: cast_nullable_to_non_nullable
              as bool,
      effectsEnabled: null == effectsEnabled
          ? _value.effectsEnabled
          : effectsEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      allowUserEffectsToggle: null == allowUserEffectsToggle
          ? _value.allowUserEffectsToggle
          : allowUserEffectsToggle // ignore: cast_nullable_to_non_nullable
              as bool,
      defaultThemeId: null == defaultThemeId
          ? _value.defaultThemeId
          : defaultThemeId // ignore: cast_nullable_to_non_nullable
              as String,
      activeThemeId: null == activeThemeId
          ? _value.activeThemeId
          : activeThemeId // ignore: cast_nullable_to_non_nullable
              as String,
      themes: null == themes
          ? _value.themes
          : themes // ignore: cast_nullable_to_non_nullable
              as List<OccasionalTheme>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$OccasionalThemeCatalogImplCopyWith<$Res>
    implements $OccasionalThemeCatalogCopyWith<$Res> {
  factory _$$OccasionalThemeCatalogImplCopyWith(
          _$OccasionalThemeCatalogImpl value,
          $Res Function(_$OccasionalThemeCatalogImpl) then) =
      __$$OccasionalThemeCatalogImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'schema_version') int schemaVersion,
      bool enabled,
      @JsonKey(name: 'allow_user_selection') bool allowUserSelection,
      @JsonKey(name: 'effects_enabled') bool effectsEnabled,
      @JsonKey(name: 'allow_user_effects_toggle') bool allowUserEffectsToggle,
      @JsonKey(name: 'default_theme_id') String defaultThemeId,
      @JsonKey(name: 'active_theme_id') String activeThemeId,
      List<OccasionalTheme> themes});
}

/// @nodoc
class __$$OccasionalThemeCatalogImplCopyWithImpl<$Res>
    extends _$OccasionalThemeCatalogCopyWithImpl<$Res,
        _$OccasionalThemeCatalogImpl>
    implements _$$OccasionalThemeCatalogImplCopyWith<$Res> {
  __$$OccasionalThemeCatalogImplCopyWithImpl(
      _$OccasionalThemeCatalogImpl _value,
      $Res Function(_$OccasionalThemeCatalogImpl) _then)
      : super(_value, _then);

  /// Create a copy of OccasionalThemeCatalog
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? schemaVersion = null,
    Object? enabled = null,
    Object? allowUserSelection = null,
    Object? effectsEnabled = null,
    Object? allowUserEffectsToggle = null,
    Object? defaultThemeId = null,
    Object? activeThemeId = null,
    Object? themes = null,
  }) {
    return _then(_$OccasionalThemeCatalogImpl(
      schemaVersion: null == schemaVersion
          ? _value.schemaVersion
          : schemaVersion // ignore: cast_nullable_to_non_nullable
              as int,
      enabled: null == enabled
          ? _value.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      allowUserSelection: null == allowUserSelection
          ? _value.allowUserSelection
          : allowUserSelection // ignore: cast_nullable_to_non_nullable
              as bool,
      effectsEnabled: null == effectsEnabled
          ? _value.effectsEnabled
          : effectsEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      allowUserEffectsToggle: null == allowUserEffectsToggle
          ? _value.allowUserEffectsToggle
          : allowUserEffectsToggle // ignore: cast_nullable_to_non_nullable
              as bool,
      defaultThemeId: null == defaultThemeId
          ? _value.defaultThemeId
          : defaultThemeId // ignore: cast_nullable_to_non_nullable
              as String,
      activeThemeId: null == activeThemeId
          ? _value.activeThemeId
          : activeThemeId // ignore: cast_nullable_to_non_nullable
              as String,
      themes: null == themes
          ? _value._themes
          : themes // ignore: cast_nullable_to_non_nullable
              as List<OccasionalTheme>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$OccasionalThemeCatalogImpl extends _OccasionalThemeCatalog {
  const _$OccasionalThemeCatalogImpl(
      {@JsonKey(name: 'schema_version') this.schemaVersion = 2,
      this.enabled = false,
      @JsonKey(name: 'allow_user_selection') this.allowUserSelection = false,
      @JsonKey(name: 'effects_enabled') this.effectsEnabled = true,
      @JsonKey(name: 'allow_user_effects_toggle')
      this.allowUserEffectsToggle = false,
      @JsonKey(name: 'default_theme_id') this.defaultThemeId = '',
      @JsonKey(name: 'active_theme_id') this.activeThemeId = '',
      final List<OccasionalTheme> themes = const []})
      : _themes = themes,
        super._();

  factory _$OccasionalThemeCatalogImpl.fromJson(Map<String, dynamic> json) =>
      _$$OccasionalThemeCatalogImplFromJson(json);

  @override
  @JsonKey(name: 'schema_version')
  final int schemaVersion;
  @override
  @JsonKey()
  final bool enabled;
  @override
  @JsonKey(name: 'allow_user_selection')
  final bool allowUserSelection;
  @override
  @JsonKey(name: 'effects_enabled')
  final bool effectsEnabled;
  @override
  @JsonKey(name: 'allow_user_effects_toggle')
  final bool allowUserEffectsToggle;
  @override
  @JsonKey(name: 'default_theme_id')
  final String defaultThemeId;
  @override
  @JsonKey(name: 'active_theme_id')
  final String activeThemeId;
  final List<OccasionalTheme> _themes;
  @override
  @JsonKey()
  List<OccasionalTheme> get themes {
    if (_themes is EqualUnmodifiableListView) return _themes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_themes);
  }

  @override
  String toString() {
    return 'OccasionalThemeCatalog(schemaVersion: $schemaVersion, enabled: $enabled, allowUserSelection: $allowUserSelection, effectsEnabled: $effectsEnabled, allowUserEffectsToggle: $allowUserEffectsToggle, defaultThemeId: $defaultThemeId, activeThemeId: $activeThemeId, themes: $themes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OccasionalThemeCatalogImpl &&
            (identical(other.schemaVersion, schemaVersion) ||
                other.schemaVersion == schemaVersion) &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            (identical(other.allowUserSelection, allowUserSelection) ||
                other.allowUserSelection == allowUserSelection) &&
            (identical(other.effectsEnabled, effectsEnabled) ||
                other.effectsEnabled == effectsEnabled) &&
            (identical(other.allowUserEffectsToggle, allowUserEffectsToggle) ||
                other.allowUserEffectsToggle == allowUserEffectsToggle) &&
            (identical(other.defaultThemeId, defaultThemeId) ||
                other.defaultThemeId == defaultThemeId) &&
            (identical(other.activeThemeId, activeThemeId) ||
                other.activeThemeId == activeThemeId) &&
            const DeepCollectionEquality().equals(other._themes, _themes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      schemaVersion,
      enabled,
      allowUserSelection,
      effectsEnabled,
      allowUserEffectsToggle,
      defaultThemeId,
      activeThemeId,
      const DeepCollectionEquality().hash(_themes));

  /// Create a copy of OccasionalThemeCatalog
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OccasionalThemeCatalogImplCopyWith<_$OccasionalThemeCatalogImpl>
      get copyWith => __$$OccasionalThemeCatalogImplCopyWithImpl<
          _$OccasionalThemeCatalogImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OccasionalThemeCatalogImplToJson(
      this,
    );
  }
}

abstract class _OccasionalThemeCatalog extends OccasionalThemeCatalog {
  const factory _OccasionalThemeCatalog(
      {@JsonKey(name: 'schema_version') final int schemaVersion,
      final bool enabled,
      @JsonKey(name: 'allow_user_selection') final bool allowUserSelection,
      @JsonKey(name: 'effects_enabled') final bool effectsEnabled,
      @JsonKey(name: 'allow_user_effects_toggle')
      final bool allowUserEffectsToggle,
      @JsonKey(name: 'default_theme_id') final String defaultThemeId,
      @JsonKey(name: 'active_theme_id') final String activeThemeId,
      final List<OccasionalTheme> themes}) = _$OccasionalThemeCatalogImpl;
  const _OccasionalThemeCatalog._() : super._();

  factory _OccasionalThemeCatalog.fromJson(Map<String, dynamic> json) =
      _$OccasionalThemeCatalogImpl.fromJson;

  @override
  @JsonKey(name: 'schema_version')
  int get schemaVersion;
  @override
  bool get enabled;
  @override
  @JsonKey(name: 'allow_user_selection')
  bool get allowUserSelection;
  @override
  @JsonKey(name: 'effects_enabled')
  bool get effectsEnabled;
  @override
  @JsonKey(name: 'allow_user_effects_toggle')
  bool get allowUserEffectsToggle;
  @override
  @JsonKey(name: 'default_theme_id')
  String get defaultThemeId;
  @override
  @JsonKey(name: 'active_theme_id')
  String get activeThemeId;
  @override
  List<OccasionalTheme> get themes;

  /// Create a copy of OccasionalThemeCatalog
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OccasionalThemeCatalogImplCopyWith<_$OccasionalThemeCatalogImpl>
      get copyWith => throw _privateConstructorUsedError;
}

BannerDisplayConfig _$BannerDisplayConfigFromJson(Map<String, dynamic> json) {
  return _BannerDisplayConfig.fromJson(json);
}

/// @nodoc
mixin _$BannerDisplayConfig {
  String get key => throw _privateConstructorUsedError;
  bool get enabled => throw _privateConstructorUsedError;
  List<String> get placements => throw _privateConstructorUsedError;
  String? get shape => throw _privateConstructorUsedError;
  double? get width => throw _privateConstructorUsedError;
  double? get height => throw _privateConstructorUsedError;
  double? get aspectRatio => throw _privateConstructorUsedError;

  /// Serializes this BannerDisplayConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BannerDisplayConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BannerDisplayConfigCopyWith<BannerDisplayConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BannerDisplayConfigCopyWith<$Res> {
  factory $BannerDisplayConfigCopyWith(
          BannerDisplayConfig value, $Res Function(BannerDisplayConfig) then) =
      _$BannerDisplayConfigCopyWithImpl<$Res, BannerDisplayConfig>;
  @useResult
  $Res call(
      {String key,
      bool enabled,
      List<String> placements,
      String? shape,
      double? width,
      double? height,
      double? aspectRatio});
}

/// @nodoc
class _$BannerDisplayConfigCopyWithImpl<$Res, $Val extends BannerDisplayConfig>
    implements $BannerDisplayConfigCopyWith<$Res> {
  _$BannerDisplayConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BannerDisplayConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? key = null,
    Object? enabled = null,
    Object? placements = null,
    Object? shape = freezed,
    Object? width = freezed,
    Object? height = freezed,
    Object? aspectRatio = freezed,
  }) {
    return _then(_value.copyWith(
      key: null == key
          ? _value.key
          : key // ignore: cast_nullable_to_non_nullable
              as String,
      enabled: null == enabled
          ? _value.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      placements: null == placements
          ? _value.placements
          : placements // ignore: cast_nullable_to_non_nullable
              as List<String>,
      shape: freezed == shape
          ? _value.shape
          : shape // ignore: cast_nullable_to_non_nullable
              as String?,
      width: freezed == width
          ? _value.width
          : width // ignore: cast_nullable_to_non_nullable
              as double?,
      height: freezed == height
          ? _value.height
          : height // ignore: cast_nullable_to_non_nullable
              as double?,
      aspectRatio: freezed == aspectRatio
          ? _value.aspectRatio
          : aspectRatio // ignore: cast_nullable_to_non_nullable
              as double?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BannerDisplayConfigImplCopyWith<$Res>
    implements $BannerDisplayConfigCopyWith<$Res> {
  factory _$$BannerDisplayConfigImplCopyWith(_$BannerDisplayConfigImpl value,
          $Res Function(_$BannerDisplayConfigImpl) then) =
      __$$BannerDisplayConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String key,
      bool enabled,
      List<String> placements,
      String? shape,
      double? width,
      double? height,
      double? aspectRatio});
}

/// @nodoc
class __$$BannerDisplayConfigImplCopyWithImpl<$Res>
    extends _$BannerDisplayConfigCopyWithImpl<$Res, _$BannerDisplayConfigImpl>
    implements _$$BannerDisplayConfigImplCopyWith<$Res> {
  __$$BannerDisplayConfigImplCopyWithImpl(_$BannerDisplayConfigImpl _value,
      $Res Function(_$BannerDisplayConfigImpl) _then)
      : super(_value, _then);

  /// Create a copy of BannerDisplayConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? key = null,
    Object? enabled = null,
    Object? placements = null,
    Object? shape = freezed,
    Object? width = freezed,
    Object? height = freezed,
    Object? aspectRatio = freezed,
  }) {
    return _then(_$BannerDisplayConfigImpl(
      key: null == key
          ? _value.key
          : key // ignore: cast_nullable_to_non_nullable
              as String,
      enabled: null == enabled
          ? _value.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      placements: null == placements
          ? _value._placements
          : placements // ignore: cast_nullable_to_non_nullable
              as List<String>,
      shape: freezed == shape
          ? _value.shape
          : shape // ignore: cast_nullable_to_non_nullable
              as String?,
      width: freezed == width
          ? _value.width
          : width // ignore: cast_nullable_to_non_nullable
              as double?,
      height: freezed == height
          ? _value.height
          : height // ignore: cast_nullable_to_non_nullable
              as double?,
      aspectRatio: freezed == aspectRatio
          ? _value.aspectRatio
          : aspectRatio // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BannerDisplayConfigImpl extends _BannerDisplayConfig {
  const _$BannerDisplayConfigImpl(
      {required this.key,
      this.enabled = true,
      final List<String> placements = const [],
      this.shape,
      this.width,
      this.height,
      this.aspectRatio})
      : _placements = placements,
        super._();

  factory _$BannerDisplayConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$BannerDisplayConfigImplFromJson(json);

  @override
  final String key;
  @override
  @JsonKey()
  final bool enabled;
  final List<String> _placements;
  @override
  @JsonKey()
  List<String> get placements {
    if (_placements is EqualUnmodifiableListView) return _placements;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_placements);
  }

  @override
  final String? shape;
  @override
  final double? width;
  @override
  final double? height;
  @override
  final double? aspectRatio;

  @override
  String toString() {
    return 'BannerDisplayConfig(key: $key, enabled: $enabled, placements: $placements, shape: $shape, width: $width, height: $height, aspectRatio: $aspectRatio)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BannerDisplayConfigImpl &&
            (identical(other.key, key) || other.key == key) &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            const DeepCollectionEquality()
                .equals(other._placements, _placements) &&
            (identical(other.shape, shape) || other.shape == shape) &&
            (identical(other.width, width) || other.width == width) &&
            (identical(other.height, height) || other.height == height) &&
            (identical(other.aspectRatio, aspectRatio) ||
                other.aspectRatio == aspectRatio));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      key,
      enabled,
      const DeepCollectionEquality().hash(_placements),
      shape,
      width,
      height,
      aspectRatio);

  /// Create a copy of BannerDisplayConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BannerDisplayConfigImplCopyWith<_$BannerDisplayConfigImpl> get copyWith =>
      __$$BannerDisplayConfigImplCopyWithImpl<_$BannerDisplayConfigImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BannerDisplayConfigImplToJson(
      this,
    );
  }
}

abstract class _BannerDisplayConfig extends BannerDisplayConfig {
  const factory _BannerDisplayConfig(
      {required final String key,
      final bool enabled,
      final List<String> placements,
      final String? shape,
      final double? width,
      final double? height,
      final double? aspectRatio}) = _$BannerDisplayConfigImpl;
  const _BannerDisplayConfig._() : super._();

  factory _BannerDisplayConfig.fromJson(Map<String, dynamic> json) =
      _$BannerDisplayConfigImpl.fromJson;

  @override
  String get key;
  @override
  bool get enabled;
  @override
  List<String> get placements;
  @override
  String? get shape;
  @override
  double? get width;
  @override
  double? get height;
  @override
  double? get aspectRatio;

  /// Create a copy of BannerDisplayConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BannerDisplayConfigImplCopyWith<_$BannerDisplayConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

BootstrapConfig _$BootstrapConfigFromJson(Map<String, dynamic> json) {
  return _BootstrapConfig.fromJson(json);
}

/// @nodoc
mixin _$BootstrapConfig {
  @JsonKey(name: 'config_source')
  String? get configSource => throw _privateConstructorUsedError;
  FeaturesConfig get features => throw _privateConstructorUsedError;
  BrandingConfig get branding => throw _privateConstructorUsedError;
  UpdateConfig get updates => throw _privateConstructorUsedError;
  NetworkConfig get network => throw _privateConstructorUsedError;
  AdsConfig get ads => throw _privateConstructorUsedError;
  List<BannerDisplayConfig> get banners => throw _privateConstructorUsedError;
  @JsonKey(name: 'occasional_theme')
  OccasionalThemeCatalog get occasionalTheme =>
      throw _privateConstructorUsedError;

  /// Serializes this BootstrapConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BootstrapConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BootstrapConfigCopyWith<BootstrapConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BootstrapConfigCopyWith<$Res> {
  factory $BootstrapConfigCopyWith(
          BootstrapConfig value, $Res Function(BootstrapConfig) then) =
      _$BootstrapConfigCopyWithImpl<$Res, BootstrapConfig>;
  @useResult
  $Res call(
      {@JsonKey(name: 'config_source') String? configSource,
      FeaturesConfig features,
      BrandingConfig branding,
      UpdateConfig updates,
      NetworkConfig network,
      AdsConfig ads,
      List<BannerDisplayConfig> banners,
      @JsonKey(name: 'occasional_theme')
      OccasionalThemeCatalog occasionalTheme});

  $FeaturesConfigCopyWith<$Res> get features;
  $BrandingConfigCopyWith<$Res> get branding;
  $UpdateConfigCopyWith<$Res> get updates;
  $NetworkConfigCopyWith<$Res> get network;
  $AdsConfigCopyWith<$Res> get ads;
  $OccasionalThemeCatalogCopyWith<$Res> get occasionalTheme;
}

/// @nodoc
class _$BootstrapConfigCopyWithImpl<$Res, $Val extends BootstrapConfig>
    implements $BootstrapConfigCopyWith<$Res> {
  _$BootstrapConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BootstrapConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? configSource = freezed,
    Object? features = null,
    Object? branding = null,
    Object? updates = null,
    Object? network = null,
    Object? ads = null,
    Object? banners = null,
    Object? occasionalTheme = null,
  }) {
    return _then(_value.copyWith(
      configSource: freezed == configSource
          ? _value.configSource
          : configSource // ignore: cast_nullable_to_non_nullable
              as String?,
      features: null == features
          ? _value.features
          : features // ignore: cast_nullable_to_non_nullable
              as FeaturesConfig,
      branding: null == branding
          ? _value.branding
          : branding // ignore: cast_nullable_to_non_nullable
              as BrandingConfig,
      updates: null == updates
          ? _value.updates
          : updates // ignore: cast_nullable_to_non_nullable
              as UpdateConfig,
      network: null == network
          ? _value.network
          : network // ignore: cast_nullable_to_non_nullable
              as NetworkConfig,
      ads: null == ads
          ? _value.ads
          : ads // ignore: cast_nullable_to_non_nullable
              as AdsConfig,
      banners: null == banners
          ? _value.banners
          : banners // ignore: cast_nullable_to_non_nullable
              as List<BannerDisplayConfig>,
      occasionalTheme: null == occasionalTheme
          ? _value.occasionalTheme
          : occasionalTheme // ignore: cast_nullable_to_non_nullable
              as OccasionalThemeCatalog,
    ) as $Val);
  }

  /// Create a copy of BootstrapConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FeaturesConfigCopyWith<$Res> get features {
    return $FeaturesConfigCopyWith<$Res>(_value.features, (value) {
      return _then(_value.copyWith(features: value) as $Val);
    });
  }

  /// Create a copy of BootstrapConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BrandingConfigCopyWith<$Res> get branding {
    return $BrandingConfigCopyWith<$Res>(_value.branding, (value) {
      return _then(_value.copyWith(branding: value) as $Val);
    });
  }

  /// Create a copy of BootstrapConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UpdateConfigCopyWith<$Res> get updates {
    return $UpdateConfigCopyWith<$Res>(_value.updates, (value) {
      return _then(_value.copyWith(updates: value) as $Val);
    });
  }

  /// Create a copy of BootstrapConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NetworkConfigCopyWith<$Res> get network {
    return $NetworkConfigCopyWith<$Res>(_value.network, (value) {
      return _then(_value.copyWith(network: value) as $Val);
    });
  }

  /// Create a copy of BootstrapConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AdsConfigCopyWith<$Res> get ads {
    return $AdsConfigCopyWith<$Res>(_value.ads, (value) {
      return _then(_value.copyWith(ads: value) as $Val);
    });
  }

  /// Create a copy of BootstrapConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $OccasionalThemeCatalogCopyWith<$Res> get occasionalTheme {
    return $OccasionalThemeCatalogCopyWith<$Res>(_value.occasionalTheme,
        (value) {
      return _then(_value.copyWith(occasionalTheme: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$BootstrapConfigImplCopyWith<$Res>
    implements $BootstrapConfigCopyWith<$Res> {
  factory _$$BootstrapConfigImplCopyWith(_$BootstrapConfigImpl value,
          $Res Function(_$BootstrapConfigImpl) then) =
      __$$BootstrapConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'config_source') String? configSource,
      FeaturesConfig features,
      BrandingConfig branding,
      UpdateConfig updates,
      NetworkConfig network,
      AdsConfig ads,
      List<BannerDisplayConfig> banners,
      @JsonKey(name: 'occasional_theme')
      OccasionalThemeCatalog occasionalTheme});

  @override
  $FeaturesConfigCopyWith<$Res> get features;
  @override
  $BrandingConfigCopyWith<$Res> get branding;
  @override
  $UpdateConfigCopyWith<$Res> get updates;
  @override
  $NetworkConfigCopyWith<$Res> get network;
  @override
  $AdsConfigCopyWith<$Res> get ads;
  @override
  $OccasionalThemeCatalogCopyWith<$Res> get occasionalTheme;
}

/// @nodoc
class __$$BootstrapConfigImplCopyWithImpl<$Res>
    extends _$BootstrapConfigCopyWithImpl<$Res, _$BootstrapConfigImpl>
    implements _$$BootstrapConfigImplCopyWith<$Res> {
  __$$BootstrapConfigImplCopyWithImpl(
      _$BootstrapConfigImpl _value, $Res Function(_$BootstrapConfigImpl) _then)
      : super(_value, _then);

  /// Create a copy of BootstrapConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? configSource = freezed,
    Object? features = null,
    Object? branding = null,
    Object? updates = null,
    Object? network = null,
    Object? ads = null,
    Object? banners = null,
    Object? occasionalTheme = null,
  }) {
    return _then(_$BootstrapConfigImpl(
      configSource: freezed == configSource
          ? _value.configSource
          : configSource // ignore: cast_nullable_to_non_nullable
              as String?,
      features: null == features
          ? _value.features
          : features // ignore: cast_nullable_to_non_nullable
              as FeaturesConfig,
      branding: null == branding
          ? _value.branding
          : branding // ignore: cast_nullable_to_non_nullable
              as BrandingConfig,
      updates: null == updates
          ? _value.updates
          : updates // ignore: cast_nullable_to_non_nullable
              as UpdateConfig,
      network: null == network
          ? _value.network
          : network // ignore: cast_nullable_to_non_nullable
              as NetworkConfig,
      ads: null == ads
          ? _value.ads
          : ads // ignore: cast_nullable_to_non_nullable
              as AdsConfig,
      banners: null == banners
          ? _value._banners
          : banners // ignore: cast_nullable_to_non_nullable
              as List<BannerDisplayConfig>,
      occasionalTheme: null == occasionalTheme
          ? _value.occasionalTheme
          : occasionalTheme // ignore: cast_nullable_to_non_nullable
              as OccasionalThemeCatalog,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BootstrapConfigImpl implements _BootstrapConfig {
  const _$BootstrapConfigImpl(
      {@JsonKey(name: 'config_source') this.configSource,
      this.features = const FeaturesConfig(),
      this.branding = const BrandingConfig(),
      this.updates = const UpdateConfig(),
      this.network = const NetworkConfig(),
      this.ads = const AdsConfig(),
      final List<BannerDisplayConfig> banners = const [],
      @JsonKey(name: 'occasional_theme')
      this.occasionalTheme = const OccasionalThemeCatalog()})
      : _banners = banners;

  factory _$BootstrapConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$BootstrapConfigImplFromJson(json);

  @override
  @JsonKey(name: 'config_source')
  final String? configSource;
  @override
  @JsonKey()
  final FeaturesConfig features;
  @override
  @JsonKey()
  final BrandingConfig branding;
  @override
  @JsonKey()
  final UpdateConfig updates;
  @override
  @JsonKey()
  final NetworkConfig network;
  @override
  @JsonKey()
  final AdsConfig ads;
  final List<BannerDisplayConfig> _banners;
  @override
  @JsonKey()
  List<BannerDisplayConfig> get banners {
    if (_banners is EqualUnmodifiableListView) return _banners;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_banners);
  }

  @override
  @JsonKey(name: 'occasional_theme')
  final OccasionalThemeCatalog occasionalTheme;

  @override
  String toString() {
    return 'BootstrapConfig(configSource: $configSource, features: $features, branding: $branding, updates: $updates, network: $network, ads: $ads, banners: $banners, occasionalTheme: $occasionalTheme)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BootstrapConfigImpl &&
            (identical(other.configSource, configSource) ||
                other.configSource == configSource) &&
            (identical(other.features, features) ||
                other.features == features) &&
            (identical(other.branding, branding) ||
                other.branding == branding) &&
            (identical(other.updates, updates) || other.updates == updates) &&
            (identical(other.network, network) || other.network == network) &&
            (identical(other.ads, ads) || other.ads == ads) &&
            const DeepCollectionEquality().equals(other._banners, _banners) &&
            (identical(other.occasionalTheme, occasionalTheme) ||
                other.occasionalTheme == occasionalTheme));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      configSource,
      features,
      branding,
      updates,
      network,
      ads,
      const DeepCollectionEquality().hash(_banners),
      occasionalTheme);

  /// Create a copy of BootstrapConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BootstrapConfigImplCopyWith<_$BootstrapConfigImpl> get copyWith =>
      __$$BootstrapConfigImplCopyWithImpl<_$BootstrapConfigImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BootstrapConfigImplToJson(
      this,
    );
  }
}

abstract class _BootstrapConfig implements BootstrapConfig {
  const factory _BootstrapConfig(
      {@JsonKey(name: 'config_source') final String? configSource,
      final FeaturesConfig features,
      final BrandingConfig branding,
      final UpdateConfig updates,
      final NetworkConfig network,
      final AdsConfig ads,
      final List<BannerDisplayConfig> banners,
      @JsonKey(name: 'occasional_theme')
      final OccasionalThemeCatalog occasionalTheme}) = _$BootstrapConfigImpl;

  factory _BootstrapConfig.fromJson(Map<String, dynamic> json) =
      _$BootstrapConfigImpl.fromJson;

  @override
  @JsonKey(name: 'config_source')
  String? get configSource;
  @override
  FeaturesConfig get features;
  @override
  BrandingConfig get branding;
  @override
  UpdateConfig get updates;
  @override
  NetworkConfig get network;
  @override
  AdsConfig get ads;
  @override
  List<BannerDisplayConfig> get banners;
  @override
  @JsonKey(name: 'occasional_theme')
  OccasionalThemeCatalog get occasionalTheme;

  /// Create a copy of BootstrapConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BootstrapConfigImplCopyWith<_$BootstrapConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
