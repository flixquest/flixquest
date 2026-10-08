import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../tv/app/tv_design.dart';
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
    // TvDialog's frame, with a list of rows in place of its pill buttons.
    final palette = TvPalette.of(context);
    return Dialog(
      backgroundColor: palette.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 28),
      elevation: 24,
      shadowColor: Colors.black.withValues(alpha: 0.54),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: palette.hairline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: MediaQuery.sizeOf(context).height * .82,
        ),
        child: FocusScope(
          node: _focusScopeNode,
          child: TvKeymap(
            onBack: () => Navigator.of(context).pop(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(36, 32, 36, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    tr('choose_playback_provider'),
                    style: TextStyle(
                      color: palette.foreground,
                      fontFamily: 'FigtreeBold',
                      fontSize: 32,
                      letterSpacing: -0.45,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    tr('choose_playback_provider_description'),
                    style: TextStyle(
                      color: palette.mutedText,
                      fontFamily: 'Figtree',
                      fontSize: 20,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Flexible(
                    child: SingleChildScrollView(
                      clipBehavior: Clip.hardEdge,
                      // Room for the focused row's lift at the edges.
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: FocusTraversalGroup(
                        policy: ReadingOrderTraversalPolicy(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            for (var index = 0;
                                index < widget.providers.length;
                                index++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: _TvProviderRow(
                                  provider: widget.providers[index],
                                  autofocus: index == 0,
                                  onActivate: () => Navigator.of(context)
                                      .pop(widget.providers[index]),
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
}

/// A provider in the TV picker: its name and what it carries, turning white
/// under focus like the TV's other list rows.
class _TvProviderRow extends StatefulWidget {
  const _TvProviderRow({
    required this.provider,
    required this.onActivate,
    this.autofocus = false,
  });

  final VideoProvider provider;
  final VoidCallback onActivate;
  final bool autofocus;

  @override
  State<_TvProviderRow> createState() => _TvProviderRowState();
}

class _TvProviderRowState extends State<_TvProviderRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    final foreground = _focused ? palette.onFocus : palette.foreground;
    final secondary = _focused ? palette.onFocusMuted : palette.mutedText;
    final description = widget.provider.contentDescription;
    return TvFocusable(
      semanticLabel: widget.provider.displayName,
      autofocus: widget.autofocus,
      onActivate: widget.onActivate,
      onFocusChanged: (hasFocus) {
        if (hasFocus != _focused) setState(() => _focused = hasFocus);
      },
      focusScale: 1,
      focusColor: Colors.transparent,
      borderRadius: BorderRadius.circular(TvDesign.cardRadius),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: _focused ? palette.focusFill : palette.idleFillFaint,
          borderRadius: BorderRadius.circular(TvDesign.cardRadius),
        ),
        child: Row(
          children: <Widget>[
            Icon(PhosphorIcons.playCircle(), size: 24, color: secondary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.provider.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontFamily: 'FigtreeSB',
                      fontSize: 19,
                    ),
                  ),
                  if (description.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: secondary,
                        fontFamily: 'Figtree',
                        fontSize: 16,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(PhosphorIcons.caretRight(), size: 18, color: secondary),
          ],
        ),
      ),
    );
  }
}
