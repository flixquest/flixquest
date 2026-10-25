import 'controllers/wellness_database_controller.dart';
import 'presentation/session/firebase_session_bridge.dart';
import 'data/sources/legacy_firebase_session.dart';
import 'data/sources/onesignal_messaging_client.dart';
import 'data/repositories/push_message_repository.dart';
import 'presentation/notifications/push_message_controller.dart';
import 'services/google_error_reporting.dart';
import 'presentation/notifications/device_registration_controller.dart';
import 'presentation/notifications/in_app_message_controller.dart';
import 'presentation/notifications/notification_controller.dart';
import 'data/sources/push_messaging_client.dart';
import 'services/in_app_messaging_service.dart';
import 'data/sync/sync_runtime.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'data/ads/ad_events_controller.dart';
import 'services/hosted_ads_repository.dart';
import 'services/firebase_backend_config_controller.dart';
import 'presentation/config/bootstrap_view_model.dart';
import 'presentation/config/refresh_controller.dart';
import 'presentation/config/config_source_controller.dart';
import 'data/sources/firebase_config_source.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'services/local_account_data.dart';
import 'presentation/session/auth_runtime.dart';
import 'presentation/session/session_view_model.dart';
import 'presentation/billing/plus_controller.dart';
import 'services/plus_navigation.dart';
import 'services/auth_session_controller.dart';
import 'dart:async';
import 'dart:io';
import 'package:provider/provider.dart';
import 'core/config/app_environment.dart';
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
import 'provider/playlist_provider.dart';
import 'provider/recently_watched_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'provider/settings_provider.dart';
import 'provider/wellness_provider.dart';
import 'services/bookmark_sync_service.dart';
import 'services/recently_watched_sync_service.dart';
import 'services/media_link_navigation_service.dart';
import 'services/device_presentation_service.dart';
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
PlaylistProvider playlistProvider = PlaylistProvider();
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
  final reporting = GoogleErrorReporting(FirebaseCrashlytics.instance,
      ignoreFlutterError: _isRecoverableImageError);
  FlutterError.onError = reporting.flutterError;
  PlatformDispatcher.instance.onError = reporting.platformError;

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
  await dotenv.load(fileName: '.env');
  await EasyLocalization.ensureInitialized();
  // Seed the shared version with the installed build so any synchronous reader
  // matches the binary instead of a hardcoded string that drifts.
  currentAppVersion = (await PackageInfo.fromPlatform()).version;
  sharedPrefsSingleton = await SharedPreferencesSingleton.getInstance();
  await settingsProvider.getCurrentAppMode();
  DevicePresentationService.instance.isTelevision =
      settingsProvider.appMode.resolve(devicePresentation) ==
          DevicePresentation.television;
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
  await settingsProvider.getAutoPipOnLeave();
  await settingsProvider.getStreamingDnd();
  await settingsProvider.getAutoLoadSources();
  await settingsProvider.getShowSubtitlesByDefault();
  await settingsProvider.getDownloadQuality();
  settingsProvider.completeHydration();
  await recentProvider.fetchMovies();
  await recentProvider.fetchEpisodes();
  await bookmarkProvider.fetchBookmarks();
  await wellnessProvider.initialize();
  await appDependencyProvider.getFlixQuestLogo();
  await appDependencyProvider.getOccasionalTheme(preserveSelection: true);
  await appDependencyProvider.getAmbientMode();
  await appDependencyProvider.getFQUrl();
  await appDependencyProvider.getTmdbProxy();
  await appDependencyProvider.getUpdateConfiguration();

  return devicePresentation;
}

void main() async {
  final devicePresentation = await appInitialize();
  final environment = AppEnvironment.fromRuntime();
  final httpOverrides = MyHttpOverrides(
      verifiedHosts: {Uri.parse(environment.laravelApiUrl).host});
  HttpOverrides.global = httpOverrides;
  final injector = await buildInjector(
      environment: environment,
      deleteLocalData: (owner) async {
    await LocalAccountData.delete(owner);
    await bookmarkProvider.fetchBookmarks();
    await playlistProvider.load();
    await recentProvider.fetchMovies();
    await recentProvider.fetchEpisodes();
    await wellnessProvider.reload();
  });
  final backendConfig = FirebaseBackendConfigController(
    fallbackUrl: environment.laravelApiUrl,
    onUrlChanged: (url) {
      // Register the new host before any credential-bearing request can use it.
      httpOverrides.verifiedHosts.add(Uri.parse(url).host.toLowerCase());
      injector.updateLaravelApiUrl(url);
    },
  );
  unawaited(backendConfig.start());
  HostedAdsRepository.instance.configure(injector.adsRepository);
  if (injector.migrationFlags.ads) {
    // Observe each rendered frame so brief visibility interruptions reset dwell.
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  }
  final adsController = injector.migrationFlags.ads
      ? AdEventsController(injector.adsRepository)
      : null;
  ConfigLifecycle? configController;
  if (!kDebugMode || injector.migrationFlags.config) {
    final bootstrap =
        BootstrapViewModel(injector.configRepository, appDependencyProvider);
    final sourceController = ConfigSourceController(injector.configRepository,
        bootstrap, injector.kvStore, SdkFirebaseConfigSource());
    await sourceController.hydrate();
    configController = sourceController;
  }
  AuthRuntime.configure(injector.session);
  SyncRuntime.configure(injector.syncCoordinator,
      enabled: injector.migrationFlags.auth && injector.migrationFlags.sync);
  if (SyncRuntime.enabled) {
    await BookmarkSyncService.instance.init();
    await RecentlyWatchedSyncService.instance.init();
    wellnessProvider.syncService.bind();
    injector.session.ownerId.addListener(() {
      bookmarkProvider.resetForOwner();
      playlistProvider.resetForOwner();
      recentProvider.resetForOwner();
      unawaited(bookmarkProvider.fetchBookmarks());
      unawaited(playlistProvider.load());
      unawaited(recentProvider.fetchMovies());
      unawaited(recentProvider.fetchEpisodes());
    });
  }
  final firebaseSession = FirebaseSessionBridge(
    session: injector.session,
    legacy: SdkLegacyFirebaseSession(),
    preferences: injector.kvStore,
    moveLocalOwner: (from, to) async {
      await WellnessDatabaseController.instance
          .moveOwner(fromOwnerId: from, toOwnerId: to);
      await wellnessProvider.reload();
      if (SyncRuntime.enabled) {
        unawaited(injector.syncCoordinator.syncAll());
      }
    },
  );
  {
    await injector.session.restore();
    // Costs one round trip on the first launch after upgrading from 4.2.x,
    // which keeps those users out of the sign-in screen. A slow network lets
    // the app start while the exchange finishes in the background.
    await firebaseSession
        .run()
        .timeout(const Duration(seconds: 10), onTimeout: () {});
    AuthSessionController.instance.initialize();
    // Restores a paying member's cached access before the first frame, so
    // no ad flashes up while Laravel confirms it.
    await injector.plus.start();
    installPlusOffer();
    await wellnessProvider.bindLaravelOwner(injector.session.ownerId);
    if (SyncRuntime.enabled) {
      await bookmarkProvider.fetchBookmarks();
      await recentProvider.fetchMovies();
      await recentProvider.fetchEpisodes();
      unawaited(injector.syncCoordinator.syncAll());
    }
    // Read after the owner is known, so the first frame shows this account's.
    await playlistProvider.load();
  }
  NotificationController? notifications;
  if (injector.migrationFlags.notifications) {
    final platform = devicePresentation == DevicePresentation.television
        ? 'tv'
        : Platform.isIOS
            ? 'ios'
            : 'android';
    final oneSignalAppId = injector.environment.oneSignalAppId;
    if (oneSignalAppId.isNotEmpty &&
        !OneSignalMessagingClient.validAppId(oneSignalAppId)) {
      throw StateError('ONESIGNAL_APP_ID must be a valid public App ID.');
    }
    PushMessagingClient messaging = SdkPushMessagingClient();
    if (oneSignalAppId.isNotEmpty) {
      final oneSignal = OneSignalMessagingClient();
      try {
        await oneSignal
            .initialize(oneSignalAppId, platform: platform)
            .timeout(const Duration(seconds: 10));
        messaging = oneSignal;
      } catch (_) {
        await oneSignal.dispose();
        debugPrint(
            'OneSignal initialization unavailable; retry on next app launch.');
      }
    }
    final messages = InAppMessageController(injector.announcementRepository,
        injector.kvStore, InAppMessagingService.present);
    notifications = NotificationController(
      DeviceRegistrationController(injector.deviceRepository, injector.session,
          injector.kvStore, messaging,
          platform: platform,
          provider: messaging is OneSignalMessagingClient ? 'onesignal' : 'fcm',
          appVersion: currentAppVersion),
      messages,
      messaging,
      pushMessages: PushMessageController(
          PushMessageRepository(injector.laravelDio), messages,
          currentOwner: () => injector.session.accountId.value,
          currentToken: () => injector.session.token),
    );
  }
  NetworkRuntime.configure(
      publicDio: injector.publicDio,
      httpCache: injector.httpCache,
      tmdb: injector.tmdbRepository);
  Timer.run(() =>
      unawaited(injector.httpCache.pruneExpired().catchError((Object _) {})));
  HomeWidgetNavigationService.configure(
    source: () => (
      language: settingsProvider.appLanguage,
      useProxy: settingsProvider.enableProxy,
      proxy: appDependencyProvider.tmdbProxy,
    ),
  );
  await MediaLinkNavigationService.initialize();
  runApp(MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionViewModel>.value(value: injector.session),
        ChangeNotifierProvider<PlusController>.value(value: injector.plus),
        ChangeNotifierProvider<PlaylistProvider>.value(value: playlistProvider),
      ],
      child: Provider<AppInjector>.value(
          value: injector,
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
              devicePresentation: devicePresentation,
              configController: configController,
              backendConfigController: backendConfig,
              adsController: adsController,
              notifications: notifications,
              firebaseSession: firebaseSession,
            ),
          ))));
}
