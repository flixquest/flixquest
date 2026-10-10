import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../models/app_colors.dart';
import '../../models/app_mode.dart';
import '../../screens/common/update_screen.dart';
import '../../functions/subtitle_style.dart';
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
            label: 'Theme mode',
            value: _themeLabel(settings.appTheme),
            icon: PhosphorIcons.moonStars(),
            onActivate: () => _showThemeModePicker(context, settings),
          ),
          _TvSettingTile(
            key: const ValueKey<String>('ambient-mode'),
            label: 'Ambient mode',
            value: appDependencies.ambientModeEnabled ? 'On' : 'Off',
            icon: PhosphorIcons.imageSquare(),
            onActivate: () => appDependencies.ambientModeEnabled =
                !appDependencies.ambientModeEnabled,
          ),
          if (occasionalCatalog.enabled)
            _TvSettingTile(
              key: const ValueKey<String>('seasonal-themes'),
              label: 'Seasonal themes',
              value: appDependencies.occasionalThemeEnabled ? 'On' : 'Off',
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
              label: 'Seasonal theme',
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
              label: 'Seasonal effects',
              value: appDependencies.occasionalEffectsEnabled ? 'On' : 'Off',
              icon: PhosphorIcons.sparkle(),
              onActivate: () => appDependencies.occasionalEffectsEnabled =
                  !appDependencies.occasionalEffectsEnabled,
            ),
          _TvSettingTile(
            key: const ValueKey<String>('color-theme'),
            label: 'Color theme',
            value: _colorThemeLabel(settings.appColorIndex),
            icon: PhosphorIcons.palette(),
            onActivate: () => _showColorThemePicker(context),
          ),
          _TvSettingTile(
            key: const ValueKey<String>('app-mode'),
            label: 'App mode',
            value: _appModeLabel(settings.appMode),
            icon: PhosphorIcons.monitor(),
            onActivate: () => _showAppModePicker(context, settings),
          ),
        ];
        final playbackTiles = <Widget>[
          _TvSettingTile(
            key: const ValueKey<String>('tmdb-proxy'),
            label: 'TMDB proxy',
            value: settings.enableProxy ? 'On' : 'Off',
            icon: PhosphorIcons.globeHemisphereWest(),
            onActivate: () => settings.enableProxy = !settings.enableProxy,
          ),
          _TvSettingTile(
            key: const ValueKey<String>('image-quality'),
            label: 'Image quality',
            value: _imageQualityLabel(settings.imageQuality),
            icon: PhosphorIcons.image(),
            onActivate: () => _showImageQualityPicker(context, settings),
          ),
          _TvSettingTile(
            key: const ValueKey<String>('auto-load-sources'),
            label: 'Auto load sources',
            value: settings.autoLoadSources ? 'On' : 'Off',
            icon: PhosphorIcons.lightning(),
            onActivate: () =>
                settings.autoLoadSources = !settings.autoLoadSources,
          ),
          _TvSettingTile(
            key: const ValueKey<String>('subtitle-settings'),
            label: 'Subtitle settings',
            value: _subtitleSummary(settings),
            icon: PhosphorIcons.closedCaptioning(),
            onActivate: () => _showSubtitleSettings(context, settings),
          ),
        ];
        final aboutTiles = <Widget>[
          _TvSettingTile(
            key: const ValueKey<String>('app-updates'),
            label: 'App updates',
            value: 'Check for updates',
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
                  kicker: 'PREFERENCES',
                  title: 'Settings',
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
                            title: 'APPEARANCE',
                            subtitle: 'Theme, backdrop, and seasonal details.',
                            children: appearanceTiles,
                          ),
                          const SizedBox(height: 22),
                          _TvSettingsSection(
                            title: 'STREAMING & PLAYBACK',
                            subtitle: 'Quality, sources, and subtitles.',
                            children: playbackTiles,
                          ),
                          const SizedBox(height: 22),
                          _TvSettingsSection(
                            title: 'ABOUT FLIXQUEST',
                            subtitle: 'Keep the TV experience current.',
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

  static String _themeLabel(String value) {
    return switch (value) {
      'amoled' => 'AMOLED',
      'light' => 'Light',
      _ => 'Dark',
    };
  }

  static String _appModeLabel(AppMode mode) => switch (mode) {
        AppMode.automatic => 'Automatic',
        AppMode.television => 'TV',
        AppMode.mobile => 'Mobile',
      };

  static Future<void> _showAppModePicker(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    final selected = await showTvDialog<AppMode>(
      context: context,
      title: 'App mode',
      content: const Text(
        'Automatic detects your device. Choose TV or Mobile to switch the '
        'interface immediately.',
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
      'original/' => 'High',
      'w600_and_h900_bestv2/' => 'Medium',
      _ => 'Low',
    };
  }

  static String _occasionalThemeLabel(AppDependencyProvider provider) {
    if (provider.selectedOccasionalThemeId == 'automatic') return 'Automatic';
    for (final theme in provider.availableOccasionalThemes) {
      if (theme.id == provider.selectedOccasionalThemeId) {
        return theme.displayName;
      }
    }
    return 'Automatic';
  }

  static String _colorThemeLabel(int index) => switch (index) {
        -1 => 'FlixQuest',
        AppColor.customIndex => 'Custom',
        1 => 'Indigo',
        2 => 'Pink',
        3 => 'Emerald',
        4 => 'Amber',
        5 => 'Violet',
        6 => 'Cyan',
        7 => 'Red',
        8 => 'Teal',
        9 => 'Orange',
        10 => 'Purple',
        11 => 'Blue',
        12 => 'Lime',
        13 => 'Rose',
        14 => 'Sky blue',
        15 => 'Green',
        16 => 'Yellow',
        17 => 'Slate',
        18 => 'Fuchsia',
        19 => 'Deep emerald',
        20 => 'Coral',
        _ => 'FlixQuest',
      };

  static Future<void> _showThemeModePicker(
    BuildContext context,
    SettingsProvider settings,
  ) {
    const options = <String, String>{
      'dark': 'Dark',
      'light': 'Light',
      'amoled': 'AMOLED',
    };
    return showTvDialog<void>(
      context: context,
      title: 'Theme mode',
      content: const Text('Choose how FlixQuest looks on this TV.'),
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
    const options = <String, String>{
      'original/': 'High',
      'w600_and_h900_bestv2/': 'Medium',
      'w500/': 'Low',
    };
    return showTvDialog<void>(
      context: context,
      title: 'Image quality',
      content: const Text(
        'Higher quality uses more bandwidth and may load more slowly.',
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
      title: 'Color theme',
      content: const _TvColorThemePicker(),
      autofocusFirstAction: false,
      actions: <TvDialogAction>[
        TvDialogAction(
          label: 'Done',
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
      'automatic': 'Automatic',
      for (final theme in provider.availableOccasionalThemes)
        theme.id: theme.displayName,
    };
    return showTvDialog<void>(
      context: context,
      title: 'Seasonal theme',
      content: const Text(
        'Automatic uses the highest-priority active occasion.',
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

  static String _subtitleSummary(SettingsProvider settings) {
    final textColor = parseStoredSubtitleColor(
      settings.subtitleForegroundColor,
      fallback: Colors.white,
    );
    final style = normalizeSubtitleTextStyle(settings.subtitleTextStyle);
    final weight = switch (style) {
      'light' => 'Light',
      'bold' => 'Bold',
      _ => 'Regular',
    };
    return '${settings.subtitleFontSize}px, $weight, ${_colorName(textColor)}';
  }

  static String _colorName(Color color) {
    for (final entry in _subtitleTextColors.entries) {
      if (entry.value.toARGB32() == color.toARGB32()) return entry.key;
    }
    for (final entry in _subtitleBackgroundColors.entries) {
      if (entry.value.toARGB32() == color.toARGB32()) return entry.key;
    }
    return 'Custom';
  }

  static const Map<String, Color> _subtitleTextColors = <String, Color>{
    'White': Colors.white,
    'Yellow': Colors.yellow,
    'Cyan': Colors.cyan,
    'Green': Colors.greenAccent,
    'Magenta': Colors.pinkAccent,
  };

  static const Map<String, Color> _subtitleBackgroundColors = <String, Color>{
    'Transparent': Colors.transparent,
    'Black 45%': Colors.black45,
    'Black 70%': Color(0xB3000000),
    'Black': Colors.black,
  };

  static Future<void> _showSubtitleSettings(
    BuildContext context,
    SettingsProvider settings,
  ) {
    return showTvDialog<void>(
      context: context,
      title: 'Subtitle settings',
      content: const _TvSubtitleSettingsContent(),
      autofocusFirstAction: false,
      actions: <TvDialogAction>[
        TvDialogAction(
          label: 'Done',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  static Future<void> _showSubtitleFontSizePicker(
    BuildContext context,
    SettingsProvider settings,
  ) {
    final options = <int>[for (var size = 5; size <= 30; size += 5) size];
    if (!options.contains(settings.subtitleFontSize)) {
      options.add(settings.subtitleFontSize);
      options.sort();
    }
    return showTvDialog<void>(
      context: context,
      title: 'Subtitle font size',
      content: const Text('Choose the subtitle text size.'),
      actions: <TvDialogAction>[
        for (final size in options)
          TvDialogAction(
            label: '${size}px',
            autofocus: settings.subtitleFontSize == size,
            isPrimary: settings.subtitleFontSize == size,
            onPressed: () {
              settings.subtitleFontSize = size;
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }

  static Future<void> _showSubtitleColorPicker(
    BuildContext context,
    SettingsProvider settings, {
    required bool foreground,
  }) {
    final current = parseStoredSubtitleColor(
      foreground
          ? settings.subtitleForegroundColor
          : settings.subtitleBackgroundColor,
      fallback: foreground ? Colors.white : Colors.black45,
    );
    final palette =
        foreground ? _subtitleTextColors : _subtitleBackgroundColors;
    return showTvDialog<void>(
      context: context,
      title: foreground ? 'Subtitle text color' : 'Subtitle background color',
      content: const Text('Choose a color for subtitles.'),
      actions: <TvDialogAction>[
        for (final entry in palette.entries)
          TvDialogAction(
            label: entry.key,
            autofocus: current.toARGB32() == entry.value.toARGB32(),
            isPrimary: current.toARGB32() == entry.value.toARGB32(),
            onPressed: () {
              final value = serializeSubtitleColor(entry.value);
              if (foreground) {
                settings.subtitleForegroundColor = value;
              } else {
                settings.subtitleBackgroundColor = value;
              }
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }

  static Future<void> _showSubtitleWeightPicker(
    BuildContext context,
    SettingsProvider settings,
  ) {
    const options = <String, String>{
      'light': 'Light',
      'regular': 'Regular',
      'bold': 'Bold',
    };
    return showTvDialog<void>(
      context: context,
      title: 'Subtitle text weight',
      content: const Text('Choose the subtitle font weight.'),
      actions: <TvDialogAction>[
        for (final option in options.entries)
          TvDialogAction(
            label: option.value,
            autofocus: settings.subtitleTextStyle == option.key,
            isPrimary: settings.subtitleTextStyle == option.key,
            onPressed: () {
              settings.subtitleTextStyle = option.key;
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }
}

class _TvSubtitleSettingsContent extends StatelessWidget {
  const _TvSubtitleSettingsContent();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final foreground = parseStoredSubtitleColor(
      settings.subtitleForegroundColor,
      fallback: Colors.white,
    );
    final background = parseStoredSubtitleColor(
      settings.subtitleBackgroundColor,
      fallback: Colors.black45,
    );
    final weight =
        switch (normalizeSubtitleTextStyle(settings.subtitleTextStyle)) {
      'light' => 'Light',
      'bold' => 'Bold',
      _ => 'Regular',
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _TvSubtitleOption(
          label: 'Font size',
          value: '${settings.subtitleFontSize}px',
          autofocus: true,
          onActivate: () => TvSettingsScreen._showSubtitleFontSizePicker(
            context,
            settings,
          ),
        ),
        _TvSubtitleOption(
          label: 'Text color',
          value: TvSettingsScreen._colorName(foreground),
          color: foreground,
          onActivate: () => TvSettingsScreen._showSubtitleColorPicker(
            context,
            settings,
            foreground: true,
          ),
        ),
        _TvSubtitleOption(
          label: 'Background color',
          value: TvSettingsScreen._colorName(background),
          color: background,
          onActivate: () => TvSettingsScreen._showSubtitleColorPicker(
            context,
            settings,
            foreground: false,
          ),
        ),
        _TvSubtitleOption(
          label: 'Text weight',
          value: weight,
          onActivate: () => TvSettingsScreen._showSubtitleWeightPicker(
            context,
            settings,
          ),
        ),
      ],
    );
  }
}

class _TvSubtitleOption extends StatelessWidget {
  const _TvSubtitleOption({
    required this.label,
    required this.value,
    required this.onActivate,
    this.color,
    this.autofocus = false,
  });

  final String label;
  final String value;
  final VoidCallback onActivate;
  final Color? color;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TvFocusable(
        semanticLabel: '$label, $value',
        autofocus: autofocus,
        onActivate: onActivate,
        focusScale: 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: TvDesign.surfaceFor(context, emphasis: 0.012),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: palette.hairline),
          ),
          child: Row(
            children: <Widget>[
              if (color != null) ...<Widget>[
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: palette.foreground.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: palette.foreground,
                    fontFamily: 'FigtreeSB',
                    fontSize: 21,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: 20,
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                PhosphorIcons.caretRight(),
                color: palette.mutedText,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
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
            semanticLabel:
                '${TvSettingsScreen._colorThemeLabel(appColor.index)} color theme'
                '${selectedIndex == appColor.index ? ', selected' : ''}',
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
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onActivate;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return TvListRow(
      focusNode: focusNode,
      label: label,
      value: value,
      icon: icon,
      onActivate: onActivate,
    );
  }
}
