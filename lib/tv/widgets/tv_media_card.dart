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
                  border: Border.all(color: TvDesign.hairline),
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
              color: dimmed ? const Color(0x8c000000) : Colors.transparent,
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
              color: colors.onSurface,
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
              color: TvDesign.mutedText,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// A card's corner label: small white capitals on a dark plate, legible over
/// any poster without competing with the accent colour.
class TvMediaBadge extends StatelessWidget {
  const TvMediaBadge({required this.label, super.key});

  static const top10 = 'TOP 10';
  static const newEpisodes = 'NEW EPISODES';
  static const recent = 'NEW';

  /// How long after release a title still counts as new.
  static const recentWindow = Duration(days: 30);

  final String label;

  /// [recent] for a title released (or, for a series, first aired) within
  /// [recentWindow] of [now]; nothing for older or upcoming titles.
  static String? recencyOf(TvMediaItem item, {DateTime? now}) {
    final released = DateTime.tryParse(item.releaseDate ?? '');
    if (released == null) return null;
    final today = now ?? DateTime.now();
    if (released.isAfter(today)) return null;
    return today.difference(released) <= recentWindow ? recent : null;
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xd9050606),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 3, 5, 3),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.clip,
          softWrap: false,
          style: const TextStyle(
            color: TvDesign.foreground,
            fontFamily: 'FigtreeBold',
            fontSize: 11,
            height: 1.1,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.item, required this.showTitle});

  final TvMediaItem item;

  /// Names the title on the card itself when no text sits below it.
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final icon = Icon(
      item.kind == TvMediaKind.movie
          ? PhosphorIcons.filmSlate()
          : PhosphorIcons.television(),
      color: colors.onSurfaceVariant,
      size: 42,
    );
    return ColoredBox(
      color: colors.surfaceContainerHighest,
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
                        color: colors.onSurface,
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
