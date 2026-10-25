import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../mobile/widgets/page_kit.dart';
import '../../models/offline_download.dart';
import '../../provider/settings_provider.dart';
import '../../video_providers/names.dart';
import 'player/player_sheet_ui.dart';

/// The download qualities, by height: ask every time, the best a source has,
/// or one height.
Map<int, String> downloadQualityOptions() => {
      SettingsProvider.downloadQualityAsk: tr('download_quality_ask'),
      0: tr('download_quality_best'),
      360: '360p',
      480: '480p',
      720: '720p',
      1080: '1080p',
    };

/// The choices before a download or a manual playback: which provider, then
/// which resolution and audio track. Plain rows in the app's palette, so they follow the
/// theme; opened from the player ([inPlayer]) they take the player's.
abstract final class DownloadSelectionSheets {
  /// Null means cancelled. A result with no track preserves the stream default.
  /// The loading sheet also lets users cancel slow manifest inspection.
  static Future<DownloadAudioSelection?> chooseAudio(
    BuildContext context, {
    required Future<List<OfflineAudioTrack>> tracks,
    bool inPlayer = false,
  }) {
    Widget builder(BuildContext context) =>
        _AudioSelectionSheet(tracks: tracks);
    return inPlayer
        ? showPlayerSheet<DownloadAudioSelection>(
            context: context, builder: builder)
        : showAppSheet<DownloadAudioSelection>(context, builder: builder);
  }

  /// The height downloads use, asked the first time and kept in settings.
  /// Null means cancelled; [SettingsProvider.downloadQualityAsk] means the
  /// provider and resolution are picked for each download.
  static Future<int?> preferredQuality(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    final saved = settings.downloadQuality;
    if (saved != null) return saved;
    final chosen = await chooseQuality(context);
    if (chosen != null) settings.downloadQuality = chosen;
    return chosen;
  }

  /// A download quality picked from [downloadQualityOptions]; without
  /// [includeAsk], for one batch of downloads that can't stop to ask.
  static Future<int?> chooseQuality(
    BuildContext context, {
    bool includeAsk = true,
  }) {
    return showAppSheet<int>(
      context,
      builder: (context) => _ChoiceSheet<int>(
        title: tr('download_quality_prompt_title'),
        subtitle: tr(includeAsk
            ? 'download_quality_prompt_description'
            : 'download_quality_batch_description'),
        choices: [
          for (final option in downloadQualityOptions().entries)
            if (includeAsk || option.key != SettingsProvider.downloadQualityAsk)
              _Choice(
                value: option.key,
                title: option.value,
                subtitle: option.key > 0
                    ? _resolutionDescription(option.value)
                    : option.key == 0
                        ? tr('download_quality_best_description')
                        : tr('download_quality_ask_description'),
                icon: PhosphorIcons.monitorPlay(),
              ),
        ],
      ),
    );
  }

  /// Whether to download every season (true) or only [seasonName] (false).
  static Future<bool?> chooseSeasonScope(
    BuildContext context, {
    required String seasonName,
    required int seasonCount,
  }) {
    return showAppSheet<bool>(
      context,
      builder: (context) => _ChoiceSheet<bool>(
        title: tr('download_series_title'),
        subtitle: tr('download_series_description'),
        choices: [
          _Choice(
            value: false,
            title: seasonName,
            subtitle: tr('download_this_season_description'),
            icon: PhosphorIcons.listNumbers(),
          ),
          _Choice(
            value: true,
            title: tr('download_all_seasons'),
            subtitle: tr('download_all_seasons_description',
                namedArgs: {'count': '$seasonCount'}),
            icon: PhosphorIcons.stack(),
          ),
        ],
      ),
    );
  }

  static Future<VideoProvider?> showProvider(
    BuildContext context, {
    required List<VideoProvider> providers,
    String? title,
    String? subtitle,
  }) {
    return showAppSheet<VideoProvider>(
      context,
      builder: (context) => _ChoiceSheet<VideoProvider>(
        title: title ?? tr('download_choose_provider'),
        subtitle: subtitle ?? tr('download_choose_provider_description'),
        choices: [
          for (final provider in providers)
            _Choice(
              value: provider,
              title: provider.displayName,
              subtitle: provider.contentDescription,
              icon: PhosphorIcons.hardDrives(),
            ),
        ],
      ),
    );
  }

  static Future<String?> showResolution(
    BuildContext context, {
    required List<String> resolutions,
    String? providerName,
    Map<String, int?> estimatedSizes = const {},
    ValueListenable<Map<String, int?>>? estimatedSizesListenable,
    bool inPlayer = false,
  }) {
    Widget builder(BuildContext context) {
      Widget buildSheet(Map<String, int?> sizes) => _ChoiceSheet<String>(
            title: tr('download_choose_resolution'),
            subtitle: providerName == null
                ? tr('download_resolution_description')
                : tr(
                    'download_from_provider',
                    namedArgs: {'name': providerName},
                  ),
            choices: [
              for (final resolution in resolutions)
                _Choice(
                  value: resolution,
                  title: resolution,
                  titleDetail: _sizeDescription(sizes, resolution),
                  subtitle: _resolutionDescription(resolution),
                  icon: PhosphorIcons.monitorPlay(),
                ),
            ],
          );
      final listenable = estimatedSizesListenable;
      return listenable == null
          ? buildSheet(estimatedSizes)
          : ValueListenableBuilder<Map<String, int?>>(
              valueListenable: listenable,
              builder: (_, sizes, __) => buildSheet(sizes),
            );
    }

    return inPlayer
        ? showPlayerSheet<String>(context: context, builder: builder)
        : showAppSheet<String>(context, builder: builder);
  }

  static String _resolutionDescription(String resolution) {
    final height = int.tryParse(
      RegExp(r'(\d{3,4})').firstMatch(resolution)?.group(1) ?? '',
    );
    if (height == null) return tr('quality_adaptive');
    if (height >= 2160) return tr('quality_uhd');
    if (height >= 1080) return tr('quality_fhd');
    if (height >= 720) return tr('quality_hd');
    return tr('quality_small');
  }

  static String _sizeDescription(
    Map<String, int?> estimatedSizes,
    String resolution,
  ) {
    final bytes = estimatedSizes[resolution];
    return bytes == null ? tr('size_unknown') : '~${_formatBytes(bytes)}';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    return '${(mb / 1024).toStringAsFixed(1)} GB';
  }
}

class DownloadAudioSelection {
  const DownloadAudioSelection(this.track);

  final OfflineAudioTrack? track;
}

class _AudioSelectionSheet extends StatefulWidget {
  const _AudioSelectionSheet({required this.tracks});

  final Future<List<OfflineAudioTrack>> tracks;

  @override
  State<_AudioSelectionSheet> createState() => _AudioSelectionSheetState();
}

class _AudioSelectionSheetState extends State<_AudioSelectionSheet> {
  List<OfflineAudioTrack>? _tracks;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tracks = await widget.tracks;
      if (!mounted) return;
      if (tracks.length <= 1) {
        Navigator.pop(context, DownloadAudioSelection(tracks.firstOrNull));
      } else {
        setState(() => _tracks = tracks);
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final tracks = _tracks;
    if (tracks != null) {
      return _ChoiceSheet<DownloadAudioSelection>(
        title: tr('download_choose_audio'),
        subtitle: tr('download_audio_description'),
        choices: [
          for (final track in tracks)
            _Choice(
              value: DownloadAudioSelection(track),
              title: track.name,
              subtitle: '',
              icon: PhosphorIcons.speakerHigh(),
            ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_failed)
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                color: palette.foreground,
                backgroundColor: palette.idleFill,
                minHeight: 3,
              ),
            ),
          const SizedBox(height: AppSpace.md),
          Text(tr(_failed ? 'download_audio_error' : 'download_audio_loading')),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('cancel')),
          ),
        ],
      ),
    );
  }
}

class _Choice<T> {
  const _Choice({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.titleDetail,
  });

  final T value;
  final String title;
  final String? titleDetail;
  final String subtitle;
  final IconData icon;
}

/// A heading and a list of plain rows: a muted icon, the choice, a detail
/// beside it (a file size), a muted line under it and a chevron.
class _ChoiceSheet<T> extends StatelessWidget {
  const _ChoiceSheet({
    required this.title,
    required this.subtitle,
    required this.choices,
  });

  final String title;
  final String subtitle;
  final List<_Choice<T>> choices;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .82,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              gutter,
              AppSpace.md,
              gutter,
              AppSpace.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppType.sectionHeader.copyWith(
                    fontFamily: AppType.bold,
                    color: palette.foreground,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  subtitle,
                  style: AppType.metadata.copyWith(
                    fontSize: 13,
                    color: palette.mutedText,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: AppSpace.xxl),
              itemCount: choices.length,
              itemBuilder: (context, index) {
                final choice = choices[index];
                return InkWell(
                  onTap: () => Navigator.pop(context, choice.value),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 60),
                    child: Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                        gutter,
                        AppSpace.md,
                        gutter - AppSpace.xs,
                        AppSpace.md,
                      ),
                      child: Row(
                        children: [
                          Icon(choice.icon, size: 22, color: palette.mutedText),
                          const SizedBox(width: AppSpace.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        choice.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppType.cardTitle.copyWith(
                                          fontSize: 15,
                                          color: palette.foreground,
                                        ),
                                      ),
                                    ),
                                    if (choice.titleDetail != null) ...[
                                      const SizedBox(width: AppSpace.sm),
                                      Text(
                                        choice.titleDetail!,
                                        maxLines: 1,
                                        style: AppType.metadata.copyWith(
                                          fontSize: 13,
                                          color: palette.secondaryText,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (choice.subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    choice.subtitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppType.metadata.copyWith(
                                      color: palette.mutedText,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpace.sm),
                          Icon(
                            PhosphorIcons.caretRight(),
                            size: 18,
                            color: palette.mutedText,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
