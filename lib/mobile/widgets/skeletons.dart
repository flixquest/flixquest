import 'package:flutter/material.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import 'hero_card.dart';
import 'media_art.dart';
import 'poster_card.dart';

/// Home's shape while it loads: the hero card and two rows, breathing slowly
/// between two surface tones, as the TV's skeleton does.
class HomeSkeleton extends StatefulWidget {
  const HomeSkeleton({super.key});

  @override
  State<HomeSkeleton> createState() => _HomeSkeletonState();
}

class _HomeSkeletonState extends State<HomeSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final width = MediaQuery.sizeOf(context).width;
    final poster = posterWidth(context);
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final color = Color.lerp(
            palette.surface,
            palette.raisedSurface,
            Curves.easeInOut.transform(_pulse.value),
          )!;
          Widget block(double w, double h, {double radius = AppRadii.card}) =>
              Container(
                width: w,
                height: h,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(radius),
                ),
              );
          Widget row() => Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.rowGap),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsetsDirectional.only(start: gutter),
                      child: block(140, 16, radius: 4),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: poster / PosterCard.aspectRatio,
                      child: ListView.separated(
                        physics: const NeverScrollableScrollPhysics(),
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: gutter),
                        itemCount: 4,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, __) =>
                            block(poster, poster / PosterCard.aspectRatio),
                      ),
                    ),
                  ],
                ),
              );
          return Column(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: gutter),
                child: block(
                  double.infinity,
                  HeroCard.heightFor(width, gutter),
                  radius: AppRadii.hero,
                ),
              ),
              const SizedBox(height: AppSpace.xxl),
              row(),
              row(),
            ],
          );
        },
      ),
    );
  }
}
