import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../design/skeleton.dart';
import 'hero_card.dart';
import 'media_art.dart';
import 'poster_card.dart';

/// Home's shape while it loads: the hero card and two rows, breathing slowly
/// between two surface tones, as the TV's skeleton does.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpace.gutter(context);
    final width = MediaQuery.sizeOf(context).width;
    return SkeletonPulse(
      child: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: SkeletonBlock(
              height: HeroCard.heightFor(width, gutter),
              radius: AppRadii.hero,
            ),
          ),
          const SizedBox(height: AppSpace.xxl),
          const PosterRowSkeleton(),
          const PosterRowSkeleton(),
        ],
      ),
    );
  }
}

/// A row of titles while it loads: its header and four posters. Inside a
/// [SkeletonPulse].
class PosterRowSkeleton extends StatelessWidget {
  const PosterRowSkeleton({this.header = true, super.key});

  final bool header;

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpace.gutter(context);
    final poster = posterWidth(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.rowGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (header) ...<Widget>[
            Padding(
              padding: EdgeInsetsDirectional.only(start: gutter),
              child: const SkeletonBlock.line(width: 140, height: 16),
            ),
            const SizedBox(height: AppSpace.md),
          ],
          SizedBox(
            height: poster / PosterCard.aspectRatio,
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: gutter),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, __) => SkeletonBlock(
                width: poster,
                height: poster / PosterCard.aspectRatio,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
