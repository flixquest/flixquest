import 'package:flutter_downloader/flutter_downloader.dart';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'constants/app_constants.dart';
import 'flixquest_main.dart';
import 'models/translation.dart';
import 'provider/app_dependency_provider.dart';
import 'provider/bookmark_provider.dart';
import 'provider/playlist_provider.dart';
import 'provider/recently_watched_provider.dart';
import 'provider/settings_provider.dart';
import 'provider/wellness_provider.dart';
import 'services/device_presentation_service.dart';
import 'services/home_widget_navigation_service.dart';
import 'services/media_link_navigation_service.dart';
import 'singleton/sharedpreferences_singleton.dart';
import 'tv/platform/device_presentation.dart';
import 'tv/platform/device_presentation_detector.dart';

bool isTablet(BuildContext context) => MediaQuery.sizeOf(context).width > 1000;
final settingsProvider = SettingsProvider();
final recentProvider = RecentProvider();
final bookmarkProvider = BookmarkProvider();
final playlistProvider = PlaylistProvider();
final appDependencyProvider = AppDependencyProvider();
final wellnessProvider = WellnessProvider.instance;

Future<DevicePresentation> appInitialize({
  DevicePresentationDetector? devicePresentationDetector,
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Let Flutter paint behind Android's transparent gesture-navigation area.
  // Individual surfaces remain responsible for applying SafeArea padding to
  // interactive content.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final devicePresentation = await resolveDevicePresentation(
    detector: devicePresentationDetector,
  );

  // Initialize MediaKit for video playback with multiple codec support
  // MediaKit.ensureInitialized();

  // Reset orientation to all orientations on app start
  // This is CRITICAL for handling ungraceful app termination (force-close, system kill)
  // When the app is killed while streaming in landscape mode, this ensures
  // orientation is reset on next app launch since dispose() never gets called
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Android 7.0 predates ISRG Root X1, which anchors the API's certificate.
  try {
    final root = await rootBundle.load('assets/ca/isrg-root-x1.pem');
    SecurityContext.defaultContext
        .setTrustedCertificatesBytes(root.buffer.asUint8List());
  } catch (_) {/* The platform already trusts it. */}
  await FlutterDownloader.initialize(debug: false);
  await EasyLocalization.ensureInitialized();
  // Seed the shared version with the installed build so any synchronous reader
  // matches the binary instead of a hardcoded string that drifts.
  currentAppVersion = (await PackageInfo.fromPlatform()).version;
  sharedPrefsSingleton = await SharedPreferencesSingleton.getInstance();
  await settingsProvider.getCurrentAppMode();
  DevicePresentationService.instance.isTelevision =
      settingsProvider.appMode.resolve(devicePresentation) ==
          DevicePresentation.television;

  await settingsProvider.getCurrentThemeMode();
  await settingsProvider.getCurrentMaterial3Mode();
  await settingsProvider.initMixpanel();
  await settingsProvider.getCurrentAdultMode();
  await settingsProvider.getCurrentDefaultScreen();
  await settingsProvider.getCurrentImageQuality();
  await settingsProvider.getCurrentWatchCountry();
  await settingsProvider.getSeekDuration();
  await settingsProvider.getHoldSpeeds();
  await settingsProvider.getMaxBufferDuration();
  await settingsProvider.getVideoResolution();
  await settingsProvider.getSubtitleLanguage();
  await settingsProvider.getSubtitleMode();
  await settingsProvider.getViewMode();
  await settingsProvider.getSubtitleSize();
  await settingsProvider.getForegroundSubtitleColor();
  await settingsProvider.getBackgroundSubtitleColor();
  await settingsProvider.getAppLanguage();
  await settingsProvider.getAppColorIndex();
  await settingsProvider.getCustomAppColor();
  await settingsProvider.getPlayerTimeStyle();
  await settingsProvider.getUseProxyMode();
  await settingsProvider.getSubtitleStyle();
  await settingsProvider.getEnableNextEpisodeButton();
  await settingsProvider.getIntroDbSettings();
  await settingsProvider.getPlayerAmbientGlowEnabled();
  await settingsProvider.getAutoPipOnLeave();
  await settingsProvider.getStreamingDnd();
  await settingsProvider.getAutoLoadSources();
  settingsProvider.completeHydration();
  await recentProvider.fetchMovies();
  await recentProvider.fetchEpisodes();
  await bookmarkProvider.fetchBookmarks();
  await wellnessProvider.initialize();
  await appDependencyProvider.getFlixQuestLogo();
  await appDependencyProvider.getOccasionalTheme(preserveSelection: true);
  await appDependencyProvider.getAmbientMode();
  await appDependencyProvider.getTmdbProxy();
  await appDependencyProvider.getUpdateConfiguration();

  return devicePresentation;
}

Future<void> main() async {
  final presentation = await appInitialize();
  await playlistProvider.load();
  HomeWidgetNavigationService.configure(
      source: () => (
            language: settingsProvider.appLanguage,
            useProxy: settingsProvider.enableProxy,
            proxy: appDependencyProvider.tmdbProxy,
          ));
  await MediaLinkNavigationService.initialize();
  runApp(ChangeNotifierProvider<PlaylistProvider>.value(
    value: playlistProvider,
    child: EasyLocalization(
      supportedLocales: Translation.all,
      path: 'assets/translations',
      fallbackLocale: Translation.all[0],
      startLocale: Locale(settingsProvider.appLanguage),
      child: FlixQuest(
        settingsProvider: settingsProvider,
        recentProvider: recentProvider,
        bookmarkProvider: bookmarkProvider,
        appDependencyProvider: appDependencyProvider,
        devicePresentation: presentation,
      ),
    ),
  ));
}
