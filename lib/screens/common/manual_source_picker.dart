import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../tv/focus/tv_focusable.dart';
import '../../tv/focus/tv_keymap.dart';
import '../../video_providers/names.dart';
import 'download_selection_sheets.dart';

/// Asks the user to pick one provider manually before playback starts.
///
/// Shown when the "Auto load sources" setting is disabled. Returns the chosen
/// provider, or null when the picker was dismissed without a choice.
Future<VideoProvider?> showPlaybackProviderPicker({
  required BuildContext context,
  required List<VideoProvider> providers,
  required bool useTvPlayer,
}) {
  if (useTvPlayer) {
    return showDialog<VideoProvider>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TvProviderPickerDialog(providers: providers),
    );
  }
  return DownloadSelectionSheets.showProvider(
    context,
    providers: providers,
    title: tr('choose_playback_provider'),
    subtitle: tr('choose_playback_provider_description'),
  );
}

class _TvProviderPickerDialog extends StatefulWidget {
  const _TvProviderPickerDialog({required this.providers});

  final List<VideoProvider> providers;

  @override
  State<_TvProviderPickerDialog> createState() =>
      _TvProviderPickerDialogState();
}

class _TvProviderPickerDialogState extends State<_TvProviderPickerDialog> {
  final FocusScopeNode _focusScopeNode =
      FocusScopeNode(debugLabel: 'TV provider picker');

  @override
  void dispose() {
    _focusScopeNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: colors.surface,
      insetPadding: const EdgeInsets.all(72),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: MediaQuery.sizeOf(context).height * .78,
        ),
        child: FocusScope(
          node: _focusScopeNode,
          child: TvKeymap(
            onBack: () => Navigator.of(context).pop(),
            child: Padding(
              padding: const EdgeInsets.all(36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    tr('choose_playback_provider'),
                    style: TextStyle(
                      color: colors.onSurface,
                      fontFamily: 'FigtreeSB',
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    tr('choose_playback_provider_description'),
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontFamily: 'Figtree',
                      fontSize: 21,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Flexible(
                    child: SingleChildScrollView(
                      clipBehavior: Clip.hardEdge,
                      child: FocusTraversalGroup(
                        policy: ReadingOrderTraversalPolicy(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            for (var index = 0;
                                index < widget.providers.length;
                                index++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildProviderRow(
                                  colors,
                                  widget.providers[index],
                                  autofocus: index == 0,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProviderRow(
    ColorScheme colors,
    VideoProvider provider, {
    required bool autofocus,
  }) {
    return TvFocusable(
      semanticLabel: provider.displayName,
      autofocus: autofocus,
      focusScale: 1.02,
      onActivate: () => Navigator.of(context).pop(provider),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                PhosphorIcons.playCircle(),
                size: 22,
                color: colors.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    provider.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontFamily: 'FigtreeSB',
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    provider.contentDescription,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontFamily: 'Figtree',
                      fontSize: 17,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              PhosphorIcons.caretRight(),
              size: 20,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
