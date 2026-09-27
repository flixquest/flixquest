import 'package:flutter/material.dart';

import '../../catalog/home_feed_controller.dart';
import '../../catalog/media_item.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../design/title_logo.dart';
import '../playback.dart';
import 'media_art.dart';
import 'media_rows.dart';
import 'poster_card.dart';
import 'section_header.dart';
import 'title_sheet.dart';

/// One of Home's random genre rows, laid out as [HomeCategory.layout] says:
/// FlixQuest's categorized feed, in the new cards.
///
/// Its titles are fetched when it first comes into view; [load] should hand
/// back the same future each time, so scrolling past and back again doesn't
/// fetch twice.
class CategorySection extends StatelessWidget {
  const CategorySection({
    required this.category,
    required this.load,
    required this.onSeeAll,
    this.kicker,
    super.key,
  });

  final HomeCategory category;

  /// Which kind the genre is, where the page shows both.
  final String? kicker;
  final Future<List<MediaItem>> Function() load;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MediaItem>>(
      future: load(),
      builder: (context, snapshot) {
        final items = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done) {
          return _Placeholder(
            title: category.genre.genreName ?? '',
            kicker: kicker,
          );
        }
        if (items == null || items.isEmpty) return const SizedBox.shrink();
        return _build(context, items);
      },
    );
  }

  Widget _build(BuildContext context, List<MediaItem> items) {
    final title = category.genre.genreName ?? '';
    const gap = SizedBox(height: AppSpace.md);
    switch (category.layout) {
      case CategoryLayout.feature:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SectionHeader(title: title, kicker: kicker, onSeeAll: onSeeAll),
            FeatureCard(item: items.first),
            if (items.length > 1) ...<Widget>[
              gap,
              PosterRow(items: items.skip(1).toList(growable: false)),
            ],
          ],
        );
      case CategoryLayout.stillsAndPosters:
        final stills = items.take(6).toList(growable: false);
        final posters = items.skip(6).toList(growable: false);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            StillRow(
              title: title,
              kicker: kicker,
              items: stills,
              onSeeAll: onSeeAll,
            ),
            if (posters.isNotEmpty) ...<Widget>[
              gap,
              PosterRow(items: posters),
            ],
          ],
        );
      case CategoryLayout.twoPosterRows:
        final first = <MediaItem>[
          for (var i = 0; i < items.length; i += 2) items[i],
        ];
        final second = <MediaItem>[
          for (var i = 1; i < items.length; i += 2) items[i],
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            PosterRow(
              title: title,
              kicker: kicker,
              items: first,
              onSeeAll: onSeeAll,
            ),
            if (second.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              PosterRow(items: second),
            ],
          ],
        );
      case CategoryLayout.stills:
        return StillRow(
          title: title,
          kicker: kicker,
          items: items,
          onSeeAll: onSeeAll,
        );
      case CategoryLayout.posters:
        return PosterRow(
          title: title,
          kicker: kicker,
          items: items,
          onSeeAll: onSeeAll,
        );
    }
  }
}

/// A title given the width of the page: its still, its logo and what it is.
class FeatureCard extends StatelessWidget {
  const FeatureCard({required this.item, super.key});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpace.gutter(context);
    final width = MediaQuery.sizeOf(context).width - gutter * 2;
    const white = Color(0xFFFFFFFF);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: gutter),
      child: Pressable(
        semanticLabel: mediaSemanticLabel(item),
        onTap: () => MobilePlayback.openDetails(context, item),
        onLongPress: () => showTitleSheet(context, item),
        child: SizedBox(
          height: width * 9 / 16,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.card),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                MediaArt(
                  item: item,
                  path: item.backdropPath ?? item.posterPath,
                  width: width,
                  size: item.backdropPath == null ? null : ArtSize.backdrop,
                  placeholder: MediaArt.darkPlaceholder,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0x00000000), Color(0xCC000000)],
                      stops: <double>[.4, 1],
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: 14,
                  end: 14,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        height: 44,
                        child: TitleLogo(
                          item: item,
                          maxHeight: 44,
                          alignment: AlignmentDirectional.bottomStart,
                          fallback: Align(
                            alignment: AlignmentDirectional.bottomStart,
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.sectionHeader.copyWith(
                                fontFamily: AppType.bold,
                                fontSize: 20,
                                color: white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mediaFacts(item),
                        style: AppType.metadata.copyWith(
                          color: const Color(0xD9FFFFFF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The section's room while its titles load: the header, then a quiet row.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.title, this.kicker});

  final String title;
  final String? kicker;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final width = posterWidth(context);
    final gutter = AppSpace.gutter(context);
    return ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionHeader(title: title, kicker: kicker),
          SizedBox(
            height: width / PosterCard.aspectRatio,
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: gutter),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, __) => Container(
                width: width,
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
