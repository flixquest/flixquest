import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../catalog/new_and_hot.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../app/tv_design.dart';
import '../app/tv_shell_layout.dart';
import '../controllers/tv_media_details_controller.dart';
import '../focus/tv_screen_focus_controller.dart';
import '../models/tv_media_item.dart';
import '../widgets/tv_browse_skeleton.dart';
import '../widgets/tv_browse_view.dart';
import '../widgets/tv_spotlight.dart';
import '../widgets/tv_state_panel.dart';

/// The New & Hot destination: what's coming, what everyone's watching, and
/// today's Top 10s, as one browse page of rows rather than the phone's
/// segments, since the remote moves between rows anyway.
///
/// The billboard leads with the best-known title on its way. Coming cards
/// carry the day they arrive; holding OK on one adds it to My List, or
/// takes it off, so it is there on the day.
class TvNewAndHotScreen extends StatefulWidget {
  const TvNewAndHotScreen({
    required this.metrics,
    required this.onOpenMedia,
    this.focusController,
    this.source,
    this.now,
    this.details = const TvMediaDetailsController(),
    super.key,
  });

  final TvShellMetrics metrics;
  final ValueChanged<TvMediaItem> onOpenMedia;
  final TvScreenFocusController? focusController;

  /// Stand-ins for TMDB and the clock in tests.
  final NewAndHotSource? source;
  final DateTime Function()? now;

  /// Where My List is kept, as the title pages keep it.
  final TvMediaDetailsController details;

  /// How far ahead the billboard looks for its title.
  static const featuredWindow = Duration(days: 30);

  @override
  State<TvNewAndHotScreen> createState() => _TvNewAndHotScreenState();
}

class _TvNewAndHotScreenState extends State<TvNewAndHotScreen> {
  Future<NewAndHotPage>? _page;
  String? _configurationKey;
  String? _dateLocale;
  bool _datesReady = false;
  bool _saving = false;

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
    final settings = context.watch<SettingsProvider>();
    final dependencies = context.watch<AppDependencyProvider>();
    final key = '${settings.appLanguage}|${settings.enableProxy}|'
        '${dependencies.tmdbProxy}|${settings.isAdult}';
    if (_configurationKey != key) {
      _configurationKey = key;
      _page = _load(settings, dependencies);
    }
  }

  Future<NewAndHotPage> _load(
    SettingsProvider settings,
    AppDependencyProvider dependencies,
  ) {
    return NewAndHotCatalog(
      widget.source ??
          CatalogNewAndHotSource(
            settings: settings,
            dependencies: dependencies,
          ),
      now: widget.now ?? DateTime.now,
    ).loadPage();
  }

  void _retry() {
    setState(() {
      _page = _load(
        context.read<SettingsProvider>(),
        context.read<AppDependencyProvider>(),
      );
    });
  }

  DateTime get _today {
    final now = (widget.now ?? DateTime.now)();
    return DateTime(now.year, now.month, now.day);
  }

  String _dayLabel(DateTime day) =>
      day == _today ? tr('today') : DateFormat.MMMd(_dateLocale).format(day);

  /// Coming 3 Oct, or Premieres 3 Oct for a series.
  String _arrivalLabel(TvMediaItem item, DateTime day) => tr(
        item.kind == TvMediaKind.movie ? 'coming_date' : 'premieres_date',
        namedArgs: <String, String>{'date': _dayLabel(day)},
      );

  TvSpotlightData _comingSpotlight(
    NewAndHotPage page,
    TvMediaItem item,
    DateTime day,
  ) =>
      TvSpotlightData(
        id: item.stableId,
        title: item.title,
        facts: <String>[
          item.kind == TvMediaKind.movie ? tr('movie') : tr('series'),
          ...page.genreNames(item).take(2),
        ],
        overview: item.overview,
        kicker: _arrivalLabel(item, day).toUpperCase(),
        kickerIcon: PhosphorIcons.calendarBlank(),
        item: item,
      );

  /// The best-known title arriving soon, else whatever leads the rest.
  (TvMediaItem, DateTime?)? _featured(NewAndHotPage page) {
    final premieres = page.premieres;
    final horizon = _today.add(TvNewAndHotScreen.featuredWindow);
    final soon = premieres.where((entry) => !entry.$1.isAfter(horizon));
    if (soon.isNotEmpty) {
      final best = soon.reduce(
        (a, b) => (b.$2.popularity ?? 0) > (a.$2.popularity ?? 0) ? b : a,
      );
      return (best.$2, best.$1);
    }
    if (premieres.isNotEmpty) return (premieres.first.$2, premieres.first.$1);
    final leading = page.everyoneWatching.firstOrNull ??
        page.topMovies.firstOrNull ??
        page.topSeries.firstOrNull;
    return leading == null ? null : (leading, null);
  }

  Future<void> _toggleMyList(TvMediaItem item) async {
    if (_saving) return;
    _saving = true;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final saved = await widget.details.isBookmarked(item);
      final now = await widget.details.toggleBookmark(item, saved);
      if (!mounted || now == saved) return;
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(tr(now ? 'added_to_my_list' : 'removed_from_my_list')),
        ));
    } finally {
      _saving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    // A full-bleed screen: only the browse view's artwork reaches the edges.
    final insets = TvShellInsets.of(context);
    return FutureBuilder<NewAndHotPage>(
      future: _page,
      builder: (context, snapshot) {
        final loading =
            snapshot.connectionState != ConnectionState.done || !_datesReady;
        final page = snapshot.data;
        return AnimatedSwitcher(
          // The page fades in over its skeleton rather than cutting to it.
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOut,
          child: KeyedSubtree(
            key: ValueKey<String>(
              loading
                  ? 'loading'
                  : page == null
                      ? 'error'
                      : page.isEmpty
                          ? 'empty'
                          : 'loaded',
            ),
            child: loading
                ? TvBrowseSkeleton(metrics: widget.metrics)
                : _buildLoaded(page, insets),
          ),
        );
      },
    );
  }

  Widget _buildLoaded(NewAndHotPage? page, EdgeInsets insets) {
    final featured = page == null ? null : _featured(page);
    if (page == null || featured == null) {
      return Padding(
        padding: insets,
        child: page == null
            ? TvStatePanel(
                title: tr('something_went_wrong'),
                message: tr('new_and_hot_load_failed'),
                icon: PhosphorIcons.fire(),
                actionLabel: tr('retry'),
                onAction: _retry,
              )
            : TvStatePanel(
                title: tr('new_and_hot_empty'),
                message: tr('tv_new_and_hot_empty_message'),
                icon: PhosphorIcons.fire(),
                actionLabel: tr('refresh'),
                onAction: _retry,
              ),
      );
    }
    final premieres = page.premieres;
    final days = <String, DateTime>{
      for (final (day, item) in premieres) item.stableId: day,
    };
    final (featuredItem, featuredDay) = featured;
    return TvBrowseView(
      featured: featuredItem,
      featuredSpotlight: featuredDay == null
          ? null
          : _comingSpotlight(page, featuredItem, featuredDay),
      metrics: widget.metrics,
      onOpenMedia: widget.onOpenMedia,
      focusController: widget.focusController,
      focusMemoryScope: 'tv-new-and-hot-row',
      // A coming card carries its day; the rest go by the usual labels.
      badgeFor: (item) => switch (days[item.stableId]) {
        final day? => _dayLabel(day).toUpperCase(),
        null => null,
      },
      rows: <TvBrowseRow>[
        TvMediaRow(
          title: tr('coming_soon'),
          scopeId: 'new-coming-soon',
          items: <TvMediaItem>[for (final (_, item) in premieres) item],
          spotlightFor: (item) =>
              _comingSpotlight(page, item, days[item.stableId]!),
          onItemMenu: _toggleMyList,
          itemMenuHint: tr('tv_hold_ok_for_my_list'),
        ),
        TvMediaRow(
          title: tr('everyone_watching'),
          scopeId: 'new-everyone-watching',
          items: page.everyoneWatching,
        ),
        TvTopTenRow(
          title: tr('top_10_movies'),
          scopeId: 'new-top-movies',
          items: page.topMovies,
        ),
        TvTopTenRow(
          title: tr('top_10_series'),
          scopeId: 'new-top-series',
          items: page.topSeries,
        ),
      ],
    );
  }
}
