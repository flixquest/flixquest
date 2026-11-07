import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../functions/function.dart';
import '../../models/app_colors.dart';
import '../../models/app_mode.dart';
import '../../screens/common/language_choose.dart' show appLanguageChoices;
import '../../screens/common/update_screen.dart';
import '../../provider/settings_provider.dart';
import '../../provider/app_dependency_provider.dart';
import '../app/tv_design.dart';
import '../focus/tv_screen_focus_controller.dart';
import '../focus/tv_focusable.dart';
import '../widgets/tv_dialog.dart';
import '../widgets/tv_list_row.dart';
import '../widgets/tv_page_header.dart';

class TvSettingsScreen extends StatelessWidget {
  const TvSettingsScreen({
    required this.metrics,
    this.focusController,
    super.key,
  });

  final TvShellMetrics metrics;
  final TvScreenFocusController? focusController;

  @override
  Widget build(BuildContext context) {
    // Rebuild translated labels when the app locale changes.
    Localizations.localeOf(context);
    final settings = context.watch<SettingsProvider>();
    final appDependencies = context.watch<AppDependencyProvider>();
    final occasionalCatalog = appDependencies.occasionalThemeCatalog;
    final occasionalThemes = appDependencies.availableOccasionalThemes;
    return _TvSettingsFocusEntry(
      focusController: focusController,
      builder: (themeFocusNode) {
        final appearanceTiles = <Widget>[
          _TvSettingTile(
            key: const ValueKey<String>('theme-mode'),
            focusNode: themeFocusNode,
            label: tr('theme_mode'),
            value: _themeLabel(settings.appTheme),
            icon: PhosphorIcons.moonStars(),
            onActivate: () => _showThemeModePicker(context, settings),
          ),
          _TvSettingTile(
            key: const ValueKey<String>('app-language'),
            label: tr('app_language'),
            value: _appLanguageLabel(settings.appLanguage),
            icon: PhosphorIcons.translate(),
            onActivate: () => _showAppLanguagePicker(context, settings),
          ),
          _TvSettingTile(
            key: const ValueKey<String>('ambient-mode'),
            label: tr('ambient_mode'),
            value: appDependencies.ambientModeEnabled
                ? tr('tv_on')
                : tr('player_off'),
            icon: PhosphorIcons.imageSquare(),
            onActivate: () => appDependencies.ambientModeEnabled =
                !appDependencies.ambientModeEnabled,
          ),
          if (occasionalCatalog.enabled)
            _TvSettingTile(
              key: const ValueKey<String>('seasonal-themes'),
              label: tr('seasonal_themes'),
              value: appDependencies.occasionalThemeEnabled
                  ? tr('tv_on')
                  : tr('player_off'),
              icon: PhosphorIcons.sparkle(),
              onActivate: () => appDependencies.occasionalThemeEnabled =
                  !appDependencies.occasionalThemeEnabled,
            ),
          if (occasionalCatalog.enabled &&
              appDependencies.occasionalThemeEnabled &&
              occasionalCatalog.allowUserSelection &&
              occasionalThemes.isNotEmpty)
            _TvSettingTile(
              key: const ValueKey<String>('seasonal-theme'),
              label: tr('occasional_theme'),
              value: _occasionalThemeLabel(appDependencies),
              icon: PhosphorIcons.sparkle(),
              onActivate: () =>
                  _showOccasionalThemePicker(context, appDependencies),
            ),
          if (occasionalCatalog.enabled &&
              appDependencies.occasionalThemeEnabled &&
              occasionalCatalog.effectsEnabled &&
              occasionalCatalog.allowUserEffectsToggle)
            _TvSettingTile(
              key: const ValueKey<String>('seasonal-effects'),
              label: tr('seasonal_effects'),
              value: appDependencies.occasionalEffectsEnabled
                  ? tr('tv_on')
                  : tr('player_off'),
              icon: PhosphorIcons.sparkle(),
              onActivate: () => appDependencies.occasionalEffectsEnabled =
                  !appDependencies.occasionalEffectsEnabled,
            ),
          _TvSettingTile(
            key: const ValueKey<String>('color-theme'),
            label: tr('tv_color_theme'),
            value: _colorThemeLabel(settings.appColorIndex),
            icon: PhosphorIcons.palette(),
            onActivate: () => _showColorThemePicker(context),
          ),
          _TvSettingTile(
            key: const ValueKey<String>('app-mode'),
            label: tr('app_mode'),
            value: _appModeLabel(settings.appMode),
            icon: PhosphorIcons.monitor(),
            onActivate: () => _showAppModePicker(context, settings),
          ),
        ];
        final sourceTiles = <Widget>[
          _TvSettingTile(
            key: const ValueKey<String>('tmdb-proxy'),
            label: tr('tv_tmdb_proxy'),
            value: settings.enableProxy
                ? tr('tmdb_proxy_turn_off')
                : tr('tmdb_proxy_auto_off'),
            icon: PhosphorIcons.globeHemisphereWest(),
            showsNext: false,
            onActivate: () {
              if (settings.enableProxy) settings.disableTmdbProxy();
            },
          ),
          _TvSettingTile(
            key: const ValueKey<String>('image-quality'),
            label: tr('image_quality'),
            value: _imageQualityLabel(settings.imageQuality),
            icon: PhosphorIcons.image(),
            onActivate: () => _showImageQualityPicker(context, settings),
          ),
        ];
        final aboutTiles = <Widget>[
          _TvSettingTile(
            key: const ValueKey<String>('app-updates'),
            label: tr('tv_app_updates'),
            value: tr('tv_check_for_updates'),
            icon: PhosphorIcons.downloadSimple(),
            onActivate: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const UpdateScreen(isForced: false, television: true),
              ),
            ),
          ),
        ];

        return Padding(
          padding: EdgeInsets.fromLTRB(
            metrics.contentPadding,
            0,
            metrics.contentPadding,
            metrics.contentPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(left: TvDesign.focusOutset + 4),
                child: TvPageHeader(
                  kicker: tr('tv_preferences'),
                  title: tr('settings'),
                  compact: metrics.compact,
                ),
              ),
              SizedBox(height: metrics.compact ? 12 : 18),
              Expanded(
                child: SingleChildScrollView(
                  clipBehavior: Clip.hardEdge,
                  padding: const EdgeInsets.all(TvDesign.focusOutset),
                  // A readable column rather than rows the width of the TV.
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _TvSettingsSection(
                            title: tr('tv_appearance'),
                            subtitle:
                                tr('tv_theme_backdrop_and_seasonal_details'),
                            children: appearanceTiles,
                          ),
                          const SizedBox(height: 22),
                          _TvSettingsSection(
                            title: tr('tv_content_sources'),
                            subtitle: tr(
                                'tv_catalog_images_connection_and_source_priority'),
                            children: sourceTiles,
                          ),
                          const SizedBox(height: 22),
                          const SizedBox(height: 22),
                          const SizedBox(height: 22),
                          _TvSettingsSection(
                            title: tr('tv_storage'),
                            subtitle: tr('tv_clear_cached_and_temporary_files'),
                            children: <Widget>[_TvClearCacheTile()],
                          ),
                          const SizedBox(height: 22),
                          _TvSettingsSection(
                            title: tr('tv_about_flixquest'),
                            subtitle: tr('tv_keep_the_tv_experience_current'),
                            children: aboutTiles,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _appLanguageLabel(String code) {
    for (final language in appLanguageChoices()) {
      if (language.languageCode == code) return language.languageName;
    }
    return code;
  }

  static Future<void> _showAppLanguagePicker(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    final selected = await showTvDialog<String>(
      context: context,
      title: tr('app_language'),
      content: _TvAppLanguagePicker(selected: settings.appLanguage),
      autofocusFirstAction: false,
      actions: <TvDialogAction>[
        TvDialogAction(
          label: tr('cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
    if (selected == null || !context.mounted) return;
    settings.appLanguage = selected;
    await context.setLocale(Locale(selected));
  }

  static String _themeLabel(String value) {
    return switch (value) {
      'amoled' => tr('tv_amoled'),
      'light' => tr('ins_theme_light'),
      _ => tr('ins_theme_dark'),
    };
  }

  static String _appModeLabel(AppMode mode) => switch (mode) {
        AppMode.automatic => tr('automatic'),
        AppMode.television => tr('tv'),
        AppMode.mobile => tr('app_mode_mobile'),
      };

  static Future<void> _showAppModePicker(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    final selected = await showTvDialog<AppMode>(
      context: context,
      title: tr('app_mode'),
      content: Text(
        tr('app_mode_description'),
      ),
      actions: <TvDialogAction>[
        for (final mode in AppMode.values)
          TvDialogAction(
            label: _appModeLabel(mode),
            autofocus: settings.appMode == mode,
            isPrimary: settings.appMode == mode,
            onPressed: () => Navigator.of(context).pop(mode),
          ),
      ],
    );
    if (selected != null) settings.appMode = selected;
  }

  static String _imageQualityLabel(String value) {
    return switch (value) {
      'original/' => tr('high'),
      'w600_and_h900_bestv2/' => tr('medium'),
      _ => tr('low'),
    };
  }

  static String _occasionalThemeLabel(AppDependencyProvider provider) {
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

  static String _colorThemeLabel(int index) => switch (index) {
        -1 => 'FlixQuest',
        AppColor.customIndex => tr('tv_custom'),
        1 => tr('tv_indigo'),
        2 => tr('tv_pink'),
        3 => tr('tv_emerald'),
        4 => tr('tv_amber'),
        5 => tr('tv_violet'),
        6 => tr('tv_cyan'),
        7 => tr('tv_red'),
        8 => tr('tv_teal'),
        9 => tr('tv_orange'),
        10 => tr('tv_purple'),
        11 => tr('tv_blue'),
        12 => tr('tv_lime'),
        13 => tr('tv_rose'),
        14 => tr('tv_sky_blue'),
        15 => tr('tv_green'),
        16 => tr('tv_yellow'),
        17 => tr('tv_slate'),
        18 => tr('tv_fuchsia'),
        19 => tr('tv_deep_emerald'),
        20 => tr('tv_coral'),
        _ => 'FlixQuest',
      };

  static Future<void> _showThemeModePicker(
    BuildContext context,
    SettingsProvider settings,
  ) {
    final options = <String, String>{
      'dark': tr('ins_theme_dark'),
      'light': tr('ins_theme_light'),
      'amoled': tr('tv_amoled'),
    };
    return showTvDialog<void>(
      context: context,
      title: tr('theme_mode'),
      content: Text(tr('tv_choose_how_flixquest_looks_on_this_tv')),
      actions: <TvDialogAction>[
        for (final option in options.entries)
          TvDialogAction(
            label: option.value,
            autofocus: settings.appTheme == option.key,
            isPrimary: settings.appTheme == option.key,
            onPressed: () {
              settings.appTheme = option.key;
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }

  static Future<void> _showImageQualityPicker(
    BuildContext context,
    SettingsProvider settings,
  ) {
    final options = <String, String>{
      'original/': tr('high'),
      'w600_and_h900_bestv2/': tr('medium'),
      'w500/': tr('low'),
    };
    return showTvDialog<void>(
      context: context,
      title: tr('image_quality'),
      content: Text(
        tr('tv_higher_quality_uses_more_bandwidth_and_may_load_more_slowly'),
      ),
      actions: <TvDialogAction>[
        for (final option in options.entries)
          TvDialogAction(
            label: option.value,
            autofocus: settings.imageQuality == option.key,
            isPrimary: settings.imageQuality == option.key,
            onPressed: () {
              settings.imageQuality = option.key;
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }

  static Future<void> _showColorThemePicker(BuildContext context) {
    return showTvDialog<void>(
      context: context,
      title: tr('tv_color_theme'),
      content: const _TvColorThemePicker(),
      autofocusFirstAction: false,
      actions: <TvDialogAction>[
        TvDialogAction(
          label: tr('tv_done'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  static Future<void> _showOccasionalThemePicker(
    BuildContext context,
    AppDependencyProvider provider,
  ) {
    final options = <String, String>{
      'automatic': tr('automatic'),
      for (final theme in provider.availableOccasionalThemes)
        theme.id: theme.displayName,
    };
    return showTvDialog<void>(
      context: context,
      title: tr('occasional_theme'),
      content: Text(
        tr('tv_automatic_uses_the_highest_priority_active_occasion'),
      ),
      actions: <TvDialogAction>[
        for (final option in options.entries)
          TvDialogAction(
            label: option.value,
            autofocus: provider.selectedOccasionalThemeId == option.key,
            isPrimary: provider.selectedOccasionalThemeId == option.key,
            onPressed: () {
              provider.selectOccasionalTheme(option.key);
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }
}

class _TvAppLanguagePicker extends StatelessWidget {
  const _TvAppLanguagePicker({required this.selected});

  final String selected;

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final languages = appLanguageChoices();
    final hasSelection = languages.any(
      (language) => language.languageCode == selected,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(tr('choose_language')),
        const SizedBox(height: 18),
        for (final language in languages)
          TvListRow(
            key: ValueKey<String>('app-language-${language.languageCode}'),
            label: language.languageName,
            value: language.languageCode == selected ? tr('tv_selected') : null,
            showsNext: false,
            autofocus: language.languageCode == selected ||
                (!hasSelection && language == languages.first),
            onActivate: () => Navigator.of(context).pop(language.languageCode),
          ),
      ],
    );
  }
}

class _TvClearCacheTile extends StatefulWidget {
  const _TvClearCacheTile();

  @override
  State<_TvClearCacheTile> createState() => _TvClearCacheTileState();
}

class _TvClearCacheTileState extends State<_TvClearCacheTile> {
  bool _clearing = false;

  Future<void> _clear() async {
    if (_clearing) return;
    setState(() => _clearing = true);
    var cleared = false;
    var failed = false;
    // These directories may be the same on Android, so clear them in sequence.
    for (final clear in [clearCache, clearTempCache]) {
      try {
        cleared = await clear() || cleared;
      } catch (error) {
        failed = true;
        debugPrint('TV cache clearing failed: $error');
      }
    }
    if (!mounted) return;
    setState(() => _clearing = false);
    await showTvDialog<void>(
      context: context,
      title: failed
          ? tr('tv_cache_clearing_incomplete')
          : cleared
              ? tr('tv_cache_cleared')
              : tr('tv_no_cache_to_clear'),
      content: Text(failed
          ? tr('tv_some_cached_files_could_not_be_cleared_please_try_again')
          : cleared
              ? tr('tv_cached_and_temporary_files_were_cleared')
              : tr('tv_there_are_no_cached_or_temporary_files_to_clear')),
      actions: <TvDialogAction>[
        TvDialogAction(
          label: tr('tv_done'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => _TvSettingTile(
        key: const ValueKey<String>('clear-cache'),
        label: tr('clear_cache'),
        value: _clearing ? tr('tv_clearing') : tr('tv_clear_temporary_files'),
        icon: PhosphorIcons.eraser(),
        showsNext: false,
        onActivate: _clear,
      );
}

class _TvSettingsFocusEntry extends StatefulWidget {
  const _TvSettingsFocusEntry({
    required this.builder,
    this.focusController,
  });

  final Widget Function(FocusNode themeFocusNode) builder;
  final TvScreenFocusController? focusController;

  @override
  State<_TvSettingsFocusEntry> createState() => _TvSettingsFocusEntryState();
}

class _TvSettingsFocusEntryState extends State<_TvSettingsFocusEntry> {
  final FocusNode _themeFocusNode =
      FocusNode(debugLabel: 'TV setting theme mode');

  @override
  void initState() {
    super.initState();
    widget.focusController?.attach(this, _requestFocus);
  }

  @override
  void didUpdateWidget(_TvSettingsFocusEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.focusController, widget.focusController)) {
      oldWidget.focusController?.detach(this);
      widget.focusController?.attach(this, _requestFocus);
    }
  }

  bool _requestFocus() {
    if (_themeFocusNode.context == null || !_themeFocusNode.canRequestFocus) {
      return false;
    }
    _themeFocusNode.requestFocus();
    return true;
  }

  @override
  void dispose() {
    widget.focusController?.detach(this);
    _themeFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_themeFocusNode);
}

class _TvColorThemePicker extends StatefulWidget {
  const _TvColorThemePicker();

  @override
  State<_TvColorThemePicker> createState() => _TvColorThemePickerState();
}

class _TvColorThemePickerState extends State<_TvColorThemePicker> {
  final Map<int, FocusNode> _focusNodes = <int, FocusNode>{};

  FocusNode _nodeFor(int index) {
    return _focusNodes.putIfAbsent(
      index,
      () => FocusNode(debugLabel: 'color-$index'),
    );
  }

  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _selectColor(SettingsProvider settings, int index) {
    settings.appColorIndex = index;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild translated labels when the app locale changes.
    Localizations.localeOf(context);
    final palette = TvPalette.of(context);
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.appTheme == 'dark' || settings.appTheme == 'amoled';
    final swatches = AppColorsList().appColors(isDark,
        customColor:
            settings.customAppColor > 0 ? settings.customAppColor : null);
    final selectedIndex =
        swatches.any((color) => color.index == settings.appColorIndex)
            ? settings.appColorIndex
            : swatches.first.index;

    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: <Widget>[
        for (final appColor in swatches)
          TvFocusable(
            key: ValueKey<int>(appColor.index),
            focusNode: _nodeFor(appColor.index),
            semanticLabel: tr('tv_color_theme_semantics', namedArgs: {
              'color': TvSettingsScreen._colorThemeLabel(appColor.index),
              'selected': selectedIndex == appColor.index
                  ? tr('tv_selected_suffix')
                  : ''
            }),
            autofocus: selectedIndex == appColor.index,
            focusScale: 1.025,
            onActivate: () => _selectColor(settings, appColor.index),
            child: Container(
              width: 116,
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                color: TvDesign.surfaceFor(context, emphasis: 0.012),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: palette.hairline),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: appColor.cs.primary,
                      shape: BoxShape.circle,
                    ),
                    child: selectedIndex == appColor.index
                        ? Icon(
                            PhosphorIcons.check(PhosphorIconsStyle.bold),
                            size: 17,
                            color: appColor.cs.onPrimary,
                          )
                        : null,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      TvSettingsScreen._colorThemeLabel(appColor.index),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.foreground,
                        fontFamily: 'FigtreeSB',
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TvSettingsSection extends StatelessWidget {
  const _TvSettingsSection({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;

  /// Read out with the section; the rows say enough on screen.
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Rebuild translated labels when the app locale changes.
    Localizations.localeOf(context);
    return Semantics(
      container: true,
      label: '$title. $subtitle',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TvSectionLabel(title),
          for (final child in children)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: child,
            ),
        ],
      ),
    );
  }
}

class _TvSettingTile extends StatelessWidget {
  const _TvSettingTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onActivate,
    this.focusNode,
    this.showsNext = true,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onActivate;
  final FocusNode? focusNode;
  final bool showsNext;

  @override
  Widget build(BuildContext context) {
    // Rebuild translated labels when the app locale changes.
    Localizations.localeOf(context);
    return TvListRow(
      focusNode: focusNode,
      label: label,
      value: value,
      icon: icon,
      showsNext: showsNext,
      onActivate: onActivate,
    );
  }
}
