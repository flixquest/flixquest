// Freezed forwards constructor parameter annotations onto generated fields.
// ignore_for_file: invalid_annotation_target

import 'dart:convert';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flixquest/core/json/json_reader.dart';
import 'package:flixquest/models/occasional_theme.dart' as domain;
import 'package:flixquest/models/banner_ad.dart' as domain;
part 'bootstrap_config.freezed.dart';
part 'bootstrap_config.g.dart';

Map<String, dynamic> _section(Object? value) => JsonReader.asMap(value) ?? {};
Map<String, dynamic> _normalize(
  Map<String, dynamic> json, {
  Map<String, bool> booleans = const {},
  Map<String, int> integers = const {},
  Map<String, String> strings = const {},
}) =>
    {
      ...json,
      for (final entry in booleans.entries)
        entry.key: JsonReader.asBool(json[entry.key]) ?? entry.value,
      for (final entry in integers.entries)
        entry.key: JsonReader.asInt(json[entry.key]) ?? entry.value,
      for (final entry in strings.entries)
        entry.key: JsonReader.asString(json[entry.key]) ?? entry.value,
    };

@freezed
class FeaturesConfig with _$FeaturesConfig {
  const factory FeaturesConfig({
    @JsonKey(name: 'enable_stream') @Default(true) bool enableStream,
    @JsonKey(name: 'enable_download') @Default(true) bool enableDownload,
    @JsonKey(name: 'enable_live_tv') @Default(true) bool enableLiveTv,
    @JsonKey(name: 'enable_ott') @Default(true) bool enableOtt,
  }) = _FeaturesConfig;
  factory FeaturesConfig.fromJson(Map<String, dynamic> json) =>
      _$FeaturesConfigFromJson(_featuresConfigJson(json));
}

@freezed
class BrandingConfig with _$BrandingConfig {
  const factory BrandingConfig({
    @JsonKey(name: 'app_logo_url') @Default('') String appLogoUrl,
    @JsonKey(name: 'cinemax_logo') @Default('default') String cinemaxLogo,
  }) = _BrandingConfig;
  factory BrandingConfig.fromJson(Map<String, dynamic> json) =>
      _$BrandingConfigFromJson(_brandingConfigJson(json));
}

@freezed
class UpdateConfig with _$UpdateConfig {
  const factory UpdateConfig({
    @JsonKey(name: 'forced_update') @Default(false) bool forcedUpdate,
    @JsonKey(name: 'latest_version') @Default('') String latestVersion,
    @JsonKey(name: 'latest_build_number') @Default(0) int latestBuildNumber,
    @JsonKey(name: 'min_build_number') @Default(0) int minBuildNumber,
    @JsonKey(name: 'app_download_url') @Default('') String appDownloadUrl,
    @JsonKey(name: 'change_log') @Default('') String changeLog,
  }) = _UpdateConfig;
  factory UpdateConfig.fromJson(Map<String, dynamic> json) =>
      _$UpdateConfigFromJson(_updateConfigJson(json));
}

@freezed
class NetworkConfig with _$NetworkConfig {
  const factory NetworkConfig({
    @JsonKey(name: 'flixquest_api_instances')
    @Default([])
    List<String> flixquestApiInstances,
    @JsonKey(name: 'flixquest_api_url_v2')
    @Default('')
    String flixquestApiUrlV2,
    @JsonKey(name: 'tmdb_api_key') @Default('') String tmdbApiKey,
    @JsonKey(name: 'tmdb_proxy') @Default('') String tmdbProxy,
  }) = _NetworkConfig;
  factory NetworkConfig.fromJson(Map<String, dynamic> json) =>
      _$NetworkConfigFromJson(_networkConfigJson(json));
}

@freezed
class AdsConfig with _$AdsConfig {
  const factory AdsConfig({
    @JsonKey(name: 'banner_ad_network')
    @Default('native')
    String bannerAdNetwork,
    @JsonKey(name: 'hosted_banner_mode')
    @Default('stack')
    String hostedBannerMode,
    @JsonKey(name: 'unity_game_id_android')
    @Default('5445375')
    String unityGameIdAndroid,
    @JsonKey(name: 'unity_banner_placement_id')
    @Default('Banner_Android')
    String unityBannerPlacementId,
    @JsonKey(name: 'unity_test_mode') @Default(false) bool unityTestMode,
    @JsonKey(name: 'startio_banner_enabled')
    @Default(false)
    bool startioBannerEnabled,
    @JsonKey(name: 'startio_interstitial_enabled')
    @Default(false)
    bool startioInterstitialEnabled,
    @JsonKey(name: 'startio_interstitial_interval_seconds')
    @Default(600)
    int startioInterstitialIntervalSeconds,
    @JsonKey(name: 'startio_tv_interstitial_mode')
    @Default('video')
    String startioTvInterstitialMode,
  }) = _AdsConfig;
  factory AdsConfig.fromJson(Map<String, dynamic> json) =>
      _$AdsConfigFromJson(_adsConfigJson(json));
}

/// Wire DTOs reuse the existing parser for palettes, presets and validation.
@freezed
class ThemeEffect with _$ThemeEffect {
  const factory ThemeEffect({
    @Default(false) bool enabled,
    @Default('none') String type,
    @Default(28) int density,
    @Default(1.0) double speed,
    @Default(.65) double opacity,
    @Default([]) List<String> colors,
  }) = _ThemeEffect;
  factory ThemeEffect.fromJson(Map<String, dynamic> json) =>
      _$ThemeEffectFromJson(json);
}

@freezed
class OccasionalTheme with _$OccasionalTheme {
  const OccasionalTheme._();
  const factory OccasionalTheme({
    required String id,
    @JsonKey(name: 'display_name') required String displayName,
    @Default('') String description,
    required bool enabled,
    @JsonKey(name: 'user_selectable') required bool userSelectable,
    required int priority,
    @JsonKey(name: 'primary_color') required String primaryColor,
    @JsonKey(name: 'secondary_color') required String secondaryColor,
    @JsonKey(name: 'tertiary_color') required String tertiaryColor,
    @JsonKey(name: 'logo_url') @Default('') String logoUrl,
    @JsonKey(name: 'light_background_color') String? lightBackgroundColor,
    @JsonKey(name: 'dark_background_color') String? darkBackgroundColor,
    @JsonKey(name: 'starts_at') DateTime? startsAt,
    @JsonKey(name: 'ends_at') DateTime? endsAt,
    required ThemeEffect effect,
  }) = _OccasionalTheme;
  factory OccasionalTheme.fromJson(Map<String, dynamic> json) =>
      _$OccasionalThemeFromJson(domain.OccasionalTheme.fromJson(json).toJson());
  domain.OccasionalTheme toDomain() =>
      domain.OccasionalTheme.fromJson(toJson());
}

@freezed
class OccasionalThemeCatalog with _$OccasionalThemeCatalog {
  const OccasionalThemeCatalog._();
  const factory OccasionalThemeCatalog({
    @JsonKey(name: 'schema_version') @Default(2) int schemaVersion,
    @Default(false) bool enabled,
    @JsonKey(name: 'allow_user_selection')
    @Default(false)
    bool allowUserSelection,
    @JsonKey(name: 'effects_enabled') @Default(true) bool effectsEnabled,
    @JsonKey(name: 'allow_user_effects_toggle')
    @Default(false)
    bool allowUserEffectsToggle,
    @JsonKey(name: 'default_theme_id') @Default('') String defaultThemeId,
    @JsonKey(name: 'active_theme_id') @Default('') String activeThemeId,
    @Default([]) List<OccasionalTheme> themes,
  }) = _OccasionalThemeCatalog;
  factory OccasionalThemeCatalog.fromJson(Map<String, dynamic> json) =>
      _$OccasionalThemeCatalogFromJson(_catalogJson(json));
  domain.OccasionalThemeCatalog toDomain({DateTime? resolvedAt}) =>
      domain.OccasionalThemeCatalog.fromJson({
        ...toJson(),
        if (resolvedAt != null)
          'resolved_at': resolvedAt.toUtc().toIso8601String(),
      });
}

@freezed
class BannerDisplayConfig with _$BannerDisplayConfig {
  const BannerDisplayConfig._();
  const factory BannerDisplayConfig({
    required String key,
    @Default(true) bool enabled,
    @Default([]) List<String> placements,
    String? shape,
    double? width,
    double? height,
    double? aspectRatio,
  }) = _BannerDisplayConfig;
  factory BannerDisplayConfig.fromJson(Map<String, dynamic> json) =>
      _$BannerDisplayConfigFromJson(json);
  domain.BannerDisplayConfig toDomain() =>
      domain.BannerDisplayConfig.fromJson(key, toJson());
}

List<Map<String, dynamic>> _banners(Object? value) {
  if (value is String) {
    try {
      value = jsonDecode(value);
    } catch (_) {
      return [];
    }
  }
  if (value is Map && value.containsKey('banners')) value = value['banners'];
  final result = <Map<String, dynamic>>[];
  void add(Object? key, Object? data) {
    final map = JsonReader.asMap(data);
    if (map == null) return;
    result.add({
      ...map,
      'key': '$key',
      'enabled': JsonReader.asBool(map['enabled']) ?? true,
      'placements': map['placements'] is List
          ? (map['placements'] as List).whereType<String>().toList()
          : <String>[],
      for (final field in ['width', 'height', 'aspectRatio'])
        field: JsonReader.asDouble(map[field]),
    });
  }

  if (value is Map) {
    for (final entry in value.entries) {
      add(entry.key, entry.value);
    }
  } else if (value is List) {
    for (final item in value.whereType<Map>()) {
      if (item.containsKey('key')) {
        add(item['key'], item);
      } else {
        for (final entry in item.entries) {
          add(entry.key, entry.value);
        }
      }
    }
  }
  return result;
}

@freezed
class BootstrapConfig with _$BootstrapConfig {
  const factory BootstrapConfig({
    @JsonKey(name: 'config_source') String? configSource,
    @Default(FeaturesConfig()) FeaturesConfig features,
    @Default(BrandingConfig()) BrandingConfig branding,
    @Default(UpdateConfig()) UpdateConfig updates,
    @Default(NetworkConfig()) NetworkConfig network,
    @Default(AdsConfig()) AdsConfig ads,
    @Default([]) List<BannerDisplayConfig> banners,
    @JsonKey(name: 'occasional_theme')
    @Default(OccasionalThemeCatalog())
    OccasionalThemeCatalog occasionalTheme,
  }) = _BootstrapConfig;
  factory BootstrapConfig.fromJson(Map<String, dynamic> json) =>
      _$BootstrapConfigFromJson({
        ...json,
        for (final name in [
          'features',
          'branding',
          'updates',
          'network',
          'ads'
        ])
          name: _section(json[name]),
        'banners': _banners(json['banners']),
        'occasional_theme': json['occasional_theme'] ?? {'enabled': false},
      });
}

Map<String, dynamic> _featuresConfigJson(Map<String, dynamic> json) {
  json = {
    ...json,
    if (!json.containsKey('enable_live_tv'))
      'enable_live_tv': json['enable_ott']
  };
  return _normalize(
    json,
    booleans: {
      'enable_stream': true,
      'enable_download': true,
      'enable_live_tv': true,
      'enable_ott': true
    },
  );
}

Map<String, dynamic> _brandingConfigJson(Map<String, dynamic> json) {
  return _normalize(
    json,
    strings: {'app_logo_url': '', 'cinemax_logo': 'default'},
  );
}

Map<String, dynamic> _updateConfigJson(Map<String, dynamic> json) {
  return _normalize(
    json,
    booleans: {'forced_update': false},
    integers: {'latest_build_number': 0, 'min_build_number': 0},
    strings: {'latest_version': '', 'app_download_url': '', 'change_log': ''},
  );
}

Map<String, dynamic> _networkConfigJson(Map<String, dynamic> json) {
  var urls = json['flixquest_api_instances'];
  if (urls is String) {
    try {
      urls = jsonDecode(urls);
    } catch (_) {
      urls = null;
    }
  }
  if (urls is Map) urls = urls['instances'];
  json = {
    ...json,
    'flixquest_api_instances': urls is List
        ? urls
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList()
        : <String>[]
  };
  return _normalize(
    json,
    strings: {'flixquest_api_url_v2': '', 'tmdb_api_key': '', 'tmdb_proxy': ''},
  );
}

Map<String, dynamic> _adsConfigJson(Map<String, dynamic> json) {
  return _normalize(
    json,
    booleans: {
      'unity_test_mode': false,
      'startio_banner_enabled': false,
      'startio_interstitial_enabled': false
    },
    integers: {'startio_interstitial_interval_seconds': 600},
    strings: {
      'banner_ad_network': 'native',
      'hosted_banner_mode': 'stack',
      'unity_game_id_android': '5445375',
      'unity_banner_placement_id': 'Banner_Android',
      'startio_tv_interstitial_mode': 'video'
    },
  );
}

Map<String, dynamic> _catalogJson(Map<String, dynamic> json) {
  final empty = json['themes'] is List && (json['themes'] as List).isEmpty;
  final parsed = domain.OccasionalThemeCatalog.tryFromJsonString(
      jsonEncode(empty ? {...json, 'enabled': false} : json));
  if (parsed == null) throw const FormatException('Invalid theme catalog');
  return {
    ...parsed.toJson(),
    if (empty) 'enabled': JsonReader.asBool(json['enabled']) ?? false,
    'active_theme_id':
        (json['active_theme_id'] ?? '').toString().trim().toLowerCase(),
  };
}
