import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../constants/api_constants.dart';
import '../../constants/app_constants.dart';
import '../../constants/loading_colors.dart';
import '../../functions/function.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../app/tv_design.dart';

/// The URL of a TMDB profile photo at [size], or null without one.
String? tvProfileImageUrl(
  BuildContext context,
  String? path, {
  String size = 'w342',
}) {
  if (path == null || path.isEmpty) return null;
  final settings = context.watch<SettingsProvider>();
  final proxy = context.watch<AppDependencyProvider>().tmdbProxy;
  final base = buildImageUrl(
    TMDB_BASE_IMAGE_URL,
    proxy,
    settings.enableProxy,
    context,
  );
  return '$base$size$path';
}

/// A person's photo, poster-shaped, with a quiet figure when there is none.
class TvPersonPortrait extends StatelessWidget {
  const TvPersonPortrait({
    required this.profilePath,
    required this.width,
    super.key,
  });

  final String? profilePath;
  final double width;

  static const aspectRatio = 2 / 3;

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    final url = tvProfileImageUrl(context, profilePath);
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final placeholder = ColoredBox(
      color: palette.raisedSurface,
      child: Center(
        child: Icon(
          PhosphorIcons.user(),
          color: palette.mutedText,
          size: width * 0.34,
        ),
      ),
    );
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(TvDesign.cardRadius),
          child: url == null
              ? placeholder
              : CachedNetworkImage(
                  cacheManager: cacheProp(),
                  imageUrl: url,
                  memCacheWidth: (width * ratio).round(),
                  memCacheHeight: (width / aspectRatio * ratio).round(),
                  fit: BoxFit.cover,
                  placeholder: (_, __) => ColoredBox(
                    color: AppLoadingColors.of(context).cachedImagePlaceholder,
                  ),
                  errorWidget: (_, __, ___) => placeholder,
                ),
        ),
      ),
    );
  }
}

/// Someone in a title's credits: their photo, their name, and what they
/// did, in a row of faces.
class TvPersonCard extends StatelessWidget {
  const TvPersonCard({
    required this.name,
    required this.profilePath,
    required this.width,
    this.role,
    super.key,
  });

  final String name;
  final String? role;
  final String? profilePath;
  final double width;

  /// The name and role under the photo.
  static const detailsHeight = 46.0;

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    final role = this.role;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TvPersonPortrait(profilePath: profilePath, width: width),
          const SizedBox(height: 7),
          Text(
            name,
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
            role ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.mutedText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
