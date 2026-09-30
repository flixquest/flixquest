import 'package:flutter/material.dart';

import '../../catalog/media_item.dart';
import '../../design/app_tokens.dart';
import 'media_rows.dart' show recencyBadge;
import 'poster_card.dart';

/// How many posters a browse grid fits at [context]'s width: three on a
/// phone, five from tablet width and six on a wide screen.
int posterGridColumns(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return width >= AppBreakpoints.wide
      ? 6
      : width >= AppBreakpoints.tablet
          ? 5
          : 3;
}

/// The grid My List and a collection share: 2:3 posters, ten apart.
SliverGridDelegate posterGridDelegate(BuildContext context) =>
    SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: posterGridColumns(context),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: PosterCard.aspectRatio,
    );

/// A page's titles as 2:3 posters, [posterGridColumns] across, with nothing
/// under them: the grid a collection's and My List's "See all" pages show.
class PosterGrid extends StatelessWidget {
  const PosterGrid({required this.items, super.key});

  final List<MediaItem> items;

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpace.gutter(context);
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        gutter,
        AppSpace.sm,
        gutter,
        AppSpace.xxl + MediaQuery.paddingOf(context).bottom,
      ),
      gridDelegate: posterGridDelegate(context),
      itemCount: items.length,
      itemBuilder: (context, index) => LayoutBuilder(
        builder: (context, constraints) => PosterCard(
          item: items[index],
          width: constraints.maxWidth,
          badge: recencyBadge(items[index]),
        ),
      ),
    );
  }
}
