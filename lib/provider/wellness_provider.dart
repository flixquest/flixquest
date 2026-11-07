import '../data/sync/library_scope.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/wellness_database_controller.dart';
import '../models/wellness.dart';
import '../models/wellness_insights.dart';

class WellnessProvider extends ChangeNotifier {
  WellnessProvider._();

  static final WellnessProvider instance = WellnessProvider._();
  static const guestOwnerId = 'guest';
  static const _deviceIdKey = 'wellness.device_id.v1';

  final WellnessDatabaseController _database =
      WellnessDatabaseController.instance;

  List<WellnessViewingSession> _sessions = const <WellnessViewingSession>[];
  WellnessRange _range = WellnessRange.week;
  bool _loading = true;

  String _ownerId = guestOwnerId;
  String _deviceId = '';

  List<WellnessViewingSession> get sessions => _sessions;
  WellnessRange get range => _range;
  bool get loading => _loading;

  String get activeOwnerId => _ownerId;
  String get deviceId => _deviceId;

  WellnessInsights get insights => WellnessInsights.fromSessions(
        _sessions,
        period: WellnessPeriod.forRange(_range, DateTime.now()),
      );

  WellnessInsights get previousInsights => WellnessInsights.fromSessions(
        _sessions,
        period: WellnessPeriod.forRange(_range, DateTime.now()).previous(),
      );

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString(_deviceIdKey) ?? _newDeviceId();
    await prefs.setString(_deviceIdKey, _deviceId);
    _ownerId = guestOwnerId;
    await reload();
  }

  String _newDeviceId() {
    final random = Random.secure();
    final entropy = List<int>.generate(4, (_) => random.nextInt(1 << 32))
        .map((value) => value.toRadixString(16).padLeft(8, '0'))
        .join();
    return '${DateTime.now().microsecondsSinceEpoch}-$entropy';
  }

  Future<void> reload() async {
    _loading = true;
    notifyListeners();
    final owner = _ownerId;
    final sessions = await _database.sessionsForOwner(owner);
    if (owner != _ownerId) return;
    _sessions = sessions;
    _loading = false;
    notifyListeners();
  }

  void setRange(WellnessRange range) {
    if (_range == range) return;
    _range = range;
    notifyListeners();
  }

  Future<void> recordPlayback({
    required String sessionId,
    required WellnessPlaybackTracker tracker,
    required WellnessMediaType mediaType,
    required WellnessPlaybackSource source,
    required String contentId,
    required String title,
    required int durationMs,
    required int progressEndMs,
    required bool completed,
    String? seriesId,
    String? subtitle,
    int? seasonNumber,
    int? episodeNumber,
    String? posterPath,
    String? backdropPath,
    int? releaseYear,
    String? provider,
    List<String> genres = const <String>[],
    List<String> languages = const <String>[],
    List<String> countries = const <String>[],
    int? networkBytes,
    bool syncImmediately = false,
  }) async {
    final now = DateTime.now();
    final segments = tracker.snapshot(now);
    final watchedMs = segments.fold<int>(
      0,
      (total, segment) => total + segment.watchedMs,
    );
    if (watchedMs < const Duration(seconds: 30).inMilliseconds) return;
    final ownerAtWrite = _ownerId;
    final session = WellnessViewingSession(
      id: sessionId,
      ownerId: ownerAtWrite,
      deviceId: _deviceId,
      mediaType: mediaType,
      source: source,
      contentId: contentId,
      seriesId: seriesId,
      title: title,
      subtitle: subtitle,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      startedAtUtc: tracker.createdAtUtc,
      endedAtUtc: now.toUtc(),
      timezoneOffsetMinutes: now.timeZoneOffset.inMinutes,
      watchedMs: watchedMs,
      durationMs: durationMs,
      progressEndMs: progressEndMs,
      completed:
          completed || (durationMs > 0 && progressEndMs / durationMs >= 0.85),
      segments: segments,
      posterPath: posterPath,
      backdropPath: backdropPath,
      releaseYear: releaseYear,
      provider: provider,
      genres: genres,
      languages: languages,
      countries: countries,
      networkBytes: networkBytes,
      updatedAtUtc: DateTime.fromMillisecondsSinceEpoch(LibraryScope.nowUtcMs(),
          isUtc: true),
      synced: false,
    );
    await _database.upsertSession(session);
    if (ownerAtWrite == _ownerId) {
      _sessions = await _database.sessionsForOwner(_ownerId);
      notifyListeners();
    }
  }

  Future<void> deleteSession(String id) async {
    await _database.tombstoneSession(_ownerId, id);
    await reload();
  }

  Future<void> clearHistory() async {
    await _database.tombstoneAll(_ownerId);
    await reload();
  }

  Future<String> exportJson() async {
    final sessions = await _database.sessionsForOwner(_ownerId);
    return WellnessDatabaseController.encodeExport(sessions);
  }

  Future<String> exportCsv() async {
    final sessions = await _database.sessionsForOwner(_ownerId);
    return WellnessDatabaseController.encodeCsv(sessions);
  }
}
