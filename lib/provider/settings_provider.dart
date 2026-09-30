import 'package:flutter/material.dart';
import '../functions/subtitle_style.dart';
import '../models/default_home.dart';
import '../preferences/setting_preferences.dart';
import '../services/analytics_service.dart';
import '../video_providers/names.dart';

class SettingsProvider with ChangeNotifier {
  final SettingsPreferences _settingsPreferences = SettingsPreferences();

  bool _isAdult = false;
  bool get isAdult => _isAdult;

  bool _isMaterial3Enabled = false;
  bool get isMaterial3Enabled => _isMaterial3Enabled;

  String _appTheme = 'amoled';
  String get appTheme => _appTheme;

  DefaultHome _defaultHome = DefaultHome.home;
  DefaultHome get defaultHome => _defaultHome;

  String _imageQuality = 'w500/';
  String get imageQuality => _imageQuality;

  String _defaultCountry = 'US';
  String get defaultCountry => _defaultCountry;

  int _defaultSeekDuration = 10;
  int get defaultSeekDuration => _defaultSeekDuration;

  int _playerTimeDisplay = 1;
  int get playerTimeDisplay => _playerTimeDisplay;

  // int _defaultMinBufferDuration = 120000;
  // int get defaultMinBufferDuration => _defaultMinBufferDuration;

  int _defaultMaxBufferDuration = 120000;
  int get defaultMaxBufferDuration => _defaultMaxBufferDuration;

  int _defaultVideoResolution = 0;
  int get defaultVideoResolution => _defaultVideoResolution;

  String _defaultSubtitleLanguage = 'en';
  String get defaultSubtitleLanguage => _defaultSubtitleLanguage;

  bool _defaultViewMode = true;
  bool get defaultViewMode => _defaultViewMode;

  AnalyticsService? _analytics;
  bool _isHydrating = true;

  AnalyticsService get analytics => _analytics ?? AnalyticsService.instance;

  /// Backward-compatible accessor used during migration.
  /// Prefer [analytics] for new code.
  AnalyticsService get mixpanel => analytics;

  /// Prevent persisted values loaded at startup from being reported as user
  /// changes. Call once all settings have been hydrated.
  void completeHydration() => _isHydrating = false;

  void _trackSetting(String name, Object value) {
    if (!_isHydrating && _analytics?.isInitialized == true) {
      analytics.trackSettingsChange(
        settingName: name,
        newValue: value.toString(),
      );
    }
  }

  String _subtitleForegroundColor = serializeSubtitleColor(Colors.white);
  String get subtitleForegroundColor => _subtitleForegroundColor;

  String _subtitleBackgroundColor = serializeSubtitleColor(Colors.black45);
  String get subtitleBackgroundColor => _subtitleBackgroundColor;

  int _subtitleFontSize = 17;
  int get subtitleFontSize => _subtitleFontSize;

  String _appLanguage = 'en';
  String get appLanguage => _appLanguage;

  bool _fetchSpecificLangSubs = false;
  bool get fetchSpecificLangSubs => _fetchSpecificLangSubs;

  int _appColorIndex = -1;
  int get appColorIndex => _appColorIndex;

  int _customAppColor = 0;
  int get customAppColor => _customAppColor;

  List<String> _streamProviderOrder = const [];
  List<String> get streamProviderOrder =>
      List.unmodifiable(_streamProviderOrder);

  bool _enableProxy = false;
  bool get enableProxy => _enableProxy;

  String _subtitleTextStyle = 'regular';
  String get subtitleTextStyle => _subtitleTextStyle;

  bool _enableNextEpisodeButton = false;
  bool get enableNextEpisodeButton => _enableNextEpisodeButton;

  bool _enableIntroDbSkipButtons = true;
  bool get enableIntroDbSkipButtons => _enableIntroDbSkipButtons;

  bool _playerAmbientGlowEnabled = false;
  bool get playerAmbientGlowEnabled => _playerAmbientGlowEnabled;

  bool _autoLoadSources = true;
  bool get autoLoadSources => _autoLoadSources;

  // theme change
  Future<void> getCurrentThemeMode() async {
    appTheme = await _settingsPreferences.getThemeMode();
  }

  set appTheme(String value) {
    _appTheme = value;
    _settingsPreferences.setThemeMode(value);
    _trackSetting('App Theme', value);
    notifyListeners();
  }

  // material theme change
  Future<void> getCurrentMaterial3Mode() async {
    isMaterial3Enabled = await _settingsPreferences.getMaterial3Mode();
  }

  set isMaterial3Enabled(bool value) {
    _isMaterial3Enabled = value;
    _settingsPreferences.setMaterial3Mode(value);
    _trackSetting('Material 3', value);
    notifyListeners();
  }

  // adult preference change
  Future<void> getCurrentAdultMode() async {
    isAdult = await _settingsPreferences.getAdultMode();
  }

  set isAdult(bool value) {
    _isAdult = value;
    _settingsPreferences.setAdultMode(value);
    _trackSetting('Adult Mode', value);
    notifyListeners();
  }

  // screen preference
  Future<void> getCurrentDefaultScreen() async {
    _defaultHome = await _settingsPreferences.getDefaultHome();
    notifyListeners();
  }

  set defaultHome(DefaultHome value) {
    _defaultHome = value;
    _settingsPreferences.setDefaultHome(value);
    _trackSetting('Default Screen', value.id);
    notifyListeners();
  }

  // image preference
  Future<void> getCurrentImageQuality() async {
    imageQuality = await _settingsPreferences.getImageQuality();
  }

  set imageQuality(String value) {
    _imageQuality = value;
    _settingsPreferences.setImageQuality(value);
    _trackSetting('Image Quality', value);
    notifyListeners();
  }

  // watch country
  Future<void> getCurrentWatchCountry() async {
    defaultCountry = await _settingsPreferences.getCountryName();
  }

  set defaultCountry(String value) {
    _defaultCountry = value;
    _settingsPreferences.setCountryName(value);
    _trackSetting('Default Country', value);
    notifyListeners();
  }

  // analytics (Mixpanel)
  Future<void> initMixpanel() async {
    _analytics = await AnalyticsService.init();
    notifyListeners();
  }

  Future<void> getSeekDuration() async {
    defaultSeekDuration = await _settingsPreferences.getSeekDuraion();
  }

  set defaultSeekDuration(int value) {
    _defaultSeekDuration = value;
    _settingsPreferences.setSeekDuration(value);
    _trackSetting('Seek Duration', value);
    notifyListeners();
  }

  Future<void> getViewMode() async {
    defaultViewMode = await _settingsPreferences.autoFullScreen();
  }

  set defaultViewMode(bool value) {
    _defaultViewMode = value;
    _settingsPreferences.setDefaultFullScreen(value);
    _trackSetting('Auto Fullscreen', value);
    notifyListeners();
  }

  // Future<void> getMinBufferDuration() async {
  //   defaultMinBufferDuration = await videoPlayerPreferences.getMinBuffer();
  // }

  // set defaultMinBufferDuration(int value) {
  //   _defaultMinBufferDuration = value;
  //   videoPlayerPreferences.setMinBufferDuration(value);
  //   notifyListeners();
  // }

  Future<void> getMaxBufferDuration() async {
    defaultMaxBufferDuration = await _settingsPreferences.getMaxBuffer();
  }

  set defaultMaxBufferDuration(int value) {
    _defaultMaxBufferDuration = value.clamp(15000, 180000);
    _settingsPreferences.setMaxBufferDuration(_defaultMaxBufferDuration);
    _trackSetting('Max Buffer Duration', _defaultMaxBufferDuration);
    notifyListeners();
  }

  Future<void> getVideoResolution() async {
    defaultVideoResolution =
        await _settingsPreferences.getDefaultVideoQuality();
  }

  set defaultVideoResolution(int value) {
    _defaultVideoResolution = value;
    _settingsPreferences.setDefaultVideoQuality(value);
    _trackSetting('Default Video Resolution', value);
    notifyListeners();
  }

  Future<void> getSubtitleLanguage() async {
    defaultSubtitleLanguage = await _settingsPreferences.getSubLanguage();
  }

  set defaultSubtitleLanguage(String value) {
    _defaultSubtitleLanguage = value;
    _settingsPreferences.setDefaultSubtitle(value);
    _trackSetting('Subtitle Language', value);
    notifyListeners();
  }

  Future<void> getForegroundSubtitleColor() async {
    subtitleForegroundColor = await _settingsPreferences.subtitleForeground();
  }

  set subtitleForegroundColor(String value) {
    _subtitleForegroundColor = serializeSubtitleColor(
      parseStoredSubtitleColor(value, fallback: Colors.white),
    );
    _settingsPreferences.setSubtitleForeground(_subtitleForegroundColor);
    _trackSetting('Subtitle Foreground', _subtitleForegroundColor);
    notifyListeners();
  }

  Future<void> getBackgroundSubtitleColor() async {
    subtitleBackgroundColor = await _settingsPreferences.subtitleBackground();
  }

  set subtitleBackgroundColor(String value) {
    _subtitleBackgroundColor = serializeSubtitleColor(
      parseStoredSubtitleColor(value, fallback: Colors.black45),
    );
    _settingsPreferences.setSubtitleBackground(_subtitleBackgroundColor);
    _trackSetting('Subtitle Background', _subtitleBackgroundColor);
    notifyListeners();
  }

  Future<void> getSubtitleSize() async {
    subtitleFontSize = await _settingsPreferences.subtitleFont();
  }

  set subtitleFontSize(int value) {
    _subtitleFontSize = normalizeSubtitleFontSize(value);
    _settingsPreferences.setSubtitleFont(_subtitleFontSize);
    _trackSetting('Subtitle Font Size', _subtitleFontSize);
    notifyListeners();
  }

  Future<void> getAppLanguage() async {
    appLanguage = await _settingsPreferences.getAppLang();
  }

  set appLanguage(String value) {
    _appLanguage = value;
    _settingsPreferences.setAppLanguage(value);
    _trackSetting('App Language', value);
    notifyListeners();
  }

  Future<void> getSubtitleMode() async {
    fetchSpecificLangSubs = await _settingsPreferences.getSubtitleMode();
  }

  set fetchSpecificLangSubs(bool value) {
    _fetchSpecificLangSubs = value;
    _settingsPreferences.setSubtitleMode(value);
    _trackSetting('Specific Subtitle Language', value);
    notifyListeners();
  }

  Future<void> getAppColorIndex() async {
    appColorIndex = await _settingsPreferences.getAppColorIndex();
  }

  set appColorIndex(int value) {
    _appColorIndex = value;
    _settingsPreferences.setAppColorIndex(value);
    _trackSetting('App Color', value);
    notifyListeners();
  }

  Future<void> getCustomAppColor() async {
    final stored = await _settingsPreferences.getAppCustomColor();
    if (stored != null) {
      _customAppColor = stored;
    }
  }

  set customAppColor(int value) {
    _customAppColor = value;
    _settingsPreferences.setAppCustomColor(value);
    _trackSetting('Custom App Color', value.toRadixString(16));
    notifyListeners();
  }

  Future<void> getStreamProviderOrder() async {
    _streamProviderOrder = await _settingsPreferences.getStreamProviderOrder();
  }

  List<VideoProvider> orderStreamProviders(
    Iterable<VideoProvider> availableProviders,
  ) {
    return VideoProviderOrder.apply(
      availableProviders,
      _streamProviderOrder,
    );
  }

  void setStreamProviderOrder(Iterable<VideoProvider> providers) {
    final codes = <String>{};
    for (final provider in providers) {
      codes.add(provider.codeName);
    }
    final value = codes.toList(growable: false);
    if (_sameOrder(_streamProviderOrder, value)) return;
    _streamProviderOrder = value;
    _settingsPreferences.setStreamProviderOrder(value);
    _trackSetting('Stream Provider Order', value.join(','));
    notifyListeners();
  }

  bool _sameOrder(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  Future<void> getPlayerTimeStyle() async {
    playerTimeDisplay = await _settingsPreferences.getPlayerStyleIndex();
  }

  set playerTimeDisplay(int value) {
    _playerTimeDisplay = value;
    _settingsPreferences.setPlayerStyleIndex(value);
    _trackSetting('Player Time Display', value);
    notifyListeners();
  }

  Future<void> getUseProxyMode() async {
    enableProxy = await _settingsPreferences.getUseProxy();
  }

  set enableProxy(bool value) {
    _enableProxy = value;
    _settingsPreferences.setUseProxy(value);
    _trackSetting('Proxy Mode', value);
    notifyListeners();
  }

  Future<void> getSubtitleStyle() async {
    subtitleTextStyle = await _settingsPreferences.getSubtitleStyle();
  }

  set subtitleTextStyle(String value) {
    _subtitleTextStyle = normalizeSubtitleTextStyle(value);
    _settingsPreferences.setSubtitleStyle(_subtitleTextStyle);
    _trackSetting('Subtitle Text Style', _subtitleTextStyle);
    notifyListeners();
  }

  Future<void> getEnableNextEpisodeButton() async {
    enableNextEpisodeButton =
        await _settingsPreferences.getEnableNextEpisodeButton();
  }

  set enableNextEpisodeButton(bool value) {
    _enableNextEpisodeButton = value;
    _settingsPreferences.setEnableNextEpisodeButton(value);
    _trackSetting('Next Episode Button', value);
    notifyListeners();
  }

  Future<void> getIntroDbSettings() async {
    enableIntroDbSkipButtons =
        await _settingsPreferences.getEnableIntroDbSkipButtons();
  }

  set enableIntroDbSkipButtons(bool value) {
    _enableIntroDbSkipButtons = value;
    _settingsPreferences.setEnableIntroDbSkipButtons(value);
    _trackSetting('IntroDB Skip Buttons', value);
    notifyListeners();
  }

  Future<void> getPlayerAmbientGlowEnabled() async {
    playerAmbientGlowEnabled =
        await _settingsPreferences.getPlayerAmbientGlowEnabled();
  }

  set playerAmbientGlowEnabled(bool value) {
    if (_playerAmbientGlowEnabled == value) return;
    _playerAmbientGlowEnabled = value;
    _settingsPreferences.setPlayerAmbientGlowEnabled(value);
    _trackSetting('Player Ambient Glow', value);
    notifyListeners();
  }

  Future<void> getAutoLoadSources() async {
    autoLoadSources = await _settingsPreferences.getAutoLoadSources();
  }

  set autoLoadSources(bool value) {
    _autoLoadSources = value;
    _settingsPreferences.setAutoLoadSources(value);
    _trackSetting('Auto Load Sources', value);
    notifyListeners();
  }
}
