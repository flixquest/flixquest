import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flixquest/data/models/bootstrap_config.dart';
import 'package:flixquest/services/app_remote_config.dart';

/// Firebase is a payload provider; only Laravel can authorize applying it.
abstract interface class FirebaseConfigSource {
  Stream<void> get updates;
  Future<BootstrapConfig?> refresh();
}

class SdkFirebaseConfigSource implements FirebaseConfigSource {
  SdkFirebaseConfigSource({FirebaseRemoteConfig? remote})
      : _providedRemote = remote;
  final FirebaseRemoteConfig? _providedRemote;
  FirebaseRemoteConfig get _remote =>
      _providedRemote ?? FirebaseRemoteConfig.instance;
  Future<void>? _configured;

  @override
  Stream<void> get updates => _remote.onConfigUpdated.map((_) {});

  @override
  Future<BootstrapConfig?> refresh() async {
    try {
      await (_configured ??= AppRemoteConfig.configure(_remote));
      final activated = await _remote.activate();
      var fetched = false;
      try {
        await _remote.fetchAndActivate();
        fetched = true;
      } catch (_) {
        // An activated SDK cache is still valid when the fetch is offline.
      }
      final published = {
        for (final entry in _remote.getAll().entries)
          if (entry.value.source == ValueSource.valueRemote)
            entry.key: entry.value.asString(),
      };
      if (published.isEmpty && !fetched && !activated) return null;
      return firebaseConfigSnapshot(published);
    } catch (_) {
      _configured = null;
      return null;
    }
  }
}

/// Normalize Firebase's flat keys through the same DTO as Laravel. Unpublished
/// keys use bundled defaults, including the historical enable_ott fallback.
BootstrapConfig firebaseConfigSnapshot(Map<String, dynamic> published) {
  if (published.isEmpty) return const BootstrapConfig(configSource: 'firebase');
  Map<String, dynamic> section(List<String> keys) => {
        for (final key in keys)
          if (published.containsKey(key)) key: published[key],
      };
  Object? jsonValue(String key) {
    final value = published[key];
    if (value is! String) return value;
    try {
      return jsonDecode(value);
    } catch (_) {
      if (key == 'occasional_theme') rethrow;
      return null;
    }
  }

  return BootstrapConfig.fromJson({
    'config_source': 'firebase',
    'features': section([
      'enable_stream',
      'enable_download',
      'enable_live_tv',
      'enable_ott',
    ]),
    'branding': section(['app_logo_url', 'cinemax_logo']),
    'updates': section([
      'forced_update',
      'latest_version',
      'latest_build_number',
      'min_build_number',
      'app_download_url',
      'change_log',
    ]),
    'network': section([
      'flixquest_api_instances',
      'flixquest_api_url_v2',
      'tmdb_api_key',
      'tmdb_proxy',
    ]),
    'ads': section([
      'banner_ad_network',
      'hosted_banner_mode',
      'unity_game_id_android',
      'unity_banner_placement_id',
      'unity_test_mode',
      'startio_banner_enabled',
      'startio_interstitial_enabled',
      'startio_interstitial_interval_seconds',
      'startio_tv_interstitial_mode',
    ]),
    'banners': jsonValue('banners'),
    'occasional_theme': jsonValue('occasional_theme'),
  });
}
