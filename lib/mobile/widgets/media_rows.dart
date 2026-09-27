import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../catalog/media_item.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../design/media_badge.dart';
import '../../design/top_ten_rank.dart';
import '../../widgets/common_widgets.dart' show AppStreamingService;
import '../playback.dart';
import 'media_art.dart';
import 'poster_card.dart';
import 'continue_sheet.dart';
import 'section_header.dart';
import 'title_sheet.dart';

/// The phone's badge for [item] on an ordinary row: NEW for a recent release.
String? recencyBadge(MediaItem item) =>
    MediaBadge.recencyOf(item) == null ? null : tr('badge_new');

/// A titled, sideways-scrolling row with its header above it.
class _Row extends StatelessWidget {
  const _Row({
    this.title,
    this.kicker,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    this.onSeeAll,
    this.spacing = 10,
  });

  /// The header; none for a row that continues the one above it.
  final String? title;
  final String? kicker;
  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final VoidCallback? onSeeAll;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpace.gutter(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (title case final title?)
          SectionHeader(title: title, kicker: kicker, onSeeAll: onSeeAll),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: gutter),
            itemCount: itemCount,
            separatorBuilder: (_, __) => SizedBox(width: spacing),
            itemBuilder: itemBuilder,
          ),
        ),
      ],
    );
  }
}

/// Posters in a row, each with its own badge if it has one.
class PosterRow extends StatelessWidget {
  const PosterRow({
    this.title,
    this.kicker,
    required this.items,
    this.badgeFor = recencyBadge,
    this.onSeeAll,
    super.key,
  });

  final String? title;
  final String? kicker;
  final List<MediaItem> items;
  final String? Function(MediaItem item) badgeFor;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final width = posterWidth(context);
    return _Row(
      title: title,
      kicker: kicker,
      height: width / PosterCard.aspectRatio,
      itemCount: items.length,
      onSeeAll: onSeeAll,
      itemBuilder: (context, index) => PosterCard(
        item: items[index],
        width: width,
        badge: badgeFor(items[index]),
      ),
    );
  }
}

/// Today's ten, each poster with its rank drawn tall beside it.
class TopTenRow extends StatelessWidget {
  const TopTenRow({required this.title, required this.items, super.key});

  final String title;
  final List<MediaItem> items;

  @override
  Widget build(BuildContext context) {
    final width = posterWidth(context) * .92;
    final height = width / PosterCard.aspectRatio;
    final top = items.take(10).toList(growable: false);
    return _Row(
      title: title,
      height: height,
      itemCount: top.length,
      spacing: 4,
      // A rank tucks under its poster's left edge, so each pair is laid
      // out left to right in every language; the row still runs the
      // reader's way.
      itemBuilder: (context, index) => Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TopTenRank(rank: index + 1, cardWidth: width, height: height),
            PosterCard(item: top[index], width: width),
          ],
        ),
      ),
    );
  }
}

/// Titles the viewer is part way through: a wide still, progress along its
/// foot, and what is left under it. Tap resumes.
class ContinueRow extends StatelessWidget {
  const ContinueRow({required this.title, required this.items, super.key});

  final String title;
  final List<MediaItem> items;

  @override
  Widget build(BuildContext context) {
    final width = posterWidth(context) * 1.55;
    return _Row(
      title: title,
      height: width * 9 / 16 + ContinueCard.detailsHeight(context),
      itemCount: items.length,
      itemBuilder: (context, index) =>
          ContinueCard(item: items[index], width: width),
    );
  }
}

class ContinueCard extends StatelessWidget {
  const ContinueCard({required this.item, required this.width, super.key});

  final MediaItem item;
  final double width;

  /// Room for the two lines under the still, at the viewer's text size.
  static double detailsHeight(BuildContext context) =>
      MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3).scale(1) *
          34 +
      8;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    final progress = (item.progress ?? 0).clamp(0.0, 1.0);
    final subtitle = continueSubtitle(item);
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Pressable(
            semanticLabel: '${item.title}, $subtitle',
            onTap: () => MobilePlayback.play(context, item),
            onLongPress: () => showContinueSheet(context, item),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.card),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    MediaArt(
                      item: item,
                      path: item.backdropPath ?? item.posterPath,
                      width: width,
                      size: item.backdropPath == null ? null : ArtSize.still,
                      placeholder: MediaArt.darkPlaceholder,
                    ),
                    // A shade at the foot so the play mark and the bar read
                    // on bright stills.
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[Color(0x00000000), Color(0x8C000000)],
                          stops: <double>[.45, 1],
                        ),
                      ),
                    ),
                    Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0x66000000),
                          border: Border.all(
                            color: const Color(0xE6FFFFFF),
                            width: 1.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(9),
                          child: Icon(
                            PhosphorIcons.play(PhosphorIconsStyle.fill),
                            size: 18,
                            color: const Color(0xFFFFFFFF),
                          ),
                        ),
                      ),
                    ),
                    // A next episode has no progress yet.
                    if (item.upNext == null)
                      PositionedDirectional(
                        start: 0,
                        end: 0,
                        bottom: 0,
                        child: SizedBox(
                          height: 3,
                          child: Stack(
                            fit: StackFit.expand,
                            children: <Widget>[
                              const ColoredBox(color: Color(0x3DFFFFFF)),
                              FractionallySizedBox(
                                alignment: AlignmentDirectional.centerStart,
                                widthFactor: progress,
                                child: ColoredBox(color: accent),
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
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.cardTitle.copyWith(
                        color: palette.foreground,
                        fontSize: 13,
                        height: 17 / 13,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.metadata.copyWith(
                          color: palette.mutedText,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox.square(
                dimension: 32,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: tr('more_options'),
                  iconSize: 20,
                  color: palette.mutedText,
                  onPressed: () => showContinueSheet(context, item),
                  icon: Icon(PhosphorIcons.dotsThreeVertical()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The services' logos on their own plates; each opens its catalog.
class ServiceRow extends StatelessWidget {
  const ServiceRow({
    required this.title,
    required this.services,
    required this.onOpen,
    super.key,
  });

  final String title;
  final List<AppStreamingService> services;
  final ValueChanged<AppStreamingService> onOpen;

  @override
  Widget build(BuildContext context) {
    final width = posterWidth(context) * 1.3;
    return _Row(
      title: title,
      height: width * 9 / 16,
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        return Pressable(
          semanticLabel: service.name,
          onTap: () => onOpen(service),
          child: Container(
            width: width,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              // A fixed plate: the logos are drawn for a dark ground.
              color: const Color(0xFF1E1F22),
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Image.asset(service.imagePath, fit: BoxFit.contain),
          ),
        );
      },
    );
  }
}

/// A title's wide still with its name over the foot: for rows that vary the
/// poster rhythm. Artwork, so fixed colours in every theme.
class StillCard extends StatelessWidget {
  const StillCard({required this.item, required this.width, super.key});

  final MediaItem item;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: mediaSemanticLabel(item),
      onTap: () => MobilePlayback.openDetails(context, item),
      onLongPress: () => showTitleSheet(context, item),
      child: SizedBox(
        width: width,
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
                size: item.backdropPath == null ? null : ArtSize.still,
                placeholder: MediaArt.darkPlaceholder,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0x00000000), Color(0xB3000000)],
                    stops: <double>[.45, 1],
                  ),
                ),
              ),
              PositionedDirectional(
                start: 10,
                end: 10,
                bottom: 8,
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.cardTitle.copyWith(
                    color: const Color(0xFFFFFFFF),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wide stills in a row.
class StillRow extends StatelessWidget {
  const StillRow({
    this.title,
    this.kicker,
    required this.items,
    this.onSeeAll,
    super.key,
  });

  final String? title;
  final String? kicker;
  final List<MediaItem> items;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final width = posterWidth(context) * 2;
    return _Row(
      title: title,
      kicker: kicker,
      height: width * 9 / 16,
      itemCount: items.length,
      onSeeAll: onSeeAll,
      itemBuilder: (context, index) =>
          StillCard(item: items[index], width: width),
    );
  }
}
