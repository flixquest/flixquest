import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/api_constants.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../models/credits.dart';
import '../../models/movie.dart';
import '../../models/videos.dart';
import '../../models/watch_providers.dart';
import '../../screens/person/cast_detail.dart';
import 'media_art.dart';
import 'pill_button.dart';

/// The parts a details page is built from, each quiet and in the palette's
/// roles: ink for what can be pressed, the accent only on progress.

/// A block standing in for content while it loads.
class DetailsBlock extends StatelessWidget {
  const DetailsBlock({
    this.width = double.infinity,
    required this.height,
    this.radius = AppRadii.card,
    super.key,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppPalette.of(context).raisedSurface,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      );
}

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
                    person.character ?? '',
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

/// Where to stream, rent or buy a title in the viewer's country.
Future<void> showWatchProvidersSheet(
  BuildContext context,
  Future<WatchProviders> providers,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .8,
      ),
      child: _WatchProviders(providers: providers),
    ),
  );
}

class _WatchProviders extends StatelessWidget {
  const _WatchProviders({required this.providers});

  final Future<WatchProviders> providers;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsetsDirectional.fromSTEB(
          gutter,
          0,
          gutter,
          AppSpace.xxl,
        ),
        child: FutureBuilder<WatchProviders>(
          future: providers,
          builder: (context, snapshot) {
            final data = snapshot.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  tr('watch_providers'),
                  style:
                      AppType.sectionHeader.copyWith(color: palette.foreground),
                ),
                const SizedBox(height: AppSpace.lg),
                if (snapshot.connectionState != ConnectionState.done)
                  const DetailsBlock(height: 120)
                else if (data == null)
                  DetailsMessage(message: tr('check_connection'))
                else ...<Widget>[
                  _ProviderGroup(
                    title: tr('stream'),
                    empty: tr('no_stream'),
                    providers: <(String?, String?)>[
                      for (final p in data.flatRate ?? const <FlatRate>[])
                        (p.logoPath, p.providerName),
                    ],
                  ),
                  _ProviderGroup(
                    title: tr('rent'),
                    empty: tr('no_rent'),
                    providers: <(String?, String?)>[
                      for (final p in data.rent ?? const <Rent>[])
                        (p.logoPath, p.providerName),
                    ],
                  ),
                  _ProviderGroup(
                    title: tr('buy'),
                    empty: tr('no_buy'),
                    providers: <(String?, String?)>[
                      for (final p in data.buy ?? const <Buy>[])
                        (p.logoPath, p.providerName),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProviderGroup extends StatelessWidget {
  const _ProviderGroup({
    required this.title,
    required this.empty,
    required this.providers,
  });

  final String title;
  final String empty;
  final List<(String?, String?)> providers;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: AppType.kicker.copyWith(color: palette.mutedText),
          ),
          const SizedBox(height: AppSpace.md),
          if (providers.isEmpty)
            Text(empty, style: AppType.body.copyWith(color: palette.mutedText))
          else
            Wrap(
              spacing: AppSpace.md,
              runSpacing: AppSpace.md,
              children: <Widget>[
                for (final (logo, name) in providers)
                  SizedBox(
                    width: 72,
                    child: Column(
                      children: <Widget>[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadii.hero),
                          child: Container(
                            width: 56,
                            height: 56,
                            color: palette.raisedSurface,
                            child: tmdbImageUrl(context, logo, size: 'w154/') ==
                                    null
                                ? null
                                : CachedNetworkImage(
                                    imageUrl: tmdbImageUrl(context, logo,
                                        size: 'w154/')!,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          name ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppType.metadata
                              .copyWith(color: palette.foreground),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
