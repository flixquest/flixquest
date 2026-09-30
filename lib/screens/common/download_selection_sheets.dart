import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../mobile/widgets/page_kit.dart';
import '../../video_providers/names.dart';
import 'player/player_sheet_ui.dart';

/// The choices before a download or a manual playback: which provider, then
/// which resolution. Plain rows in the app's palette, so they follow the
/// theme; opened from the player ([inPlayer]) they take the player's.
abstract final class DownloadSelectionSheets {
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
