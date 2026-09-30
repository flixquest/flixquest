import 'dart:math' as math;

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
import 'provider_loading_widget.dart';

/// Landscape screens at least this wide (TV at 960, landscape phones and
/// tablets) put the title over full-bleed artwork instead of beneath it.
const _wideMinWidth = 560.0;

/// Below this, the wide layout has no room for the ad column beside the race
/// and stacks it underneath instead.
const _adsBesideMinWidth = 760.0;

/// The ad column's width: a medium rectangle and its pass button.
const _adsWidth = 300.0;

/// The hand-off between a title page and its player.
///
/// Keeping the title's artwork and identity on screen makes resolving a stream
/// feel like playback is starting, rather than navigating to an unrelated
/// loading page. The source race stays visible and honest beneath the title.
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
    final wide =
        viewport.width > viewport.height && viewport.width >= _wideMinWidth;
    final hasArtwork = (backdropPath?.isNotEmpty ?? false) ||
        (posterPath?.isNotEmpty ?? false);
    // Kept clear of TV overscan at the screen's edges.
    final side = wide
        ? (viewport.width >= 900 ? 48.0 : AppSpace.xxl)
        : AppSpace.gutter(context);
    // Clears the portrait artwork, so the title starts where it has faded
    // into the page.
    final artworkClearance =
        (viewport.width * 9 / 16 + 58).clamp(210.0, 330.0).toDouble();
    final race = ProviderLoadingWidget(
      providers: providers,
      currentIndex: currentProviderIndex,
    );

    return Scaffold(
      backgroundColor: palette.page,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: hasArtwork || palette.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _PlaybackArtwork(
              backdropPath: backdropPath,
              posterPath: posterPath,
              wide: wide,
              portraitHeight: artworkClearance + 48,
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final padding = wide
                      ? EdgeInsetsDirectional.fromSTEB(side, 56, side, 24)
                      : EdgeInsetsDirectional.fromSTEB(
                          side,
                          0,
                          side,
                          AppSpace.xxxl,
                        );
                  return SingleChildScrollView(
                    padding: padding,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: math.max(
                          0,
                          constraints.maxHeight - padding.vertical,
                        ),
                      ),
                      child: wide
                          ? _WideLoadingLayout(
                              title: title,
                              subtitle: subtitle,
                              race: race,
                            )
                          : _PortraitLoadingLayout(
                              title: title,
                              subtitle: subtitle,
                              artworkClearance: artworkClearance,
                              race: race,
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
                    start: wide ? side - 8 : AppSpace.sm,
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
                    end: wide ? side : AppSpace.lg,
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
    required this.artworkClearance,
    required this.race,
  });

  final String title;
  final String? subtitle;
  final double artworkClearance;
  final Widget race;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(height: artworkClearance),
        _TitleBlock(title: title, subtitle: subtitle, wide: false),
        const SizedBox(height: AppSpace.xxl),
        race,
        const SizedBox(height: AppSpace.xxxl),
        const Center(child: _LoadingAds()),
      ],
    );
  }
}

class _WideLoadingLayout extends StatelessWidget {
  const _WideLoadingLayout({
    required this.title,
    required this.subtitle,
    required this.race,
  });

  final String title;
  final String? subtitle;
  final Widget race;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final adsBeside = constraints.maxWidth >= _adsBesideMinWidth;
        final details = Align(
          alignment: AlignmentDirectional.centerStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _TitleBlock(title: title, subtitle: subtitle, wide: true),
                const SizedBox(height: AppSpace.xxl),
                race,
                if (!adsBeside) ...<Widget>[
                  const SizedBox(height: AppSpace.xxl),
                  const _LoadingAds(),
                ],
              ],
            ),
          ),
        );
        if (!adsBeside) {
          return Align(alignment: Alignment.center, child: details);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(child: details),
            const SizedBox(width: 40),
            const SizedBox(width: _adsWidth, child: _LoadingAds()),
          ],
        );
      },
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.title,
    required this.subtitle,
    required this.wide,
  });

  final String title;
  final String? subtitle;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final subtitle = this.subtitle?.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppType.scaled(
            context,
            wide ? AppType.heroTitle : AppType.pageTitle,
          ).copyWith(color: palette.foreground),
        ),
        if (subtitle?.isNotEmpty == true) ...<Widget>[
          const SizedBox(height: AppSpace.xs),
          Text(
            subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppType.scaled(context, AppType.body).copyWith(
              color: wide ? palette.secondaryText : palette.mutedText,
            ),
          ),
        ],
      ],
    );
  }
}

/// A medium rectangle. The viewer is waiting anyway, so it earns a viewable
/// impression on every play without delaying it.
class _LoadingAds extends StatelessWidget {
  const _LoadingAds();

  @override
  Widget build(BuildContext context) =>
      const StartIoAdSlot(placement: 'stream_loading');
}

class _PlaybackArtwork extends StatelessWidget {
  const _PlaybackArtwork({
    required this.backdropPath,
    required this.posterPath,
    required this.wide,
    required this.portraitHeight,
  });

  final String? backdropPath;
  final String? posterPath;
  final bool wide;
  final double portraitHeight;

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

    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: double.infinity,
        height: wide ? viewport.height : portraitHeight,
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
                fadeInDuration: const Duration(milliseconds: 320),
                placeholder: (_, __) => ColoredBox(color: palette.page),
                errorWidget: (_, __, ___) => ColoredBox(color: palette.page),
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
            if (image != null)
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
            if (wide) ...<Widget>[
              // The text column sits on the start side; the ad column and the
              // rest of the artwork stay readable under a lighter veil.
              ColoredBox(color: palette.scrim(.42)),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.centerStart,
                    end: AlignmentDirectional.centerEnd,
                    stops: const <double>[0, .38, .72],
                    colors: <Color>[
                      palette.scrim(.92),
                      palette.scrim(.72),
                      palette.scrim(0),
                    ],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: const <double>[0, .45],
                    colors: <Color>[palette.page, palette.scrim(0)],
                  ),
                ),
              ),
            ] else
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const <double>[0, .45, .85, 1],
                    colors: <Color>[
                      palette.scrim(0),
                      palette.scrim(.06),
                      palette.scrim(.86),
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
