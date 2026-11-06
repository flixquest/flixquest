import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../models/wellness_recap.dart';
import '../../../models/wellness_recap_story.dart';

/// The shapes a recap exports to. Sizes are the card's own coordinates: it is
/// always laid out at this size and scaled, so the preview and the exported
/// file have the same layout on every phone.
enum ShareRecapFormat {
  /// 1080 × 1350, the tallest image a feed shows whole.
  post(Size(360, 450), 3),

  /// 1080 × 1920 for Stories and Status.
  story(Size(360, 640), 5);

  const ShareRecapFormat(this.designSize, this.posterCount);

  final Size designSize;

  /// The most posters the art fan shows.
  final int posterCount;

  static const int exportWidth = 1080;

  double get aspectRatio => designSize.width / designSize.height;

  /// The ratio that renders a boundary [boundaryWidth] wide at [exportWidth]
  /// pixels, whatever size the preview happens to be.
  double pixelRatioFor(double boundaryWidth) => exportWidth / boundaryWidth;
}

enum ShareRecapStyle { light, dark, lightsOut }

enum ShareRecapArtKind { poster, backdrop }

/// Turns a stored artwork path into an image, or null when it can't be shown.
typedef ShareRecapArtResolver = ImageProvider? Function(
  String path,
  ShareRecapArtKind kind,
);

const Color _accent = Color(0xFFF57C00);

class _CardColors {
  const _CardColors({
    required this.base,
    required this.deep,
    required this.foreground,
    required this.scrimTop,
    required this.scrimMiddle,
    required this.artOpacity,
    required this.tile,
  });

  final Color base;
  final Color deep;
  final Color foreground;
  final double scrimTop;
  final double scrimMiddle;
  final double artOpacity;
  final Color tile;

  Color get muted => foreground.withValues(alpha: .7);
  Color get faint => foreground.withValues(alpha: .24);

  static _CardColors of(ShareRecapStyle style) => switch (style) {
        ShareRecapStyle.light => const _CardColors(
            base: Color(0xFFFAF8F5),
            deep: Color(0xFFF3ECE3),
            foreground: Color(0xFF1E1A16),
            scrimTop: .5,
            scrimMiddle: .86,
            artOpacity: .9,
            tile: Color(0xFFEDE4D8),
          ),
        ShareRecapStyle.dark => const _CardColors(
            base: Color(0xFF17191C),
            deep: Color(0xFF0E0F11),
            foreground: Colors.white,
            scrimTop: .62,
            scrimMiddle: .86,
            artOpacity: 1,
            tile: Color(0xFF2A2D31),
          ),
        ShareRecapStyle.lightsOut => const _CardColors(
            base: Colors.black,
            deep: Colors.black,
            foreground: Colors.white,
            scrimTop: .74,
            scrimMiddle: .94,
            artOpacity: .85,
            tile: Color(0xFF191919),
          ),
      };
}

/// The recap people share: a period's viewing as a single picture.
///
/// Parent it at any size with [ShareRecapFormat.aspectRatio]; it scales itself
/// and ignores the system text size, because the file it becomes is read on
/// someone else's phone.
class ShareRecapCard extends StatelessWidget {
  const ShareRecapCard({
    required this.story,
    required this.format,
    required this.style,
    required this.includeTitles,
    required this.includeHabits,
    required this.artFor,
    super.key,
  });

  final WellnessRecapStory story;
  final ShareRecapFormat format;
  final ShareRecapStyle style;

  /// Whether titles and their artwork may appear.
  final bool includeTitles;

  /// Whether the viewer type, genres and viewing times may appear.
  final bool includeHabits;

  final ShareRecapArtResolver artFor;

  /// Every image this card draws, so an export can wait for them.
  static List<ImageProvider> artworkOf({
    required WellnessRecapStory story,
    required ShareRecapFormat format,
    required bool includeTitles,
    required ShareRecapArtResolver artFor,
  }) {
    if (!includeTitles) return const [];
    return <ImageProvider?>[
      for (final title in _fanOf(story, format))
        artFor(title.posterPath!, ShareRecapArtKind.poster),
      if (story.backgroundPath != null)
        artFor(story.backgroundPath!, ShareRecapArtKind.backdrop),
    ].whereType<ImageProvider>().toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _CardColors.of(style);
    final size = format.designSize;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.fill,
        child: SizedBox.fromSize(
          size: size,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.noScaling,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _Backdrop(
                  colors: colors,
                  image: includeTitles && story.backgroundPath != null
                      ? artFor(
                          story.backgroundPath!,
                          ShareRecapArtKind.backdrop,
                        )
                      : null,
                ),
                switch (format) {
                  ShareRecapFormat.post => _PostLayout(card: this),
                  ShareRecapFormat.story => _StoryLayout(card: this),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }

  _CardColors get _colors => _CardColors.of(style);

  List<WellnessRecapTitle> get _fanTitles =>
      includeTitles ? _fanOf(story, format) : const <WellnessRecapTitle>[];

  /// Four posters can't balance around the top title in the middle, so a fan
  /// of four gives up its last.
  static List<WellnessRecapTitle> _fanOf(
    WellnessRecapStory story,
    ShareRecapFormat format,
  ) {
    final posters = story.postersUpTo(format.posterCount);
    return posters.length == 4 ? posters.sublist(0, 3) : posters;
  }

  WellnessViewerProfile? get _profile => includeHabits ? story.profile : null;

  List<WellnessRecapBar> get _bars =>
      // A day's bars are its hours, which are a habit; longer periods only
      // show which days had viewing.
      !includeHabits && story.period.kind == WellnessRecapPeriodKind.day
          ? const <WellnessRecapBar>[]
          : story.bars;
}

class _PostLayout extends StatelessWidget {
  const _PostLayout({required this.card});

  final ShareRecapCard card;

  @override
  Widget build(BuildContext context) {
    final colors = card._colors;
    final story = card.story;
    final fan = card._fanTitles;
    final topTitle =
        card.includeTitles ? story.titles.firstOrNull?.title : null;
    final genres = card.includeHabits ? story.genres : const <String>[];
    final stats = card.story
        .stats(includeHabits: card.includeHabits)
        .take(fan.isEmpty ? 3 : 2)
        .toList(growable: false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(period: story.period, colors: colors),
          const SizedBox(height: 10),
          if (fan.isNotEmpty) ...[
            Expanded(child: _PosterFan(card: card, titles: fan)),
            const SizedBox(height: 12),
            _Identity(card: card, nameSize: 29),
            const SizedBox(height: 9),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 11,
                  child: _TimeBlock(
                    milliseconds: story.totalWatchedMs,
                    size: 32,
                    colors: colors,
                  ),
                ),
                for (final stat in stats)
                  Expanded(
                    flex: 7,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 8),
                      child: _Stat(stat: stat, colors: colors, size: 21),
                    ),
                  ),
              ],
            ),
          ] else ...[
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.bottomStart,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Identity(card: card, nameSize: 31),
                    const SizedBox(height: 8),
                    _TimeBlock(
                      milliseconds: story.totalWatchedMs,
                      size: 76,
                      colors: colors,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _StatRow(stats: stats, colors: colors),
          ],
          if (genres.isNotEmpty) ...[
            const SizedBox(height: 9),
            _GenreLine(genres: genres, colors: colors),
          ],
          if (topTitle != null && (fan.isEmpty || genres.isEmpty)) ...[
            const SizedBox(height: 9),
            _TopTitleLine(title: topTitle, colors: colors),
          ],
          if (card._bars.isNotEmpty) ...[
            const SizedBox(height: 9),
            SizedBox(
              height: 34,
              child: _RhythmChart(bars: card._bars, colors: colors),
            ),
          ],
          const SizedBox(height: 9),
          _Footer(colors: colors),
        ],
      ),
    );
  }
}

class _StoryLayout extends StatelessWidget {
  const _StoryLayout({required this.card});

  final ShareRecapCard card;

  @override
  Widget build(BuildContext context) {
    final colors = card._colors;
    final story = card.story;
    final fan = card._fanTitles;
    final ranked = card.includeTitles
        ? story.titles.take(3).toList(growable: false)
        : const <WellnessRecapTitle>[];
    final genres = card.includeHabits ? story.genres : const <String>[];
    final stats = story
        .stats(includeHabits: card.includeHabits)
        .take(fan.isEmpty ? 3 : 2)
        .toList(growable: false);
    final busiest = card.includeHabits ? story.insights.busiestDay : null;
    final showBusiest =
        busiest != null && story.period.kind != WellnessRecapPeriodKind.day;
    return Padding(
      // Stories cover their top and bottom edges with the app's own controls,
      // so the words stay inside and only the artwork runs to the edge.
      padding: const EdgeInsets.fromLTRB(24, 54, 24, 54),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(period: story.period, colors: colors),
          const SizedBox(height: 14),
          Expanded(
            child: fan.isNotEmpty
                ? _PosterFan(card: card, titles: fan)
                : Align(
                    alignment: AlignmentDirectional.bottomStart,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Identity(card: card, nameSize: 38),
                        const SizedBox(height: 10),
                        _TimeBlock(
                          milliseconds: story.totalWatchedMs,
                          size: 84,
                          colors: colors,
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          if (fan.isNotEmpty) ...[
            _Identity(card: card, nameSize: 33),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 11,
                  child: _TimeBlock(
                    milliseconds: story.totalWatchedMs,
                    size: 34,
                    colors: colors,
                  ),
                ),
                for (final stat in stats)
                  Expanded(
                    flex: 7,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 8),
                      child: _Stat(stat: stat, colors: colors, size: 22),
                    ),
                  ),
              ],
            ),
          ] else
            _StatRow(stats: stats, colors: colors),
          if (ranked.length >= 2) ...[
            const SizedBox(height: 12),
            for (var i = 0; i < ranked.length; i++)
              _RankedTitle(rank: i + 1, title: ranked[i], colors: colors),
          ] else if (ranked.length == 1) ...[
            const SizedBox(height: 12),
            _TopTitleLine(title: ranked.first.title, colors: colors),
          ],
          if (genres.isNotEmpty) ...[
            const SizedBox(height: 10),
            _GenreChips(genres: genres, colors: colors),
          ],
          if (card._bars.isNotEmpty) ...[
            const SizedBox(height: 12),
            if (showBusiest) ...[
              Text(
                tr('ins_card_busiest', namedArgs: {
                  'day': DateFormat.MMMd().format(busiest.$1),
                  'time': formatWatchedTime(busiest.$2),
                }),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _text(colors.muted, 10.5, 'FigtreeSB'),
              ),
              const SizedBox(height: 6),
            ],
            SizedBox(
              height: fan.isEmpty ? 64 : 40,
              child: _RhythmChart(bars: card._bars, colors: colors),
            ),
          ],
          const SizedBox(height: 11),
          _Footer(colors: colors),
        ],
      ),
    );
  }
}

/// The top title's art, heavily blurred and sunk into the card's colour, so
/// every recap takes on the mood of what was watched.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.colors, required this.image});

  final _CardColors colors;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final art = image;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colors.base, colors.deep],
            ),
          ),
        ),
        if (art != null)
          Opacity(
            opacity: colors.artOpacity,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: 26,
                sigmaY: 26,
                tileMode: TileMode.clamp,
              ),
              child: Image(
                image: art,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        if (art == null) ...[
          PositionedDirectional(
            end: -96,
            top: -70,
            child: _Ring(diameter: 330, stroke: 58, color: colors.foreground),
          ),
          PositionedDirectional(
            start: -70,
            top: 150,
            child: _Ring(diameter: 170, stroke: 30, color: _accent),
          ),
        ],
        // A warm glow keeps the brand present whatever the art's colours are.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -.5),
              radius: .95,
              colors: [
                _accent.withValues(alpha: art == null ? .24 : .1),
                _accent.withValues(alpha: 0),
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0, .42, .72],
              colors: [
                colors.base
                    .withValues(alpha: art == null ? 0 : colors.scrimTop),
                colors.base
                    .withValues(alpha: art == null ? 0 : colors.scrimMiddle),
                colors.deep,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({
    required this.diameter,
    required this.stroke,
    required this.color,
  });

  final double diameter;
  final double stroke;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: .07), width: stroke),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.period, required this.colors});

  final WellnessRecapPeriod period;
  final _CardColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.asset(
            'assets/images/logo.png',
            width: 26,
            height: 26,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'FLIXQUEST',
          style: _text(colors.foreground, 12.5, 'FigtreeBold', spacing: 1.3),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _absolutePeriod(period),
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _text(colors.foreground, 12, 'FigtreeSB'),
          ),
        ),
      ],
    );
  }
}

/// A shared image outlives the moment: "This week" means nothing a month
/// later in someone's feed, so the card always names the actual dates.
String _absolutePeriod(WellnessRecapPeriod period) {
  final start = period.startLocal;
  return switch (period.kind) {
    WellnessRecapPeriodKind.day => DateFormat.yMMMd().format(start),
    WellnessRecapPeriodKind.week =>
      '${DateFormat.MMMd().format(start)} – ${DateFormat.MMMd().format(
        period.endLocal.subtract(const Duration(days: 1)),
      )}',
    WellnessRecapPeriodKind.month => DateFormat.yMMMM().format(start),
    WellnessRecapPeriodKind.year => DateFormat.y().format(start),
  };
}

/// Up to five posters fanned out, most watched in the middle and on top. It
/// fills whatever height the words leave it.
class _PosterFan extends StatelessWidget {
  const _PosterFan({required this.card, required this.titles});

  final ShareRecapCard card;
  final List<WellnessRecapTitle> titles;

  @override
  Widget build(BuildContext context) {
    return OverflowBox(
      // The outer posters are meant to run off the card's edges.
      maxWidth: card.format.designSize.width * 2,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          final posterHeight = height * .96;
          final width = posterHeight * 2 / 3;
          // Painted outermost first so the top title lands on top.
          final slots = _slotsFor(titles.length);
          final order = List<int>.generate(titles.length, (i) => i)
            ..sort((a, b) => slots[b].depth.compareTo(slots[a].depth));
          return Stack(
            alignment: Alignment.center,
            children: [
              for (final index in order)
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..translateByDouble(
                      slots[index].x * width,
                      slots[index].depth * height * .03,
                      0,
                      1,
                    )
                    ..rotateZ(slots[index].turn * math.pi / 180)
                    ..scaleByDouble(
                      slots[index].scale,
                      slots[index].scale,
                      1,
                      1,
                    ),
                  child: _Poster(
                    title: titles[index],
                    width: width,
                    height: posterHeight,
                    card: card,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static List<_FanSlot> _slotsFor(int count) => switch (count) {
        1 => const [_FanSlot(0, 0, 1, 0)],
        2 => const [
            _FanSlot(-.3, -5, 1, 0),
            _FanSlot(.34, 6, .9, 1),
          ],
        3 => const [
            _FanSlot(0, 0, 1, 0),
            _FanSlot(-.68, -8, .84, 1),
            _FanSlot(.68, 8, .84, 1),
          ],
        _ => const [
            _FanSlot(0, 0, 1, 0),
            _FanSlot(-.62, -7, .86, 1),
            _FanSlot(.62, 7, .86, 1),
            _FanSlot(-1.14, -14, .72, 2),
            _FanSlot(1.14, 14, .72, 2),
          ],
      };
}

class _FanSlot {
  const _FanSlot(this.x, this.turn, this.scale, this.depth);

  /// Offset from the centre, in poster widths.
  final double x;

  /// Rotation in degrees.
  final double turn;
  final double scale;

  /// 0 is frontmost.
  final int depth;
}

class _Poster extends StatelessWidget {
  const _Poster({
    required this.title,
    required this.width,
    required this.height,
    required this.card,
  });

  final WellnessRecapTitle title;
  final double width;
  final double height;
  final ShareRecapCard card;

  @override
  Widget build(BuildContext context) {
    final colors = card._colors;
    final image = card.artFor(title.posterPath!, ShareRecapArtKind.poster);
    final fallback = _PosterFallback(title: title.title, colors: colors);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.tile,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .42),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      clipBehavior: Clip.antiAlias,
      child: image == null
          ? fallback
          : Image(
              image: image,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              frameBuilder: (context, child, frame, wasSync) =>
                  frame == null && !wasSync ? fallback : child,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }
}

/// What stands in for a poster that couldn't load, so an offline export is
/// still a finished picture rather than an empty frame.
class _PosterFallback extends StatelessWidget {
  const _PosterFallback({required this.title, required this.colors});

  final String title;
  final _CardColors colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.tile,
            Color.alphaBlend(_accent.withValues(alpha: .34), colors.tile),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: _text(colors.foreground, 13, 'FigtreeBold'),
          ),
        ),
      ),
    );
  }
}

/// The viewer type and the fact behind it, or a plain heading when there is
/// no type to claim.
class _Identity extends StatelessWidget {
  const _Identity({required this.card, required this.nameSize});

  final ShareRecapCard card;
  final double nameSize;

  @override
  Widget build(BuildContext context) {
    final colors = card._colors;
    final profile = card._profile;
    final name = profile == null
        ? tr('ins_card_story').replaceAll('\n', ' ')
        : _typeName(profile.type);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ScaleDown(
          child: Text(
            name,
            maxLines: 1,
            style: _text(
              colors.foreground,
              nameSize,
              'FigtreeBlack',
              spacing: -.6,
              height: 1.06,
            ),
          ),
        ),
        if (profile != null) ...[
          const SizedBox(height: 2),
          Text(
            _typeReason(profile),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _text(_accentOn(colors), 12.5, 'FigtreeBold'),
          ),
        ],
      ],
    );
  }
}

String _typeName(WellnessViewerType type) => tr(switch (type) {
      WellnessViewerType.nightOwl => 'ins_type_night_owl',
      WellnessViewerType.earlyBird => 'ins_type_early_bird',
      WellnessViewerType.weekendBinger => 'ins_type_weekend',
      WellnessViewerType.streakKeeper => 'ins_type_streak',
      WellnessViewerType.marathoner => 'ins_type_marathoner',
      WellnessViewerType.completionist => 'ins_type_completionist',
      WellnessViewerType.seriesDevotee => 'ins_type_series',
      WellnessViewerType.movieLover => 'ins_type_movie',
      WellnessViewerType.worldExplorer => 'ins_type_explorer',
      WellnessViewerType.timeTraveller => 'ins_type_time_traveller',
      WellnessViewerType.comfortRewatcher => 'ins_type_rewatcher',
      WellnessViewerType.sampler => 'ins_type_sampler',
      WellnessViewerType.liveRegular => 'ins_type_live',
      WellnessViewerType.storyChaser => 'ins_type_chaser',
    });

/// The viewer type's name, for the caption that travels with the image.
String shareRecapTypeName(WellnessViewerType type) => _typeName(type);

String _typeReason(WellnessViewerProfile profile) {
  final value = profile.value;
  String percent(String key) => tr(key, namedArgs: {'percent': '$value%'});
  String count(String key) => tr(key, namedArgs: {'n': '$value'});
  return switch (profile.type) {
    WellnessViewerType.nightOwl => percent('ins_type_night_owl_why'),
    WellnessViewerType.earlyBird => percent('ins_type_early_bird_why'),
    WellnessViewerType.weekendBinger => percent('ins_type_weekend_why'),
    WellnessViewerType.completionist => percent('ins_type_completionist_why'),
    WellnessViewerType.liveRegular => percent('ins_type_live_why'),
    WellnessViewerType.streakKeeper => plural('ins_type_streak_why', value),
    WellnessViewerType.seriesDevotee => count('ins_type_series_why'),
    WellnessViewerType.movieLover => count('ins_type_movie_why'),
    WellnessViewerType.worldExplorer => count('ins_type_explorer_why'),
    WellnessViewerType.comfortRewatcher => count('ins_type_rewatcher_why'),
    WellnessViewerType.marathoner => tr('ins_type_marathoner_why',
        namedArgs: {'time': formatWatchedTime(value)}),
    WellnessViewerType.storyChaser =>
      tr('ins_type_chaser_why', namedArgs: {'time': formatWatchedTime(value)}),
    WellnessViewerType.timeTraveller => tr('ins_type_time_traveller_why',
        namedArgs: {'decade': profile.label ?? ''}),
    WellnessViewerType.sampler => tr('ins_type_sampler_why', namedArgs: {
        'started': '$value',
        'finished': '${profile.secondValue}',
      }),
  };
}

/// Total watch time with the units set smaller than the digits, the way a
/// stat reads on a poster.
class _TimeBlock extends StatelessWidget {
  const _TimeBlock({
    required this.milliseconds,
    required this.size,
    required this.colors,
  });

  final int milliseconds;
  final double size;
  final _CardColors colors;

  @override
  Widget build(BuildContext context) {
    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final digit = _text(
      colors.foreground,
      size,
      'FigtreeBlack',
      spacing: size * -.012,
      height: 1,
    );
    final unit = _text(colors.foreground, size * .5, 'FigtreeBold', height: 1);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ScaleDown(
          child: Text.rich(
            TextSpan(children: [
              if (hours > 0) ...[
                TextSpan(
                  text: NumberFormat.decimalPattern('en').format(hours),
                  style: digit,
                ),
                TextSpan(text: 'h', style: unit),
              ],
              // Past a hundred hours the minutes are noise.
              if (hours > 0 && hours < 100 && minutes > 0)
                TextSpan(text: ' ', style: unit),
              if (hours < 100 && (minutes > 0 || hours == 0)) ...[
                TextSpan(text: '$minutes', style: digit),
                TextSpan(text: 'm', style: unit),
              ],
            ]),
            maxLines: 1,
            textDirection: ui.TextDirection.ltr,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          tr('ins_card_playback'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _text(colors.muted, 10.5, 'Figtree'),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.stats, required this.colors});

  final List<WellnessRecapStat> stats;
  final _CardColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final stat in stats)
          Expanded(child: _Stat(stat: stat, colors: colors, size: 23)),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.stat, required this.colors, required this.size});

  final WellnessRecapStat stat;
  final _CardColors colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    final value = stat.kind == WellnessRecapStatKind.longestSitting
        ? formatWatchedTime(stat.value)
        : NumberFormat.decimalPattern('en').format(stat.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ScaleDown(
          child: Text(
            value,
            maxLines: 1,
            style: _text(colors.foreground, size, 'FigtreeBold', height: 1.15),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          tr(switch (stat.kind) {
            WellnessRecapStatKind.finished => 'ins_completed',
            WellnessRecapStatKind.streak => 'ins_card_streak',
            WellnessRecapStatKind.activeDays => 'ins_active_days_label',
            WellnessRecapStatKind.titles => 'ins_card_titles',
            WellnessRecapStatKind.newTitles => 'ins_card_new',
            WellnessRecapStatKind.longestSitting => 'ins_card_longest',
            WellnessRecapStatKind.sessions => 'ins_sessions',
          }),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _text(colors.muted, 10.5, 'Figtree'),
        ),
      ],
    );
  }
}

class _TopTitleLine extends StatelessWidget {
  const _TopTitleLine({required this.title, required this.colors});

  final String title;
  final _CardColors colors;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: [
        TextSpan(
          text: '${tr('ins_most_watched')}  ',
          style: _text(colors.muted, 11, 'Figtree'),
        ),
        TextSpan(
          text: title,
          style: _text(colors.foreground, 11.5, 'FigtreeBold'),
        ),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _GenreLine extends StatelessWidget {
  const _GenreLine({required this.genres, required this.colors});

  final List<String> genres;
  final _CardColors colors;

  @override
  Widget build(BuildContext context) {
    return Text(
      genres.join('  ·  '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _text(colors.foreground, 11.5, 'FigtreeSB'),
    );
  }
}

class _RankedTitle extends StatelessWidget {
  const _RankedTitle({
    required this.rank,
    required this.title,
    required this.colors,
  });

  final int rank;
  final WellnessRecapTitle title;
  final _CardColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            child: Text(
              '$rank',
              style: _text(_accentOn(colors), 13, 'FigtreeBlack'),
            ),
          ),
          Expanded(
            child: Text(
              title.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _text(colors.foreground, 13.5, 'FigtreeBold'),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatWatchedTime(title.watchedMs),
            textDirection: ui.TextDirection.ltr,
            style: _text(colors.muted, 11.5, 'FigtreeSB'),
          ),
        ],
      ),
    );
  }
}

class _GenreChips extends StatelessWidget {
  const _GenreChips({required this.genres, required this.colors});

  final List<String> genres;
  final _CardColors colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 23,
      child: ClipRect(
        child: Wrap(
          spacing: 6,
          children: [
            for (final genre in genres)
              Container(
                height: 23,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  color: colors.foreground.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    genre,
                    maxLines: 1,
                    style: _text(colors.foreground, 10.5, 'FigtreeSB'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bars drawn by hand: a month has up to 31 of them, far too narrow for each
/// to hold its own label, so labels are placed freely along the axis.
class _RhythmChart extends StatelessWidget {
  const _RhythmChart({required this.bars, required this.colors});

  final List<WellnessRecapBar> bars;
  final _CardColors colors;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _RhythmPainter(
        bars: bars,
        idle: colors.faint,
        label: colors.muted,
        accent: _accentOn(colors),
        direction: Directionality.of(context),
      ),
    );
  }
}

class _RhythmPainter extends CustomPainter {
  const _RhythmPainter({
    required this.bars,
    required this.idle,
    required this.label,
    required this.accent,
    required this.direction,
  });

  final List<WellnessRecapBar> bars;
  final Color idle;
  final Color label;
  final Color accent;
  final ui.TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    const labelSpace = 13.0;
    final hasLabels = bars.any((bar) => bar.label.isNotEmpty);
    final chartHeight = size.height - (hasLabels ? labelSpace : 0);
    final peak = bars.fold<int>(0, (a, b) => math.max(a, b.watchedMs));
    final slot = size.width / bars.length;
    final gap = math.min(slot * .28, 4.0);
    // A day has six slots; left to fill them, a single bar becomes a slab.
    final barWidth = math.min(slot - gap, 16.0);
    final radius = Radius.circular(math.min(barWidth / 2, 3));
    final rtl = direction == ui.TextDirection.rtl;
    for (var i = 0; i < bars.length; i++) {
      final bar = bars[i];
      final position = rtl ? bars.length - 1 - i : i;
      final x = position * slot + (slot - barWidth) / 2;
      final fraction = peak == 0 ? 0.0 : bar.watchedMs / peak;
      final height = math.max(chartHeight * fraction, 2.0);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, chartHeight - height, barWidth, height),
          topLeft: radius,
          topRight: radius,
        ),
        Paint()
          ..color = peak > 0 && bar.watchedMs == peak ? accent : idle
          ..isAntiAlias = true,
      );
      if (bar.label.isEmpty) continue;
      final text = TextPainter(
        text: TextSpan(
          text: bar.label,
          style: _text(label, 9, 'Figtree'),
        ),
        textDirection: direction,
        maxLines: 1,
      )..layout();
      final centred = x + barWidth / 2 - text.width / 2;
      text.paint(
        canvas,
        Offset(
          centred.clamp(0.0, math.max(0.0, size.width - text.width)),
          chartHeight + 3,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_RhythmPainter oldDelegate) =>
      oldDelegate.bars != bars ||
      oldDelegate.idle != idle ||
      oldDelegate.accent != accent ||
      oldDelegate.direction != direction;
}

class _Footer extends StatelessWidget {
  const _Footer({required this.colors});

  final _CardColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        tr('ins_card_cta', namedArgs: {'site': 'flix.quest'}),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _text(colors.foreground.withValues(alpha: .78), 11, 'FigtreeSB'),
      ),
    );
  }
}

/// Keeps a line on the start edge and only shrinks it when it wouldn't fit.
class _ScaleDown extends StatelessWidget {
  const _ScaleDown({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: child,
    );
  }
}

/// The orange loses contrast on the pale card, so it darkens there.
Color _accentOn(_CardColors colors) => colors.foreground == Colors.white
    ? const Color(0xFFFF9A2E)
    : const Color(0xFFB85A00);

TextStyle _text(
  Color color,
  double size,
  String family, {
  double? spacing,
  double? height,
}) =>
    TextStyle(
      color: color,
      fontSize: size,
      fontFamily: family,
      letterSpacing: spacing,
      height: height,
      decoration: TextDecoration.none,
    );
