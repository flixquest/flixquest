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
import '../focus/tv_focusable.dart';
import '../models/tv_media_item.dart';

class TvHero extends StatelessWidget {
  const TvHero({
    required this.item,
    required this.compact,
    required this.onOpenDetails,
    super.key,
  });

  final TvMediaItem item;
  final bool compact;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final proxy = context.watch<AppDependencyProvider>().tmdbProxy;
    final path = item.backdropPath ?? item.posterPath;
    final imageUrl = path == null
        ? null
        : '${buildImageUrl(
            TMDB_BASE_IMAGE_URL,
            proxy,
            settings.enableProxy,
            context,
          )}original/$path';
    final metadata = <String>[
      if (item.year case final year?) year,
      item.kind == TvMediaKind.movie ? 'Movie' : 'Series',
      if (item.rating case final rating?) '★ ${rating.toStringAsFixed(1)}',
    ];

    return SizedBox(
      height: compact ? 240 : 310,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (imageUrl == null)
              ColoredBox(color: TvDesign.surfaceFor(context, emphasis: 0.03))
            else
              CachedNetworkImage(
                cacheManager: cacheProp(),
                imageUrl: imageUrl,
                // The hero is displayed at a bounded width; avoid decoding
                // TMDB's original multi-megapixel image into TV RAM.
                memCacheWidth: (MediaQuery.sizeOf(context).width *
                        MediaQuery.devicePixelRatioOf(context))
                    .round(),
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                placeholder: (_, __) => ColoredBox(
                  color: AppLoadingColors.of(context).cachedImagePlaceholder,
                ),
                errorWidget: (_, __, ___) =>
                    ColoredBox(color: TvDesign.surfaceFor(context)),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: <Color>[
                    Color(0x00000000),
                    Color(0x5c000000),
                    Color(0xf7000000),
                  ],
                  stops: <double>[0, 0.55, 1],
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0x00000000),
                    Color(0x08000000),
                    Color(0xff050606),
                  ],
                  stops: <double>[0, 0.64, 1],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 22 : 32,
                compact ? 18 : 24,
                compact ? 22 : 32,
                compact ? 22 : 30,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: compact ? 410 : 530),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            item.kind == TvMediaKind.movie
                                ? PhosphorIcons.filmSlate()
                                : PhosphorIcons.television(),
                            color: colors.primary,
                            size: 19,
                          ),
                          const SizedBox(width: 9),
                          Text(
                            item.kind == TvMediaKind.movie
                                ? 'FEATURED MOVIE'
                                : 'FEATURED SERIES',
                            style: TextStyle(
                              color: colors.primary,
                              fontFamily: 'FigtreeSB',
                              fontSize: compact ? 11 : 12,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: TvDesign.foreground,
                          fontFamily: 'FigtreeBold',
                          fontSize: compact ? 32 : 44,
                          height: 0.98,
                          letterSpacing: -0.7,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        metadata.join('   '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xffd2d2d2),
                          fontFamily: 'FigtreeSB',
                          fontSize: 14,
                          height: 1.1,
                        ),
                      ),
                      if (item.overview.isNotEmpty) ...<Widget>[
                        SizedBox(height: compact ? 8 : 10),
                        Text(
                          item.overview,
                          maxLines: compact ? 2 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xffdedede),
                            fontSize: compact ? 13 : 15,
                            height: 1.25,
                          ),
                        ),
                      ],
                      SizedBox(height: compact ? 12 : 15),
                      TvFocusable(
                        semanticLabel: 'More information about ${item.title}',
                        onActivate: onOpenDetails,
                        focusScale: 1.035,
                        focusColor: colors.primary,
                        borderRadius: BorderRadius.circular(5),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xf2ffffff),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                PhosphorIcons.info(),
                                color: Colors.black,
                                size: 19,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'More info',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontFamily: 'FigtreeSB',
                                  fontSize: 16,
                                ),
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
          ],
        ),
      ),
    );
  }
}
