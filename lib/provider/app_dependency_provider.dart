import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/occasional_theme.dart';
import '../preferences/app_dependency_preferences.dart';

class AppDependencyProvider extends ChangeNotifier {
  final AppDependencies _preferences = AppDependencies();
  String _flixQuestLogo = 'default';
  String get flixQuestLogo => _flixQuestLogo;
  bool get displayWatchNowButton => false;
  bool get displayDownloadButton => false;
  bool get displayLiveTV => false;

  bool _isForcedUpdate = false;
  bool get isForcedUpdate => _isForcedUpdate;

  String _latestAppVersion = '';
  String get latestAppVersion => _latestAppVersion;

  int _latestBuildNumber = 0;
  int get latestBuildNumber => _latestBuildNumber;

  int _minimumBuildNumber = 0;
  int get minimumBuildNumber => _minimumBuildNumber;

  String _appDownloadUrl = '';
  String get appDownloadUrl => _appDownloadUrl;

  /// Split-APK links keyed by ABI; see [AppUpdateService.resolveDownloadUrl].
  Map<String, String> _abiDownloadUrls = const {};
  Map<String, String> get abiDownloadUrls => _abiDownloadUrls;

  String _changeLog = '';
  String get changeLog => _changeLog;

  String _tmdbProxy = '';
  String get tmdbProxy => _tmdbProxy;

  /// The Telegram channel Home invites people to join; null hides the invite.
  Uri? _telegramChannelUrl;
  Uri? get telegramChannelUrl => _telegramChannelUrl;

  /// Takes an `https://t.me/...` link (or a `tg:` one); anything else, empty
  /// included, turns the invite off.
  void setTelegramChannelUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    final valid = uri != null &&
        (((uri.scheme == 'https' || uri.scheme == 'http') &&
                uri.host.isNotEmpty) ||
            uri.scheme == 'tg');
    final url = valid ? uri : null;
    if (_telegramChannelUrl == url) return;
    _telegramChannelUrl = url;
    notifyListeners();
  }

  OccasionalThemeCatalog _occasionalThemeCatalog =
      const OccasionalThemeCatalog.disabled();
  String _selectedOccasionalThemeId = 'automatic';
  bool _occasionalThemeEnabled = true;
  bool _occasionalEffectsEnabled = true;
  bool _ambientModeEnabled = false;
  int _nextAmbientScopeId = 0;
  final Map<int, Color?> _ambientScopes = <int, Color?>{};
  int _nextEffectSuppressionId = 0;
  final Set<int> _effectSuppressionScopes = <int>{};
  Timer? _occasionalThemeBoundaryTimer;

  OccasionalThemeCatalog get occasionalThemeCatalog => _occasionalThemeCatalog;
  String get selectedOccasionalThemeId => _selectedOccasionalThemeId;
  bool get occasionalThemeEnabled => _occasionalThemeEnabled;
  bool get occasionalEffectsEnabled => _occasionalEffectsEnabled;
  bool get ambientModeEnabled => _ambientModeEnabled;
  Color? get activeAmbientColor {
    if (!_ambientModeEnabled || activeOccasionalTheme != null) return null;
    for (final color in _ambientScopes.values.toList().reversed) {
      if (color != null) return color;
    }
    return null;
  }

  List<OccasionalTheme> get availableOccasionalThemes =>
      _occasionalThemeCatalog.activeThemes
          .where((theme) => theme.userSelectable)
          .toList(growable: false);
  OccasionalTheme? get activeOccasionalTheme => !_occasionalThemeEnabled
      ? null
      : _occasionalThemeCatalog.resolve(
          selectedThemeId: _selectedOccasionalThemeId,
        );
  bool get shouldShowOccasionalEffects {
    final theme = activeOccasionalTheme;
    return theme != null &&
        _occasionalThemeCatalog.effectsEnabled &&
        _occasionalEffectsEnabled &&
        _effectSuppressionScopes.isEmpty &&
        theme.effect.enabled &&
        theme.effect.type != OccasionalEffectType.none;
  }

  String get effectiveLogoUrl {
    final occasionalLogo = activeOccasionalTheme?.logoUrl.trim() ?? '';
    if (occasionalLogo.isNotEmpty) return occasionalLogo;
    return _flixQuestLogo == 'default' ? '' : _flixQuestLogo.trim();
  }

  Future<void> getFlixQuestLogo() async {
    flixQuestLogo = await _preferences.getFlixQuestLogo();
  }

  set flixQuestLogo(String value) {
    final normalized = value.trim().isEmpty ? 'default' : value.trim();
    if (_flixQuestLogo == normalized) return;
    _flixQuestLogo = normalized;
    _preferences.setFlixQuestUrl(normalized);
    notifyListeners();
  }

  set isForcedUpdate(bool value) {
    _isForcedUpdate = value;
    notifyListeners();
  }

  Future<void> getUpdateConfiguration() async {
    final config = _preferences.getUpdateConfiguration();
    _isForcedUpdate = config['forced'] as bool;
    _latestAppVersion = config['latestVersion'] as String;
    _latestBuildNumber = config['latestBuild'] as int;
    _minimumBuildNumber = config['minimumBuild'] as int;
    _appDownloadUrl = config['downloadUrl'] as String;
    _abiDownloadUrls = config['abiDownloadUrls'] as Map<String, String>;
    _changeLog = config['changeLog'] as String;
    notifyListeners();
  }

  void setUpdateConfiguration({
    required bool forced,
    required String latestVersion,
    required int latestBuild,
    required int minimumBuild,
    required String downloadUrl,
    Map<String, String> abiDownloadUrls = const {},
    required String changeLog,
  }) {
    final normalizedVersion = latestVersion.trim();
    final normalizedDownloadUrl = downloadUrl.trim();
    final normalizedAbiUrls = Map<String, String>.unmodifiable({
      for (final entry in abiDownloadUrls.entries)
        if (entry.value.trim().isNotEmpty) entry.key: entry.value.trim(),
    });
    if (_isForcedUpdate == forced &&
        _latestAppVersion == normalizedVersion &&
        _latestBuildNumber == latestBuild &&
        _minimumBuildNumber == minimumBuild &&
        _appDownloadUrl == normalizedDownloadUrl &&
        mapEquals(_abiDownloadUrls, normalizedAbiUrls) &&
        _changeLog == changeLog) {
      return;
    }
    _isForcedUpdate = forced;
    _latestAppVersion = normalizedVersion;
    _latestBuildNumber = latestBuild;
    _minimumBuildNumber = minimumBuild;
    _appDownloadUrl = normalizedDownloadUrl;
    _abiDownloadUrls = normalizedAbiUrls;
    _changeLog = changeLog;
    _preferences.setUpdateConfiguration(
      forced: forced,
      latestVersion: normalizedVersion,
      latestBuild: latestBuild,
      minimumBuild: minimumBuild,
      downloadUrl: normalizedDownloadUrl,
      abiDownloadUrls: normalizedAbiUrls,
      changeLog: changeLog,
    );
    notifyListeners();
  }

  Future<void> getTmdbProxy() async {
    tmdbProxy = await _preferences.getTmdbProxy();
  }

  set tmdbProxy(String value) {
    _tmdbProxy = value;
    _preferences.setTmdbProxy(value);
    notifyListeners();
  }

  Future<void> getOccasionalTheme({bool preserveSelection = false}) async {
    _occasionalThemeCatalog = OccasionalThemeCatalog.fromJsonString(
      await _preferences.getOccasionalTheme(),
    );
    _selectedOccasionalThemeId =
        (await _preferences.getOccasionalThemeSelection()).trim().toLowerCase();
    _occasionalThemeEnabled = await _preferences.getOccasionalThemeEnabled();
    _occasionalEffectsEnabled =
        await _preferences.getOccasionalEffectsEnabled();
    if (!preserveSelection) _normalizeOccasionalThemeSelection(persist: true);
    _scheduleOccasionalThemeBoundary();
    notifyListeners();
  }

  Future<void> getAmbientMode() async {
    _ambientModeEnabled = await _preferences.getAmbientModeEnabled();
    notifyListeners();
  }

  set ambientModeEnabled(bool value) {
    if (_ambientModeEnabled == value) return;
    _ambientModeEnabled = value;
    _preferences.setAmbientModeEnabled(value);
    notifyListeners();
  }

  int pushAmbientScope() {
    final id = ++_nextAmbientScopeId;
    _ambientScopes[id] = null;
    return id;
  }

  void updateAmbientScope(int id, Color color) {
    if (!_ambientScopes.containsKey(id) || _ambientScopes[id] == color) return;
    _ambientScopes[id] = color;
    notifyListeners();
  }

  void popAmbientScope(int id) {
    if (!_ambientScopes.containsKey(id)) return;
    final wasActive = activeAmbientColor;
    _ambientScopes.remove(id);
    if (wasActive == activeAmbientColor) return;
    notifyListeners();
  }

  int suppressOccasionalEffects() {
    final id = ++_nextEffectSuppressionId;
    final wasSuppressed = _effectSuppressionScopes.isNotEmpty;
    _effectSuppressionScopes.add(id);
    if (!wasSuppressed) notifyListeners();
    return id;
  }

  void releaseOccasionalEffectsSuppression(int id) {
    if (!_effectSuppressionScopes.remove(id)) return;
    if (_effectSuppressionScopes.isEmpty) notifyListeners();
  }

  set occasionalThemeCatalog(OccasionalThemeCatalog value) =>
      applyOccasionalThemeCatalog(value);

  /// Provider switches may temporarily omit a theme the user chose. Resolve
  /// the current catalog normally while keeping that preference for its return.
  void applyOccasionalThemeCatalog(OccasionalThemeCatalog value,
      {bool preserveSelection = false}) {
    _occasionalThemeCatalog = value;
    _preferences.setOccasionalTheme(value.toJsonString());
    if (!preserveSelection) _normalizeOccasionalThemeSelection(persist: true);
    _scheduleOccasionalThemeBoundary();
    notifyListeners();
  }

  /// Applies a remotely supplied catalog only when it is structurally valid.
  /// Invalid updates leave the persisted/active catalog untouched so built-in
  /// occasion presets continue to provide the fallback experience.
  bool applyRemoteOccasionalTheme(String json) {
    final catalog = OccasionalThemeCatalog.tryFromJsonString(json);
    if (catalog == null) return false;
    occasionalThemeCatalog = catalog;
    return true;
  }

  void selectOccasionalTheme(String id) {
    final normalized = id.trim().toLowerCase();
    if (normalized != 'automatic' &&
        !availableOccasionalThemes.any((theme) => theme.id == normalized)) {
      return;
    }
    if (_selectedOccasionalThemeId == normalized) return;
    _selectedOccasionalThemeId = normalized;
    _preferences.setOccasionalThemeSelection(normalized);
    notifyListeners();
  }

  set occasionalThemeEnabled(bool value) {
    if (_occasionalThemeEnabled == value) return;
    _occasionalThemeEnabled = value;
    _preferences.setOccasionalThemeEnabled(value);
    notifyListeners();
  }

  set occasionalEffectsEnabled(bool value) {
    if (_occasionalEffectsEnabled == value) return;
    _occasionalEffectsEnabled = value;
    _preferences.setOccasionalEffectsEnabled(value);
    notifyListeners();
  }

  void _normalizeOccasionalThemeSelection({required bool persist}) {
    final valid = _selectedOccasionalThemeId == 'automatic' ||
        (_occasionalThemeCatalog.allowUserSelection &&
            availableOccasionalThemes
                .any((theme) => theme.id == _selectedOccasionalThemeId));
    if (valid) return;
    _selectedOccasionalThemeId = 'automatic';
    if (persist) {
      _preferences.setOccasionalThemeSelection('automatic');
    }
  }

  void _scheduleOccasionalThemeBoundary() {
    _occasionalThemeBoundaryTimer?.cancel();
    final now = DateTime.now().toUtc();
    DateTime? boundary;
    for (final theme in _occasionalThemeCatalog.themes) {
      if (!theme.enabled) continue;
      DateTime? candidate;
      if (theme.startsAt != null && now.isBefore(theme.startsAt!.toUtc())) {
        candidate = theme.startsAt!.toUtc();
      } else if (theme.isActiveAt(now) && theme.endsAt != null) {
        candidate = theme.endsAt!.toUtc().add(
              const Duration(milliseconds: 1),
            );
      }
      if (candidate != null &&
          (boundary == null || candidate.isBefore(boundary))) {
        boundary = candidate;
      }
    }
    if (boundary == null) return;
    _occasionalThemeBoundaryTimer = Timer(boundary.difference(now), () {
      _normalizeOccasionalThemeSelection(persist: true);
      _scheduleOccasionalThemeBoundary();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _occasionalThemeBoundaryTimer?.cancel();
    super.dispose();
  }
}
