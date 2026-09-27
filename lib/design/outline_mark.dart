import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The FlixQuest mark in outline, in [color]: what stands in for artwork
/// that isn't there, on phones and TV alike.
class OutlineMark extends StatelessWidget {
  const OutlineMark({required this.height, required this.color, super.key});

  final double height;
  final Color color;

  static const asset = 'assets/images/fq_svg.svg';

  /// A mark sized for a box whose shorter side is [side]: a third of it,
  /// kept between 16 and 64.
  static double heightFor(double side) =>
      (side.isFinite ? side * .34 : 40.0).clamp(16.0, 64.0);

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        asset,
        height: height,
        excludeFromSemantics: true,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
}
