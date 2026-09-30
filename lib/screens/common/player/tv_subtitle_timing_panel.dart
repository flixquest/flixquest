import 'package:better_player_plus/better_player_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Subtitle timing on television: a card along the top of the picture, so
/// the captions at the bottom stay in view and can be matched to the
/// dialogue while playback carries on. Left and Right on the dial move the
/// captions earlier or later; holding either speeds up.
class TvSubtitleTimingPanel extends StatefulWidget {
  const TvSubtitleTimingPanel({
    required this.controller,
    required this.onClose,
    this.accentColor = Colors.deepOrange,
    super.key,
  });

  final BetterPlayerController controller;
  final VoidCallback onClose;
  final Color accentColor;

  static const fineStep = Duration(milliseconds: 100);
  static const coarseStep = Duration(milliseconds: 500);
  static const limit = Duration(seconds: 10);

  @override
  State<TvSubtitleTimingPanel> createState() => _TvSubtitleTimingPanelState();
}

class _TvSubtitleTimingPanelState extends State<TvSubtitleTimingPanel> {
  final _scope = FocusScopeNode(debugLabel: 'TV subtitle timing');
  final _dial = FocusNode(debugLabel: 'TV subtitle timing dial');
  final _reset = FocusNode(debugLabel: 'TV subtitle timing reset');
  final _done = FocusNode(debugLabel: 'TV subtitle timing done');
  int _repeats = 0;

  @override
  void initState() {
    super.initState();
    // The player hides its controls as this opens, which pulls focus to the
    // picture; take it back once that has happened.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _dial.requestFocus();
    });
  }

  @override
  void dispose() {
    _dial.dispose();
    _reset.dispose();
    _done.dispose();
    _scope.dispose();
    super.dispose();
  }

  void _setOffset(Duration offset) {
    final limit = TvSubtitleTimingPanel.limit.inMilliseconds;
    final milliseconds = offset.inMilliseconds.clamp(-limit, limit);
    widget.controller.setSubtitleOffset(Duration(milliseconds: milliseconds));
  }

  KeyEventResult _handleDialKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final direction = key == LogicalKeyboardKey.arrowLeft
        ? -1
        : key == LogicalKeyboardKey.arrowRight
            ? 1
            : 0;
    if (direction == 0) return KeyEventResult.ignored;
    // A tap is a tenth of a second; a held key moves in half seconds after
    // a moment, so the whole range is a couple of seconds away.
    _repeats = event is KeyRepeatEvent ? _repeats + 1 : 0;
    final step = _repeats > 8
        ? TvSubtitleTimingPanel.coarseStep
        : TvSubtitleTimingPanel.fineStep;
    _setOffset(widget.controller.subtitleOffset + step * direction);
    return KeyEventResult.handled;
  }

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      if (event is KeyDownEvent) widget.onClose();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_dial.hasFocus) _reset.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (!_dial.hasFocus) _dial.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_done.hasFocus) _reset.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (_reset.hasFocus) _done.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      node: _scope,
      onKeyEvent: _handleKey,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Only the top of the picture is shaded; the captions stay clear.
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [Color(0xcc000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(48, 30, 48, 30),
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: 560,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                decoration: BoxDecoration(
                  color: BetterPlayerTvPanelColors.of(context).panel,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ValueListenableBuilder<Duration>(
                  valueListenable: widget.controller.subtitleOffsetListenable,
                  builder: (context, offset, _) => _content(offset),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(Duration offset) {
    final colors = BetterPlayerTvPanelColors.of(context);
    final status = offset == Duration.zero
        ? tr('subtitle_timing_synced')
        : tr(offset.isNegative ? 'subtitle_earlier' : 'subtitle_later');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(PhosphorIcons.timer(), color: colors.muted, size: 18),
            const SizedBox(width: 8),
            Text(
              tr('subtitle_timing').toUpperCase(),
              style: TextStyle(
                color: colors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _TimingDial(
          focusNode: _dial,
          offset: offset,
          status: status,
          accentColor: widget.accentColor,
          onKeyEvent: _handleDialKey,
        ),
        const SizedBox(height: 12),
        Text(
          tr('subtitle_timing_help'),
          style: TextStyle(
            color: colors.muted,
            fontSize: 13,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _PanelButton(
              key: const Key('tv_subtitle_timing_reset'),
              focusNode: _reset,
              icon: PhosphorIcons.arrowCounterClockwise(),
              label: tr('subtitle_timing_reset'),
              onPressed: () => _setOffset(Duration.zero),
            ),
            const SizedBox(width: 10),
            _PanelButton(
              key: const Key('tv_subtitle_timing_done'),
              focusNode: _done,
              icon: PhosphorIcons.check(),
              label: tr('close'),
              onPressed: widget.onClose,
            ),
          ],
        ),
      ],
    );
  }
}

/// The offset, large, between Earlier and Later arrows, over a track from
/// −10s to +10s filled from the centre. Filled with the page's ink under
/// focus, like every focused thing on the TV.
class _TimingDial extends StatefulWidget {
  const _TimingDial({
    required this.focusNode,
    required this.offset,
    required this.status,
    required this.accentColor,
    required this.onKeyEvent,
  });

  final FocusNode focusNode;
  final Duration offset;
  final String status;
  final Color accentColor;
  final FocusOnKeyEventCallback onKeyEvent;

  @override
  State<_TimingDial> createState() => _TimingDialState();
}

class _TimingDialState extends State<_TimingDial> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = BetterPlayerTvPanelColors.of(context);
    final foreground = _focused ? colors.onFocus : colors.foreground;
    final muted = _focused ? colors.onFocusMuted : colors.muted;
    final limit = TvSubtitleTimingPanel.limit.inMilliseconds;
    final atMinimum = widget.offset.inMilliseconds <= -limit;
    final atMaximum = widget.offset.inMilliseconds >= limit;
    Widget arrow(IconData icon, String label, bool atEnd) => Opacity(
          opacity: atEnd ? .3 : 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foreground, size: 26),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(color: muted, fontSize: 12)),
            ],
          ),
        );
    return Semantics(
      slider: true,
      label: tr('subtitle_timing'),
      value: _offsetValue(widget.offset),
      child: Focus(
        focusNode: widget.focusNode,
        onKeyEvent: widget.onKeyEvent,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: _focused
                ? colors.focusFill
                : colors.foreground.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  arrow(PhosphorIconsBold.caretLeft, tr('subtitle_earlier'),
                      atMinimum),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          _offsetValue(widget.offset),
                          key: const Key('tv_subtitle_timing_value'),
                          style: TextStyle(
                            color: foreground,
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          widget.status,
                          style: TextStyle(color: muted, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  arrow(PhosphorIconsBold.caretRight, tr('subtitle_later'),
                      atMaximum),
                ],
              ),
              const SizedBox(height: 14),
              _TimingTrack(
                fraction: widget.offset.inMilliseconds / limit,
                fill: _focused ? colors.onFocus : widget.accentColor,
                track: _focused ? colors.onFocusTrack : colors.track,
              ),
              const SizedBox(height: 6),
              DefaultTextStyle(
                style: TextStyle(color: muted, fontSize: 11),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text('−10s'), Text('0s'), Text('+10s')],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A thin track with a centre tick, filled from the centre to [fraction]
/// (−1 to 1) and capped with a knob.
class _TimingTrack extends StatelessWidget {
  const _TimingTrack({
    required this.fraction,
    required this.fill,
    required this.track,
  });

  final double fraction;
  final Color fill;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final value = fraction.clamp(-1.0, 1.0);
    return SizedBox(
      height: 14,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final half = constraints.maxWidth / 2;
          final knob = half + half * value;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 5,
                height: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: track,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Positioned(
                left: half - 1,
                top: 1,
                width: 2,
                height: 12,
                child: ColoredBox(color: track),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 120),
                left: value < 0 ? knob : half,
                width: (knob - half).abs(),
                top: 5,
                height: 4,
                child: ColoredBox(color: fill),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 120),
                left: knob - 7,
                top: 0,
                width: 14,
                height: 14,
                child: DecoratedBox(
                  decoration:
                      BoxDecoration(color: fill, shape: BoxShape.circle),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A panel action: translucent at rest, filled with ink under focus.
class _PanelButton extends StatefulWidget {
  const _PanelButton({
    required this.focusNode,
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final FocusNode focusNode;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  State<_PanelButton> createState() => _PanelButtonState();
}

class _PanelButtonState extends State<_PanelButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = BetterPlayerTvPanelColors.of(context);
    final foreground = _focused ? colors.onFocus : colors.foreground;
    return FocusableActionDetector(
      focusNode: widget.focusNode,
      onFocusChange: (focused) => setState(() => _focused = focused),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _focused ? colors.focusFill : colors.idleFill,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: foreground, size: 20),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _offsetValue(Duration offset) {
  if (offset == Duration.zero) return '0.0s';
  final seconds = offset.inMilliseconds / 1000;
  final sign = seconds > 0 ? '+' : '−';
  return '$sign${seconds.abs().toStringAsFixed(1)}s';
}
