import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/vast/vast_ad_session.dart';

/// The player's controls while a video ad plays: an "Ad" label with the time
/// left, Skip once the ad allows it, an ad progress line and, on touch
/// screens, the advertiser link and a way out.
class VastAdOverlay extends StatefulWidget {
  const VastAdOverlay({
    required this.session,
    required this.television,
    this.onVisitAdvertiser,
    this.onExit,
    super.key,
  });

  final VastAdSession session;
  final bool television;

  /// Opens the advertiser page; null hides the link (always on TV).
  final ValueChanged<Uri>? onVisitAdvertiser;
  final VoidCallback? onExit;

  /// Ad progress is amber so it never reads as the content's timeline.
  static const progressColor = Color(0xFFFFC107);

  @override
  State<VastAdOverlay> createState() => _VastAdOverlayState();
}

class _VastAdOverlayState extends State<VastAdOverlay> {
  final FocusNode _skipFocus = FocusNode(debugLabel: 'vast-skip');
  bool _skipWasAvailable = false;

  /// OK was pressed before Skip appeared: the countdown is highlighted.
  bool _waitHint = false;
  Timer? _waitHintTimer;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
  }

  @override
  void didUpdateWidget(VastAdOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      oldWidget.session.removeListener(_onSession);
      widget.session.addListener(_onSession);
    }
  }

  void _onSession() {
    final canSkip = widget.session.value.canSkip;
    // On TV the remote must land on Skip the moment it appears.
    if (canSkip && !_skipWasAvailable && widget.television) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _skipFocus.requestFocus();
      });
    }
    _skipWasAvailable = canSkip;
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    _waitHintTimer?.cancel();
    _skipFocus.dispose();
    super.dispose();
  }

  static final _arrowKeys = {
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
  };

  static final _selectKeys = {
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.gameButtonA,
  };

  /// The remote has one control here, Skip. Arrows and OK find it once it is
  /// there; before that OK highlights the countdown instead of doing nothing.
  /// Back stays with the player, which leaves.
  KeyEventResult _onRemoteKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final arrow = _arrowKeys.contains(key);
    if (!arrow && !_selectKeys.contains(key)) return KeyEventResult.ignored;
    if (widget.session.value.canSkip) {
      if (_skipFocus.hasPrimaryFocus) {
        return arrow ? KeyEventResult.handled : KeyEventResult.ignored;
      }
      _skipFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (!arrow && event is KeyDownEvent) {
      _waitHintTimer?.cancel();
      setState(() => _waitHint = true);
      _waitHintTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _waitHint = false);
      });
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.television ? 1.25 : 1.0;
    final inset = widget.television ? 32.0 : 12.0;
    final clickThrough = widget.session.ad.clickThrough;
    final overlay = ValueListenableBuilder<VastAdState>(
      valueListenable: widget.session,
      builder: (context, state, _) => Stack(
        fit: StackFit.expand,
        children: [
          // Taps on the picture do nothing: an ad opens only from its link.
          GestureDetector(behavior: HitTestBehavior.opaque),
          if (state.buffering && !state.ended)
            const Center(
              child: SizedBox.square(
                dimension: 36,
                child: CircularProgressIndicator(
                    strokeWidth: 3, color: Colors.white),
              ),
            ),
          SafeArea(
            minimum: EdgeInsets.all(inset),
            child: Stack(children: [
              if (!widget.television && widget.onExit != null)
                Positioned(
                  top: 0,
                  left: 0,
                  child: _RoundButton(
                    icon: Icons.arrow_back,
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: widget.onExit!,
                  ),
                ),
              if (!widget.television &&
                  widget.onVisitAdvertiser != null &&
                  clickThrough != null &&
                  state.started)
                Positioned(
                  top: 0,
                  right: 0,
                  child: _Pill(
                    scale: scale,
                    onPressed: () => _visit(),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Visit advertiser'),
                      SizedBox(width: 6),
                      Icon(Icons.north_east, size: 16, color: Colors.white),
                    ]),
                  ),
                ),
              Positioned(
                left: 0,
                bottom: 12,
                child: _Pill(
                  scale: scale,
                  emphasized: _waitHint && !state.skippable,
                  child: Text(
                    state.started ? 'Ad · ${_clock(state.remaining)}' : 'Ad',
                    style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                ),
              ),
              if (state.skippable && state.started)
                Positioned(
                  right: 0,
                  bottom: 12,
                  child: state.canSkip
                      ? _Pill(
                          scale: scale,
                          focusNode: _skipFocus,
                          emphasized: true,
                          onPressed: widget.session.requestSkip,
                          child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Skip ad'),
                                SizedBox(width: 6),
                                Icon(Icons.skip_next_rounded,
                                    size: 20, color: Colors.white),
                              ]),
                        )
                      : _Pill(
                          scale: scale,
                          emphasized: _waitHint,
                          child: Text(
                            'Skip in ${state.skipCountdown}',
                            style: const TextStyle(
                                fontFeatures: [FontFeature.tabularFigures()]),
                          ),
                        ),
                ),
            ]),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: LinearProgressIndicator(
              value: state.progress,
              minHeight: 3,
              color: VastAdOverlay.progressColor,
              backgroundColor: Colors.white24,
            ),
          ),
        ],
      ),
    );
    if (!widget.television) return overlay;
    return Focus(autofocus: true, onKeyEvent: _onRemoteKey, child: overlay);
  }

  void _visit() {
    final url = widget.session.click();
    if (url != null) widget.onVisitAdvertiser?.call(url);
  }

  static String _clock(Duration value) {
    final seconds = (value.inMilliseconds / 1000).ceil();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

class _Pill extends StatefulWidget {
  const _Pill({
    required this.child,
    required this.scale,
    this.onPressed,
    this.focusNode,
    this.emphasized = false,
  });

  final Widget child;
  final double scale;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;
  final bool emphasized;

  @override
  State<_Pill> createState() => _PillState();
}

class _PillState extends State<_Pill> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onPressed != null;
    final content = DefaultTextStyle(
      style: TextStyle(
        color: Colors.white,
        fontSize: 13 * widget.scale,
        fontFamily: 'FigtreeSB',
        height: 1.1,
      ),
      child: IconTheme(
        data: IconThemeData(color: Colors.white, size: 18 * widget.scale),
        child: widget.child,
      ),
    );
    final pill = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.symmetric(
          horizontal: 12 * widget.scale, vertical: 8 * widget.scale),
      decoration: BoxDecoration(
        color: _focused
            ? Colors.white.withValues(alpha: 0.28)
            : Colors.black.withValues(alpha: widget.emphasized ? 0.72 : 0.55),
        borderRadius: BorderRadius.circular(6 * widget.scale),
        border: Border.all(
          color: _focused
              ? Colors.white
              : Colors.white.withValues(alpha: widget.emphasized ? 0.6 : 0.0),
          width: _focused ? 2 : 1,
        ),
      ),
      child: content,
    );
    if (!interactive) return pill;
    return FocusableActionDetector(
      focusNode: widget.focusNode,
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => widget.onPressed!()),
      },
      child: Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: pill,
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: tooltip,
          color: Colors.white,
          icon: Icon(icon),
          onPressed: onPressed,
        ),
      );
}
