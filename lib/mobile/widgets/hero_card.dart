import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../catalog/home_hero.dart';
import '../../catalog/media_item.dart';
import '../../constants/app_constants.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../design/title_logo.dart';
import '../my_list.dart';
import '../playback.dart';
import 'media_art.dart';
import 'pill_button.dart';
import 'poster_card.dart';

/// Home's featured title as a card: its artwork, its logo, what it is, and
/// Play and My List under it. The card is artwork, so it looks the same in
/// every theme; the page around it follows the theme.
class HeroCard extends StatefulWidget {
  const HeroCard({required this.hero, this.genres = const [], super.key});

  final HomeHero hero;

  /// The title's genre names, shown after its year.
  final List<String> genres;

  /// The card's height for a page [width] wide: tall like a poster on
  /// phones, a wide frame on tablets.
  static double heightFor(double width, double gutter) {
    final cardWidth = width - gutter * 2;
    return width >= AppBreakpoints.tablet
        ? (cardWidth * 9 / 16).clamp(0, 460).toDouble()
        : (cardWidth * 1.3).clamp(0, 520).toDouble();
  }

  /// The artwork the card shows for [item] on this screen: the poster on
  /// phones, the backdrop on tablets or when there's no poster.
  static (String?, String?) artworkFor(BuildContext context, MediaItem item) {
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet;
    return wide || item.posterPath == null
        ? (item.backdropPath ?? item.posterPath, ArtSize.backdrop)
        : (item.posterPath, null);
  }

  /// Where that artwork is, for loading it ahead. Outside build.
  static String? artworkUrl(BuildContext context, MediaItem item) {
    final (path, size) = artworkFor(context, item);
    return tmdbImageUrl(context, path, size: size, listen: false);
  }

  @override
  State<HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<HeroCard> {
  bool _starting = false;

  MediaItem get _item => widget.hero.item;

  Future<void> _play() async {
    setState(() => _starting = true);
    try {
      await MobilePlayback.play(context, _item);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  /// "Resume S2:E4" for an episode in progress, "Play S2:E5" for the one
  /// after a finished episode, "Resume" for a movie, else "Play".
  String _playLabel() {
    if (!widget.hero.continuing) return tr('play');
    if (_item.upNext case final next?) {
      return tr('play_episode',
          namedArgs: <String, String>{'episode': next.label});
    }
    final episode = _item.recentEpisode;
    final season = episode?.seasonNum;
    final number = episode?.episodeNum;
    if (season == null || number == null) return tr('resume_title');
    return tr(
      'resume_episode',
      namedArgs: <String, String>{'episode': 'S$season:E$number'},
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final media = MediaQuery.sizeOf(context);
    final gutter = AppSpace.gutter(context);
    final height = HeroCard.heightFor(media.width, gutter);
    final art = HeroCard.artworkFor(context, item);
    final accent = Theme.of(context).colorScheme.primary;
    final saved = MyList.contains(context, item);
    // What FlixQuest's hero always said: the year, the rating, and now the
    // genres too.
    final facts = <String>[
      if (item.year case final year?) year,
      ...widget.genres.take(2),
      if (item.rating case final rating? when rating > 0)
        '★ ${rating.toStringAsFixed(1)}',
    ].join('  ·  ');
    final kicker = widget.hero.continuing
        ? tr('continue_watching')
        : tr(item.kind == MediaKind.movie ? 'movie' : 'series_one');
    const white = Color(0xFFFFFFFF);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: gutter),
      // Not a Pressable: its buttons must stay reachable by screen readers,
      // and the card shouldn't sink while one of them is held.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => MobilePlayback.openDetails(context, item),
        child: SizedBox(
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.hero),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Semantics(
                  button: true,
                  label: mediaSemanticLabel(item),
                  onTapHint: tr('details'),
                  child: MediaArt(
                    item: item,
                    path: art.$1,
                    width: media.width,
                    size: art.$2,
                    alignment: Alignment.topCenter,
                    placeholder: MediaArt.darkPlaceholder,
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Color(0x00000000),
                        Color(0x33000000),
                        Color(0xE0000000),
                      ],
                      stops: <double>[.35, .6, 1],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        _HeroKicker(label: kicker, accent: accent),
                        const SizedBox(height: AppSpace.sm),
                        SizedBox(
                          height: 72,
                          child: Center(
                            child: TitleLogo(
                              item: item,
                              maxHeight: 72,
                              alignment: Alignment.bottomCenter,
                              fallback: Align(
                                alignment: Alignment.bottomCenter,
                                child: Text(
                                  item.title,
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppType.heroTitle.copyWith(
                                    color: white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpace.md),
                        Text(
                          facts,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppType.metadata.copyWith(
                            color: const Color(0xD9FFFFFF),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: AppSpace.lg),
                        Row(
                          children: <Widget>[
                            if (MobilePlayback.canPlay(context)) ...<Widget>[
                              Expanded(
                                child: PillButton(
                                  onArtwork: true,
                                  primary: true,
                                  busy: _starting,
                                  icon: PhosphorIcons.play(
                                    PhosphorIconsStyle.fill,
                                  ),
                                  label: _playLabel(),
                                  onPressed: _play,
                                ),
                              ),
                              const SizedBox(width: AppSpace.sm),
                            ],
                            Expanded(
                              child: PillButton(
                                onArtwork: true,
                                icon: saved
                                    ? PhosphorIcons.check()
                                    : PhosphorIcons.plus(),
                                label: tr('my_list'),
                                onPressed: () => MyList.toggle(context, item),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What a hero card is, the way Netflix marks its own: the FlixQuest mark
/// in the accent, then SERIES, MOVIE or CONTINUE WATCHING in wide white
/// capitals, shadowed so bright artwork can't swallow it.
class _HeroKicker extends StatelessWidget {
  const _HeroKicker({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SvgPicture.asset(
          'assets/images/fq_svg.svg',
          height: 18,
          colorFilter: ColorFilter.mode(accent, BlendMode.srcIn),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFFFFFFFF),
                fontFamily: AppType.bold,
                fontSize: 13,
                height: 1,
                letterSpacing: 3,
                shadows: <Shadow>[
                  Shadow(color: Color(0x99000000), blurRadius: 8),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Home's hero: [heroes] as cards the viewer can swipe through, turning on
/// their own every [interval] as FlixQuest's hero always has, with dots
/// under them to show where the viewer is.
///
/// It holds still while touched, while scrolled out of sight, while its tab
/// is hidden, and when the system asks for less motion; it runs round from
/// the last card to the first.
class HeroCarousel extends StatefulWidget {
  const HeroCarousel({
    required this.heroes,
    required this.genresFor,
    this.onShown,
    this.interval = const Duration(seconds: 7),
    super.key,
  });

  final List<HomeHero> heroes;
  final List<String> Function(MediaItem item) genresFor;

  /// Told which hero is showing, first and after every turn.
  final ValueChanged<HomeHero>? onShown;
  final Duration interval;

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  Timer? _timer;
  bool _held = false;
  int _index = 0;

  int get _count => widget.heroes.length;

  @override
  void initState() {
    super.initState();
    _restart();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announce();
      _preloadNext();
    });
  }

  @override
  void didUpdateWidget(HeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= _count) _index = 0;
    if (oldWidget.interval != widget.interval ||
        oldWidget.heroes.length != _count) {
      _restart();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    if (_count > 1) _timer = Timer.periodic(widget.interval, (_) => _turn());
  }

  /// Whether a turn would be seen and welcome right now.
  bool get _canTurn {
    if (!mounted || _held) return false;
    if (!TickerMode.of(context)) return false;
    if (MediaQuery.disableAnimationsOf(context)) return false;
    final page = Scrollable.maybeOf(context)?.position;
    final height = context.size?.height ?? 0;
    return page == null || page.pixels < height * .6;
  }

  void _turn() {
    if (_canTurn) _go(1);
  }

  void _go(int step) {
    if (_count <= 1) return;
    setState(() => _index = (_index + step) % _count);
    _announce();
    _preloadNext();
  }

  void _announce() {
    if (mounted && _count > 0) widget.onShown?.call(widget.heroes[_index]);
  }

  /// Fetches the next card's artwork ahead, so it fades in whole rather than
  /// over an empty frame.
  void _preloadNext() {
    if (!mounted || _count <= 1) return;
    final item = widget.heroes[(_index + 1) % _count].item;
    final url = HeroCard.artworkUrl(context, item);
    if (url == null) return;
    precacheImage(
      CachedNetworkImageProvider(url, cacheManager: cacheProp()),
      context,
      onError: (_, __) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final height = HeroCard.heightFor(media.width, AppSpace.gutter(context));
    if (_count == 0) return const SizedBox.shrink();
    final hero = widget.heroes[_index];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: height,
          child: Listener(
            onPointerDown: (_) => _held = true,
            onPointerUp: (_) {
              _held = false;
              _restart();
            },
            onPointerCancel: (_) => _held = false,
            child: GestureDetector(
              // A flick sideways moves on or back, as FlixQuest's hero did.
              onHorizontalDragEnd: _count <= 1
                  ? null
                  : (details) {
                      final velocity = details.primaryVelocity ?? 0;
                      if (velocity.abs() < 120) return;
                      final forward = velocity < 0;
                      final rtl =
                          Directionality.of(context) == TextDirection.rtl;
                      _go(forward != rtl ? 1 : -1);
                      _restart();
                    },
              // FlixQuest's crossfade: the next card fades in as it settles
              // from a touch larger.
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 850),
                reverseDuration: const Duration(milliseconds: 650),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    ...previous,
                    if (current != null) current,
                  ],
                ),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale:
                        Tween<double>(begin: 1.025, end: 1).animate(animation),
                    child: child,
                  ),
                ),
                child: HeroCard(
                  key: ValueKey<String>(hero.item.stableId),
                  hero: hero,
                  genres: widget.genresFor(hero.item),
                ),
              ),
            ),
          ),
        ),
        if (_count > 1) ...<Widget>[
          const SizedBox(height: AppSpace.md),
          _Dots(count: _count, index: _index),
        ],
      ],
    );
  }
}

/// Where the carousel is: a short ink bar for the card showing, dots for the
/// rest.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == index ? 16 : 5,
              height: 5,
              decoration: BoxDecoration(
                color: i == index
                    ? palette.foreground
                    : palette.mutedText.withValues(alpha: .45),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}
