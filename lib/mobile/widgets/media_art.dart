import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../catalog/media_item.dart';
import '../../constants/api_constants.dart';
import '../../constants/app_constants.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../design/outline_mark.dart';
import '../../functions/function.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';

/// TMDB sizes for artwork that isn't a poster. Posters follow the image
/// quality setting.
abstract final class ArtSize {
  static const backdrop = 'w1280/';
  static const still = 'w780/';
}

/// A poster's width on a browse row: three whole posters and the edge of a
/// fourth across a phone, a little larger on tablets.
double posterWidth(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final gutter = AppSpace.gutter(context);
  final fit = (width - gutter * 2 - 20) / 3.15;
  return width >= AppBreakpoints.tablet
      ? fit.clamp(132.0, 160.0)
      : fit.clamp(104.0, 140.0);
}

/// [path] on TMDB's image server, through the proxy when it is on; posters
/// use the image quality setting unless [size] says otherwise.
///
/// From build, it rebuilds when those settings change; anywhere else (a
/// callback, a timer) pass [listen] false.
String? tmdbImageUrl(
  BuildContext context,
  String? path, {
  String? size,
  bool listen = true,
}) {
  if (path == null || path.isEmpty) return null;
  final settings = Provider.of<SettingsProvider>(context, listen: listen);
  final proxy =
      Provider.of<AppDependencyProvider>(context, listen: listen).tmdbProxy;
  final base = buildImageUrl(
    TMDB_BASE_IMAGE_URL,
    proxy,
    settings.enableProxy,
    context,
  );
  return '$base${size ?? settings.imageQuality}$path';
}

/// A title's artwork filling its box: [path] decoded near the size it is
/// drawn, a quiet panel while it loads, and the FlixQuest mark when there is
/// none.
class MediaArt extends StatelessWidget {
  const MediaArt({
    required this.item,
    required this.path,
    required this.width,
    this.size,
    this.alignment = Alignment.center,
    this.placeholder,
    super.key,
  });

  final MediaItem item;
  final String? path;

  /// The drawn width, which sets the decode size.
  final double width;
  final String? size;
  final Alignment alignment;

  /// The tone shown while loading; the theme's raised surface by default.
  /// Artwork with its own dark overlay passes a fixed dark tone, so it loads
  /// the same in every theme.
  final Color? placeholder;

  /// The fixed dark tone for artwork surfaces (the hero, stills), as the
  /// service logo plates use.
  static const darkPlaceholder = Color(0xFF1E1F22);

  @override
  Widget build(BuildContext context) {
    final url = tmdbImageUrl(context, path, size: size);
    if (url == null) {
      return MediaArtFallback(item: item, background: placeholder);
    }
    final palette = AppPalette.of(context);
    return CachedNetworkImage(
      cacheManager: cacheProp(),
      imageUrl: url,
      memCacheWidth: (width * MediaQuery.devicePixelRatioOf(context)).round(),
      fit: BoxFit.cover,
      alignment: alignment,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, __) =>
          ColoredBox(color: placeholder ?? palette.raisedSurface),
      errorWidget: (_, __, ___) =>
          MediaArtFallback(item: item, background: placeholder),
    );
  }
}

/// A title's artwork that isn't there.
class MediaArtFallback extends StatelessWidget {
  const MediaArtFallback({required this.item, this.background, super.key});

  final MediaItem item;
  final Color? background;

  @override
  Widget build(BuildContext context) => ArtPlaceholder(background: background);
}

/// Any artwork that isn't there (a poster, a still, a face): the FlixQuest
/// mark in outline, quiet on the panel and sized to the box.
class ArtPlaceholder extends StatelessWidget {
  const ArtPlaceholder({this.background, super.key});

  /// The panel; the theme's raised surface by default. A fixed tone means
  /// dark artwork ground, where the mark is translucent white in every theme.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return ColoredBox(
      color: background ?? palette.raisedSurface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: OutlineMark(
              height: OutlineMark.heightFor(constraints.biggest.shortestSide),
              color: background == null
                  ? palette.mutedText
                  : const Color(0x61FFFFFF),
            ),
          );
        },
      ),
    );
  }
}
