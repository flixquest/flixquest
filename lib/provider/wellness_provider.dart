import '../data/sync/library_scope.dart';
import '../data/sync/sync_runtime.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/wellness_database_controller.dart';
import '../models/wellness.dart';
import '../models/wellness_insights.dart';
import '../services/wellness_sync_service.dart';

class WellnessProvider extends ChangeNotifier {
  WellnessProvider._();

  static final WellnessProvider instance = WellnessProvider._();
  static const guestOwnerId = 'guest';
  static const _deviceIdKey = 'wellness.device_id.v1';

  /// Coalesces the saves a player makes in a burst (pause, background,
  /// completion and dispose can all land within seconds of each other).
  static const _urgentPushDelay = Duration(seconds: 10);
  static const _routinePushDelay = Duration(minutes: 5);

  final WellnessDatabaseController _database =
      WellnessDatabaseController.instance;
  late final WellnessSyncService _syncService;
  ValueListenable<String?>? _laravelOwner;
  Timer? _syncDebounce;
  DateTime? _pushDueAt;
  List<WellnessViewingSession> _sessions = const <WellnessViewingSession>[];
  WellnessRange _range = WellnessRange.week;
  bool _loading = true;
  bool _guestMergeDismissed = false;
  bool _hasGuestHistory = false;
  String _ownerId = guestOwnerId;
  String _deviceId = '';

  List<WellnessViewingSession> get sessions => _sessions;
  WellnessRange get range => _range;
  bool get loading => _loading;
  bool get canSync => _syncService.canSync;
  WellnessSyncService get syncService => _syncService;
  String get activeOwnerId => _ownerId;
  String get deviceId => _deviceId;
  bool get shouldOfferGuestMerge =>
      !SyncRuntime.enabled &&
      canSync &&
      _hasGuestHistory &&
      !_guestMergeDismissed;

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
    _syncService = WellnessSyncService();
    _syncService.status.addListener(_onSyncStatusChanged);
    _syncService.lastSynced.addListener(notifyListeners);
    _ownerId = guestOwnerId;
    await reload();
  }

  void _onSyncStatusChanged() {
    if (_syncService.status.value == WellnessSyncStatus.success) {
      unawaited(reload());
    } else {
      notifyListeners();
    }
  }

  Future<void> flushPending() async {
    if (_syncDebounce == null || !canSync) return;
    _syncDebounce?.cancel();
    _syncDebounce = null;
    _pushDueAt = null;
    await _syncService.pushPending();
  }

  Future<void> autoSyncIfSignedIn() => _autoSync();

  Future<void> bindLaravelOwner(ValueListenable<String?> owner) async {
    _laravelOwner?.removeListener(_onLaravelOwner);
    _laravelOwner = owner;
    owner.addListener(_onLaravelOwner);
    await _applyLaravelOwner();
  }

  void _onLaravelOwner() => unawaited(_applyLaravelOwner());

  Future<void> _applyLaravelOwner() async {
    _syncDebounce?.cancel();
    _ownerId = _laravelOwner?.value ?? guestOwnerId;
    _guestMergeDismissed = false;
    _sessions = [];
    notifyListeners();
    await reload();
    _hasGuestHistory = await _database.ownerSessionCount(guestOwnerId) > 0;
    notifyListeners();
  }

  String _newDeviceId() {
    final random = Random.secure();
    final entropy = List<int>.generate(4, (_) => random.nextInt(1 << 32))
        .map((value) => value.toRadixString(16).padLeft(8, '0'))
        .join();
    return '${DateTime.now().microsecondsSinceEpoch}-$entropy';
  }

  /// A pull the user did not ask for, skipped when this account synced
  /// within the sync runner's interval.
  Future<void> _autoSync() async {
    if (_syncService.isFresh) return;
    await syncNow();
  }

  /// Pushes after [delay], unless a push is already due sooner.
  void _schedulePush(Duration delay) {
    final dueAt = DateTime.now().add(delay);
    final pendingDueAt = _pushDueAt;
    if (_syncDebounce?.isActive == true &&
        pendingDueAt != null &&
        pendingDueAt.isBefore(dueAt)) {
      return;
    }
    _syncDebounce?.cancel();
    _pushDueAt = dueAt;
    _syncDebounce = Timer(delay, () {
      _pushDueAt = null;
      _syncDebounce = null;
      unawaited(_syncService.pushPending());
    });
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
    if (SyncRuntime.enabled &&
        tracker.libraryGeneration != null &&
        tracker.libraryGeneration != LibraryScope.generation) {
      return;
    }
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
    if (canSync && ownerAtWrite.startsWith('user:')) {
      _schedulePush(syncImmediately ? _urgentPushDelay : _routinePushDelay);
    }
  }

  Future<bool> syncNow() async {
    final success = await _syncService.syncNow();
    if (success) await reload();
    return success;
  }

  Future<void> mergeGuestHistory() async {
    if (!canSync || !_ownerId.startsWith('user:')) return;
    final owner = _ownerId;
    await SyncRuntime.coordinator!.mergeGuest(owner);
    if (owner != _ownerId) return;
    _hasGuestHistory = await _database.ownerSessionCount(guestOwnerId) > 0;
    await reload();
  }

  void dismissGuestMerge() {
    _guestMergeDismissed = true;
    notifyListeners();
  }

  Future<void> deleteSession(String id) async {
    await _database.tombstoneSession(_ownerId, id);
    await reload();
    if (canSync) _schedulePush(_urgentPushDelay);
  }

  Future<void> clearHistory() async {
    await _database.tombstoneAll(_ownerId);
    await reload();
    if (canSync) _schedulePush(_urgentPushDelay);
  }

  Future<String> exportJson() async {
    final sessions = await _database.sessionsForOwner(_ownerId);
    return WellnessDatabaseController.encodeExport(sessions);
  }

  Future<String> exportCsv() async {
    final sessions = await _database.sessionsForOwner(_ownerId);
    return WellnessDatabaseController.encodeCsv(sessions);
  }

  @override
  void dispose() {
    _syncDebounce?.cancel();
    _laravelOwner?.removeListener(_onLaravelOwner);
    _syncService.status.removeListener(_onSyncStatusChanged);
    _syncService.lastSynced.removeListener(notifyListeners);
    _syncService.dispose();
    super.dispose();
  }
}
