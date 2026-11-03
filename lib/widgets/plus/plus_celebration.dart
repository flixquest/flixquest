import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../presentation/billing/plus_controller.dart';
import 'plus_format.dart';
import 'plus_visuals.dart';

/// The moment Plus starts in this session (a payment confirms, a code is
/// redeemed): an aurora bloom, a burst of foil confetti and the date ads
/// stay away until. It sits above the navigator, closes itself after a few
/// seconds and on any tap or key, and never shows to a member who simply
/// opens the app.
class PlusCelebration extends StatefulWidget {
  const PlusCelebration({this.television = false, super.key});

  final bool television;

  @override
  State<PlusCelebration> createState() => _PlusCelebrationState();
}

class _PlusCelebrationState extends State<PlusCelebration>
    with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _burst = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600));
  final FocusNode _focus = FocusNode(debugLabel: 'Plus celebration');
  PlusController? _plus;
  Timer? _autoClose;
  FocusNode? _returnFocus;
  bool _showing = false;
  DateTime? _until;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final plus = Provider.of<PlusController?>(context);
    _plus = plus;
    if (plus != null && plus.celebrationPending && !_showing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _show());
    }
  }

  void _show() {
    final plus = _plus;
    if (!mounted || plus == null || _showing || !plus.celebrationPending) {
      return;
    }
    plus.takeCelebration();
    unawaited(prepareDates(context));
    HapticFeedback.mediumImpact();
    setState(() {
      _showing = true;
      _until = plus.activeUntil;
    });
    _entrance.forward(from: 0);
    _burst.forward(from: 0);
    _returnFocus = FocusManager.instance.primaryFocus;
    _focus.requestFocus();
    _autoClose?.cancel();
    _autoClose = Timer(const Duration(milliseconds: 5200), _close);
  }

  Future<void> _close() async {
    _autoClose?.cancel();
    if (!_showing || !mounted) return;
    await _entrance.reverse();
    if (!mounted) return;
    setState(() => _showing = false);
    // The remote keeps its place on the screen underneath.
    final previous = _returnFocus;
    _returnFocus = null;
    if (previous != null && previous.context != null) previous.requestFocus();
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    _entrance.dispose();
    _burst.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showing) return const SizedBox.shrink();
    final until = _until;
    final scale = widget.television ? 1.25 : 1.0;
    // Above the navigator there is no Material, so text would fall back to
    // the yellow-underlined debug style.
    return Material(
      type: MaterialType.transparency,
      child: Focus(
        focusNode: _focus,
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent) unawaited(_close());
          return KeyEventResult.handled;
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _close,
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _entrance, curve: Curves.easeOut),
            child: Semantics(
              liveRegion: true,
              label: tr('plus_welcome_title'),
              child: PlusAurora(
                energy: 1.5,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    const ColoredBox(color: Color(0x66000000)),
                    IgnorePointer(
                      child: CustomPaint(painter: _ConfettiPainter(_burst)),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            ScaleTransition(
                              scale: CurvedAnimation(
                                  parent: _entrance, curve: Curves.elasticOut),
                              child: PlusEmblem(size: 104 * scale),
                            ),
                            SizedBox(height: 28 * scale),
                            PlusWordmark(size: 26 * scale),
                            SizedBox(height: 18 * scale),
                            Text(
                              tr('plus_welcome_title'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'FigtreeBold',
                                fontSize: 28 * scale,
                                height: 1.15,
                                letterSpacing: -.5,
                                color: PlusColors.ink,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              until == null
                                  ? tr('plus_welcome_body')
                                  : tr('plus_welcome_until',
                                      args: [formatDay(context, until)]),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Figtree',
                                fontSize: 15 * scale,
                                height: 1.4,
                                color: PlusColors.mutedInk,
                              ),
                            ),
                            SizedBox(height: 30 * scale),
                            Text(
                              widget.television
                                  ? tr('plus_press_any_key')
                                  : tr('plus_tap_to_continue'),
                              style: TextStyle(
                                fontFamily: 'FigtreeSB',
                                fontSize: 12 * scale,
                                letterSpacing: 1.2,
                                color: PlusColors.mutedInk,
                              ),
                            ),
                          ],
                        ),
                      ),
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

/// Foil confetti thrown from the centre, falling under gravity.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.progress) : super(repaint: progress);

  final Animation<double> progress;

  static final List<_Piece> _pieces = List<_Piece>.generate(84, (i) {
    final random = math.Random(i * 7919);
    return _Piece(
      angle: random.nextDouble() * 2 * math.pi,
      speed: .45 + random.nextDouble() * .7,
      spin: (random.nextDouble() - .5) * 14,
      size: 4 + random.nextDouble() * 6,
      color: const <Color>[
        PlusColors.gold,
        PlusColors.coral,
        PlusColors.violet,
        PlusColors.teal,
        PlusColors.ink,
      ][i % 5],
      round: i % 3 == 0,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t <= 0 || t >= 1) return;
    final origin = Offset(size.width / 2, size.height * .42);
    final reach = math.max(size.width, size.height) * .62;
    final fade = t < .75 ? 1.0 : (1 - t) / .25;
    final paint = Paint();
    for (final piece in _pieces) {
      final travel = Curves.easeOutCubic.transform(t) * reach * piece.speed;
      final fall = t * t * size.height * .35;
      final position = origin +
          Offset(math.cos(piece.angle) * travel,
              math.sin(piece.angle) * travel + fall);
      paint.color = piece.color.withValues(alpha: fade.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(piece.spin * t);
      if (piece.round) {
        canvas.drawCircle(Offset.zero, piece.size / 2.4, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero,
                width: piece.size,
                height: piece.size * .45),
            const Radius.circular(1),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => false;
}

class _Piece {
  const _Piece({
    required this.angle,
    required this.speed,
    required this.spin,
    required this.size,
    required this.color,
    required this.round,
  });

  final double angle;
  final double speed;
  final double spin;
  final double size;
  final Color color;
  final bool round;
}
