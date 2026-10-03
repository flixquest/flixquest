import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flixquest/core/cache/cache_policy.dart';
import 'package:flixquest/core/storage/kv_store.dart';
import 'package:flixquest/preferences/app_dependency_preferences.dart';
import '../models/bootstrap_config.dart';

/// Owns the bootstrap snapshot and its validator across process restarts.
/// HTTP caching is bypassed so a persisted payload always matches its ETag.
class ConfigRepository {
  ConfigRepository(this._dio, this._store, {DateTime Function()? now})
      : _now = now ?? DateTime.now;
  final Dio _dio;
  final KvStore _store;
  final DateTime Function() _now;
  final AppDependencies _legacy = AppDependencies();
  static const _snapshotKey = 'config.bootstrap.snapshot';
  static const _etagKey = 'config.bootstrap.etag';

  Map<String, dynamic>? _snapshot() {
    final value = _store.getJson(_snapshotKey);
    if (value is! Map<String, dynamic> ||
        value['data'] is! Map<String, dynamic>) {
      return null;
    }
    try {
      BootstrapConfig.fromJson(value['data'] as Map<String, dynamic>);
      return value;
    } catch (_) {
      return null;
    }
  }

  DateTime? get lastValidatedAt {
    final time = _snapshot()?['validated_at'];
    return time is String ? DateTime.tryParse(time)?.toUtc() : null;
  }

  Future<BootstrapConfig> loadCached() async {
    final snapshot = _snapshot();
    if (snapshot != null) {
      return BootstrapConfig.fromJson(snapshot['data'] as Map<String, dynamic>);
    }
    // First cutover can be offline before Laravel has ever returned a payload.
    final update = _legacy.getUpdateConfiguration();
    final theme = await _legacy.getOccasionalTheme();
    Map<String, dynamic>? catalog;
    try {
      final decoded = jsonDecode(theme);
      if (decoded is Map<String, dynamic>) {
        catalog = OccasionalThemeCatalog.fromJson(decoded).toJson();
      }
    } catch (_) {/* Safe disabled theme if the legacy cache is malformed. */}
    return BootstrapConfig.fromJson({
      'branding': {'app_logo_url': await _legacy.getFlixQuestLogo()},
      'network': {
        'flixquest_api_instances': await _legacy.getFQInstances(),
        'flixquest_api_url_v2': await _legacy.getFQURL(),
        'tmdb_proxy': await _legacy.getTmdbProxy(),
      },
      'updates': {
        'forced_update': update['forced'],
        'latest_version': update['latestVersion'],
        'latest_build_number': update['latestBuild'],
        'min_build_number': update['minimumBuild'],
        'app_download_url': update['downloadUrl'],
        'change_log': update['changeLog'],
      },
      if (catalog != null) 'occasional_theme': catalog,
    });
  }

  Future<BootstrapConfig> refresh() async {
    final snapshot = _snapshot();
    final etag = snapshot?['etag'];
    try {
      var response = await _fetch(etag is String ? etag : null);
      if (response.statusCode == 304 && snapshot == null) {
        response = await _fetch(null);
      }
      if (response.statusCode == 304 && snapshot != null) {
        await _store.setJson(_snapshotKey,
            {...snapshot, 'validated_at': _now().toUtc().toIso8601String()});
        return BootstrapConfig.fromJson(
            snapshot['data'] as Map<String, dynamic>);
      }
      final envelope = response.data;
      if (response.statusCode != 200 ||
          envelope is! Map<String, dynamic> ||
          envelope['success'] != true ||
          envelope['data'] is! Map<String, dynamic>) {
        throw const FormatException('Invalid bootstrap response');
      }
      final data =
          Map<String, dynamic>.from(envelope['data'] as Map<String, dynamic>);
      if (data.containsKey('occasional_theme')) {
        try {
          final theme = data['occasional_theme'];
          if (theme is! Map<String, dynamic>) {
            throw const FormatException('Invalid catalog');
          }
          OccasionalThemeCatalog.fromJson(theme);
        } catch (_) {
          data['occasional_theme'] =
              (await loadCached()).occasionalTheme.toJson();
        }
      }
      final config = BootstrapConfig.fromJson(data);
      final validator = response.headers.value('etag');
      await _store.setJson(_snapshotKey, {
        'data': data,
        'etag': validator,
        'validated_at': _now().toUtc().toIso8601String(),
      });
      if (validator == null) {
        await _store.remove(_etagKey);
      } else {
        await _store.setString(_etagKey, validator);
      }
      await _persistLegacy(config, data);
      return config;
    } catch (_) {
      return loadCached();
    }
  }

  Future<Response<dynamic>> _fetch(String? etag) => _dio.get<dynamic>(
        'config/bootstrap',
        options: Options(
          headers: {
            if (etag != null) 'If-None-Match': etag,
            'Cache-Control': 'no-cache'
          },
          validateStatus: (status) => status == 200 || status == 304,
          extra: {'authRequired': false, 'cachePolicy': CachePolicy.noStore},
        ),
      );

  Future<void> _persistLegacy(
      BootstrapConfig config, Map<String, dynamic> raw) async {
    final logo = config.branding.appLogoUrl.trim();
    await _legacy
        .setFlixQuestUrl(logo.isNotEmpty ? logo : config.branding.cinemaxLogo);
    await _legacy
        .setFlixquestAPIInstances(config.network.flixquestApiInstances);
    await _legacy.setFlixquestAPIUrl(config.network.flixquestApiUrlV2);
    await _legacy.setTmdbProxy(config.network.tmdbProxy);
    await _legacy.setOccasionalTheme(
        jsonEncode(raw['occasional_theme'] ?? {'enabled': false}));
    await _legacy.setUpdateConfiguration(
      forced: config.updates.forcedUpdate,
      latestVersion: config.updates.latestVersion,
      latestBuild: config.updates.latestBuildNumber,
      minimumBuild: config.updates.minBuildNumber,
      downloadUrl: config.updates.appDownloadUrl,
      changeLog: config.updates.changeLog,
    );
  }
}
