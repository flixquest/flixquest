import 'package:flutter/material.dart';

import 'app_palette.dart';

/// A Top 10 row's rank: a tall hollow number beside the poster, its right
/// edge tucked under the artwork the way Netflix draws it.
///
/// It is drawn rather than laid out as text, so the digits can sit on the
/// poster's bottom edge and run under it without pushing it along.
class TopTenRank extends StatelessWidget {
  const TopTenRank({
    required this.rank,
    required this.cardWidth,
    required this.height,
    this.bottomInset = 0,
    this.dimmed = false,
    super.key,
  });

  final int rank;

  /// The poster's width, which the number is sized from.
  final double cardWidth;

  /// The height of the item beside it, so the two line up in the row.
  final double height;

  /// Space below the poster's bottom edge within [height], such as a focus
  /// ring's padding.
  final double bottomInset;
  final bool dimmed;

  /// How far the digits run under the poster, as a fraction of [cardWidth].
  static const _tuck = 0.14;

  /// The room a rank takes ahead of its poster. Two digits need more, even
  /// drawn tighter.
  static double extentFor(int rank, double cardWidth) =>
      cardWidth * (rank >= 10 ? 1.12 : 0.7);

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    // A grey between the page and the text, so the hollow number reads as an
    // outline in any theme; stepping back, it sinks toward the page.
    final outlineColor = Color.lerp(
      palette.page,
      palette.foreground,
      dimmed ? 0.16 : 0.42,
    )!;
    return SizedBox(
      width: extentFor(rank, cardWidth),
      height: height,
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: outlineColor),
          duration: const Duration(milliseconds: 200),
          builder: (_, outline, __) => CustomPaint(
            painter: _RankPainter(
              rank: rank,
              fontSize: cardWidth * 1.5,
              tuck: cardWidth * _tuck,
              bottomInset: bottomInset,
              fill: palette.page,
              outline: outline ?? outlineColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _RankPainter extends CustomPainter {
  const _RankPainter({
    required this.rank,
    required this.fontSize,
    required this.tuck,
    required this.bottomInset,
    required this.fill,
    required this.outline,
  });

  final int rank;
  final double fontSize;
  final double tuck;
  final double bottomInset;

  /// Inside the digits: the page, so they read as hollow.
  final Color fill;
  final Color outline;

  TextPainter _layout(TextStyle style) => TextPainter(
        text: TextSpan(text: '$rank', style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final base = TextStyle(
      fontFamily: 'FigtreeBold',
      fontSize: fontSize,
      height: 1,
      // Pulls "10" together so it stays close to a single digit's width.
      letterSpacing: rank >= 10 ? -fontSize * 0.1 : 0,
    );
    final fillText = _layout(base.copyWith(color: fill));
    final stroke = _layout(base.copyWith(
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (fontSize * 0.018).clamp(2.0, 4.0)
        ..strokeJoin = StrokeJoin.round
        ..color = outline,
    ));
    final baseline = fillText.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    final offset = Offset(
      size.width + tuck - fillText.width,
      size.height - bottomInset - baseline,
    );
    fillText.paint(canvas, offset);
    stroke.paint(canvas, offset);
    fillText.dispose();
    stroke.dispose();
  }

  @override
  bool shouldRepaint(_RankPainter oldDelegate) =>
      rank != oldDelegate.rank ||
      fontSize != oldDelegate.fontSize ||
      tuck != oldDelegate.tuck ||
      bottomInset != oldDelegate.bottomInset ||
      fill != oldDelegate.fill ||
      outline != oldDelegate.outline;
}
