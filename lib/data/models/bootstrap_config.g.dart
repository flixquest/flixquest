// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bootstrap_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FeaturesConfigImpl _$$FeaturesConfigImplFromJson(Map<String, dynamic> json) =>
    _$FeaturesConfigImpl(
      enableStream: json['enable_stream'] as bool? ?? true,
      enableDownload: json['enable_download'] as bool? ?? true,
      enableLiveTv: json['enable_live_tv'] as bool? ?? true,
      enableOtt: json['enable_ott'] as bool? ?? true,
    );

Map<String, dynamic> _$$FeaturesConfigImplToJson(
        _$FeaturesConfigImpl instance) =>
    <String, dynamic>{
      'enable_stream': instance.enableStream,
      'enable_download': instance.enableDownload,
      'enable_live_tv': instance.enableLiveTv,
      'enable_ott': instance.enableOtt,
    };

_$BrandingConfigImpl _$$BrandingConfigImplFromJson(Map<String, dynamic> json) =>
    _$BrandingConfigImpl(
      appLogoUrl: json['app_logo_url'] as String? ?? '',
      cinemaxLogo: json['cinemax_logo'] as String? ?? 'default',
    );

Map<String, dynamic> _$$BrandingConfigImplToJson(
        _$BrandingConfigImpl instance) =>
    <String, dynamic>{
      'app_logo_url': instance.appLogoUrl,
      'cinemax_logo': instance.cinemaxLogo,
    };

_$UpdateConfigImpl _$$UpdateConfigImplFromJson(Map<String, dynamic> json) =>
    _$UpdateConfigImpl(
      forcedUpdate: json['forced_update'] as bool? ?? false,
      latestVersion: json['latest_version'] as String? ?? '',
      latestBuildNumber: (json['latest_build_number'] as num?)?.toInt() ?? 0,
      minBuildNumber: (json['min_build_number'] as num?)?.toInt() ?? 0,
      appDownloadUrl: json['app_download_url'] as String? ?? '',
      changeLog: json['change_log'] as String? ?? '',
    );

Map<String, dynamic> _$$UpdateConfigImplToJson(_$UpdateConfigImpl instance) =>
    <String, dynamic>{
      'forced_update': instance.forcedUpdate,
      'latest_version': instance.latestVersion,
      'latest_build_number': instance.latestBuildNumber,
      'min_build_number': instance.minBuildNumber,
      'app_download_url': instance.appDownloadUrl,
      'change_log': instance.changeLog,
    };

_$NetworkConfigImpl _$$NetworkConfigImplFromJson(Map<String, dynamic> json) =>
    _$NetworkConfigImpl(
      flixquestApiInstances: (json['flixquest_api_instances'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      flixquestApiUrlV2: json['flixquest_api_url_v2'] as String? ?? '',
      tmdbApiKey: json['tmdb_api_key'] as String? ?? '',
      tmdbProxy: json['tmdb_proxy'] as String? ?? '',
    );

Map<String, dynamic> _$$NetworkConfigImplToJson(_$NetworkConfigImpl instance) =>
    <String, dynamic>{
      'flixquest_api_instances': instance.flixquestApiInstances,
      'flixquest_api_url_v2': instance.flixquestApiUrlV2,
      'tmdb_api_key': instance.tmdbApiKey,
      'tmdb_proxy': instance.tmdbProxy,
    };

_$AdsConfigImpl _$$AdsConfigImplFromJson(Map<String, dynamic> json) =>
    _$AdsConfigImpl(
      bannerAdNetwork: json['banner_ad_network'] as String? ?? 'native',
      hostedBannerMode: json['hosted_banner_mode'] as String? ?? 'stack',
      unityGameIdAndroid: json['unity_game_id_android'] as String? ?? '5445375',
      unityBannerPlacementId:
          json['unity_banner_placement_id'] as String? ?? 'Banner_Android',
      unityTestMode: json['unity_test_mode'] as bool? ?? false,
      startioBannerEnabled: json['startio_banner_enabled'] as bool? ?? false,
      startioInterstitialEnabled:
          json['startio_interstitial_enabled'] as bool? ?? false,
      startioInterstitialIntervalSeconds:
          (json['startio_interstitial_interval_seconds'] as num?)?.toInt() ??
              600,
      startioTvInterstitialMode:
          json['startio_tv_interstitial_mode'] as String? ?? 'video',
    );

Map<String, dynamic> _$$AdsConfigImplToJson(_$AdsConfigImpl instance) =>
    <String, dynamic>{
      'banner_ad_network': instance.bannerAdNetwork,
      'hosted_banner_mode': instance.hostedBannerMode,
      'unity_game_id_android': instance.unityGameIdAndroid,
      'unity_banner_placement_id': instance.unityBannerPlacementId,
      'unity_test_mode': instance.unityTestMode,
      'startio_banner_enabled': instance.startioBannerEnabled,
      'startio_interstitial_enabled': instance.startioInterstitialEnabled,
      'startio_interstitial_interval_seconds':
          instance.startioInterstitialIntervalSeconds,
      'startio_tv_interstitial_mode': instance.startioTvInterstitialMode,
    };

_$ThemeEffectImpl _$$ThemeEffectImplFromJson(Map<String, dynamic> json) =>
    _$ThemeEffectImpl(
      enabled: json['enabled'] as bool? ?? false,
      type: json['type'] as String? ?? 'none',
      density: (json['density'] as num?)?.toInt() ?? 28,
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
      opacity: (json['opacity'] as num?)?.toDouble() ?? .65,
      colors: (json['colors'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$ThemeEffectImplToJson(_$ThemeEffectImpl instance) =>
    <String, dynamic>{
      'enabled': instance.enabled,
      'type': instance.type,
      'density': instance.density,
      'speed': instance.speed,
      'opacity': instance.opacity,
      'colors': instance.colors,
    };

_$OccasionalThemeImpl _$$OccasionalThemeImplFromJson(
        Map<String, dynamic> json) =>
    _$OccasionalThemeImpl(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      description: json['description'] as String? ?? '',
      enabled: json['enabled'] as bool,
      userSelectable: json['user_selectable'] as bool,
      priority: (json['priority'] as num).toInt(),
      primaryColor: json['primary_color'] as String,
      secondaryColor: json['secondary_color'] as String,
      tertiaryColor: json['tertiary_color'] as String,
      logoUrl: json['logo_url'] as String? ?? '',
      lightBackgroundColor: json['light_background_color'] as String?,
      darkBackgroundColor: json['dark_background_color'] as String?,
      startsAt: json['starts_at'] == null
          ? null
          : DateTime.parse(json['starts_at'] as String),
      endsAt: json['ends_at'] == null
          ? null
          : DateTime.parse(json['ends_at'] as String),
      effect: ThemeEffect.fromJson(json['effect'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$OccasionalThemeImplToJson(
        _$OccasionalThemeImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'display_name': instance.displayName,
      'description': instance.description,
      'enabled': instance.enabled,
      'user_selectable': instance.userSelectable,
      'priority': instance.priority,
      'primary_color': instance.primaryColor,
      'secondary_color': instance.secondaryColor,
      'tertiary_color': instance.tertiaryColor,
      'logo_url': instance.logoUrl,
      'light_background_color': instance.lightBackgroundColor,
      'dark_background_color': instance.darkBackgroundColor,
      'starts_at': instance.startsAt?.toIso8601String(),
      'ends_at': instance.endsAt?.toIso8601String(),
      'effect': instance.effect.toJson(),
    };

_$OccasionalThemeCatalogImpl _$$OccasionalThemeCatalogImplFromJson(
        Map<String, dynamic> json) =>
    _$OccasionalThemeCatalogImpl(
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 2,
      enabled: json['enabled'] as bool? ?? false,
      allowUserSelection: json['allow_user_selection'] as bool? ?? false,
      effectsEnabled: json['effects_enabled'] as bool? ?? true,
      allowUserEffectsToggle:
          json['allow_user_effects_toggle'] as bool? ?? false,
      defaultThemeId: json['default_theme_id'] as String? ?? '',
      activeThemeId: json['active_theme_id'] as String? ?? '',
      themes: (json['themes'] as List<dynamic>?)
              ?.map((e) => OccasionalTheme.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$OccasionalThemeCatalogImplToJson(
        _$OccasionalThemeCatalogImpl instance) =>
    <String, dynamic>{
      'schema_version': instance.schemaVersion,
      'enabled': instance.enabled,
      'allow_user_selection': instance.allowUserSelection,
      'effects_enabled': instance.effectsEnabled,
      'allow_user_effects_toggle': instance.allowUserEffectsToggle,
      'default_theme_id': instance.defaultThemeId,
      'active_theme_id': instance.activeThemeId,
      'themes': instance.themes.map((e) => e.toJson()).toList(),
    };

_$BannerDisplayConfigImpl _$$BannerDisplayConfigImplFromJson(
        Map<String, dynamic> json) =>
    _$BannerDisplayConfigImpl(
      key: json['key'] as String,
      enabled: json['enabled'] as bool? ?? true,
      placements: (json['placements'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      shape: json['shape'] as String?,
      width: (json['width'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      aspectRatio: (json['aspectRatio'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$$BannerDisplayConfigImplToJson(
        _$BannerDisplayConfigImpl instance) =>
    <String, dynamic>{
      'key': instance.key,
      'enabled': instance.enabled,
      'placements': instance.placements,
      'shape': instance.shape,
      'width': instance.width,
      'height': instance.height,
      'aspectRatio': instance.aspectRatio,
    };

_$BootstrapConfigImpl _$$BootstrapConfigImplFromJson(
        Map<String, dynamic> json) =>
    _$BootstrapConfigImpl(
      features: json['features'] == null
          ? const FeaturesConfig()
          : FeaturesConfig.fromJson(json['features'] as Map<String, dynamic>),
      branding: json['branding'] == null
          ? const BrandingConfig()
          : BrandingConfig.fromJson(json['branding'] as Map<String, dynamic>),
      updates: json['updates'] == null
          ? const UpdateConfig()
          : UpdateConfig.fromJson(json['updates'] as Map<String, dynamic>),
      network: json['network'] == null
          ? const NetworkConfig()
          : NetworkConfig.fromJson(json['network'] as Map<String, dynamic>),
      ads: json['ads'] == null
          ? const AdsConfig()
          : AdsConfig.fromJson(json['ads'] as Map<String, dynamic>),
      banners: (json['banners'] as List<dynamic>?)
              ?.map((e) =>
                  BannerDisplayConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      occasionalTheme: json['occasional_theme'] == null
          ? const OccasionalThemeCatalog()
          : OccasionalThemeCatalog.fromJson(
              json['occasional_theme'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$BootstrapConfigImplToJson(
        _$BootstrapConfigImpl instance) =>
    <String, dynamic>{
      'features': instance.features.toJson(),
      'branding': instance.branding.toJson(),
      'updates': instance.updates.toJson(),
      'network': instance.network.toJson(),
      'ads': instance.ads.toJson(),
      'banners': instance.banners.map((e) => e.toJson()).toList(),
      'occasional_theme': instance.occasionalTheme.toJson(),
    };
