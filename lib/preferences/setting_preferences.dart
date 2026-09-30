// ignore_for_file: constant_identifier_names
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/models/default_home.dart';

class SettingsPreferences {
  static const ADULT_MODE_STATUS = 'adultStatus-v2';

  setAdultMode(bool value) async {
    sharedPrefsSingleton.setBool(ADULT_MODE_STATUS, value);
  }

  Future<bool> getAdultMode() async {
    return sharedPrefsSingleton.getBool(ADULT_MODE_STATUS) ?? false;
  }

  static const COUNTRY_STATUS = 'US';

  setCountryName(String countryName) async {
    sharedPrefsSingleton.setString(COUNTRY_STATUS, countryName);
  }

  Future<String> getCountryName() async {
    return sharedPrefsSingleton.getString(COUNTRY_STATUS) ?? 'US';
  }

  setDefaultHome(DefaultHome value) async {
    await value.save(sharedPrefsSingleton);
  }

  Future<DefaultHome> getDefaultHome() async =>
      DefaultHome.load(sharedPrefsSingleton);

  static const IMAGE_QUALITY_STATUS = 'w500/';
  setImageQuality(String imageQuality) async {
    sharedPrefsSingleton.setString(IMAGE_QUALITY_STATUS, imageQuality);
  }

  Future<String> getImageQuality() async {
    return sharedPrefsSingleton.getString(IMAGE_QUALITY_STATUS) ?? 'w500/';
  }

  static const MATERIAL3_MODE_STATUS = 'materialStatus';

  setMaterial3Mode(bool value) async {
    sharedPrefsSingleton.setBool(MATERIAL3_MODE_STATUS, value);
  }

  Future<bool> getMaterial3Mode() async {
    return sharedPrefsSingleton.getBool(MATERIAL3_MODE_STATUS) ?? false;
  }

  static const THEME_MODE_STATUS = 'themeStatusV2';

  setThemeMode(String value) async {
    sharedPrefsSingleton.setString(THEME_MODE_STATUS, value);
  }

  Future<String> getThemeMode() async {
    return sharedPrefsSingleton.getString(THEME_MODE_STATUS) ?? 'amoled';
  }

  static const SEEK_PREFERENCE = 'seek';
  setSeekDuration(int seekDuration) async {
    sharedPrefsSingleton.setInt(SEEK_PREFERENCE, seekDuration);
  }

  Future<int> getSeekDuraion() async {
    return sharedPrefsSingleton.getInt(SEEK_PREFERENCE) ?? 10;
  }

  // static const MIN_BUFFER_PREFERENCE = 'min_buffer';
  // setMinBufferDuration(int bufferDuration) async {
  //
  //   sharedPrefsSingleton.setInt(MIN_BUFFER_PREFERENCE, bufferDuration);
  // }

  // Future<int> getMinBuffer() async {
  //
  //   return sharedPrefsSingleton.getInt(MIN_BUFFER_PREFERENCE) ?? 120000;
  // }

  static const MAX_BUFFER_PREFERENCE = 'max_buffer';
  setMaxBufferDuration(int bufferDuration) async {
    sharedPrefsSingleton.setInt(MAX_BUFFER_PREFERENCE, bufferDuration);
  }

  Future<int> getMaxBuffer() async {
    return (sharedPrefsSingleton.getInt(MAX_BUFFER_PREFERENCE) ?? 120000)
        .clamp(15000, 180000);
  }

  static const DEFAULT_VIDEO_QUALITY = 'video_quality';
  setDefaultVideoQuality(int videoQuality) async {
    sharedPrefsSingleton.setInt(DEFAULT_VIDEO_QUALITY, videoQuality);
  }

  Future<int> getDefaultVideoQuality() async {
    return sharedPrefsSingleton.getInt(DEFAULT_VIDEO_QUALITY) ?? 0;
  }

  static const DEFAULT_SUBTITLE = 'default_subtitle_v2';
  setDefaultSubtitle(String language) async {
    sharedPrefsSingleton.setString(DEFAULT_SUBTITLE, language);
  }

  Future<String> getSubLanguage() async {
    return sharedPrefsSingleton.getString(DEFAULT_SUBTITLE) ?? 'en';
  }

  static const DEFAULT_FULL_SCREEN = 'default_full_screen';
  setDefaultFullScreen(bool mode) async {
    sharedPrefsSingleton.setBool(DEFAULT_FULL_SCREEN, mode);
  }

  Future<bool> autoFullScreen() async {
    return sharedPrefsSingleton.getBool(DEFAULT_FULL_SCREEN) ?? true;
  }

  static const SUBTITLE_FOREGROUND_COLOR = 'subtitle_foreground_color';
  setSubtitleForeground(String color) async {
    sharedPrefsSingleton.setString(SUBTITLE_FOREGROUND_COLOR, color);
  }

  Future<String> subtitleForeground() async {
    return sharedPrefsSingleton.getString(SUBTITLE_FOREGROUND_COLOR) ??
        'Color(0xffffffff)';
  }

  static const SUBTITLE_BACKGROUND_COLOR = 'subtitle_background_color';
  setSubtitleBackground(String color) async {
    sharedPrefsSingleton.setString(SUBTITLE_BACKGROUND_COLOR, color);
  }

  Future<String> subtitleBackground() async {
    return sharedPrefsSingleton.getString(SUBTITLE_BACKGROUND_COLOR) ??
        'Color(0x73000000)';
  }

  static const SUBTITLE_FONT_SIZE = 'subtitle_font_size';
  setSubtitleFont(int size) async {
    sharedPrefsSingleton.setInt(SUBTITLE_FONT_SIZE, size);
  }

  Future<int> subtitleFont() async {
    return sharedPrefsSingleton.getInt(SUBTITLE_FONT_SIZE) ?? 17;
  }

  static const SUBTITLE_MODE = 'subtitle_mode';
  setSubtitleMode(bool mode) async {
    sharedPrefsSingleton.setBool(SUBTITLE_MODE, mode);
  }

  Future<bool> getSubtitleMode() async {
    return sharedPrefsSingleton.getBool(SUBTITLE_MODE) ?? false;
  }

  static const APP_LANGUAGE_CODE = 'en';

  setAppLanguage(String lang) async {
    sharedPrefsSingleton.setString(APP_LANGUAGE_CODE, lang);
  }

  Future<String> getAppLang() async {
    return sharedPrefsSingleton.getString(APP_LANGUAGE_CODE) ?? 'en';
  }

  static const APP_COLOR_INDEX = 'appColorIndex';

  setAppColorIndex(int index) async {
    sharedPrefsSingleton.setInt(APP_COLOR_INDEX, index);
  }

  Future<int> getAppColorIndex() async {
    return sharedPrefsSingleton.getInt(APP_COLOR_INDEX) ?? -1;
  }

  static const APP_CUSTOM_COLOR = 'appCustomColor';

  setAppCustomColor(int value) async {
    sharedPrefsSingleton.setInt(APP_CUSTOM_COLOR, value);
  }

  Future<int?> getAppCustomColor() async {
    return sharedPrefsSingleton.getInt(APP_CUSTOM_COLOR);
  }

  static const STREAM_PROVIDER_ORDER = 'stream_provider_order_v1';
  static const _LEGACY_PROVIDER_PRECEDENCE = 'providerPrecedence-v14';

  Future<void> setStreamProviderOrder(List<String> providerCodes) async {
    await sharedPrefsSingleton.setStringList(
      STREAM_PROVIDER_ORDER,
      providerCodes,
    );
  }

  Future<List<String>> getStreamProviderOrder() async {
    final saved = sharedPrefsSingleton.getStringList(STREAM_PROVIDER_ORDER);
    if (saved != null) return _uniqueNonEmpty(saved);

    // Preserve the former static-provider preference on upgrade. Old entries
    // were stored as "code-displayName" tokens, while dynamic providers use
    // namespaced stable codes.
    final legacy = sharedPrefsSingleton.getString(_LEGACY_PROVIDER_PRECEDENCE);
    if (legacy == null || legacy.trim().isEmpty) return const [];

    final migrated = _uniqueNonEmpty(
      legacy.trim().split(RegExp(r'\s+')).map((entry) {
        final oldCode = entry.split('-').first.trim();
        if (oldCode.isEmpty) return '';
        return oldCode == 'vixsrc' ? 'direct:vixsrc' : 'scraper:$oldCode';
      }),
    );
    await setStreamProviderOrder(migrated);
    return migrated;
  }

  List<String> _uniqueNonEmpty(Iterable<String> values) {
    final unique = <String>{};
    for (final value in values) {
      final normalized = value.trim();
      if (normalized.isNotEmpty) unique.add(normalized);
    }
    return unique.toList(growable: false);
  }

  static const PLAYER_STYLE_INDEX = 'playerStyleIndex';

  setPlayerStyleIndex(int index) async {
    sharedPrefsSingleton.setInt(PLAYER_STYLE_INDEX, index);
  }

  Future<int> getPlayerStyleIndex() async {
    return sharedPrefsSingleton.getInt(PLAYER_STYLE_INDEX) ?? 1;
  }

  static const USE_PROXY = 'use_proxy';

  setUseProxy(bool useProxy) {
    sharedPrefsSingleton.setBool(USE_PROXY, useProxy);
  }

  Future<bool> getUseProxy() async {
    return sharedPrefsSingleton.getBool(USE_PROXY) ?? false;
  }

  static const SUBTITLE_TEXT_STYLE = 'subtitle_text_style';

  setSubtitleStyle(String value) {
    sharedPrefsSingleton.setString(SUBTITLE_TEXT_STYLE, value);
  }

  Future<String> getSubtitleStyle() async {
    return sharedPrefsSingleton.getString(SUBTITLE_TEXT_STYLE) ?? 'regular';
  }

  static const ENABLE_NEXT_EPISODE_BUTTON = 'enable_next_episode_button';

  setEnableNextEpisodeButton(bool value) {
    sharedPrefsSingleton.setBool(ENABLE_NEXT_EPISODE_BUTTON, value);
  }

  Future<bool> getEnableNextEpisodeButton() async {
    return sharedPrefsSingleton.getBool(ENABLE_NEXT_EPISODE_BUTTON) ?? false;
  }

  static const ENABLE_INTRODB_SKIP_BUTTONS = 'enable_introdb_skip_buttons';

  setEnableIntroDbSkipButtons(bool value) =>
      sharedPrefsSingleton.setBool(ENABLE_INTRODB_SKIP_BUTTONS, value);

  Future<bool> getEnableIntroDbSkipButtons() async =>
      sharedPrefsSingleton.getBool(ENABLE_INTRODB_SKIP_BUTTONS) ?? true;

  static const PLAYER_AMBIENT_GLOW_ENABLED = 'player_ambient_glow_enabled';

  setPlayerAmbientGlowEnabled(bool value) {
    sharedPrefsSingleton.setBool(PLAYER_AMBIENT_GLOW_ENABLED, value);
  }

  Future<bool> getPlayerAmbientGlowEnabled() async {
    return sharedPrefsSingleton.getBool(PLAYER_AMBIENT_GLOW_ENABLED) ?? false;
  }

  static const AUTO_LOAD_SOURCES = 'auto_load_sources_v1';

  setAutoLoadSources(bool value) {
    sharedPrefsSingleton.setBool(AUTO_LOAD_SOURCES, value);
  }

  Future<bool> getAutoLoadSources() async {
    return sharedPrefsSingleton.getBool(AUTO_LOAD_SOURCES) ?? true;
  }

  static const RECENT_SEARCHES = 'recent_searches';

  Future<List<String>> getRecentSearches() async {
    return sharedPrefsSingleton.getStringList(RECENT_SEARCHES) ?? [];
  }

  Future<void> addRecentSearch(String searchTerm) async {
    List<String> searches = await getRecentSearches();

    // Remove if already exists (to move to top)
    searches.remove(searchTerm);

    // Add to beginning
    searches.insert(0, searchTerm);

    // Keep only last 10
    if (searches.length > 10) {
      searches = searches.sublist(0, 10);
    }

    await sharedPrefsSingleton.setStringList(RECENT_SEARCHES, searches);
  }

  Future<void> removeRecentSearch(String searchTerm) async {
    List<String> searches = await getRecentSearches();
    searches.remove(searchTerm);
    await sharedPrefsSingleton.setStringList(RECENT_SEARCHES, searches);
  }

  Future<void> clearRecentSearches() async {
    await sharedPrefsSingleton.setStringList(RECENT_SEARCHES, []);
  }
}
