import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../constants/loading_colors.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../constants/api_constants.dart';
import '../../constants/app_constants.dart';
import '../../functions/function.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../app/tv_design.dart';
import '../models/tv_media_item.dart';
import '../../design/media_badge.dart';

export '../../design/media_badge.dart';

class TvMediaCard extends StatelessWidget {
  const TvMediaCard({
    required this.item,
    required this.width,
    this.artworkOnly = false,
    this.dimmed = false,
    this.badge,
    super.key,
  });

  final TvMediaItem item;
  final double width;

  /// Leaves out the title and facts below the artwork, for rows whose
  /// spotlight already shows them for the focused card.
  final bool artworkOnly;

  /// Shades the artwork, for cards outside the row being browsed.
  final bool dimmed;

  /// A short label over the artwork's top corner, such as [TvMediaBadge.top10].
  final String? badge;

  static const artworkAspectRatio = 2 / 3;
  static const detailsHeight = 46.0;

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    final colors = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final proxy = context.watch<AppDependencyProvider>().tmdbProxy;
    final path = item.posterPath ?? item.backdropPath;
    final imageUrl = path == null
        ? null
        : '${buildImageUrl(
            TMDB_BASE_IMAGE_URL,
            proxy,
            settings.enableProxy,
            context,
          )}${settings.imageQuality}$path';

    final artwork = AspectRatio(
      aspectRatio: artworkAspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TvDesign.cardRadius),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (imageUrl == null)
              _ImageFallback(item: item, showTitle: artworkOnly)
            else
              CachedNetworkImage(
                cacheManager: cacheProp(),
                imageUrl: imageUrl,
                // Decode close to the rendered size to avoid retaining
                // multi-megapixel TMDB frames for small TV cards.
                memCacheWidth:
                    (width * MediaQuery.devicePixelRatioOf(context)).round(),
                memCacheHeight: (width /
                        artworkAspectRatio *
                        MediaQuery.devicePixelRatioOf(context))
                    .round(),
                fit: BoxFit.cover,
                placeholder: (_, __) => ColoredBox(
                  color: AppLoadingColors.of(context).cachedImagePlaceholder,
                ),
                errorWidget: (_, __, ___) =>
                    _ImageFallback(item: item, showTitle: artworkOnly),
              ),
            if (!artworkOnly)
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: palette.hairline),
                  borderRadius: BorderRadius.circular(TvDesign.cardRadius),
                ),
              ),
            if (badge case final badge?)
              Positioned(
                left: 6,
                top: 6,
                right: 6,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: TvMediaBadge(label: badge),
                ),
              ),
            if (item.progress case final progress?)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  color: colors.primary,
                  backgroundColor: Colors.white24,
                ),
              ),
            // A plain shaded rect rather than an Opacity, which would
            // cost every dimmed card an offscreen layer on TV GPUs.
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              color: dimmed ? palette.dim : Colors.transparent,
            ),
          ],
        ),
      ),
    );
    if (artworkOnly) return SizedBox(width: width, child: artwork);

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          artwork,
          const SizedBox(height: 7),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.foreground,
              fontFamily: 'FigtreeSB',
              fontSize: 16,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.progressLabel ??
                <String>[
                  if (item.year != null) item.year!,
                  if (item.rating case final rating?)
                    '★ ${rating.toStringAsFixed(1)}'
                  else
                    item.kind == TvMediaKind.movie ? 'Movie' : 'Series',
                ].join('  •  '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// The TV's name for the shared corner label.
typedef TvMediaBadge = MediaBadge;

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.item, required this.showTitle});

  final TvMediaItem item;

  /// Names the title on the card itself when no text sits below it.
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    final icon = Icon(
      item.kind == TvMediaKind.movie
          ? PhosphorIcons.filmSlate()
          : PhosphorIcons.television(),
      color: palette.mutedText,
      size: 42,
    );
    return ColoredBox(
      color: palette.raisedSurface,
      child: Center(
        child: !showTitle
            ? icon
            : Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    icon,
                    const SizedBox(height: 10),
                    Text(
                      item.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.foreground,
                        fontFamily: 'FigtreeSB',
                        fontSize: 14,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
