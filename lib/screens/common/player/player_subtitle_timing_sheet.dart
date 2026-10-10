import 'package:better_player_plus/better_player_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'player_sheet_ui.dart';

/// A content-sized timing sheet. All controls are visible on opening; only
/// unusually short screens or large text need to scroll.
class PlayerSubtitleTimingSheet extends StatelessWidget {
  const PlayerSubtitleTimingSheet({
    required this.controller,
    required this.onClose,
    super.key,
  });

  final BetterPlayerController controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 420;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: PlayerSheetScaffold(
          title: tr('subtitle_timing'),
          subtitle: tr('subtitle_timing_help'),
          subtitleMaxLines: 2,
          fitContent: true,
          actions: [
            PlayerSheetAction(
              icon: PhosphorIcons.x(),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: onClose,
            ),
          ],
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, compact ? 12 : 24),
            child: _SubtitleTimingControl(
              controller: controller,
              compact: compact,
            ),
          ),
        ),
      ),
    );
  }
}

class _SubtitleTimingControl extends StatefulWidget {
  const _SubtitleTimingControl(
      {required this.controller, this.compact = false});

  final BetterPlayerController controller;
  final bool compact;

  @override
  State<_SubtitleTimingControl> createState() => _SubtitleTimingControlState();
}

class _SubtitleTimingControlState extends State<_SubtitleTimingControl> {
  static const _step = Duration(milliseconds: 500);
  static const _minimum = Duration(seconds: -10);
  static const _limit = Duration(seconds: 10);

  late Duration _offset;

  @override
  void initState() {
    super.initState();
    _offset = widget.controller.subtitleOffset;
  }

  @override
  void didUpdateWidget(_SubtitleTimingControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _offset = widget.controller.subtitleOffset;
    }
  }

  void _setOffset(Duration offset) {
    final milliseconds = offset.inMilliseconds.clamp(
      -_limit.inMilliseconds,
      _limit.inMilliseconds,
    );
    widget.controller.setSubtitleOffset(Duration(milliseconds: milliseconds));
    setState(() => _offset = widget.controller.subtitleOffset);
  }

  @override
  Widget build(BuildContext context) {
    final colors = BetterPlayerPanelColors.of(context);
    final offset = _offset;
    final isSynced = offset == Duration.zero;
    final status = isSynced
        ? tr('subtitle_timing_synced')
        : tr(offset.isNegative ? 'subtitle_earlier' : 'subtitle_later');
    Widget step(Key key, IconData icon, String tooltip, VoidCallback? onTap) =>
        IconButton.filledTonal(
          key: key,
          tooltip: tooltip,
          onPressed: onTap,
          style: IconButton.styleFrom(
            backgroundColor: colors.raised,
            foregroundColor: colors.foreground,
            disabledBackgroundColor: colors.selectedFill,
            disabledForegroundColor: colors.muted.withValues(alpha: .5),
            fixedSize: const Size(48, 48),
          ),
          icon: Icon(icon, size: 20),
        );
    final value = AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      child: Text(
        _subtitleOffsetValue(offset),
        key: ValueKey(offset.inMilliseconds),
        style: TextStyle(
          color: colors.foreground,
          fontFamily: 'FigtreeBold',
          fontSize: widget.compact ? 32 : 40,
          height: 1.1,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    final statusLabel = Text(
      status,
      key: const Key('subtitle_timing_value'),
      style: TextStyle(color: colors.muted, fontSize: 14),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.compact)
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [value, statusLabel],
          )
        else ...[
          value,
          const SizedBox(height: 4),
          statusLabel,
        ],
        SizedBox(height: widget.compact ? 8 : 16),
        Row(
          children: [
            step(
              const Key('subtitle_timing_earlier'),
              PhosphorIcons.minus(),
              '${tr('subtitle_earlier')} 0.5s',
              offset <= _minimum ? null : () => _setOffset(offset - _step),
            ),
            Expanded(
              child: Slider(
                key: const Key('subtitle_timing_slider'),
                value: offset.inMilliseconds
                    .clamp(-_limit.inMilliseconds, _limit.inMilliseconds)
                    .toDouble(),
                min: -_limit.inMilliseconds.toDouble(),
                max: _limit.inMilliseconds.toDouble(),
                divisions: 80,
                semanticFormatterCallback: (_) => _subtitleOffsetLabel(offset),
                onChanged: (value) =>
                    _setOffset(Duration(milliseconds: value.round())),
              ),
            ),
            step(
              const Key('subtitle_timing_later'),
              PhosphorIcons.plus(),
              '${tr('subtitle_later')} 0.5s',
              offset >= _limit ? null : () => _setOffset(offset + _step),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 60),
          child: DefaultTextStyle(
            style: TextStyle(color: colors.muted, fontSize: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [Text('−10s'), Text('0s'), Text('+10s')],
            ),
          ),
        ),
        SizedBox(height: widget.compact ? 8 : 16),
        TextButton.icon(
          key: const Key('subtitle_timing_reset'),
          onPressed: isSynced ? null : () => _setOffset(Duration.zero),
          icon: Icon(PhosphorIcons.arrowCounterClockwise(), size: 18),
          label: Text(tr('subtitle_timing_reset')),
        ),
      ],
    );
  }
}

String _subtitleOffsetValue(Duration offset) {
  if (offset == Duration.zero) return '0.0s';
  final seconds = offset.inMilliseconds / 1000;
  final sign = seconds > 0 ? '+' : '−';
  return '$sign${seconds.abs().toStringAsFixed(1)}s';
}

String _subtitleOffsetLabel(Duration offset) {
  if (offset == Duration.zero) return tr('subtitle_timing_synced');
  final seconds = (offset.inMilliseconds.abs() / 1000).toStringAsFixed(2);
  final compactSeconds = seconds.replaceFirst(RegExp(r'\.?0+$'), '');
  return tr(
    offset.isNegative ? 'subtitle_offset_earlier' : 'subtitle_offset_later',
    namedArgs: {'offset': compactSeconds},
  );
}
