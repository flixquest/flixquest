import 'dart:async';
import 'dart:math' as math;

import 'package:better_player_plus/better_player_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../constants/app_constants.dart';
import '../../../design/app_tokens.dart';
import '../../../mobile/widgets/pill_button.dart' show PlaybackIcon;
import 'player_sheet_ui.dart';

/// The phone player's page while it isn't full screen, a "watch page" in the
/// spirit of the app's details pages: the video at the top on black, then
/// what's playing over a wash of its own artwork, a row of action chips, and
/// what to watch next (the season's episodes, more like this, or the other
/// channels).
///
/// Colours come from [BetterPlayerPanelColors], so the page follows the
/// app's mode like the player's sheets do; anything drawn on artwork (the
/// now-playing bars, the play glyphs) keeps fixed white.

/// TMDB artwork at [size] ("w300", "w342", …), or null without a path.
String? tmdbImage(String? path, String size) =>
    path == null || path.isEmpty ? null : 'https://image.tmdb.org/t/p/$size$path';

/// A soft card on the page: a shade of ink rather than a panel colour, so
/// it reads the same on the black dark page and the light one.
Color _cardColor(BetterPlayerPanelColors colors) =>
    colors.foreground.withValues(alpha: .07);

/// The video on black, status bar included, with the page scrolling under
/// it.
class PlayerWatchLayout extends StatelessWidget {
  const PlayerWatchLayout({
    required this.video,
    required this.slivers,
    this.controller,
    super.key,
  });

  final Widget video;
  final List<Widget> slivers;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final colors = BetterPlayerPanelColors.of(context);
    final padding = MediaQuery.paddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The strip above the video is black in every mode.
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: ColoredBox(
        color: colors.page,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ColoredBox(
              color: Colors.black,
              child: Padding(
                padding: EdgeInsets.only(top: padding.top),
                child: AspectRatio(aspectRatio: 16 / 9, child: video),
              ),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: CustomScrollView(
                  controller: controller,
                  slivers: <Widget>[
                    ...slivers,
                    SliverToBoxAdapter(
                      child: SizedBox(height: padding.bottom + AppSpace.xxxl),
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

/// What's playing: a kicker, the title, a line under it, the facts, an
/// optional synopsis and the actions, over a wash of the title's artwork.
class WatchHeader extends StatelessWidget {
  const WatchHeader({
    required this.title,
    this.kicker,
    this.subtitle,
    this.meta,
    this.synopsis,
    this.washImageUrl,
    this.actions = const <WatchAction>[],
    super.key,
  });

  final String title;

  /// Over the title: a season and episode, or the LIVE badge.
  final Widget? kicker;

  /// Under the title: the episode's name, or what's on now.
  final String? subtitle;
  final String? meta;
  final String? synopsis;

  /// Artwork to wash the header with; it's shrunk to a few pixels and
  /// stretched back up, which blurs it for free.
  final String? washImageUrl;
  final List<WatchAction> actions;

  @override
  Widget build(BuildContext context) {
    final colors = BetterPlayerPanelColors.of(context);
    final gutter = AppSpace.gutter(context);
    final kicker = this.kicker;
    final subtitle = this.subtitle;
    final meta = this.meta;
    final synopsis = this.synopsis;
    final wash = washImageUrl;
    return Stack(
      children: <Widget>[
        if (wash != null) Positioned.fill(child: _ArtworkWash(url: wash)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                gutter,
                AppSpace.xl,
                gutter,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (kicker != null) ...<Widget>[
                    kicker,
                    const SizedBox(height: AppSpace.sm),
                  ],
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.scaled(
                        context,
                        AppType.pageTitle.copyWith(
                          fontSize: 24,
                          height: 28 / 24,
                          color: colors.foreground,
                        ),
                      ),
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.body.copyWith(
                        fontFamily: AppType.semiBold,
                        fontSize: 15,
                        color: colors.secondary,
                      ),
                    ),
                  ],
                  if (meta != null && meta.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      meta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.metadata.copyWith(
                        fontSize: 13,
                        color: colors.muted,
                      ),
                    ),
                  ],
                  if (synopsis != null && synopsis.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpace.md),
                    _ExpandableSynopsis(text: synopsis),
                  ],
                ],
              ),
            ),
            if (actions.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpace.lg),
              SizedBox(
                height: WatchActionChip.height,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  itemCount: actions.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpace.sm),
                  itemBuilder: (_, index) =>
                      WatchActionChip(action: actions[index]),
                ),
              ),
            ],
            const SizedBox(height: AppSpace.sm),
          ],
        ),
      ],
    );
  }
}

/// The title's artwork, a few pixels wide and stretched across the header,
/// fading into the page: the video's colour bleeding into what's under it.
class _ArtworkWash extends StatelessWidget {
  const _ArtworkWash({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final colors = BetterPlayerPanelColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image(
              image: ResizeImage(
                CachedNetworkImageProvider(url, cacheManager: cacheProp()),
                width: 32,
              ),
              fit: BoxFit.cover,
              // Bicubic upscaling of a tiny image is a smooth blur.
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              frameBuilder: (context, child, frame, synchronous) =>
                  AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOut,
                child: child,
              ),
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const <double>[0, .6, 1],
                  colors: <Color>[
                    colors.page.withValues(alpha: dark ? .5 : .62),
                    colors.page.withValues(alpha: dark ? .84 : .88),
                    colors.page,
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

/// Three lines, then the rest on a tap.
class _ExpandableSynopsis extends StatefulWidget {
  const _ExpandableSynopsis({required this.text});

  final String text;

  @override
  State<_ExpandableSynopsis> createState() => _ExpandableSynopsisState();
}

class _ExpandableSynopsisState extends State<_ExpandableSynopsis> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final colors = BetterPlayerPanelColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _open = !_open),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: AlignmentDirectional.topStart,
        child: Text(
          widget.text,
          maxLines: _open ? null : 3,
          overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
          style: AppType.body.copyWith(
            height: 1.45,
            color: colors.secondary,
          ),
        ),
      ),
    );
  }
}

/// One thing the page can do from its action row.
class WatchAction {
  const WatchAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// The page's main action, in ink.
  final bool primary;

  /// A small spinner in the icon's place while it works.
  final bool busy;
}

/// A rounded chip with an icon and a label, the way a watch page lays out
/// its actions in one scrolling row.
class WatchActionChip extends StatelessWidget {
  const WatchActionChip({required this.action, super.key});

  final WatchAction action;

  static const height = 44.0;

  @override
  Widget build(BuildContext context) {
    final colors = BetterPlayerPanelColors.of(context);
    final background = action.primary ? colors.pill : _cardColor(colors);
    final foreground = action.primary ? colors.onPill : colors.foreground;
    final onTap = action.onTap;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: Opacity(
        opacity: onTap == null ? .45 : 1,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(height / 2),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap == null || action.busy
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onTap();
                  },
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 18, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (action.busy)
                    SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    )
                  else if (PlaybackIcon.keeps(action.icon))
                    PlaybackIcon(action.icon, size: 18, color: foreground)
                  else
                    Icon(action.icon, size: 18, color: foreground),
                  const SizedBox(width: AppSpace.sm),
                  Text(
                    action.label,
                    maxLines: 1,
                    style: AppType.cardTitle.copyWith(color: foreground),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small uppercase line, muted, for a season and episode over a title.
class WatchKicker extends StatelessWidget {
  const WatchKicker(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label.toUpperCase(),
        style: AppType.kicker.copyWith(
          color: BetterPlayerPanelColors.of(context).muted,
        ),
      );
}

/// LIVE, with a dot that breathes, for the page under a live stream.
class WatchLiveBadge extends StatefulWidget {
  const WatchLiveBadge({this.trailing, super.key});

  /// Muted words after the badge, such as the channel's category.
  final String? trailing;

  /// Broadcast red, the same in every theme.
  static const red = Color(0xFFE50914);

  @override
  State<WatchLiveBadge> createState() => _WatchLiveBadgeState();
}

class _WatchLiveBadgeState extends State<WatchLiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = BetterPlayerPanelColors.of(context);
    final trailing = widget.trailing;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: WatchLiveBadge.red,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(7, 3, 8, 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                FadeTransition(
                  opacity: Tween<double>(begin: .35, end: 1).animate(_pulse),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  tr('player_live'),
                  style: AppType.kicker.copyWith(
                    color: Colors.white,
                    fontFamily: AppType.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (trailing != null && trailing.isNotEmpty) ...<Widget>[
          const SizedBox(width: AppSpace.sm),
          Flexible(
            child: Text(
              trailing.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.kicker.copyWith(color: colors.muted),
            ),
          ),
        ],
      ],
    );
  }
}

/// A section's heading, with a count or a control at its end.
class WatchSectionHeader extends StatelessWidget {
  const WatchSectionHeader({
    required this.title,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = BetterPlayerPanelColors.of(context);
    final gutter = AppSpace.gutter(context);
    final trailing = this.trailing;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        gutter,
        AppSpace.xxl,
        gutter,
        AppSpace.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: AppType.scaled(context, AppType.sectionHeader).copyWith(
                  fontFamily: AppType.bold,
                  color: colors.foreground,
                ),
              ),
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: AppSpace.md),
            // A long season name gives way to the heading.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * .55,
              ),
              child: trailing,
            ),
          ],
        ],
      ),
    );
  }
}

/// A count at the end of a section heading.
class WatchCount extends StatelessWidget {
  const WatchCount(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppType.metadata.copyWith(
          fontSize: 13,
          color: BetterPlayerPanelColors.of(context).muted,
        ),
      );
}

/// "Season 2 ▾": the season being shown, opening the others.
class WatchSeasonButton extends StatelessWidget {
  const WatchSeasonButton({
    required this.label,
    required this.onTap,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = BetterPlayerPanelColors.of(context);
    return Material(
      color: _cardColor(colors),
      borderRadius: BorderRadius.circular(AppRadii.button),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: loading ? null : onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 10, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.cardTitle.copyWith(color: colors.foreground),
                  ),
                ),
                const SizedBox(width: 6),
                if (loading)
                  SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.muted,
                    ),
                  )
                else
                  Icon(
                    PhosphorIcons.caretDown(PhosphorIconsStyle.bold),
                    size: 16,
                    color: colors.foreground,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The episode after this one, a press from playing.
class WatchUpNextCard extends StatelessWidget {
  const WatchUpNextCard({
    required this.title,
    required this.onPlay,
    this.meta,
    this.imageUrl,
    super.key,
  });

  final String title;
  final String? meta;
  final String? imageUrl;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final colors = BetterPlayerPanelColors.of(context);
    final gutter = AppSpace.gutter(context);
    final meta = this.meta;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(gutter, AppSpace.lg, gutter, 0),
      child: Semantics(
        button: true,
        label: '${tr('up_next')}, $title',
        excludeSemantics: true,
        child: Material(
          color: _cardColor(colors),
          borderRadius: BorderRadius.circular(AppRadii.hero),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onPlay();
            },
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 112,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _Artwork(
                        url: imageUrl,
                        fallbackIcon: PhosphorIcons.filmStrip(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        WatchKicker(tr('up_next')),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.cardTitle.copyWith(
                            fontSize: 15,
                            height: 1.25,
                            color: colors.foreground,
                          ),
                        ),
                        if (meta != null && meta.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 3),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.metadata.copyWith(
                              color: colors.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.pill,
                      shape: BoxShape.circle,
                    ),
                    child: PlaybackIcon(
                      PhosphorIcons.play(PhosphorIconsStyle.fill),
                      size: 20,
                      color: colors.onPill,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An episode in the season list: its still, with the now-playing bars and
/// the watch progress on the one playing, then its name and facts, and two
/// lines of synopsis under the row.
class WatchEpisodeTile extends StatelessWidget {
  const WatchEpisodeTile({
    required this.number,
    required this.title,
    this.meta,
    this.synopsis,
    this.stillUrl,
    this.current = false,
    this.upNext = false,
    this.unaired = false,
    this.progress,
    this.onTap,
    super.key,
  });

  final int number;
  final String title;
  final String? meta;
  final String? synopsis;
  final String? stillUrl;
  final bool current;
  final bool upNext;

  /// Not out yet: dimmed, and not playable.
  final bool unaired;

  /// Along the bottom of the still on the episode playing.
  final Widget? progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = BetterPlayerPanelColors.of(context);
    final gutter = AppSpace.gutter(context);
    final meta = this.meta;
    final synopsis = this.synopsis;
    final progress = this.progress;
    final tap = current || unaired ? null : onTap;
    final kicker = current
        ? tr('player_now_playing')
        : upNext
            ? tr('up_next')
            : null;
    return Semantics(
      selected: current,
      button: tap != null,
      child: Material(
        color: current ? _cardColor(colors) : Colors.transparent,
        child: InkWell(
          onTap: tap,
          child: Opacity(
            opacity: unaired ? .5 : 1,
            child: Padding(
              padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      SizedBox(
                        width: 136,
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Stack(
                            fit: StackFit.expand,
                            children: <Widget>[
                              _Artwork(
                                url: stillUrl,
                                fallbackIcon: PhosphorIcons.filmStrip(),
                              ),
                              if (current)
                                const DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Color(0x8C000000),
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(AppRadii.card),
                                    ),
                                  ),
                                  child: Center(
                                    child: NowPlayingBars(color: Colors.white),
                                  ),
                                )
                              else if (!unaired)
                                const Center(child: _PlayGlyph()),
                              if (progress != null)
                                PositionedDirectional(
                                  start: 0,
                                  end: 0,
                                  bottom: 0,
                                  child: progress,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (kicker != null) ...<Widget>[
                              WatchKicker(kicker),
                              const SizedBox(height: 4),
                            ],
                            Text(
                              '$number. $title',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.cardTitle.copyWith(
                                fontFamily:
                                    current ? AppType.bold : AppType.semiBold,
                                fontSize: 15,
                                height: 1.25,
                                color: colors.foreground,
                              ),
                            ),
                            if (meta != null && meta.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 4),
                              Text(
                                meta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.metadata.copyWith(
                                  color: colors.muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (synopsis != null && synopsis.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      synopsis,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.body.copyWith(
                        fontSize: 13,
                        height: 1.4,
                        color: colors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A thin progress bar for the bottom edge of artwork, the played part in
/// the accent.
class WatchProgressBar extends StatelessWidget {
  const WatchProgressBar({required this.value, super.key});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(AppRadii.card),
      ),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 3,
        color: Theme.of(context).colorScheme.primary,
        // On artwork, which is the same in every mode.
        backgroundColor: Colors.white24,
      ),
    );
  }
}

/// [WatchProgressBar] for what's playing now, read once a second; nothing
/// while [read] has no answer (an ad, or a stream still starting).
class WatchLiveProgress extends StatefulWidget {
  const WatchLiveProgress({required this.read, super.key});

  final double? Function() read;

  @override
  State<WatchLiveProgress> createState() => _WatchLiveProgressState();
}

class _WatchLiveProgressState extends State<WatchLiveProgress> {
  Timer? _timer;
  double? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.read();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final value = widget.read();
      if (mounted && value != _value) setState(() => _value = value);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    return value == null
        ? const SizedBox.shrink()
        : WatchProgressBar(value: value);
  }
}

/// A play glyph in a dark disc, centred on artwork that can be played.
class _PlayGlyph extends StatelessWidget {
  const _PlayGlyph();

  @override
  Widget build(BuildContext context) => Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .45),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white70, width: 1.2),
        ),
        child: PlaybackIcon(
          PhosphorIcons.play(PhosphorIconsStyle.fill),
          size: 13,
          color: Colors.white,
        ),
      );
}

/// Artwork on a raised tile while it loads, with an icon if it can't.
class _Artwork extends StatelessWidget {
  const _Artwork({required this.url, required this.fallbackIcon});

  final String? url;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final colors = BetterPlayerPanelColors.of(context);
    final url = this.url;
    final fallback = Center(
      child: Icon(fallbackIcon, size: 22, color: colors.muted),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: ColoredBox(
        color: colors.raised,
        child: url == null
            ? fallback
            : LayoutBuilder(
                builder: (context, constraints) => CachedNetworkImage(
                  cacheManager: cacheProp(),
                  imageUrl: url,
                  fit: BoxFit.cover,
                  memCacheWidth: constraints.maxWidth.isFinite
                      ? (constraints.maxWidth *
                              MediaQuery.devicePixelRatioOf(context))
                          .round()
                      : null,
                  fadeInDuration: const Duration(milliseconds: 200),
                  placeholder: (_, __) => const SizedBox.expand(),
                  errorWidget: (_, __, ___) => fallback,
                ),
              ),
      ),
    );
  }
}

/// Three bars rising and falling: this one is playing. Still when the
/// system asks for less motion.
class NowPlayingBars extends StatefulWidget {
  const NowPlayingBars({required this.color, this.size = 18, super.key});

  final Color color;
  final double size;

  @override
  State<NowPlayingBars> createState() => _NowPlayingBarsState();
}

class _NowPlayingBarsState extends State<NowPlayingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  // Whole cycles per loop, so the loop has no seam.
  static const _speeds = <int>[2, 3, 2];
  static const _phases = <double>[0, .35, .7];
  static const _still = <double>[.55, .95, .7];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final still = MediaQuery.disableAnimationsOf(context);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (var i = 0; i < 3; i++) ...<Widget>[
                if (i > 0) SizedBox(width: size * .14),
                Container(
                  width: size * .2,
                  height: size *
                      (still
                          ? _still[i]
                          : .3 +
                              .7 *
                                  (.5 +
                                      .5 *
                                          math.sin(2 *
                                              math.pi *
                                              (_controller.value * _speeds[i] +
                                                  _phases[i])))),
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A poster in the More Like This grid.
class WatchPosterTile extends StatelessWidget {
  const WatchPosterTile({
    required this.title,
    required this.onTap,
    this.posterUrl,
    this.semanticLabel,
    super.key,
  });

  final String title;
  final String? posterUrl;
  final String? semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = BetterPlayerPanelColors.of(context);
    final url = posterUrl;
    return Semantics(
      button: true,
      label: semanticLabel ?? title,
      excludeSemantics: true,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (url != null)
            _Artwork(url: url, fallbackIcon: PhosphorIcons.filmSlate())
          else
            // No poster: the title on the tile, so it's still choosable.
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.card),
              child: ColoredBox(
                color: colors.raised,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Center(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.cardTitle.copyWith(
                        fontSize: 13,
                        color: colors.secondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.card),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// More Like This as a grid of posters: three across on a phone, five on a
/// tablet.
class WatchPosterGrid extends StatelessWidget {
  const WatchPosterGrid({
    required this.itemCount,
    required this.itemBuilder,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpace.gutter(context);
    final wide =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet;
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(gutter, AppSpace.xs, gutter, 0),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: wide ? 5 : 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2 / 3,
        ),
        itemCount: itemCount,
        itemBuilder: itemBuilder,
      ),
    );
  }
}

/// A recommendation before it plays: its backdrop, name, year and rating,
/// what it's about, and Play. Resolves true when Play was pressed.
Future<bool?> showWatchPreview(
  BuildContext context, {
  required String title,
  String? meta,
  String? overview,
  String? backdropUrl,
}) {
  return showPlayerSheet<bool>(
    context: context,
    builder: (sheetContext) {
      final colors = BetterPlayerPanelColors.of(sheetContext);
      final bottom = MediaQuery.paddingOf(sheetContext).bottom;
      return SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottom + AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.track,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
            if (backdropUrl != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _Artwork(
                    url: backdropUrl,
                    fallbackIcon: PhosphorIcons.filmSlate(),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: AppType.sectionHeader.copyWith(
                      fontFamily: AppType.bold,
                      fontSize: 21,
                      height: 1.2,
                      color: colors.foreground,
                    ),
                  ),
                  if (meta != null && meta.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      meta,
                      style: AppType.metadata.copyWith(
                        fontSize: 13,
                        color: colors.muted,
                      ),
                    ),
                  ],
                  if (overview != null && overview.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpace.md),
                    Text(
                      overview,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.body.copyWith(
                        height: 1.45,
                        color: colors.secondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpace.xl),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      icon: PlaybackIcon(
                        PhosphorIcons.play(PhosphorIconsStyle.fill),
                        size: 20,
                      ),
                      label: Text(tr('play')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// A channel in the live page's list: its logo (with the now-playing bars
/// on the one being watched), its name, what's on now with a red dot, and
/// what's next.
class WatchChannelTile extends StatelessWidget {
  const WatchChannelTile({
    required this.name,
    required this.logo,
    this.nowPlaying,
    this.nextUp,
    this.detail,
    this.current = false,
    this.onTap,
    super.key,
  });

  final String name;

  /// The logo, or an initial in its place.
  final Widget logo;
  final String? nowPlaying;
  final String? nextUp;

  /// When nothing is known to be on: the channel's categories.
  final String? detail;
  final bool current;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = BetterPlayerPanelColors.of(context);
    final gutter = AppSpace.gutter(context);
    final nowPlaying = this.nowPlaying;
    final nextUp = this.nextUp;
    final detail = this.detail;
    final tap = current ? null : onTap;
    return Semantics(
      selected: current,
      button: tap != null,
      child: Material(
        color: current ? _cardColor(colors) : Colors.transparent,
        child: InkWell(
          onTap: tap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(gutter, 10, gutter, 10),
            child: Row(
              children: <Widget>[
                SizedBox.square(
                  dimension: 56,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.hero),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        ColoredBox(color: colors.raised, child: logo),
                        if (current)
                          const ColoredBox(
                            color: Color(0x99000000),
                            child: Center(
                              child: NowPlayingBars(color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (current) ...<Widget>[
                        WatchKicker(tr('player_now_playing')),
                        const SizedBox(height: 3),
                      ],
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.cardTitle.copyWith(
                          fontFamily: current ? AppType.bold : AppType.semiBold,
                          fontSize: 15,
                          color: colors.foreground,
                        ),
                      ),
                      if (nowPlaying != null && nowPlaying.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: <Widget>[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: WatchLiveBadge.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                nowPlaying,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.metadata.copyWith(
                                  fontSize: 13,
                                  color: colors.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else if (detail != null && detail.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.metadata.copyWith(color: colors.muted),
                        ),
                      ],
                      if (nextUp != null && nextUp.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          tr('player_next_up', namedArgs: {'title': nextUp}),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.metadata.copyWith(color: colors.muted),
                        ),
                      ],
                    ],
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

/// Nothing to list: an icon and a line, quietly.
class WatchEmptyNote extends StatelessWidget {
  const WatchEmptyNote({required this.icon, required this.message, super.key});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = BetterPlayerPanelColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 32, color: colors.muted),
          const SizedBox(height: AppSpace.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppType.body.copyWith(color: colors.muted),
          ),
        ],
      ),
    );
  }
}
