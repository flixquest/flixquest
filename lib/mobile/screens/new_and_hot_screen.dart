import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../catalog/media_item.dart';
import '../../catalog/new_and_hot.dart';
import '../../catalog/title_logos.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../design/title_logo.dart';
import '../../design/top_ten_rank.dart';
import '../../models/genres.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/bookmark_provider.dart';
import '../../provider/settings_provider.dart';
import '../app/mobile_tabs.dart';
import '../my_list.dart';
import '../playback.dart';
import '../widgets/filter_chips.dart';
import '../widgets/media_art.dart';
import '../widgets/pill_button.dart';
import '../widgets/poster_card.dart';
import '../widgets/title_sheet.dart';
import 'home_screen.dart' show HomeAdSlot;

/// New & Hot loads only the selected segment, then retains its result until
/// the viewer refreshes that segment. Switching a pill starts at the top.
class NewAndHotScreen extends StatefulWidget {
  const NewAndHotScreen({
    this.source,
    this.now,
    this.showTitleLogos = true,
    this.adBuilder,
    super.key,
  });

  final NewAndHotSource? source;
  final DateTime Function()? now;
  final bool showTitleLogos;
  final WidgetBuilder? adBuilder;

  @override
  State<NewAndHotScreen> createState() => _NewAndHotScreenState();
}

class _NewAndHotScreenState extends State<NewAndHotScreen> {
  HotSegment _segment = HotSegment.comingSoon;
  final Map<HotSegment, NewAndHotFeed> _feeds = <HotSegment, NewAndHotFeed>{};
  final Set<HotSegment> _loading = <HotSegment>{};
  final Set<HotSegment> _failed = <HotSegment>{};
  final ScrollController _ownScroll = ScrollController();
  MobileTabController? _tabs;
  TitleLogos? _logos;
  bool _started = false;
  String? _dateLocale;
  bool _datesReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).toString();
    if (_dateLocale != locale) {
      _dateLocale = locale;
      _datesReady = false;
      initializeDateFormatting(locale).then((_) {
        if (mounted && _dateLocale == locale) {
          setState(() => _datesReady = true);
        }
      });
    }
    final tabs = MobileTabScope.maybeOf(context);
    if (!identical(tabs, _tabs)) {
      _tabs?.removeResetListener(MobileTab.newAndHot, _reset);
      _tabs = tabs?..addResetListener(MobileTab.newAndHot, _reset);
    }
    if (!_started) {
      _started = true;
      _load(_segment);
    }
  }

  @override
  void dispose() {
    _tabs?.removeResetListener(MobileTab.newAndHot, _reset);
    _logos?.dispose();
    _ownScroll.dispose();
    super.dispose();
  }

  NewAndHotSource _source() =>
      widget.source ??
      CatalogNewAndHotSource(
        settings: context.read<SettingsProvider>(),
        dependencies: context.read<AppDependencyProvider>(),
      );

  Future<void> _load(HotSegment segment, {bool refresh = false}) async {
    if (_loading.contains(segment) ||
        (!refresh && _feeds.containsKey(segment))) {
      return;
    }
    setState(() {
      _loading.add(segment);
      _failed.remove(segment);
    });
    try {
      final feed = await NewAndHotCatalog(
        _source(),
        now: widget.now ?? DateTime.now,
      ).load(segment);
      if (!mounted) return;
      setState(() {
        _feeds[segment] = feed;
        _loading.remove(segment);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading.remove(segment);
        _failed.add(segment);
      });
    }
  }

  void _select(HotSegment segment) {
    if (_segment == segment) return;
    setState(() => _segment = segment);
    final scroll = _tabs?.scrollController(MobileTab.newAndHot) ?? _ownScroll;
    if (scroll.hasClients) scroll.jumpTo(0);
    _load(segment);
  }

  void _reset() => _select(HotSegment.comingSoon);

  TitleLogos _logosFor(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final dependencies = context.read<AppDependencyProvider>();
    final current = _logos;
    if (current != null &&
        current.language == TitleLogos.languageCode(settings.appLanguage) &&
        current.proxyEnabled == settings.enableProxy &&
        current.proxyUrl == dependencies.tmdbProxy) {
      return current;
    }
    current?.dispose();
    return _logos = TitleLogos(
      language: settings.appLanguage,
      proxyEnabled: settings.enableProxy,
      proxyUrl: dependencies.tmdbProxy,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final feed = _feeds[_segment];
    final labels = <HotSegment, String>{
      HotSegment.comingSoon: tr('coming_soon'),
      HotSegment.everyoneWatching: tr('everyone_watching'),
      HotSegment.topMovies: tr('top_10_movies'),
      HotSegment.topSeries: tr('top_10_series'),
    };
    final page = Column(
      children: <Widget>[
        SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
                gutter, AppSpace.lg, gutter, AppSpace.lg),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(tr('new_and_hot'),
                  style: AppType.pageTitle.copyWith(color: palette.foreground)),
            ),
          ),
        ),
        FilterChips(chips: <FilterChipSpec>[
          for (final segment in HotSegment.values)
            FilterChipSpec(
              label: labels[segment]!,
              selected: segment == _segment,
              onTap: () => _select(segment),
            ),
        ]),
        const SizedBox(height: AppSpace.lg),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOut,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: RefreshIndicator(
              key: ValueKey<HotSegment>(_segment),
              color: palette.mutedText,
              onRefresh: () => _load(_segment, refresh: true),
              child: ListView(
                controller:
                    _tabs?.scrollController(MobileTab.newAndHot) ?? _ownScroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsetsDirectional.only(bottom: 100),
                children: <Widget>[
                  if ((feed == null && _loading.contains(_segment)) ||
                      (_segment == HotSegment.comingSoon && !_datesReady))
                    _HotSkeleton(segment: _segment)
                  else if (feed == null && _failed.contains(_segment))
                    _HotMessage(
                      message: tr('new_and_hot_load_failed'),
                      retry: () => _load(_segment, refresh: true),
                    )
                  else if (feed == null || feed.isEmpty)
                    _HotMessage(message: tr('new_and_hot_empty'))
                  else
                    ..._content(context, feed),
                ],
              ),
            ),
          ),
        ),
      ],
    );
    return ColoredBox(
      color: palette.page,
      child: widget.showTitleLogos
          ? TitleLogoScope(logos: _logosFor(context), child: page)
          : page,
    );
  }

  List<Widget> _content(BuildContext context, NewAndHotFeed feed) {
    final gutter = AppSpace.gutter(context);
    if (_segment == HotSegment.comingSoon) {
      return <Widget>[
        for (final (index, group) in feed.groups.indexed) ...<Widget>[
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
                gutter, 0, gutter, AppSpace.rowGap),
            child: _PremiereGroupCard(
              group: group,
              movieGenres: feed.movieGenres,
              seriesGenres: feed.seriesGenres,
              showTitleLogos: widget.showTitleLogos,
            ),
          ),
          if (index == 2)
            widget.adBuilder?.call(context) ??
                HomeAdSlot(placement: 'new_and_hot'),
        ],
      ];
    }
    if (_segment == HotSegment.everyoneWatching) {
      return <Widget>[
        for (final item in feed.items)
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
                gutter, 0, gutter, AppSpace.rowGap),
            child: _WatchingCard(
                item: item, showTitleLogos: widget.showTitleLogos),
          ),
      ];
    }
    return <Widget>[
      for (final (index, item) in feed.items.indexed)
        Padding(
          padding:
              EdgeInsetsDirectional.fromSTEB(gutter, 0, gutter, AppSpace.lg),
          child: _RankedCard(item: item, rank: index + 1),
        ),
    ];
  }
}

class _PremiereGroupCard extends StatelessWidget {
  const _PremiereGroupCard({
    required this.group,
    required this.movieGenres,
    required this.seriesGenres,
    required this.showTitleLogos,
  });

  final PremiereGroup group;
  final List<Genres> movieGenres;
  final List<Genres> seriesGenres;
  final bool showTitleLogos;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final locale = Localizations.localeOf(context).toString();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 68,
          child: Column(
            children: <Widget>[
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                    DateFormat.MMM(locale).format(group.date).toUpperCase(),
                    maxLines: 1,
                    style: AppType.kicker.copyWith(color: palette.mutedText)),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(DateFormat.d(locale).format(group.date),
                    style:
                        AppType.pageTitle.copyWith(color: palette.foreground)),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            children: <Widget>[
              for (final item in group.items) ...<Widget>[
                _PremiereCard(
                  item: item,
                  date: group.date,
                  genres:
                      item.kind == MediaKind.movie ? movieGenres : seriesGenres,
                  showTitleLogos: showTitleLogos,
                ),
                if (item != group.items.last)
                  const SizedBox(height: AppSpace.xxl),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PremiereCard extends StatelessWidget {
  const _PremiereCard({
    required this.item,
    required this.date,
    required this.genres,
    required this.showTitleLogos,
  });

  final MediaItem item;
  final DateTime date;
  final List<Genres> genres;
  final bool showTitleLogos;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final genreNames = <String>[
      tr(item.kind == MediaKind.movie ? 'movie' : 'series_one'),
      for (final id in item.genreIds)
        for (final genre in genres)
          if (genre.genreID == id && genre.genreName != null) genre.genreName!,
    ];
    final dateText = DateFormat.MMMd(Localizations.localeOf(context).toString())
        .format(date);
    return Pressable(
      semanticLabel: mediaSemanticLabel(item),
      onTap: () => MobilePlayback.openDetails(context, item),
      onLongPress: () => showTitleSheet(context, item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Backdrop(item: item),
          const SizedBox(height: AppSpace.md),
          _HotTitle(item: item, showTitleLogos: showTitleLogos),
          const SizedBox(height: AppSpace.sm),
          Text(
            tr(item.kind == MediaKind.movie ? 'coming_date' : 'premieres_date',
                namedArgs: <String, String>{'date': dateText}).toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.kicker
                .copyWith(color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(genreNames.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.metadata.copyWith(color: palette.mutedText)),
          const SizedBox(height: AppSpace.sm),
          Text(item.overview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppType.body.copyWith(color: palette.secondaryText)),
          const SizedBox(height: AppSpace.md),
          _MyListButton(item: item),
        ],
      ),
    );
  }
}

class _WatchingCard extends StatelessWidget {
  const _WatchingCard({required this.item, required this.showTitleLogos});

  final MediaItem item;
  final bool showTitleLogos;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Pressable(
      semanticLabel: mediaSemanticLabel(item),
      onTap: () => MobilePlayback.openDetails(context, item),
      onLongPress: () => showTitleSheet(context, item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Backdrop(item: item),
          const SizedBox(height: AppSpace.md),
          _HotTitle(item: item, showTitleLogos: showTitleLogos),
          const SizedBox(height: AppSpace.sm),
          Text(
              <String>[
                tr(item.kind == MediaKind.movie ? 'movie' : 'series_one'),
                if (item.year != null) item.year!,
                if ((item.rating ?? 0) > 0) item.rating!.toStringAsFixed(1),
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.metadata.copyWith(color: palette.mutedText)),
          const SizedBox(height: AppSpace.sm),
          Text(item.overview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppType.body.copyWith(color: palette.secondaryText)),
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: <Widget>[
              if (MobilePlayback.canPlay(context))
                PillButton(
                  label: tr('play'),
                  icon: PhosphorIcons.play(PhosphorIconsStyle.fill),
                  primary: true,
                  onPressed: () => MobilePlayback.play(context, item),
                ),
              _MyListButton(item: item),
            ],
          ),
        ],
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: MediaArt(
            item: item,
            path: item.backdropPath ?? item.posterPath,
            width: MediaQuery.sizeOf(context).width,
            size: ArtSize.backdrop,
          ),
        ),
      );
}

class _HotTitle extends StatelessWidget {
  const _HotTitle({required this.item, required this.showTitleLogos});
  final MediaItem item;
  final bool showTitleLogos;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final fallback = Text(item.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppType.sectionHeader.copyWith(color: palette.foreground));
    if (!showTitleLogos) return fallback;
    return TitleLogo(
      item: item,
      maxHeight: 48,
      alignment: AlignmentDirectional.centerStart,
      fallback: fallback,
    );
  }
}

class _MyListButton extends StatelessWidget {
  const _MyListButton({required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final saved = MyList.contains(context, item);
    return PillButton(
      label: tr('my_list'),
      icon: saved
          ? PhosphorIcons.check(PhosphorIconsStyle.fill)
          : PhosphorIcons.plus(),
      onPressed: context.read<BookmarkProvider?>() == null
          ? null
          : () => MyList.toggle(context, item),
    );
  }
}

class _RankedCard extends StatelessWidget {
  const _RankedCard({required this.item, required this.rank});
  final MediaItem item;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    const posterWidth = 80.0;
    const posterHeight = posterWidth / PosterCard.aspectRatio;
    return Pressable(
      semanticLabel: '$rank, ${mediaSemanticLabel(item)}',
      onTap: () => MobilePlayback.openDetails(context, item),
      onLongPress: () => showTitleSheet(context, item),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          TopTenRank(rank: rank, cardWidth: posterWidth, height: posterHeight),
          PosterCard(item: item, width: posterWidth),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppType.cardTitle.copyWith(color: palette.foreground)),
                const SizedBox(height: AppSpace.sm),
                Text(
                    <String>[
                      if (item.year != null) item.year!,
                      if ((item.rating ?? 0) > 0)
                        item.rating!.toStringAsFixed(1),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.metadata.copyWith(color: palette.mutedText)),
                const SizedBox(height: AppSpace.sm),
                Text(item.overview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.metadata
                        .copyWith(color: palette.secondaryText)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HotMessage extends StatelessWidget {
  const _HotMessage({required this.message, this.retry});
  final String message;
  final VoidCallback? retry;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(32, 96, 32, 0),
      child: Column(
        children: <Widget>[
          Icon(PhosphorIcons.filmSlate(), size: 36, color: palette.mutedText),
          const SizedBox(height: AppSpace.md),
          Text(message,
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(color: palette.mutedText)),
          if (retry != null) ...<Widget>[
            const SizedBox(height: AppSpace.lg),
            PillButton(label: tr('retry'), onPressed: retry),
          ],
        ],
      ),
    );
  }
}

class _HotSkeleton extends StatefulWidget {
  const _HotSkeleton({required this.segment});
  final HotSegment segment;

  @override
  State<_HotSkeleton> createState() => _HotSkeletonState();
}

class _HotSkeletonState extends State<_HotSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final color = Color.lerp(
            palette.surface,
            palette.raisedSurface,
            Curves.easeInOut.transform(_pulse.value),
          )!;
          Widget block(double width, double height) => Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
              );
          return Padding(
            padding: EdgeInsetsDirectional.symmetric(horizontal: gutter),
            child: Column(
              children: <Widget>[
                for (var i = 0; i < 3; i++) ...<Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (widget.segment == HotSegment.comingSoon) ...<Widget>[
                        block(48, 56),
                        const SizedBox(width: AppSpace.md)
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            AspectRatio(
                              aspectRatio:
                                  widget.segment == HotSegment.topMovies ||
                                          widget.segment == HotSegment.topSeries
                                      ? 3 / 1
                                      : 16 / 9,
                              child: block(double.infinity, double.infinity),
                            ),
                            const SizedBox(height: AppSpace.md),
                            block(150, 20),
                            const SizedBox(height: AppSpace.sm),
                            block(double.infinity, 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.rowGap),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
