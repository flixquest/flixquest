import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flixquest/models/app_colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'constants/theme_data.dart';
import 'functions/function.dart';
import 'provider/app_dependency_provider.dart';
import 'provider/recently_watched_provider.dart';
import 'provider/settings_provider.dart';
import 'screens/user/user_state.dart';
import 'widgets/occasional_effect_overlay.dart';
import 'widgets/app_presentation.dart';
import 'provider/bookmark_provider.dart';
import 'provider/offline_download_provider.dart';
import 'provider/wellness_provider.dart';
import 'services/in_app_messaging_service.dart';
import 'services/deep_link_dispatcher.dart';
import 'services/home_widget_service.dart';
import 'services/recently_watched_sync_service.dart';
import 'services/app_remote_config.dart';
import 'mobile/app/mobile_shell.dart';
import 'tv/platform/device_presentation.dart';
import 'tv/navigation/tv_back_key_guard.dart';
import 'tv/widgets/tv_update_gate.dart';

class FlixQuest extends StatefulWidget {
  const FlixQuest(
      {required this.settingsProvider,
      required this.recentProvider,
      required this.bookmarkProvider,
      required this.appDependencyProvider,
      required this.devicePresentation,
      super.key});

  final SettingsProvider settingsProvider;
  final RecentProvider recentProvider;
  final BookmarkProvider bookmarkProvider;
  final AppDependencyProvider appDependencyProvider;
  final DevicePresentation devicePresentation;

  @override
  State<FlixQuest> createState() => _FlixQuestState();
}

class _FlixQuestState extends State<FlixQuest>
    with ChangeNotifier, WidgetsBindingObserver {
  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  StreamSubscription<RemoteConfigUpdate>? _remoteConfigSubscription;
  Timer? _widgetRefreshDebounce;

  Future<void> _initConfig() async {
    try {
      await AppRemoteConfig.configure(_remoteConfig);
      await _remoteConfig.ensureInitialized();
      if (!mounted) return;
      // A slow fetch must not leave playback using the disabled defaults
      // while the last activated settings are already stored on the device.
      AppRemoteConfig.apply(_remoteConfig, widget.appDependencyProvider);
      await _fetchConfig();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[PlaybackAdConfig] initialization failed: $error');
      }
      // The persisted app configuration remains usable while Firebase is
      // temporarily unavailable.
    }
    if (mounted) {
      _remoteConfigSubscription = _remoteConfig.onConfigUpdated.listen(
        _onRemoteConfigUpdated,
        onError: (Object error) {
          if (kDebugMode) {
            debugPrint('[PlaybackAdConfig] real-time update error: $error');
          }
        },
      );
    }
  }

  Future<void> _fetchConfig({bool requestPermissions = true}) async {
    try {
      final activated = await _remoteConfig.fetchAndActivate();
      if (kDebugMode) {
        debugPrint('[PlaybackAdConfig] fetch '
            'status=${_remoteConfig.lastFetchStatus.name} '
            'lastFetch=${_remoteConfig.lastFetchTime.toUtc().toIso8601String()} '
            'activated=$activated');
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[PlaybackAdConfig] fetch failed: $error; '
            'using previously activated/default values');
      }
      // Cached/default values still provide a safe startup when offline.
    }
    if (mounted) {
      AppRemoteConfig.apply(_remoteConfig, widget.appDependencyProvider);
    }
    if (requestPermissions) await requestNotificationPermissions();
  }

  Future<void> _onRemoteConfigUpdated(RemoteConfigUpdate update) async {
    try {
      final activated = await _remoteConfig.activate();
      if (kDebugMode) {
        debugPrint('[PlaybackAdConfig] real-time update '
            'keys=${update.updatedKeys.join(',')} activated=$activated');
      }
      if (mounted) {
        AppRemoteConfig.apply(_remoteConfig, widget.appDependencyProvider);
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[PlaybackAdConfig] real-time activation failed: $error');
      }
      // Keep the last successfully activated configuration.
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    if (kDebugMode) unawaited(_refreshConfigAfterReload());
  }

  Future<void> _refreshConfigAfterReload() async {
    try {
      // Hot reload preserves initState and the provider's old catalog. Fetch
      // and apply the current remote values without repeating permissions.
      await AppRemoteConfig.configure(_remoteConfig);
      await _fetchConfig(requestPermissions: false);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[PlaybackAdConfig] reload refresh failed: $error');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WellnessProvider.instance.addListener(_scheduleLocalWidgetRefresh);
    widget.bookmarkProvider.addListener(_scheduleLocalWidgetRefresh);
    _initConfig();
    fileDelete();
    InAppMessagingService.initialize();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkDispatcher.onAppReady();
      unawaited(_refreshHomeWidgets());
    });
  }

  void _scheduleLocalWidgetRefresh() {
    _widgetRefreshDebounce?.cancel();
    _widgetRefreshDebounce = Timer(const Duration(seconds: 3), () {
      unawaited(HomeWidgetService.instance.refreshLocal(
        wellness: WellnessProvider.instance,
        bookmarks: widget.bookmarkProvider,
      ));
    });
  }

  Future<void> _refreshHomeWidgets() => HomeWidgetService.instance.refreshAll(
        settings: widget.settingsProvider,
        dependencies: widget.appDependencyProvider,
        wellness: WellnessProvider.instance,
        bookmarks: widget.bookmarkProvider,
      );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      // Leaving the app is the last chance to hand off progress saved by the
      // player, so push it now instead of waiting out the debounce.
      unawaited(RecentlyWatchedSyncService.instance.flushPending());
      return;
    }
    DeepLinkDispatcher.onAppReady();
    unawaited(_refreshHomeWidgets());
    unawaited(RecentlyWatchedSyncService.instance.autoSyncIfSignedIn());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WellnessProvider.instance.removeListener(_scheduleLocalWidgetRefresh);
    widget.bookmarkProvider.removeListener(_scheduleLocalWidgetRefresh);
    _widgetRefreshDebounce?.cancel();
    _remoteConfigSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // SystemChrome.setPreferredOrientations([
    //   isTablet(context)
    //       ? DeviceOrientation.landscapeLeft
    //       : DeviceOrientation.portraitUp,
    // ]);
    return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) {
            return widget.settingsProvider;
          }),
          ChangeNotifierProvider(create: (_) {
            return widget.recentProvider;
          }),
          ChangeNotifierProvider(create: (_) {
            return widget.bookmarkProvider;
          }),
          ChangeNotifierProvider(create: (_) {
            return widget.appDependencyProvider;
          }),
          ChangeNotifierProvider(
            create: (_) => OfflineDownloadProvider()..initialize(),
          ),
          ChangeNotifierProvider.value(value: WellnessProvider.instance),
        ],
        child:
            Consumer3<SettingsProvider, RecentProvider, AppDependencyProvider>(
                builder: (context, settingsProvider, recentProvider,
                    appDependencyProvider, snapshot) {
          return AppPresentation(
            settings: settingsProvider,
            detectedPresentation: widget.devicePresentation,
            navigatorKey: InAppMessagingService.navigatorKey,
            builder: (context, devicePresentation) => DynamicColorBuilder(
              builder: (lightDynamic, darkDynamic) {
                final isDarkTheme = settingsProvider.appTheme == 'dark' ||
                    settingsProvider.appTheme == 'amoled';
                final palette = AppColorsList().appColors(
                  isDarkTheme,
                  customColor: settingsProvider.customAppColor > 0
                      ? settingsProvider.customAppColor
                      : null,
                );
                final selectedAppColor = palette.firstWhere(
                  (color) => color.index == settingsProvider.appColorIndex,
                  orElse: () => palette.first,
                );
                final appTheme = Styles.themeData(
                  appThemeMode: settingsProvider.appTheme,
                  isM3Enabled: settingsProvider.isMaterial3Enabled,
                  lightDynamicColor: lightDynamic,
                  darkDynamicColor: darkDynamic,
                  context: context,
                  appColor: selectedAppColor,
                  compactCorners:
                      devicePresentation != DevicePresentation.television,
                  occasionalTheme: appDependencyProvider.activeOccasionalTheme,
                  ambientColor: appDependencyProvider.activeAmbientColor,
                );
                unawaited(
                  HomeWidgetService.instance.syncResolvedTheme(appTheme),
                );
                final app = MaterialApp(
                  restorationScopeId: 'flixquest',
                  navigatorKey: InAppMessagingService.navigatorKey,
                  localizationsDelegates: context.localizationDelegates,
                  supportedLocales: context.supportedLocales,
                  locale: context.locale,
                  debugShowCheckedModeBanner: false,
                  builder: (context, child) =>
                      AnnotatedRegion<SystemUiOverlayStyle>(
                    value: SystemUiOverlayStyle(
                      systemNavigationBarColor: Colors.transparent,
                      systemNavigationBarDividerColor: Colors.transparent,
                      systemNavigationBarIconBrightness:
                          isDarkTheme ? Brightness.light : Brightness.dark,
                      systemNavigationBarContrastEnforced: false,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (devicePresentation == DevicePresentation.television)
                          TvUpdateGate(child: child ?? const SizedBox.shrink())
                        else
                          child ?? const SizedBox.shrink(),
                        if (devicePresentation != DevicePresentation.television)
                          OccasionalEffectOverlay(
                            theme: appDependencyProvider.activeOccasionalTheme,
                            enabled: appDependencyProvider
                                .shouldShowOccasionalEffects,
                            visibilityListenable: appDependencyProvider,
                            visibilityResolver: () => appDependencyProvider
                                .shouldShowOccasionalEffects,
                          ),
                      ],
                    ),
                  ),
                  theme: appTheme,
                  home: UserState(
                    key: ValueKey<DevicePresentation>(devicePresentation),
                    devicePresentation: devicePresentation,
                  ),
                );
                // Wraps the app itself: it has to hear about system Backs
                // before the navigator does. Keep the wrapper mounted in both
                // modes so the navigator's home builder stays up to date.
                return TvBackKeyGuard(
                  enabled: devicePresentation == DevicePresentation.television,
                  child: app,
                );
              },
            ),
          );
        }));
  }
}

/// The phone and tablet app, under its bottom bar.
class FlixQuestHomePage extends StatelessWidget {
  const FlixQuestHomePage({
    super.key,
  });

  @override
  Widget build(BuildContext context) => const MobileShell();
}

/*

String? appVersion = _remoteConfig.getString('latest_version');
      SharedPreferences sharedPrefsSingleton = await SharedPreferences.getInstance();
      String? ignoreVersion = sharedPrefsSingleton.getString('ignore_version') ?? '';
      if (mounted &&
          appVersion != currentAppVersion &&
          (ignoreVersion == '' || ignoreVersion != currentAppVersion)) {
        showBottomSheet(
          context: context,
          builder: (context) {
            return Builder(
              builder: (BuildContext innerContext) {
                return UpdateBottom(
                  appVersion: appVersion,
                  ignoreVersion: ignoreVersion,
                  sharedPrefsSingleton: sharedPrefsSingleton,
                );
              },
            );
          },
        );
      }


*/
