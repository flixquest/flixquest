import 'dart:async';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'constants/theme_data.dart';
import 'models/app_colors.dart';
import 'provider/app_dependency_provider.dart';
import 'provider/bookmark_provider.dart';
import 'provider/recently_watched_provider.dart';
import 'provider/settings_provider.dart';
import 'provider/wellness_provider.dart';
import 'services/app_navigation.dart';
import 'services/deep_link_dispatcher.dart';
import 'services/home_widget_service.dart';
import 'screens/user/user_state.dart';
import 'widgets/app_presentation.dart';
import 'widgets/occasional_effect_overlay.dart';
import 'mobile/app/mobile_shell.dart';
import 'mobile/app/mobile_update_gate.dart';
import 'tv/navigation/tv_back_key_guard.dart';
import 'tv/platform/device_presentation.dart';
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

class _FlixQuestState extends State<FlixQuest> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkDispatcher.onAppReady();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) DeepLinkDispatcher.onAppReady();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
          ChangeNotifierProvider.value(value: WellnessProvider.instance),
        ],
        child:
            Consumer3<SettingsProvider, RecentProvider, AppDependencyProvider>(
                builder: (context, settingsProvider, recentProvider,
                    appDependencyProvider, snapshot) {
          return AppPresentation(
            settings: settingsProvider,
            detectedPresentation: widget.devicePresentation,
            navigatorKey: AppNavigation.navigatorKey,
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
                  navigatorKey: AppNavigation.navigatorKey,
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
                          MobileUpdateGate(
                              child: child ?? const SizedBox.shrink()),
                        OccasionalEffectOverlay(
                          theme: appDependencyProvider.activeOccasionalTheme,
                          television: devicePresentation ==
                              DevicePresentation.television,
                          enabled:
                              appDependencyProvider.shouldShowOccasionalEffects,
                          visibilityListenable: appDependencyProvider,
                          visibilityResolver: () =>
                              appDependencyProvider.shouldShowOccasionalEffects,
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

class FlixQuestHomePage extends StatelessWidget {
  const FlixQuestHomePage({super.key});
  @override
  Widget build(BuildContext context) => const MobileShell();
}
