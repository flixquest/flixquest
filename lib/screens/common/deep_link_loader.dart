import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../constants/app_constants.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../design/skeleton.dart';
import '../../functions/function.dart';
import '../../mobile/widgets/details_header.dart';
import '../../mobile/widgets/media_art.dart';
import '../../mobile/widgets/page_kit.dart';
import '../../models/custom_exceptions.dart';

/// The route a link lands on while the record behind it is fetched.
///
/// A link can only hand the app an identity, and the detail pages read the rating, the vote count
/// and the synopsis straight off the record they are given — so a page built from the link alone
/// shows a title with none of its facts, and for a bookmarked one writes those blanks back over what
/// was saved. The fetch therefore happens here, in front of whatever artwork the link came with, and
/// the page is built only once there is a whole record to build it from.
///
/// TMDB and IMDb links arrive here directly. Widgets use this screen to retry a
/// failed fetch after preparing their destination before navigation.
class DeepLinkLoader extends StatefulWidget {
  const DeepLinkLoader({
    required this.load,
    this.initialError,
    this.title,
    this.artworkPath,
    super.key,
  });

  /// A failed pre-navigation fetch, shown immediately without fetching again.
  final Object? initialError;

  /// Fetches the record and returns the page that renders it.
  final Future<Widget> Function(BuildContext context) load;

  /// Name of the title being opened, as the link spelled it.
  final String? title;

  /// Backdrop, still or poster to show behind the wait, when the link came with one.
  final String? artworkPath;

  @override
  State<DeepLinkLoader> createState() => _DeepLinkLoaderState();
}

class _DeepLinkLoaderState extends State<DeepLinkLoader> {
  /// The TMDB helpers retry until they are told to stop, and this wait is already on top of a cold
  /// start, so it is bounded here rather than left to them.
  static const Duration _limit = Duration(seconds: 12);

  Widget? _page;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.initialError;
    if (_error == null) _resolve();
  }

  Future<void> _resolve() async {
    try {
      // The fetch helpers retry a dropped connection for hours, and a wait this route has already
      // given up on goes on retrying unseen. Asking first keeps the offline case from starting one
      // at all, and answers straight away.
      if (!await checkConnection()) {
        throw const SocketException('No connection to fetch the record');
      }
      if (!mounted) return;
      final page = await widget.load(context).timeout(_limit);
      if (!mounted) return;
      setState(() => _page = page);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  void _retry() {
    setState(() => _error = null);
    _resolve();
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    if (page != null) return page;
    final palette = AppPalette.of(context);
    if (_error != null) {
      return Scaffold(
        backgroundColor: palette.page,
        appBar: AppBar(
          backgroundColor: palette.page,
          surfaceTintColor: Colors.transparent,
          foregroundColor: palette.foreground,
        ),
        body: _failure(context),
      );
    }
    return Scaffold(
      backgroundColor: palette.page,
      body: _waiting(context),
    );
  }

  /// The page's shape while the record comes: the link's artwork (or a
  /// block where it goes), its title, and the lines a details page opens
  /// with.
  Widget _waiting(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final title = widget.title;
    final artwork = widget.artworkPath;
    final width = MediaQuery.sizeOf(context).width;
    return SkeletonPulse(
      label: title,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: width,
              height: width * 9 / 16,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (artwork != null)
                    _Artwork(path: artwork)
                  else
                    const SkeletonBlock(radius: 0),
                  PositionedDirectional(
                    top: MediaQuery.paddingOf(context).top + 8,
                    start: AppSpace.sm,
                    child: DetailsRoundButton(
                      icon: PhosphorIcons.caretLeft(),
                      tooltip:
                          MaterialLocalizations.of(context).backButtonTooltip,
                      onArtwork: true,
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null && title.isNotEmpty)
                    ExcludeSemantics(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.scaled(context, AppType.heroTitle)
                            .copyWith(color: palette.foreground),
                      ),
                    )
                  else
                    const SkeletonBlock.line(width: 220, height: 30),
                  const SizedBox(height: AppSpace.md),
                  const SkeletonBlock.line(width: 150),
                  const SizedBox(height: AppSpace.lg),
                  const SkeletonBlock(height: 48, radius: AppRadii.button),
                  const SizedBox(height: AppSpace.lg),
                  const SkeletonBlock.line(height: 13),
                  const SizedBox(height: AppSpace.sm),
                  const SkeletonBlock.line(height: 13),
                  const SizedBox(height: AppSpace.sm),
                  const FractionallySizedBox(
                    widthFactor: .6,
                    child: SkeletonBlock.line(height: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A record TMDB does not hold will not appear on a second attempt, so that case says as much and
  /// offers no retry. Everything else is the connection, which may well come back.
  Widget _failure(BuildContext context) {
    final missing = _error is NotFoundException;
    return EmptyState(
      icon: missing ? PhosphorIcons.filmSlate() : PhosphorIcons.cloudSlash(),
      title: missing ? tr('link_unavailable') : tr('error_occured'),
      message: missing ? tr('link_unavailable_message') : tr('check_connection'),
      actionLabel: missing ? null : tr('retry'),
      actionIcon: PhosphorIcons.arrowClockwise(),
      onAction: missing ? null : _retry,
    );
  }
}

/// The artwork the link arrived with, fading into the page as a details
/// page's backdrop does.
class _Artwork extends StatelessWidget {
  const _Artwork({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final url = tmdbImageUrl(context, path, size: 'w780/');
    return Stack(
      fit: StackFit.expand,
      children: [
        if (url != null)
          CachedNetworkImage(
            cacheManager: cacheProp(),
            imageUrl: url,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            placeholder: (_, __) => const SkeletonBlock(radius: 0),
            errorWidget: (_, __, ___) => const ArtPlaceholder(),
          ),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 120,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x8C000000), Color(0x00000000)],
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: const Alignment(0, 0.25),
              end: Alignment.bottomCenter,
              stops: const [0, .94, 1],
              colors: [palette.scrim(0), palette.page, palette.page],
            ),
          ),
        ),
      ],
    );
  }
}
