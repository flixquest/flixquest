import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
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
import '../models/tv_media_item.dart';
import '../../design/title_logo.dart';

export '../../design/title_logo.dart';

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
    Localizations.localeOf(context);
    final palette = TvPalette.of(context);
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
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[
                palette.scrim(0.95),
                palette.scrim(0.7),
                palette.scrim(0.2),
                palette.scrim(0),
              ],
              stops: <double>[0, 0.32, 0.62, 0.85],
            ),
          ),
        ),
        // ...and the rows at the bottom.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                palette.scrim(0),
                palette.scrim(0.25),
                palette.scrim(0.85),
                palette.page,
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
        isMovie ? tr('movie') : tr('series'),
        if (item.rating case final rating? when rating > 0)
          '★ ${rating.toStringAsFixed(1)}',
        if (item.progressLabel case final label?) label,
      ],
      overview: item.overview,
      kicker: featured
          ? (isMovie ? tr('tv_featured_movie') : tr('tv_featured_series'))
          : null,
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
///
/// It fits the height it is given. A short TV (or a page whose rows sit
/// high) leaves little room above the rows, so the synopsis gives up lines
/// first, then the facts, then the kicker; the title stays, its logo
/// shrinking only when nothing else is left to give.
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

  /// Room held back from the budget, so rounding never tips it over.
  static const _slack = 2.0;

  double get _titleSize => switch ((featured, compact)) {
        (true, true) => 34,
        (true, false) => 46,
        (false, true) => 26,
        (false, false) => 34,
      };

  double get _logoHeight => switch ((featured, compact)) {
        (true, true) => 92,
        (true, false) => 124,
        (false, true) => 56,
        (false, false) => 72,
      };

  Widget _buildTitle(
    BuildContext context, {
    required double logoHeight,
    required int maxLines,
  }) {
    final palette = TvPalette.of(context);
    final text = Text(
      data.title,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: palette.foreground,
        fontFamily: 'FigtreeBold',
        fontSize: _titleSize,
        height: 1.02,
        letterSpacing: -0.6,
      ),
    );
    final item = data.item;
    if (item == null) return text;
    return TvTitleLogo(
      item: item,
      maxHeight: logoHeight,
      // The billboard's title is looked up at once; a card's waits for focus
      // to settle, so sweeping a row does not fire a lookup per card.
      settleDelay: featured ? Duration.zero : const Duration(milliseconds: 250),
      fallback: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    return LayoutBuilder(
      builder: (context, constraints) =>
          _buildFitted(context, constraints.maxHeight),
    );
  }

  Widget _buildFitted(BuildContext context, double available) {
    final palette = TvPalette.of(context);
    final colors = Theme.of(context).colorScheme;
    final scaler = MediaQuery.textScalerOf(context);
    double lines(double fontSize, double height, int count) =>
        scaler.scale(fontSize) * height * count;

    final kickerSize = compact ? 11.0 : 12.0;
    final overviewSize = compact ? 13.0 : 15.0;
    final overviewGap = compact ? 8.0 : 10.0;
    final kicker = data.kicker;

    // Every line has a set height, so what fits can be worked out up front.
    var budget = available - _slack;
    var titleLines = featured ? 2 : 1;
    var logoHeight = _logoHeight;
    if (data.item == null) {
      logoHeight = lines(_titleSize, 1.02, titleLines);
    }
    final kickerHeight =
        kicker == null ? 0.0 : math.max(18.0, lines(kickerSize, 1.2, 1)) + 8;
    final showKicker = kicker != null && budget >= kickerHeight + logoHeight;
    if (showKicker) budget -= kickerHeight;
    if (budget < logoHeight) {
      // Too little room even for the title: one line of it, as large as
      // fits, and nothing else.
      titleLines = 1;
      logoHeight = math.max(lines(_titleSize, 1.02, 1), budget);
    }
    budget -= logoHeight;
    final factsHeight = 8 + lines(14, 1.1, 1);
    final showFacts = data.facts.isNotEmpty && budget >= factsHeight;
    if (showFacts) budget -= factsHeight;
    final overviewLines = data.overview.isEmpty
        ? 0
        : ((budget - overviewGap) / lines(overviewSize, 1.3, 1))
            .floor()
            .clamp(0, featured && !compact ? 3 : 2);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showKicker) ...<Widget>[
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
                  fontSize: kickerSize,
                  height: 1.2,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        _buildTitle(context, logoHeight: logoHeight, maxLines: titleLines),
        if (showFacts) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            data.facts.join('   '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.secondaryText,
              fontFamily: 'FigtreeSB',
              fontSize: 14,
              height: 1.1,
            ),
          ),
        ],
        if (overviewLines > 0) ...<Widget>[
          SizedBox(height: overviewGap),
          Text(
            data.overview,
            maxLines: overviewLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.secondaryText,
              fontSize: overviewSize,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }
}

/// The TV's name for the shared title logo.
typedef TvTitleLogo = TitleLogo;
