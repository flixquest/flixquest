import 'services/local_account_data.dart';
import 'presentation/session/auth_runtime.dart';
import 'presentation/session/session_view_model.dart';
import 'services/auth_session_controller.dart';
import 'dart:async';
import 'dart:io';
import 'package:provider/provider.dart';
import 'core/di/injector.dart';
import 'core/network/network_runtime.dart';
import 'dart:ui' show PlatformDispatcher;
import 'package:flixquest/flixquest_main.dart';
import '../models/translation.dart';
import '../provider/app_dependency_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
// import 'package:media_kit/media_kit.dart';
import 'constants/app_constants.dart';
import 'functions/function.dart';
import 'provider/bookmark_provider.dart';
import 'provider/recently_watched_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'provider/settings_provider.dart';
import 'provider/wellness_provider.dart';
import 'services/bookmark_sync_service.dart';
import 'services/recently_watched_sync_service.dart';
import 'services/media_link_navigation_service.dart';
import 'services/start_io_ads_service.dart';
import 'services/home_widget_navigation_service.dart';
import 'singleton/sharedpreferences_singleton.dart';
import 'tv/platform/device_presentation.dart';
import 'tv/platform/device_presentation_detector.dart';

@pragma('vm:entry-point')
Future<void> _messageHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

bool isTablet(BuildContext context) {
  double screenWidth = MediaQuery.of(context).size.width;
  double threshold = 1000.0;
  return screenWidth > threshold;
}

SettingsProvider settingsProvider = SettingsProvider();
RecentProvider recentProvider = RecentProvider();
BookmarkProvider bookmarkProvider = BookmarkProvider();
AppDependencyProvider appDependencyProvider = AppDependencyProvider();
WellnessProvider wellnessProvider = WellnessProvider.instance;
final Future<FirebaseApp> _initialization = Firebase.initializeApp();

bool _isRecoverableImageError(FlutterErrorDetails details) {
  final context = details.context?.toString() ?? '';
  final stack = details.stack?.toString() ?? '';

  // cached_network_image reports failed downloads and evicted cache files
  // through Flutter's image error channel. These are expected per-image
  // failures and widgets already provide their own fallback content.
  return context.contains('resolving an image codec') ||
      context.contains('loading an image') ||
      stack.contains('MultiImageStreamCompleter');
}

Future<DevicePresentation> appInitialize({
  DevicePresentationDetector? devicePresentationDetector,
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Let Flutter paint behind Android's transparent gesture-navigation area.
  // Individual surfaces remain responsible for applying SafeArea padding to
  // interactive content.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Firebase-dependent services and providers must not be accessed until the
  // default app has finished initializing.
  await _initialization;

  // Surface uncaught Dart and platform errors to Crashlytics. Installed only
  // after Firebase initialization so the recorder is always ready.
  FlutterError.onError = (details) {
    if (_isRecoverableImageError(details)) return;
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: true);
    return true;
  };

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

  // ByteData data =
  //     await PlatformAssetBundle().load('assets/ca/lets-encrypt-r3.pem');
  // SecurityContext.defaultContext
  //     .setTrustedCertificatesBytes(data.buffer.asUint8List());
  await dotenv.load(fileName: '.env');
  await EasyLocalization.ensureInitialized();
  // Seed the shared version with the installed build so any synchronous reader
  // matches the binary instead of a hardcoded string that drifts.
  currentAppVersion = (await PackageInfo.fromPlatform()).version;
  sharedPrefsSingleton = await SharedPreferencesSingleton.getInstance();
  StartIoAdsService.instance
      .setTelevision(devicePresentation == DevicePresentation.television);
  await clearVideoPlaybackCache();
  FirebaseMessaging.onBackgroundMessage(_messageHandler);
  await FlutterDownloader.initialize(debug: true, ignoreSsl: true);

  await settingsProvider.getCurrentThemeMode();
  await settingsProvider.getCurrentMaterial3Mode();
  await settingsProvider.initMixpanel();
  await settingsProvider.getCurrentAdultMode();
  await settingsProvider.getCurrentDefaultScreen();
  await settingsProvider.getCurrentImageQuality();
  await settingsProvider.getCurrentWatchCountry();
  await settingsProvider.getSeekDuration();
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
  await settingsProvider.getStreamProviderOrder();
  await settingsProvider.getPlayerTimeStyle();
  await settingsProvider.getUseProxyMode();
  await settingsProvider.getSubtitleStyle();
  await settingsProvider.getEnableNextEpisodeButton();
  await settingsProvider.getIntroDbSettings();
  await settingsProvider.getPlayerAmbientGlowEnabled();
  await settingsProvider.getAutoLoadSources();
  settingsProvider.completeHydration();
  await recentProvider.fetchMovies();
  await recentProvider.fetchEpisodes();
  await bookmarkProvider.fetchBookmarks();
  await wellnessProvider.initialize();
  await appDependencyProvider.getFlixQuestLogo();
  await appDependencyProvider.getOccasionalTheme();
  await appDependencyProvider.getAmbientMode();
  await appDependencyProvider.getFQUrl();
  await appDependencyProvider.getTmdbProxy();
  await appDependencyProvider.getUpdateConfiguration();

  if (!AuthRuntime.enabled) {
    await BookmarkSyncService.instance.init();
    await RecentlyWatchedSyncService.instance.init();
  }

  return devicePresentation;
}

void main() async {
  final devicePresentation = await appInitialize();
  HttpOverrides.global = MyHttpOverrides();
  final injector = await buildInjector(deleteLocalData: (owner) async {
    await LocalAccountData.delete(owner);
    await bookmarkProvider.fetchBookmarks();
    await recentProvider.fetchMovies();
    await recentProvider.fetchEpisodes();
    await wellnessProvider.reload();
  });
  AuthRuntime.configure(injector.session, enabled: injector.migrationFlags.auth);
  if (AuthRuntime.enabled) {
    await injector.session.restore();
    AuthSessionController.instance.initialize();
    await wellnessProvider.bindLaravelOwner(injector.session.ownerId);
  }
  NetworkRuntime.configure(publicDio: injector.publicDio,
      httpCache: injector.httpCache, tmdb: injector.tmdbRepository);
  Timer.run(() => unawaited(injector.httpCache.pruneExpired().catchError((Object _) {})));
  HomeWidgetNavigationService.configure(
    source: () => (
      language: settingsProvider.appLanguage,
      useProxy: settingsProvider.enableProxy,
      proxy: appDependencyProvider.tmdbProxy,
    ),
  );
  await MediaLinkNavigationService.initialize();
  runApp(ChangeNotifierProvider<SessionViewModel>.value(value: injector.session, child: Provider<AppInjector>.value(value: injector, child: EasyLocalization(
    supportedLocales: Translation.all,
    path: 'assets/translations',
    fallbackLocale: Translation.all[0],
    startLocale: Locale(settingsProvider.appLanguage),
    child: FlixQuest(
      settingsProvider: settingsProvider,
      recentProvider: recentProvider,
      bookmarkProvider: bookmarkProvider,
      appDependencyProvider: appDependencyProvider,
      devicePresentation: devicePresentation,
    ),
  ))));
}
