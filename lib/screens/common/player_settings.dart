import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../functions/subtitle_style.dart';
import '../../mobile/widgets/page_kit.dart';
import '../../mobile/widgets/settings_kit.dart';
import '/provider/settings_provider.dart';
import 'provider_choose.dart';
import 'sublanguage_choose.dart';

class PlayerSettings extends StatefulWidget {
  const PlayerSettings({super.key});

  @override
  State<PlayerSettings> createState() => _PlayerSettingsState();
}

class _PlayerSettingsState extends State<PlayerSettings> {
  Future<void> _pickSubtitleColor({
    required Color initialColor,
    required String title,
    required ValueChanged<Color> onSaved,
  }) async {
    final picked = await showColorPickerSheet(
      context,
      initialColor: initialColor,
      title: title,
      enableAlpha: true,
    );
    if (picked != null) onSaved(picked);
  }

  void _push(Widget page) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final settingValues = Provider.of<SettingsProvider>(context);
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final backgroundColor = parseStoredSubtitleColor(
      settingValues.subtitleBackgroundColor,
      fallback: Colors.black45,
    );
    final foregroundColor = parseStoredSubtitleColor(
      settingValues.subtitleForegroundColor,
      fallback: Colors.white,
    );

    return Scaffold(
      backgroundColor: palette.page,
      appBar: PageAppBar(title: tr('player_settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              gutter,
              AppSpace.sm,
              gutter,
              AppSpace.xxxl + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              SettingsGroup(
                title: tr('subtitle'),
                children: [
                  // The sample shows real subtitle colours over a frame, on
                  // purpose.
                  Padding(
                    padding: const EdgeInsets.all(AppSpace.lg),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              'assets/images/sample_frame.jpg',
                              fit: BoxFit.cover,
                            ),
                            PositionedDirectional(
                              start: 12,
                              end: 12,
                              bottom: 12,
                              child: Text(
                                tr('sample_player_text'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  backgroundColor: backgroundColor,
                                  color: foregroundColor,
                                  fontFamily: subtitleFontFamily(
                                    settingValues.subtitleTextStyle,
                                  ),
                                  fontSize:
                                      settingValues.subtitleFontSize.toDouble(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _SliderRow(
                    icon: PhosphorIcons.textAa(),
                    label: tr('text_size'),
                    value: settingValues.subtitleFontSize,
                    min: 5,
                    max: 30,
                    onChanged: (value) =>
                        settingValues.subtitleFontSize = value,
                  ),
                  ListRow(
                    icon: PhosphorIcons.palette(),
                    label: tr('text_color'),
                    trailing: ColorDot(foregroundColor),
                    onTap: () => _pickSubtitleColor(
                      initialColor: foregroundColor,
                      title: tr('text_color'),
                      onSaved: (color) => settingValues
                          .subtitleForegroundColor = serializeSubtitleColor(
                        color,
                      ),
                    ),
                  ),
                  ListRow(
                    icon: PhosphorIcons.paintBucket(),
                    label: tr('background_color'),
                    trailing: ColorDot(backgroundColor),
                    onTap: () => _pickSubtitleColor(
                      initialColor: backgroundColor,
                      title: tr('background_color'),
                      onSaved: (color) => settingValues
                          .subtitleBackgroundColor = serializeSubtitleColor(
                        color,
                      ),
                    ),
                  ),
                  ChoiceRow<String>(
                    icon: PhosphorIcons.textB(),
                    label: tr('text_weight'),
                    value: settingValues.subtitleTextStyle,
                    options: {
                      'light': tr('light'),
                      'regular': tr('regular'),
                      'bold': tr('bold'),
                    },
                    onChanged: (value) => setState(
                      () => settingValues.subtitleTextStyle = value,
                    ),
                  ),
                  ListRow(
                    icon: PhosphorIcons.closedCaptioning(),
                    label: tr('subtitle_language'),
                    value: subtitleLanguageName(
                      settingValues.defaultSubtitleLanguage,
                    ),
                    onTap: () => _push(const SubLangChoose()),
                  ),
                  SwitchRow(
                    icon: PhosphorIcons.translate(),
                    label: tr('fetch_all_subs'),
                    value: settingValues.fetchSpecificLangSubs,
                    onChanged: (value) => setState(
                      () => settingValues.fetchSpecificLangSubs = value,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xxl),
              SettingsGroup(
                title: tr('general'),
                children: [
                  ListRow(
                    icon: PhosphorIcons.arrowsDownUp(),
                    label: tr('provider_precedence'),
                    onTap: () => _push(const ProviderChooseScreen()),
                  ),
                  SwitchRow(
                    icon: PhosphorIcons.lightning(),
                    label: tr('auto_load_sources'),
                    subtitle: tr('auto_load_sources_description'),
                    value: settingValues.autoLoadSources,
                    onChanged: (value) => setState(
                      () => settingValues.autoLoadSources = value,
                    ),
                  ),
                  SwitchRow(
                    icon: PhosphorIcons.arrowsOut(),
                    label: tr('auto_full_screen'),
                    value: settingValues.defaultViewMode,
                    onChanged: (value) => setState(
                      () => settingValues.defaultViewMode = value,
                    ),
                  ),
                  SwitchRow(
                    icon: PhosphorIcons.sparkle(),
                    label: tr('player_ambient_glow'),
                    subtitle: tr('player_ambient_glow_description'),
                    value: settingValues.playerAmbientGlowEnabled,
                    onChanged: (value) =>
                        settingValues.playerAmbientGlowEnabled = value,
                  ),
                  SwitchRow(
                    icon: PhosphorIcons.pictureInpicture(),
                    label: tr('auto_pip_on_leave'),
                    subtitle: tr('auto_pip_on_leave_description'),
                    value: settingValues.autoPipOnLeave,
                    onChanged: (value) => settingValues.autoPipOnLeave = value,
                  ),
                  SwitchRow(
                    icon: PhosphorIcons.skipForward(),
                    label: tr('enable_next_episode_button'),
                    value: settingValues.enableNextEpisodeButton,
                    onChanged: (value) => setState(
                      () => settingValues.enableNextEpisodeButton = value,
                    ),
                  ),
                  SwitchRow(
                    icon: PhosphorIcons.fastForward(),
                    label: tr('enable_skip_buttons'),
                    subtitle: tr('enable_skip_buttons_description'),
                    value: settingValues.enableIntroDbSkipButtons,
                    onChanged: (value) => setState(
                      () => settingValues.enableIntroDbSkipButtons = value,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xxl),
              SettingsGroup(
                title: tr('playback_settings_group'),
                children: [
                  ChoiceRow<int>(
                    icon: PhosphorIcons.arrowsClockwise(),
                    label: tr('seek_second'),
                    value: settingValues.defaultSeekDuration,
                    options: const {
                      5: '5s',
                      10: '10s',
                      15: '15s',
                      20: '20s',
                      30: '30s',
                    },
                    onChanged: (value) => setState(
                      () => settingValues.defaultSeekDuration = value,
                    ),
                  ),
                  ChoiceRow<int>(
                    icon: PhosphorIcons.hourglassMedium(),
                    label: tr('buffer_amount'),
                    value: settingValues.defaultMaxBufferDuration,
                    options: const {
                      15000: '15s',
                      30000: '30s',
                      45000: '45s',
                      60000: '60s',
                      90000: '90s',
                      120000: '120s',
                      150000: '150s',
                      180000: '180s',
                    },
                    onChanged: (value) => setState(
                      () => settingValues.defaultMaxBufferDuration = value,
                    ),
                  ),
                  ChoiceRow<int>(
                    icon: PhosphorIcons.filmStrip(),
                    label: tr('video_resolution'),
                    value: settingValues.defaultVideoResolution,
                    options: {
                      0: tr('auto'),
                      360: '360p',
                      480: '480p',
                      720: '720p',
                      1080: '1080p',
                    },
                    onChanged: (value) => setState(
                      () => settingValues.defaultVideoResolution = value,
                    ),
                  ),
                  ChoiceRow<int>(
                    icon: PhosphorIcons.clock(),
                    label: tr('player_time_display'),
                    value: settingValues.playerTimeDisplay,
                    options: {
                      1: tr('elapsed_total'),
                      2: tr('elapsed_remaining'),
                    },
                    onChanged: (value) => setState(
                      () => settingValues.playerTimeDisplay = value,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row with a slider under its label and the current value at the end.
/// The slider's filled part keeps the accent, as progress does.
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Column(
      children: [
        ListRow(icon: icon, label: label, value: '$value'),
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: AppSpace.sm,
            end: AppSpace.sm,
            bottom: AppSpace.sm,
          ),
          child: Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            label: '$value',
            inactiveColor: palette.idleFill,
            onChanged: (next) => onChanged(next.round()),
          ),
        ),
      ],
    );
  }
}
