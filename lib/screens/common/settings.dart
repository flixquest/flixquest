import '../../core/network/network_runtime.dart';
import 'dart:io';
import 'package:flixquest/models/app_colors.dart';
import 'package:flixquest/models/default_home.dart';
import 'package:flixquest/services/globle_method.dart';

import '../../functions/function.dart';
import '/screens/common/language_choose.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '/provider/settings_provider.dart';
import '/provider/app_dependency_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'player_settings.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../mobile/widgets/page_kit.dart';
import '../../mobile/widgets/pill_button.dart';
import '../../mobile/widgets/settings_kit.dart';
import '../../ui_components/app_ui_components.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  String initialDropdownValue = 'w500';
  int initialHomeScreenValue = 0;

  String? languageFlag;
  String? languageName;
  String? release;
  bool isBelow33 = true;

  final AppColorsList appColors = AppColorsList();

  void androidVersionCheck() async {
    if (Platform.isAndroid) {
      var androidInfo = await DeviceInfoPlugin().androidInfo;
      var sdkInt = androidInfo.version.sdkInt;
      if (sdkInt >= 33) {
        setState(() {
          isBelow33 = false;
        });
      }
    }
  }

  @override
  void initState() {
    androidVersionCheck();
    super.initState();
  }

  Widget _paletteSwatch({
    required Color color,
    required Color onColor,
    required bool selected,
    required VoidCallback onTap,
    EdgeInsetsGeometry margin = const EdgeInsetsDirectional.only(end: 14),
    Widget? iconOverride,
  }) {
    return Padding(
      padding: margin,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 50,
          height: 50,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? color : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: DecoratedBox(
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(
              child: iconOverride ??
                  (selected
                      ? Icon(PhosphorIcons.check(), color: onColor)
                      : null),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickCustomColor(SettingsProvider settingsValues) async {
    final picked = await showColorPickerSheet(
      context,
      title: tr('custom_color'),
      initialColor: settingsValues.customAppColor > 0
          ? Color(settingsValues.customAppColor)
          : Theme.of(context).colorScheme.primary,
    );
    if (picked == null) return;
    setState(() {
      settingsValues.customAppColor = picked.toARGB32();
      settingsValues.appColorIndex = AppColor.customIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsValues = Provider.of<SettingsProvider>(context);
    final palette = AppPalette.of(context);
    final appDependencies = context.watch<AppDependencyProvider>();
    final occasionalCatalog = appDependencies.occasionalThemeCatalog;
    final occasionalThemes = appDependencies.availableOccasionalThemes;

    final langs = appLanguageChoices();

    for (final language in langs) {
      if (language.languageCode.contains(settingsValues.appLanguage)) {
        languageFlag = language.languageFlag;
        languageName = language.languageName;
        break;
      }
    }

    return Scaffold(
      backgroundColor: palette.page,
      appBar: PageAppBar(title: tr('settings')),
      body: AppResponsiveContent(
        padding: EdgeInsets.zero,
        maxWidth: 760,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpace.gutter(context),
            AppSpace.sm,
            AppSpace.gutter(context),
            AppSpace.xxxl + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            const SizedBox(height: 12),
            SettingsGroup(
              title: tr('appearance'),
              children: [
                ChoiceRow<String>(
                  icon: PhosphorIcons.moon(),
                  label: tr('theme_mode'),
                  value: settingsValues.appTheme,
                  options: {
                    'dark': tr('dark'),
                    'light': tr('light'),
                    'amoled': tr('amoled'),
                  },
                  onChanged: (value) =>
                      setState(() => settingsValues.appTheme = value),
                ),
                SwitchRow(
                  value: appDependencies.ambientModeEnabled,
                  icon: PhosphorIcons.imageSquare(),
                  label: tr('ambient_mode'),
                  subtitle: tr('ambient_mode_description'),
                  onChanged: (value) {
                    appDependencies.ambientModeEnabled = value;
                  },
                ),
                if (occasionalCatalog.enabled)
                  SwitchRow(
                    value: appDependencies.occasionalThemeEnabled,
                    icon: PhosphorIcons.sparkle(),
                    label: tr('seasonal_themes'),
                    subtitle: tr('seasonal_themes_description'),
                    onChanged: (value) {
                      appDependencies.occasionalThemeEnabled = value;
                    },
                  ),
                if (occasionalCatalog.enabled &&
                    appDependencies.occasionalThemeEnabled &&
                    occasionalCatalog.allowUserSelection &&
                    occasionalThemes.isNotEmpty)
                  _OccasionalThemeChoiceTile(
                    provider: appDependencies,
                  ),
                if (occasionalCatalog.enabled &&
                    appDependencies.occasionalThemeEnabled &&
                    occasionalCatalog.effectsEnabled &&
                    occasionalCatalog.allowUserEffectsToggle)
                  SwitchRow(
                    value: appDependencies.occasionalEffectsEnabled,
                    icon: PhosphorIcons.confetti(),
                    label: tr('seasonal_effects'),
                    subtitle: tr('seasonal_effects_description'),
                    onChanged: (value) {
                      appDependencies.occasionalEffectsEnabled = value;
                    },
                  ),
                ListRow(
                  icon: PhosphorIcons.play(),
                  label: tr('player_settings'),
                  onTap: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: ((context) {
                      return const PlayerSettings();
                    })));
                  },
                ),
                if (!isBelow33)
                  SwitchRow(
                    subtitle: tr('android_12'),
                    value: settingsValues.isMaterial3Enabled,
                    icon: PhosphorIcons.palette(),
                    label: tr('material_theming'),
                    onChanged: (bool value) {
                      setState(() {
                        settingsValues.isMaterial3Enabled = value;
                      });
                    },
                  ),
                SwitchRow(
                  subtitle: tr('enable_warning'),
                  value: settingsValues.enableProxy,
                  icon: PhosphorIcons.globe(),
                  label: tr('use_proxy'),
                  onChanged: (bool value) {
                    if (value) {
                      showDialog(
                          context: context,
                          builder: (BuildContext ctx) {
                            return AlertDialog(
                              title: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(tr('use_proxy_title')),
                              ),
                              content: Text(tr('use_proxy_detail')),
                              actions: <Widget>[
                                PillButton(
                                  label: tr('cancel'),
                                  onPressed: () => Navigator.pop(ctx),
                                ),
                                PillButton(
                                  label: tr('enable'),
                                  primary: true,
                                  onPressed: () {
                                    setState(() {
                                      settingsValues.enableProxy = value;
                                    });
                                    Navigator.pop(ctx);
                                  },
                                ),
                              ],
                            );
                          });
                    } else {
                      setState(() {
                        settingsValues.enableProxy = value;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            SettingsGroup(
              title: tr('content_preferences'),
              children: [
                ChoiceRow<String>(
                  icon: PhosphorIcons.image(),
                  label: tr('image_quality'),
                  value: settingsValues.imageQuality,
                  options: {
                    'original/': tr('high'),
                    'w600_and_h900_bestv2/': tr('medium'),
                    'w500/': tr('low'),
                  },
                  onChanged: (value) =>
                      setState(() => settingsValues.imageQuality = value),
                ),
                ChoiceRow<DefaultHome>(
                  icon: PhosphorIcons.deviceMobile(),
                  label: tr('default_home_screen'),
                  value: settingsValues.defaultHome,
                  options: {
                    DefaultHome.home: tr('home'),
                    DefaultHome.homeMovies: tr('home_movies'),
                    DefaultHome.homeSeries: tr('home_series'),
                    DefaultHome.search: tr('search'),
                    DefaultHome.mine: tr('my_flixquest'),
                  },
                  onChanged: (value) =>
                      setState(() => settingsValues.defaultHome = value),
                ),
                ListRow(
                  onTap: (() {
                    Navigator.push(context,
                        MaterialPageRoute(builder: ((context) {
                      return const AppLanguageChoose();
                    })));
                  }),
                  icon: PhosphorIcons.translate(),
                  label: tr('app_language'),
                  showsNext: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (languageFlag != null) ...[
                        LanguageFlag(languageFlag!),
                        const SizedBox(width: AppSpace.sm),
                      ],
                      Text(
                        languageName ?? settingsValues.appLanguage,
                        style:
                            AppType.body.copyWith(color: palette.mutedText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SettingsGroup(
              title: tr('storage'),
              children: [
                ListRow(
                  icon: PhosphorIcons.eraser(),
                  label: tr('clear_cache'),
                  showsNext: false,
                  trailing: PillButton(
                      label: tr('clear'),
                      icon: PhosphorIcons.eraser(),
                      onPressed: () async {
                        await NetworkRuntime.httpCache.clearAll();
                        await clearCache().then((value) {
                          if (!context.mounted) {
                            return;
                          }
                          GlobalMethods.showCustomScaffoldMessage(
                              SnackBar(
                                  duration: const Duration(
                                      seconds: 1, milliseconds: 500),
                                  content: Text(value
                                      ? tr('cleared_cache')
                                      : tr('cache_doesnt_exist'))),
                              context);
                        });
                        await clearTempCache().then((value) {
                          if (!context.mounted) {
                            return;
                          }
                          GlobalMethods.showCustomScaffoldMessage(
                              SnackBar(
                                  duration: const Duration(
                                      seconds: 1, milliseconds: 500),
                                  content: Text(value
                                      ? tr('cleared_cache')
                                      : tr('cache_doesnt_exist'))),
                              context);
                        });
                      }),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SettingsGroup(
              title: tr('custom_color'),
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 68,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    scrollDirection: Axis.horizontal,
                    children: [
                      ...appColors
                          .appColors(settingsValues.appTheme == 'dark' ||
                                  settingsValues.appTheme == 'amoled'
                              ? true
                              : false)
                          .map((AppColor appColor) => _paletteSwatch(
                                color: appColor.cs.primary,
                                onColor: appColor.cs.onPrimary,
                                selected: settingsValues.appColorIndex ==
                                    appColor.index,
                                onTap: () {
                                  final selected =
                                      settingsValues.appColorIndex ==
                                          appColor.index;
                                  setState(() {
                                    settingsValues.appColorIndex = selected
                                        ? AppColor.defaultIndex
                                        : appColor.index;
                                  });
                                },
                              )),
                      if (settingsValues.customAppColor > 0)
                        _paletteSwatch(
                          color: Color(settingsValues.customAppColor),
                          onColor: ThemeData.estimateBrightnessForColor(
                                      Color(settingsValues.customAppColor)) ==
                                  Brightness.dark
                              ? Colors.white
                              : Colors.black,
                          selected: settingsValues.appColorIndex ==
                              AppColor.customIndex,
                          onTap: () {
                            final selected = settingsValues.appColorIndex ==
                                AppColor.customIndex;
                            setState(() {
                              settingsValues.appColorIndex = selected
                                  ? AppColor.defaultIndex
                                  : AppColor.customIndex;
                            });
                          },
                        ),
                      _paletteSwatch(
                        color: palette.idleFill,
                        onColor: palette.foreground,
                        selected: false,
                        margin: EdgeInsets.zero,
                        iconOverride: Icon(
                          PhosphorIcons.plus(),
                          color: palette.foreground,
                        ),
                        onTap: () => _pickCustomColor(settingsValues),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OccasionalThemeChoiceTile extends StatelessWidget {
  const _OccasionalThemeChoiceTile({required this.provider});

  final AppDependencyProvider provider;

  String get _selectedLabel {
    if (provider.selectedOccasionalThemeId == 'automatic') {
      return tr('automatic');
    }
    for (final theme in provider.availableOccasionalThemes) {
      if (theme.id == provider.selectedOccasionalThemeId) {
        return theme.displayName;
      }
    }
    return tr('automatic');
  }

  @override
  Widget build(BuildContext context) {
    return ListRow(
      onTap: () => _showChoices(context),
      icon: PhosphorIcons.sparkle(),
      label: tr('occasional_theme'),
      subtitle: tr('seasonal_theme_selection_description'),
      value: _selectedLabel,
    );
  }

  Future<void> _showChoices(BuildContext context) {
    return showAppSheet<void>(
      context,
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * .78,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(sheetContext).bottom + AppSpace.lg,
          ),
          children: [
            SheetTitle(tr('occasional_theme')),
            _OccasionalThemeOption(
              title: tr('automatic'),
              description: tr('automatic_theme_description'),
              colors: const [],
              selected: provider.selectedOccasionalThemeId == 'automatic',
              onTap: () {
                provider.selectOccasionalTheme('automatic');
                Navigator.pop(sheetContext);
              },
            ),
            for (final theme in provider.availableOccasionalThemes)
              _OccasionalThemeOption(
                title: theme.displayName,
                description: theme.description.isEmpty
                    ? tr('active_seasonal_theme')
                    : theme.description,
                colors: [
                  theme.primaryColor,
                  theme.secondaryColor,
                  theme.tertiaryColor,
                ],
                selected: provider.selectedOccasionalThemeId == theme.id,
                onTap: () {
                  provider.selectOccasionalTheme(theme.id);
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _OccasionalThemeOption extends StatelessWidget {
  const _OccasionalThemeOption({
    required this.title,
    required this.description,
    required this.colors,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final List<Color> colors;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final titleColor = selected ? palette.onFocus : palette.foreground;
    final detailColor =
        selected ? palette.onFocus.withValues(alpha: .72) : palette.mutedText;
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 0, gutter, AppSpace.sm),
      child: Material(
        color: selected ? palette.focusFill : palette.idleFill,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 34,
                  child: colors.isEmpty
                      ? Icon(
                          PhosphorIcons.magicWand(),
                          color: selected ? palette.onFocus : palette.mutedText,
                        )
                      : Stack(
                          children: [
                            for (var index = 0; index < colors.length; index++)
                              Positioned(
                                left: index * 11.0,
                                top: index.isOdd ? 7 : 1,
                                child: Container(
                                  width: 25,
                                  height: 25,
                                  decoration: BoxDecoration(
                                    color: colors[index],
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selected
                                          ? palette.focusFill
                                          : palette.surface,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppType.cardTitle.copyWith(
                          fontSize: 15,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.metadata.copyWith(color: detailColor),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(PhosphorIcons.check(), color: palette.onFocus),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
