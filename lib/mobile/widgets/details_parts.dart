import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/api_constants.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../design/skeleton.dart';
import '../../models/credits.dart';
import '../../models/movie.dart';
import '../../models/videos.dart';
import '../../screens/person/cast_detail.dart';
import 'media_art.dart';
import 'pill_button.dart';
import 'poster_card.dart';

/// The parts a details page is built from, each quiet and in the palette's
/// roles: ink for what can be pressed, the accent only on progress.

/// A part that didn't load, or has nothing: one muted line, and Retry when
/// trying again could help.
class DetailsMessage extends StatelessWidget {
  const DetailsMessage({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final retry = onRetry;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              message,
              style: AppType.body.copyWith(color: palette.mutedText),
            ),
          ),
          if (retry != null) ...<Widget>[
            const SizedBox(width: AppSpace.md),
            PillButton(label: tr('retry'), height: 34, onPressed: retry),
          ],
        ],
      ),
    );
  }
}

/// One of the page's actions: an icon over its label, in ink.
class DetailsAction extends StatelessWidget {
  const DetailsAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final color = onPressed == null ? palette.mutedText : palette.foreground;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadii.button),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 64, minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.xs,
              vertical: AppSpace.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 24, color: color),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppType.metadata.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The cast as a row of faces, each opening the person's page.
class CastRow extends StatelessWidget {
  const CastRow({required this.cast, super.key});

  final List<Cast> cast;

  static const _face = 72.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final people = cast.take(16).toList(growable: false);
    return SizedBox(
      height: _face + 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: gutter),
        itemCount: people.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpace.md),
        itemBuilder: (context, index) {
          final person = people[index];
          final url = tmdbImageUrl(context, person.profilePath, size: 'w185/');
          return SizedBox(
            width: _face + 12,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.card),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => CastDetailPage(
                    cast: person,
                    heroId: 'details_${person.id}${person.creditId}',
                  ),
                ),
              ),
              child: Column(
                children: <Widget>[
                  ClipOval(
                    child: Container(
                      width: _face,
                      height: _face,
                      color: palette.raisedSurface,
                      child: url == null
                          ? Icon(PhosphorIcons.user(), color: palette.mutedText)
                          : CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              memCacheWidth: (_face *
                                      MediaQuery.devicePixelRatioOf(context))
                                  .round(),
                              errorWidget: (_, __, ___) => Icon(
                                PhosphorIcons.user(),
                                color: palette.mutedText,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    person.name ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppType.metadata.copyWith(color: palette.foreground),
                  ),
                  Text(
                    // A season's cast names its roles instead.
                    person.character ??
                        person.roles?.firstOrNull?.character ??
                        '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppType.metadata.copyWith(
                      color: palette.mutedText,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A row of faces while the cast loads.
class CastRowSkeleton extends StatelessWidget {
  const CastRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpace.gutter(context);
    return SkeletonPulse(
      child: Padding(
        padding: EdgeInsets.fromLTRB(gutter, AppSpace.xl, 0, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SkeletonBlock.line(width: 80, height: 16),
            const SizedBox(height: AppSpace.md),
            SizedBox(
              height: CastRow._face + 40,
              child: OverflowBox(
                alignment: AlignmentDirectional.topStart,
                maxWidth: double.infinity,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (var i = 0; i < 6; i++)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: AppSpace.md + 12,
                        ),
                        child: Column(
                          children: <Widget>[
                            const SkeletonBlock(
                              width: CastRow._face,
                              height: CastRow._face,
                              circle: true,
                            ),
                            const SizedBox(height: AppSpace.sm),
                            const SkeletonBlock.line(width: 60, height: 10),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Videos side by side, each a thumbnail with its name under it.
class VideoRow extends StatelessWidget {
  const VideoRow({required this.videos, super.key});

  final List<Results> videos;

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpace.gutter(context);
    final width = (MediaQuery.sizeOf(context).width * .72).clamp(220.0, 320.0);
    // The thumbnail, then two lines of title at the reader's text size.
    final height = width * 9 / 16 +
        AppSpace.sm +
        MediaQuery.textScalerOf(context).scale(14) * 18 / 14 * 2 +
        4;
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: gutter),
        itemCount: videos.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpace.md),
        itemBuilder: (context, index) => SizedBox(
          width: width,
          child: VideoTile(video: videos[index]),
        ),
      ),
    );
  }
}

/// Images side by side ([paths], all [aspectRatio]), each opening the
/// full-screen viewer at itself.
class ImageRow extends StatelessWidget {
  const ImageRow({
    required this.paths,
    required this.aspectRatio,
    required this.onOpen,
    super.key,
  });

  final List<String> paths;
  final double aspectRatio;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpace.gutter(context);
    final height = aspectRatio < 1 ? 170.0 : 124.0;
    final width = height * aspectRatio;
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: gutter),
        itemCount: paths.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final url = tmdbImageUrl(
            context,
            paths[index],
            size: aspectRatio < 1 ? 'w342/' : 'w500/',
          );
          return Pressable(
            onTap: () => onOpen(index),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.card),
              child: SizedBox(
                width: width,
                height: height,
                child: url == null
                    ? const ArtPlaceholder()
                    : CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        memCacheWidth:
                            (width * MediaQuery.devicePixelRatioOf(context))
                                .round(),
                        placeholder: (_, __) => ColoredBox(
                          color: AppPalette.of(context).raisedSurface,
                        ),
                        errorWidget: (_, __, ___) => const ArtPlaceholder(),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Facts as label and value rows.
class InfoTable extends StatelessWidget {
  const InfoTable({required this.rows, super.key});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Column(
      children: <Widget>[
        for (final (index, (label, value)) in rows.indexed) ...<Widget>[
          if (index > 0) Divider(height: 1, color: palette.hairline),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: Text(
                    label,
                    style: AppType.body.copyWith(color: palette.mutedText),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  flex: 3,
                  child: Text(
                    value,
                    style: AppType.body.copyWith(color: palette.foreground),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A video from TMDB: its YouTube thumbnail, opening in YouTube.
class VideoTile extends StatelessWidget {
  const VideoTile({required this.video, super.key});

  final Results video;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final key = video.videoLink ?? '';
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.card),
      onTap: key.isEmpty ? null : () => openVideo(video),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.card),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ColoredBox(color: MediaArt.darkPlaceholder),
                  if (key.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: '$YOUTUBE_THUMBNAIL_URL$key/hqdefault.jpg',
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  Center(
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0x73000000),
                        shape: BoxShape.circle,
                      ),
                      child: PlaybackIcon(
                        PhosphorIcons.play(PhosphorIconsStyle.fill),
                        size: 22,
                        color: const Color(0xFFFFFFFF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            video.name ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppType.cardTitle.copyWith(color: palette.foreground),
          ),
        ],
      ),
    );
  }
}

/// Opens [video] in YouTube.
Future<void> openVideo(Results video) => launchUrl(
      Uri.parse('$YOUTUBE_BASE_URL${video.videoLink}'),
      mode: LaunchMode.externalApplication,
    );

/// A wide card over artwork, with a label: a gallery or a collection.
class ArtworkCard extends StatelessWidget {
  const ArtworkCard({
    required this.url,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.aspectRatio = 16 / 9,
    super.key,
  });

  final String? url;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final double aspectRatio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    final icon = this.icon;
    final subtitle = this.subtitle;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.card),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              const ColoredBox(color: MediaArt.darkPlaceholder),
              if (url != null)
                CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0x00000000), Color(0xC7000000)],
                  ),
                ),
              ),
              PositionedDirectional(
                start: AppSpace.md,
                end: AppSpace.md,
                bottom: AppSpace.md,
                child: Row(
                  children: <Widget>[
                    if (icon != null) ...<Widget>[
                      Icon(icon, size: 18, color: const Color(0xFFFFFFFF)),
                      const SizedBox(width: AppSpace.sm),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.cardTitle.copyWith(
                              color: const Color(0xFFFFFFFF),
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
            ],
          ),
        ),
      ),
    );
  }
}

/// A title's pages elsewhere, as pills.
class SocialLinks extends StatelessWidget {
  const SocialLinks({required this.links, super.key});

  final ExternalLinks links;

  /// Whether [links] names anywhere at all.
  static bool any(ExternalLinks links) => _items(links).isNotEmpty;

  static List<(IconData, String, String)> _items(ExternalLinks links) =>
      <(IconData, String, String)>[
        if ((links.imdbId ?? '').isNotEmpty)
          (PhosphorIcons.filmSlate(), 'IMDb', '$IMDB_BASE_URL${links.imdbId}'),
        if ((links.instagramUsername ?? '').isNotEmpty)
          (
            PhosphorIcons.instagramLogo(),
            'Instagram',
            '$INSTAGRAM_BASE_URL${links.instagramUsername}',
          ),
        if ((links.facebookUsername ?? '').isNotEmpty)
          (
            PhosphorIcons.facebookLogo(),
            'Facebook',
            '$FACEBOOK_BASE_URL${links.facebookUsername}',
          ),
        if ((links.twitterUsername ?? '').isNotEmpty)
          (
            PhosphorIcons.xLogo(),
            'X',
            '$TWITTER_BASE_URL${links.twitterUsername}',
          ),
      ];

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: AppSpace.sm,
        runSpacing: AppSpace.sm,
        children: <Widget>[
          for (final (icon, label, url) in _items(links))
            PillButton(
              label: label,
              icon: icon,
              height: 36,
              onPressed: () => launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              ),
            ),
        ],
      );
}
