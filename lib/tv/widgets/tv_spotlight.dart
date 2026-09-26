import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../constants/api_constants.dart';
import '../../constants/app_constants.dart';
import '../../functions/function.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../app/tv_design.dart';
import '../controllers/tv_title_logos.dart';
import '../models/tv_media_item.dart';

/// Full-bleed artwork for the item in the spotlight.
///
/// Changes wait for focus to settle, so holding the D-pad across a row does
/// not download and decode a backdrop per card. The new image fades in over
/// the previous one instead of flashing through an empty frame.
class TvBackdrop extends StatefulWidget {
  const TvBackdrop({
    required this.item,
    this.settleDelay = const Duration(milliseconds: 350),
    super.key,
  });

  final TvMediaItem item;
  final Duration settleDelay;

  @override
  State<TvBackdrop> createState() => _TvBackdropState();
}

class _TvBackdropState extends State<TvBackdrop> {
  /// TMDB's largest resized backdrop; `original` can be several megapixels.
  static const _imageSize = 'w1280';

  /// The settled image and, beneath it, the one it is fading in over.
  final List<String> _paths = <String>[];
  Timer? _settleTimer;

  @override
  void initState() {
    super.initState();
    final path = _pathFor(widget.item);
    if (path != null) _paths.add(path);
  }

  @override
  void didUpdateWidget(TvBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    final path = _pathFor(widget.item);
    _settleTimer?.cancel();
    // An item without artwork keeps the last backdrop rather than going black.
    if (path == null || (_paths.isNotEmpty && _paths.last == path)) return;
    _settleTimer = Timer(widget.settleDelay, () {
      if (!mounted) return;
      setState(() {
        _paths
          ..remove(path)
          ..add(path);
        if (_paths.length > 2) _paths.removeAt(0);
      });
    });
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    super.dispose();
  }

  String? _pathFor(TvMediaItem item) => item.backdropPath ?? item.posterPath;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final proxy = context.watch<AppDependencyProvider>().tmdbProxy;
    final baseUrl = buildImageUrl(
      TMDB_BASE_IMAGE_URL,
      proxy,
      settings.enableProxy,
      context,
    );
    final decodeWidth = math.min(
      1280,
      (MediaQuery.sizeOf(context).width *
              MediaQuery.devicePixelRatioOf(context))
          .round(),
    );

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        for (final path in _paths)
          CachedNetworkImage(
            key: ValueKey<String>(path),
            cacheManager: cacheProp(),
            imageUrl: '$baseUrl$_imageSize/$path',
            memCacheWidth: decodeWidth,
            fit: BoxFit.cover,
            alignment: Alignment.topRight,
            fadeInDuration: const Duration(milliseconds: 450),
            fadeOutDuration: Duration.zero,
            // Transparent, so the previous backdrop shows until this one lands.
            placeholder: (_, __) => const SizedBox.shrink(),
            errorWidget: (_, __, ___) => const SizedBox.shrink(),
          ),
        // Keeps the spotlight text legible on the left...
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[
                Color(0xf2050606),
                Color(0xb3050606),
                Color(0x33050606),
                Color(0x00050606),
              ],
              stops: <double>[0, 0.32, 0.62, 0.85],
            ),
          ),
        ),
        // ...and the rows at the bottom.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0x00050606),
                Color(0x40050606),
                Color(0xd9050606),
                TvDesign.pageBackground,
              ],
              stops: <double>[0, 0.42, 0.76, 1],
            ),
          ),
        ),
      ],
    );
  }
}

/// What the spotlight says about the focused tile: a media item, or a
/// shortcut such as a streaming service or genre.
class TvSpotlightData {
  const TvSpotlightData({
    required this.id,
    required this.title,
    this.facts = const <String>[],
    this.overview = '',
    this.kicker,
    this.kickerIcon,
    this.item,
  });

  /// The billboard's [featured] treatment adds the "Featured movie" kicker.
  factory TvSpotlightData.forItem(TvMediaItem item, {bool featured = false}) {
    final isMovie = item.kind == TvMediaKind.movie;
    return TvSpotlightData(
      id: item.stableId,
      title: item.title,
      facts: <String>[
        if (item.year case final year?) year,
        isMovie ? 'Movie' : 'Series',
        if (item.rating case final rating? when rating > 0)
          '★ ${rating.toStringAsFixed(1)}',
        if (item.progressLabel case final label?) label,
      ],
      overview: item.overview,
      kicker:
          featured ? (isMovie ? 'FEATURED MOVIE' : 'FEATURED SERIES') : null,
      kickerIcon: featured
          ? (isMovie ? PhosphorIcons.filmSlate() : PhosphorIcons.television())
          : null,
      item: item,
    );
  }

  final String id;
  final String title;
  final List<String> facts;
  final String overview;
  final String? kicker;
  final IconData? kickerIcon;

  /// The title whose logo stands in for [title], when it has one.
  final TvMediaItem? item;
}

/// Title, facts and synopsis for the tile in the spotlight.
///
/// [featured] is the billboard treatment: a larger title and more synopsis.
class TvSpotlightInfo extends StatelessWidget {
  const TvSpotlightInfo({
    required this.data,
    required this.featured,
    required this.compact,
    super.key,
  });

  final TvSpotlightData data;
  final bool featured;
  final bool compact;

  Widget _buildTitle() {
    final text = Text(
      data.title,
      maxLines: featured ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: TvDesign.foreground,
        fontFamily: 'FigtreeBold',
        fontSize: switch ((featured, compact)) {
          (true, true) => 34,
          (true, false) => 46,
          (false, true) => 26,
          (false, false) => 34,
        },
        height: 1.02,
        letterSpacing: -0.6,
      ),
    );
    final item = data.item;
    if (item == null) return text;
    return TvTitleLogo(
      item: item,
      maxHeight: switch ((featured, compact)) {
        (true, true) => 92,
        (true, false) => 124,
        (false, true) => 56,
        (false, false) => 72,
      },
      // The billboard's title is looked up at once; a card's waits for focus
      // to settle, so sweeping a row does not fire a lookup per card.
      settleDelay: featured ? Duration.zero : const Duration(milliseconds: 250),
      fallback: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final kicker = data.kicker;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (kicker != null) ...<Widget>[
          Row(
            children: <Widget>[
              if (data.kickerIcon case final icon?) ...<Widget>[
                Icon(icon, color: colors.primary, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                kicker,
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
        ],
        _buildTitle(),
        if (data.facts.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            data.facts.join('   '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xffd2d2d2),
              fontFamily: 'FigtreeSB',
              fontSize: 14,
              height: 1.1,
            ),
          ),
        ],
        if (data.overview.isNotEmpty) ...<Widget>[
          SizedBox(height: compact ? 8 : 10),
          Text(
            data.overview,
            maxLines: featured && !compact ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xffdedede),
              fontSize: compact ? 13 : 15,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }
}

/// [item]'s logo artwork from TMDB, or [fallback] (its name as text) until the
/// logo is found, or when it has none.
///
/// Logos are drawn in the space the text would take, left aligned and never
/// wider than the spotlight, so a wide wordmark and a stacked one read at a
/// similar size.
class TvTitleLogo extends StatefulWidget {
  const TvTitleLogo({
    required this.item,
    required this.maxHeight,
    required this.fallback,
    this.settleDelay = Duration.zero,
    super.key,
  });

  final TvMediaItem item;
  final double maxHeight;
  final Widget fallback;

  /// How long [item] must stay put before its logo is looked up. A logo
  /// already found shows at once.
  final Duration settleDelay;

  @override
  State<TvTitleLogo> createState() => _TvTitleLogoState();
}

class _TvTitleLogoState extends State<TvTitleLogo> {
  /// Sharp enough at the billboard's size on a 1080p panel, and a fraction of
  /// `original`.
  static const _imageSize = 'w500';

  TvTitleLogos? _logos;
  String? _path;
  Timer? _settleTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final logos = TvTitleLogoScope.maybeOf(context);
    if (!identical(logos, _logos)) {
      _logos = logos;
      _lookUp();
    }
  }

  @override
  void didUpdateWidget(TvTitleLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.kind != widget.item.kind ||
        oldWidget.item.id != widget.item.id) {
      _lookUp();
    }
  }

  void _lookUp() {
    _settleTimer?.cancel();
    final logos = _logos;
    final item = widget.item;
    _path = logos != null && logos.isKnown(item) ? logos.known(item) : null;
    if (logos == null || logos.isKnown(item)) return;
    void resolve() {
      logos.resolve(item).then((path) {
        if (!mounted || path == null) return;
        if (!identical(widget.item, item) || !identical(_logos, logos)) return;
        setState(() => _path = path);
      });
    }

    if (widget.settleDelay == Duration.zero) {
      resolve();
    } else {
      _settleTimer = Timer(widget.settleDelay, resolve);
    }
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = _path;
    if (path == null) return widget.fallback;
    final settings = context.watch<SettingsProvider>();
    final proxy = context.watch<AppDependencyProvider>().tmdbProxy;
    final baseUrl = buildImageUrl(
      TMDB_BASE_IMAGE_URL,
      proxy,
      settings.enableProxy,
      context,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = math.min(constraints.maxWidth, widget.maxHeight * 5);
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: widget.maxHeight,
          ),
          child: CachedNetworkImage(
            cacheManager: cacheProp(),
            imageUrl: '$baseUrl$_imageSize$path',
            memCacheWidth:
                (maxWidth * MediaQuery.devicePixelRatioOf(context)).round(),
            fit: BoxFit.contain,
            alignment: Alignment.bottomLeft,
            fadeInDuration: const Duration(milliseconds: 220),
            fadeOutDuration: Duration.zero,
            // The name holds the space until the artwork has decoded, and
            // stays if it never does.
            placeholder: (_, __) => widget.fallback,
            errorWidget: (_, __, ___) => widget.fallback,
            imageBuilder: (_, image) => Semantics(
              label: widget.item.title,
              image: true,
              child: Image(
                image: image,
                fit: BoxFit.contain,
                alignment: Alignment.bottomLeft,
              ),
            ),
          ),
        );
      },
    );
  }
}
