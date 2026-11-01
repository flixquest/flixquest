import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/tv_design.dart';
import '../focus/tv_keymap.dart';
import 'tv_pill_button.dart';

/// Shows [text] to read in full, such as a biography.
Future<void> showTvReaderDialog({
  required BuildContext context,
  required String title,
  required String text,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => TvReaderDialog(title: title, text: text),
  );
}

/// Long text in a dialog the remote can read through.
///
/// [TvDialog] scrolls to keep its focused button in view, which on a long
/// text would open at the end. Here Close holds focus the whole time while
/// Up and Down scroll the text; OK or Back closes.
class TvReaderDialog extends StatefulWidget {
  const TvReaderDialog({required this.title, required this.text, super.key});

  final String title;
  final String text;

  @override
  State<TvReaderDialog> createState() => _TvReaderDialogState();
}

class _TvReaderDialogState extends State<TvReaderDialog> {
  final ScrollController _scroll = ScrollController();
  bool _scrollable = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    final up = key == LogicalKeyboardKey.arrowUp;
    if (!up && key != LogicalKeyboardKey.arrowDown) {
      return KeyEventResult.ignored;
    }
    // Held keys repeat; each step scrolls on.
    if (event is KeyUpEvent) return KeyEventResult.handled;
    if (!_scroll.hasClients) return KeyEventResult.handled;
    final position = _scroll.position;
    final step = position.viewportDimension * 0.6;
    final target = (position.pixels + (up ? -step : step))
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
    return KeyEventResult.handled;
  }

  bool _syncScrollable(ScrollMetricsNotification notification) {
    final scrollable = notification.metrics.maxScrollExtent > 0;
    if (scrollable != _scrollable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _scrollable = scrollable);
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
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
        constraints: const BoxConstraints(maxWidth: 760),
        child: FocusScope(
          child: TvKeymap(
            onBack: () => Navigator.of(context).pop(),
            child: Focus(
              canRequestFocus: false,
              skipTraversal: true,
              onKeyEvent: _handleKey,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.foreground,
                        fontFamily: 'FigtreeBold',
                        fontSize: 30,
                        letterSpacing: -0.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: NotificationListener<ScrollMetricsNotification>(
                        onNotification: _syncScrollable,
                        child: SingleChildScrollView(
                          controller: _scroll,
                          child: Text(
                            widget.text,
                            style: TextStyle(
                              color: palette.secondaryText,
                              fontFamily: 'Figtree',
                              fontSize: 19,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: <Widget>[
                        TvPillButton(
                          label: tr('close'),
                          autofocus: true,
                          prominent: true,
                          height: 48,
                          scrollAlignment: null,
                          onActivate: () => Navigator.of(context).pop(),
                        ),
                        if (_scrollable) ...<Widget>[
                          const SizedBox(width: 18),
                          Flexible(
                            child: Text(
                              tr('tv_reader_scroll_hint'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.mutedText,
                                fontFamily: 'Figtree',
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
