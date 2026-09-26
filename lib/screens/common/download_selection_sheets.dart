import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../video_providers/names.dart';

abstract final class DownloadSelectionSheets {
  static Future<VideoProvider?> showProvider(
    BuildContext context, {
    required List<VideoProvider> providers,
    String title = 'Choose download provider',
    String subtitle =
        'Select the source that should provide the offline video.',
  }) {
    return showModalBottomSheet<VideoProvider>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _DownloadChoiceSheet<VideoProvider>(
        icon: PhosphorIcons.hardDrives(),
        title: title,
        subtitle: subtitle,
        choices: [
          for (final provider in providers)
            _DownloadChoice(
              value: provider,
              title: provider.displayName,
              subtitle: provider.contentDescription,
              icon: PhosphorIcons.playCircle(),
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
  }) {
    return showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        Widget buildSheet(Map<String, int?> sizes) =>
            _DownloadChoiceSheet<String>(
              icon: PhosphorIcons.downloadSimple(),
              title: 'Choose resolution',
              subtitle: providerName == null
                  ? 'Select the quality to keep on this device.'
                  : 'Downloading from $providerName',
              choices: [
                for (final resolution in resolutions)
                  _DownloadChoice(
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
      },
    );
  }

  static String _resolutionDescription(String resolution) {
    final height = int.tryParse(
      RegExp(r'(\d{3,4})').firstMatch(resolution)?.group(1) ?? '',
    );
    if (height == null) return 'Adaptive quality selected by the provider';
    if (height >= 2160) return 'Ultra HD • largest download';
    if (height >= 1080) return 'Full HD • higher data usage';
    if (height >= 720) return 'HD • balanced quality and size';
    return 'Smaller download';
  }

  static String _sizeDescription(
    Map<String, int?> estimatedSizes,
    String resolution,
  ) {
    final bytes = estimatedSizes[resolution];
    return bytes == null ? 'Size undetermined' : '~${_formatBytes(bytes)}';
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

class _DownloadChoice<T> {
  const _DownloadChoice({
    required this.value,
    required this.title,
    this.titleDetail,
    required this.subtitle,
    required this.icon,
  });

  final T value;
  final String title;
  final String? titleDetail;
  final String subtitle;
  final IconData icon;
}

class _DownloadChoiceSheet<T> extends StatelessWidget {
  const _DownloadChoiceSheet({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.choices,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<_DownloadChoice<T>> choices;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .82,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 18),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: colors.primary),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: choices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final choice = choices[index];
                return Material(
                  color: colors.surfaceContainerHighest.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(9),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: () => Navigator.pop(context, choice.value),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: .11),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              choice.icon,
                              size: 21,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        choice.title,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    if (choice.titleDetail != null) ...[
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          choice.titleDetail!,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: colors.primary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  choice.subtitle,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            PhosphorIcons.caretRight(),
                            size: 18,
                            color: colors.onSurfaceVariant,
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
