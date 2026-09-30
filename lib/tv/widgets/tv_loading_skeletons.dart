import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/skeleton.dart';
import '../app/tv_design.dart';
import 'tv_media_card.dart';

/// The first pages of a genre or streaming-service collection.
class TvCollectionGridSkeleton extends StatelessWidget {
  const TvCollectionGridSkeleton({required this.metrics, super.key});

  final TvShellMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final cardWidth = metrics.mediaCardWidth;
    final cardHeight =
        cardWidth / TvMediaCard.artworkAspectRatio + TvMediaCard.detailsHeight;
    return SkeletonPulse(
      label: 'Loading collection',
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: cardWidth,
          mainAxisExtent: cardHeight,
          mainAxisSpacing: metrics.compact ? 16 : 22,
          crossAxisSpacing: metrics.compact ? 14 : 20,
        ),
        itemCount: 16,
        itemBuilder: (context, index) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: SkeletonBlock(radius: TvDesign.cardRadius)),
            const SizedBox(height: 8),
            SkeletonBlock.line(width: index.isEven ? 104 : 132, height: 13),
            const SizedBox(height: 6),
            const SkeletonBlock.line(width: 72, height: 10),
          ],
        ),
      ),
    );
  }
}

/// Live TV's title, filters and text-only channel grid while the guide loads.
class TvLiveSkeleton extends StatelessWidget {
  const TvLiveSkeleton({required this.metrics, super.key});

  final TvShellMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final compact = metrics.compact;
    return SkeletonPulse(
      label: 'Loading Live TV',
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: metrics.contentPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SkeletonBlock.line(width: 240, height: compact ? 30 : 34),
            SizedBox(height: compact ? 14 : 18),
            Row(
              children: const <Widget>[
                SkeletonBlock(width: 220, height: 40, radius: 20),
                SizedBox(width: 28),
                SkeletonBlock(width: 290, height: 40, radius: 20),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 38,
              child: ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                scrollDirection: Axis.horizontal,
                itemCount: 8,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) => SkeletonBlock(
                  width: 58 + (index % 3) * 20,
                  height: 38,
                  radius: 19,
                ),
              ),
            ),
            SizedBox(height: compact ? 10 : 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final targetWidth = compact ? 200.0 : 240.0;
                  final spacing = compact ? 10.0 : 14.0;
                  final columns = math.max(
                    1,
                    ((constraints.maxWidth + spacing) / (targetWidth + spacing))
                        .floor(),
                  );
                  return GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent: compact ? 70 : 76,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: compact ? 12 : 18,
                    ),
                    itemCount: columns * 4,
                    itemBuilder: (_, __) => const SkeletonBlock(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The report panels and charts beneath Viewing Insights' range controls.
class TvInsightsSkeleton extends StatelessWidget {
  const TvInsightsSkeleton({required this.metrics, super.key});

  final TvShellMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      label: 'Loading viewing insights',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SkeletonBlock(
            height: metrics.compact ? 220 : 260,
            radius: TvDesign.cardRadius,
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 12.0;
              final columns = constraints.maxWidth >= 800 ? 3 : 2;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: <Widget>[
                  for (var index = 0; index < 6; index++)
                    SizedBox(
                      width: width,
                      child: const SkeletonBlock(
                        height: 92,
                        radius: TvDesign.cardRadius,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The update card and its primary action while platform details are read.
class TvUpdateSkeleton extends StatelessWidget {
  const TvUpdateSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const SkeletonPulse(
        label: 'Checking for updates',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SkeletonBlock(height: 96, radius: TvDesign.cardRadius),
            SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: SkeletonBlock(width: 260, height: 48, radius: 24),
            ),
          ],
        ),
      );
}
