import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../constants/api_constants.dart';
import '../constants/app_constants.dart' show cacheProp;
import '../design/app_palette.dart';
import '../design/app_tokens.dart';
import '../functions/function.dart';
import '../models/provider_load_state.dart';
import '../provider/app_dependency_provider.dart';
import '../provider/settings_provider.dart';
import 'hosted_ads_banner.dart';
import 'playback_ads.dart';
import 'provider_loading_widget.dart';

/// The hand-off between a title page and its player.
///
/// Keeping the title's artwork and identity on screen makes resolving a stream
/// feel like playback is starting, rather than navigating to an unrelated
/// loading page. The source race remains visible and honest in the raised
/// panel below it.
class PlaybackLoadingScreen extends StatelessWidget {
  const PlaybackLoadingScreen({
    required this.title,
    required this.providers,
    required this.currentProviderIndex,
    this.subtitle,
    this.backdropPath,
    this.posterPath,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? backdropPath;
  final String? posterPath;
  final List<ProviderLoadState> providers;
  final int currentProviderIndex;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final viewport = MediaQuery.sizeOf(context);
    final wide = viewport.width >= 1100 && viewport.width > viewport.height;
    final hasArtwork = (backdropPath?.isNotEmpty ?? false) ||
        (posterPath?.isNotEmpty ?? false);

    return Scaffold(
      backgroundColor: palette.page,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _PlaybackArtwork(
              backdropPath: backdropPath,
              posterPath: posterPath,
              wide: wide,
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: EdgeInsetsDirectional.only(
                      start: wide ? 48 : AppSpace.gutter(context),
                      end: wide ? 48 : AppSpace.gutter(context),
                      bottom: AppSpace.xxl,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - AppSpace.xxl,
                      ),
                      child: wide
                          ? _WideLoadingLayout(
                              title: title,
                              subtitle: subtitle,
                              hasArtwork: hasArtwork,
                              providers: providers,
                              currentProviderIndex: currentProviderIndex,
                            )
                          : _PortraitLoadingLayout(
                              title: title,
                              subtitle: subtitle,
                              hasArtwork: hasArtwork,
                              providers: providers,
                              currentProviderIndex: currentProviderIndex,
                            ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: wide ? 40 : AppSpace.sm,
                    top: AppSpace.xs,
                  ),
                  child: _ArtworkBackButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: AlignmentDirectional.topEnd,
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    end: wide ? 48 : AppSpace.lg,
                    top: AppSpace.md,
                  ),
                  child: SvgPicture.asset(
                    'assets/images/fq_mark.svg',
                    width: 25,
                    height: 31,
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

class _PortraitLoadingLayout extends StatelessWidget {
  const _PortraitLoadingLayout({
    required this.title,
    required this.subtitle,
    required this.hasArtwork,
    required this.providers,
    required this.currentProviderIndex,
  });

  final String title;
  final String? subtitle;
  final bool hasArtwork;
  final List<ProviderLoadState> providers;
  final int currentProviderIndex;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final viewport = MediaQuery.sizeOf(context);
    final compactLandscape = viewport.width > viewport.height;
    final artworkClearance = compactLandscape
        ? 64.0
        : (viewport.width * 9 / 16 + 58).clamp(210.0, 330.0);
    final titleColor = compactLandscape && hasArtwork
        ? const Color(0xFFF7F7F7)
        : palette.foreground;
    final subtitleColor = compactLandscape && hasArtwork
        ? const Color(0xFFD6D7D7)
        : palette.mutedText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(height: artworkClearance),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppType.scaled(context, AppType.pageTitle).copyWith(
            color: titleColor,
          ),
        ),
        if (subtitle?.trim().isNotEmpty == true) ...<Widget>[
          const SizedBox(height: AppSpace.xs),
          Text(
            subtitle!.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppType.scaled(context, AppType.body).copyWith(
              color: subtitleColor,
            ),
          ),
        ],
        const SizedBox(height: AppSpace.xl),
        StreamLoadingAds(
          child: ProviderLoadingWidget(
            providers: providers,
            currentIndex: currentProviderIndex,
          ),
        ),
      ],
    );
  }
}

class _WideLoadingLayout extends StatelessWidget {
  const _WideLoadingLayout({
    required this.title,
    required this.subtitle,
    required this.hasArtwork,
    required this.providers,
    required this.currentProviderIndex,
  });

  final String title;
  final String? subtitle;
  final bool hasArtwork;
  final List<ProviderLoadState> providers;
  final int currentProviderIndex;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final artworkColor =
        hasArtwork ? const Color(0xFFF7F7F7) : palette.foreground;
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpace.xxl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 470),
                    child: Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style:
                          AppType.scaled(context, AppType.heroTitle).copyWith(
                        color: artworkColor,
                        fontSize: 38,
                        height: 1.05,
                      ),
                    ),
                  ),
                  if (subtitle?.trim().isNotEmpty == true) ...<Widget>[
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      subtitle!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.scaled(context, AppType.body).copyWith(
                        color: hasArtwork
                            ? const Color(0xFFD6D7D7)
                            : palette.mutedText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            flex: 7,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: ProviderLoadingWidget(
                    providers: providers,
                    currentIndex: currentProviderIndex,
                  ),
                ),
                const SizedBox(width: AppSpace.xxl),
                const SizedBox(
                  width: 320,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      StartIoAdSlot(placement: 'stream_loading'),
                      SizedBox(height: AppSpace.md),
                      AdFreePassButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaybackArtwork extends StatelessWidget {
  const _PlaybackArtwork({
    required this.backdropPath,
    required this.posterPath,
    required this.wide,
  });

  final String? backdropPath;
  final String? posterPath;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final useBackdrop = backdropPath?.isNotEmpty == true;
    final path = useBackdrop ? backdropPath : posterPath;
    final image = path == null || path.isEmpty
        ? null
        : _artworkUrl(
            context,
            path,
            size: useBackdrop ? 'w1280/' : 'w780/',
          );
    final viewport = MediaQuery.sizeOf(context);
    final artworkHeight = wide
        ? viewport.height
        : (viewport.width * 9 / 16 + 180).clamp(360.0, 560.0);

    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: double.infinity,
        height: artworkHeight,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (image != null)
              CachedNetworkImage(
                cacheManager: cacheProp(),
                imageUrl: image,
                memCacheWidth:
                    (viewport.width * MediaQuery.devicePixelRatioOf(context))
                        .round(),
                fit: BoxFit.cover,
                alignment: useBackdrop ? Alignment.center : Alignment.topCenter,
                fadeInDuration: const Duration(milliseconds: 220),
                placeholder: (_, __) =>
                    ColoredBox(color: palette.raisedSurface),
                errorWidget: (_, __, ___) =>
                    ColoredBox(color: palette.raisedSurface),
              )
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(.35, -.65),
                    radius: 1.05,
                    colors: <Color>[
                      palette.idleFillStrong,
                      palette.raisedSurface,
                      palette.page,
                    ],
                  ),
                ),
              ),
            if (wide && image != null)
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x47000000),
                ),
              ),
            const Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: 120,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0x8C000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
            ),
            if (!wide)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: const Alignment(0, -.1),
                    end: Alignment.bottomCenter,
                    stops: const <double>[0, .56, .88, 1],
                    colors: <Color>[
                      Color(0x00000000),
                      Color(0x12000000),
                      palette.page,
                      palette.page,
                    ],
                  ),
                ),
              )
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: const <double>[0, .43, .76, 1],
                    colors: <Color>[
                      Color(0x00000000),
                      Color(0x24000000),
                      palette.scrim(.78),
                      palette.page,
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _artworkUrl(BuildContext context, String path,
      {required String size}) {
    final settings = context.watch<SettingsProvider>();
    final dependencies = context.watch<AppDependencyProvider>();
    final base = buildImageUrl(
      TMDB_BASE_IMAGE_URL,
      dependencies.tmdbProxy,
      settings.enableProxy,
      context,
    );
    return '$base$size$path';
  }
}

class _ArtworkBackButton extends StatelessWidget {
  const _ArtworkBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 48,
      child: IconButton(
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: const Color(0x61000000),
          foregroundColor: const Color(0xFFFFFFFF),
        ),
        icon: Icon(PhosphorIcons.caretLeft(), size: 23),
      ),
    );
  }
}
