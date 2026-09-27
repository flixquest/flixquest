import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'app_palette.dart';
import 'app_tokens.dart';

/// A page's shape while it loads: quiet blocks where its content will go,
/// breathing slowly between two surface tones, as the TV's skeleton does.
///
/// One pulse drives every [SkeletonBlock] and [SkeletonTint] beneath it, and
/// every pulse keeps the same beat, so skeletons mounted at different times
/// never breathe out of step. With animations turned off, the tone holds
/// still.
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({required this.child, this.label, super.key});

  final Widget child;

  /// Read in place of the blocks by screen readers; the blocks themselves
  /// are silent.
  final String? label;

  /// The pulse's current tone for [context]: the surface colour at rest,
  /// the raised surface at its peak. Outside a pulse, the raised surface.
  static Color colorOf(BuildContext context) {
    final palette = AppPalette.of(context);
    final tone =
        context.dependOnInheritedWidgetOfExactType<_PulseTone>()?.notifier;
    if (tone == null) return palette.raisedSurface;
    return Color.lerp(palette.surface, palette.raisedSurface, tone.value)!;
  }

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  // One clock for the whole app, so every pulse is at the same point.
  static final Stopwatch _clock = Stopwatch()..start();
  static const _half = 1100;

  static double _now() {
    final ms = _clock.elapsedMilliseconds % (_half * 2);
    final t = ms < _half ? ms / _half : (_half * 2 - ms) / _half;
    return Curves.easeInOut.transform(t);
  }

  final ValueNotifier<double> _tone = ValueNotifier<double>(_now());
  late final Ticker _ticker = createTicker((_) => _tone.value = _now());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _ticker.stop();
      _tone.value = .5;
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _tone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blocks = ExcludeSemantics(
      child: _PulseTone(notifier: _tone, child: widget.child),
    );
    final label = widget.label;
    return label == null ? blocks : Semantics(label: label, child: blocks);
  }
}

class _PulseTone extends InheritedNotifier<ValueNotifier<double>> {
  const _PulseTone({required super.notifier, required super.child});
}

/// One placeholder shape: a rounded block, or a circle for faces and
/// avatars. Outside a [SkeletonPulse] it keeps the pulse's beat on its own.
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({
    this.width = double.infinity,
    this.height,
    this.radius = AppRadii.card,
    this.circle = false,
    super.key,
  });

  /// A line of text [width] wide at [height], with a text line's softer
  /// corners.
  const SkeletonBlock.line({
    this.width = double.infinity,
    this.height = 12,
    super.key,
  })  : radius = 4,
        circle = false;

  final double width;

  /// Null fills the height it's given, as inside an [AspectRatio].
  final double? height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final block = Builder(
      builder: (context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: SkeletonPulse.colorOf(context),
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.circular(radius),
        ),
      ),
    );
    return _pulsing(context) ? block : SkeletonPulse(child: block);
  }
}

bool _pulsing(BuildContext context) =>
    context.getInheritedWidgetOfExactType<_PulseTone>() != null;

/// Paints [child]'s opaque shapes in the pulse's tone, for loading layouts
/// drawn as plain shapes. Like [SkeletonBlock], it pulses on its own outside
/// a [SkeletonPulse].
class SkeletonTint extends StatelessWidget {
  const SkeletonTint({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tinted = Builder(
      builder: (context) => ColorFiltered(
        colorFilter: ColorFilter.mode(
          SkeletonPulse.colorOf(context),
          BlendMode.srcIn,
        ),
        child: child,
      ),
    );
    return _pulsing(context) ? tinted : SkeletonPulse(child: tinted);
  }
}

/// [skeleton] while [loading], then [child], faded in over 280 ms so the
/// page settles into place instead of jumping.
class SkeletonSwitcher extends StatelessWidget {
  const SkeletonSwitcher({
    required this.loading,
    required this.skeleton,
    required this.child,
    this.alignment = AlignmentDirectional.topStart,
    super.key,
  });

  final bool loading;
  final Widget skeleton;
  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (current, previous) => Stack(
          alignment: alignment,
          children: <Widget>[...previous, if (current != null) current],
        ),
        child: KeyedSubtree(
          key: ValueKey<bool>(loading),
          child: loading ? skeleton : child,
        ),
      );
}
