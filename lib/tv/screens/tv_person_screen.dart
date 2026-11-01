import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../catalog/catalog_controller.dart';
import '../../catalog/person_credits.dart';
import '../../models/person.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../app/tv_design.dart';
import '../app/tv_shell_layout.dart';
import '../controllers/tv_media_details_controller.dart';
import '../controllers/tv_title_logos.dart';
import '../focus/tv_focus_memory.dart';
import '../focus/tv_screen_focus_controller.dart';
import '../models/tv_media_item.dart';
import '../widgets/tv_browse_skeleton.dart';
import '../widgets/tv_browse_view.dart';
import '../widgets/tv_person_card.dart';
import '../widgets/tv_pill_button.dart';
import '../widgets/tv_reader_dialog.dart';
import '../widgets/tv_spotlight.dart';
import '../widgets/tv_state_panel.dart';
import 'tv_collection_screen.dart';
import 'tv_media_details_screen.dart';

/// A person's page, laid out like the browse pages: their photo, name,
/// facts and biography on the billboard over the backdrop of the title
/// they're best known for, then their movies and series as rows.
///
/// It opens on Biography, which reads the whole of it. Down enters the
/// rows, where the spotlight names the focused title and the part they
/// played in it; Up from the first row or Back returns to the billboard,
/// and Back from there leaves the page.
class TvPersonScreen extends StatefulWidget {
  const TvPersonScreen({
    required this.personId,
    required this.name,
    this.profilePath,
    this.isAdult,
    this.controller = const TvMediaDetailsController(),
    super.key,
  });

  final int personId;
  final String name;
  final String? profilePath;

  /// Whether TMDB marks them adult, as the page that opened this one knew.
  final bool? isAdult;

  /// Loads the page, and the title pages it opens.
  final TvMediaDetailsController controller;

  /// The titles a row shows before See all opens the rest.
  static const rowLimit = 20;

  @override
  State<TvPersonScreen> createState() => _TvPersonScreenState();
}

class _Filmography {
  const _Filmography(this.movies, this.series);

  final List<PersonCredit> movies;
  final List<PersonCredit> series;

  bool get isEmpty => movies.isEmpty && series.isEmpty;
}

class _TvPersonScreenState extends State<TvPersonScreen> {
  final TvScreenFocusController _focus = TvScreenFocusController();
  final TvFocusMemory _memory = TvFocusMemory();
  Future<_Filmography>? _credits;
  PersonDetails? _person;
  String? _configurationKey;
  String? _dateLocale;
  bool _tracked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).toString();
    if (_dateLocale != locale) {
      _dateLocale = locale;
      // The birthday is written in the app's language once its dates load.
      initializeDateFormatting(locale).then((_) {
        if (mounted && _dateLocale == locale) setState(() {});
      });
    }
    final settings = context.watch<SettingsProvider>();
    final dependencies = context.watch<AppDependencyProvider>();
    final key = '${settings.appLanguage}|${settings.enableProxy}|'
        '${dependencies.tmdbProxy}';
    if (_configurationKey != key) {
      _configurationKey = key;
      _load();
    }
    if (!_tracked) {
      _tracked = true;
      settings.analytics.trackPersonPageView(
        personName: widget.name,
        personId: widget.personId,
        isAdult: widget.isAdult,
      );
    }
  }

  PersonSource get _source => widget.controller.personSource(
        settings: context.read<SettingsProvider>(),
        dependencies: context.read<AppDependencyProvider>(),
      );

  void _load() {
    final source = _source;
    final id = widget.personId;
    source.details(id).then((person) {
      if (mounted) setState(() => _person = person);
    }, onError: (Object error) {
      // The page stands without them: the name and photo came with it.
      debugPrint('[TvPerson] details unavailable: $error');
    });
    final credits = _loadCredits(source, id);
    _credits = credits;
    credits.then((_) {
      // Lands on the billboard once the page is built from them.
      if (mounted && identical(_credits, credits)) _focus.requestFocus();
    }, onError: (Object _) {});
  }

  /// Both kinds; one failing leaves the other, and the page fails only
  /// when neither loads.
  static Future<_Filmography> _loadCredits(PersonSource source, int id) async {
    Object? error;
    Future<List<PersonCredit>?> settle(Future<List<PersonCredit>> load) async {
      try {
        return await load;
      } catch (caught) {
        error = caught;
        return null;
      }
    }

    final movies = settle(source.credits(id, MediaKind.movie));
    final series = settle(source.credits(id, MediaKind.series));
    final found = <List<PersonCredit>?>[await movies, await series];
    if (found.every((list) => list == null)) throw error!;
    return _Filmography(
      found[0] ?? const <PersonCredit>[],
      found[1] ?? const <PersonCredit>[],
    );
  }

  void _retry() => setState(_load);

  void _restoreFocus(FocusNode? previous) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          previous == null ||
          previous.context == null ||
          !previous.canRequestFocus) {
        return;
      }
      previous.requestFocus();
    });
  }

  Future<void> _push(Widget page) async {
    final previous = FocusManager.instance.primaryFocus;
    final logos = TvTitleLogoScope.maybeOf(context);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        // Routes sit beside this one, not under it, so the logos go along.
        builder: (_) =>
            logos == null ? page : TvTitleLogoScope(logos: logos, child: page),
      ),
    );
    _restoreFocus(previous);
  }

  Future<void> _openTitle(TvMediaItem item) =>
      _push(TvMediaDetailsScreen(item: item, controller: widget.controller));

  void _openAll(List<PersonCredit> credits, MediaKind kind) {
    final items = <TvMediaItem>[for (final credit in credits) credit.item];
    _push(TvCollectionScreen(
      collection: MediaCollection(
        id: 'person-${widget.personId}-${kind.name}',
        title: kind == MediaKind.movie ? tr('movies') : tr('series'),
        kicker: _name.toUpperCase(),
        loadPage: (page) async => page == 1 ? items : const <TvMediaItem>[],
      ),
      onOpenMedia: _openTitle,
    ));
  }

  String get _name {
    final known = _person?.name?.trim() ?? '';
    return known.isEmpty ? widget.name : known;
  }

  String get _biography => _person?.biography?.trim() ?? '';

  void _readBiography() {
    final biography = _biography;
    showTvReaderDialog(
      context: context,
      title: _name,
      text: biography.isEmpty ? tr('no_biography_person') : biography,
    );
  }

  TvBillboardAction get _biographyAction => TvBillboardAction(
        label: tr('biography'),
        icon: PhosphorIcons.article(),
        semanticLabel: tr('tv_biography_semantics', namedArgs: {'name': _name}),
        onActivate: _readBiography,
      );

  /// An adult person's titles stay hidden unless adult content is on.
  bool _hidden({required bool adultAllowed}) =>
      (widget.isAdult == true || _person?.isAdult == true) && !adultAllowed;

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final palette = TvPalette.of(context);
    final adultAllowed = context.select<SettingsProvider, bool>(
      (settings) => settings.isAdult,
    );
    return TvFocusMemoryScope(
      memory: _memory,
      child: Scaffold(
        backgroundColor: palette.page,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final metrics = TvShellMetrics.fromConstraints(constraints);
            final system = MediaQuery.paddingOf(context);
            double safe(double inset) => math.max(inset, metrics.safeInset);
            final insets = EdgeInsets.fromLTRB(
              safe(system.left),
              safe(system.top),
              safe(system.right),
              safe(system.bottom),
            );
            return TvShellInsets(
              insets: insets,
              child: FutureBuilder<_Filmography>(
                future: _credits,
                builder: (context, snapshot) => AnimatedSwitcher(
                  // The page fades in over its skeleton rather than cutting.
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOut,
                  child: KeyedSubtree(
                    key: ValueKey<String>(
                      snapshot.connectionState != ConnectionState.done
                          ? 'loading'
                          : snapshot.hasError
                              ? 'error'
                              : 'loaded',
                    ),
                    child: _buildState(
                      snapshot,
                      metrics,
                      insets,
                      hidden: _hidden(adultAllowed: adultAllowed),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildState(
    AsyncSnapshot<_Filmography> snapshot,
    TvShellMetrics metrics,
    EdgeInsets insets, {
    required bool hidden,
  }) {
    if (snapshot.connectionState != ConnectionState.done) {
      return TvBrowseSkeleton(metrics: metrics);
    }
    final filmography = snapshot.data;
    if (snapshot.hasError || filmography == null) {
      return Padding(
        padding: insets,
        child: TvStatePanel.error(onRetry: _retry, autofocusAction: true),
      );
    }
    if (hidden || filmography.isEmpty) {
      return _buildProfileOnly(
        metrics,
        insets,
        message: hidden
            ? tr('contains_nsfw')
            : tr('tv_person_no_titles', namedArgs: {'name': _name}),
      );
    }
    final movies = filmography.movies;
    final series = filmography.series;
    // The kind whose best-known title is the better known leads, and that
    // title fills the backdrop.
    final seriesFirst = movies.isEmpty ||
        (series.isNotEmpty &&
            (series.first.item.popularity ?? 0) >
                (movies.first.item.popularity ?? 0));
    final rows = <TvBrowseRow>[
      _row(movies, MediaKind.movie),
      _row(series, MediaKind.series),
    ];
    final featured = (seriesFirst ? series : movies).first.item;
    return TvBrowseView(
      featured: featured,
      rows: seriesFirst ? rows.reversed.toList() : rows,
      metrics: metrics,
      onOpenMedia: _openTitle,
      focusController: _focus,
      focusMemoryScope: 'tv-person-${widget.personId}-row',
      billboard: (context) => _PersonHeader(
        name: _name,
        profilePath: _person?.profilePath ?? widget.profilePath,
        person: _person,
        compact: metrics.compact,
      ),
      billboardAction: _biographyAction,
    );
  }

  TvMediaRow _row(List<PersonCredit> credits, MediaKind kind) {
    final movie = kind == MediaKind.movie;
    final title = movie ? tr('movies') : tr('series');
    final shown = credits.take(TvPersonScreen.rowLimit).toList();
    final byId = <String, PersonCredit>{
      for (final credit in shown) credit.item.stableId: credit,
    };
    return TvMediaRow(
      title: title,
      scopeId: 'person-${widget.personId}-${kind.name}',
      items: <TvMediaItem>[for (final credit in shown) credit.item],
      spotlightFor: (item) => _spotlightFor(item, byId[item.stableId]),
      seeAll: credits.length > shown.length
          ? TvRowSeeAll(
              onActivate: () => _openAll(credits, kind),
              description: tr('tv_person_see_all_description',
                  namedArgs: {'name': _name}),
            )
          : null,
    );
  }

  /// The title as any card shows it, led by the part they played.
  static TvSpotlightData _spotlightFor(TvMediaItem item, PersonCredit? credit) {
    final data = TvSpotlightData.forItem(item);
    final roles = <String>[
      for (final character in credit?.characters ?? const <String>[])
        tr('tv_as_role', namedArgs: {'role': character}),
      ...?credit?.jobs,
    ];
    if (roles.isEmpty) return data;
    return TvSpotlightData(
      id: data.id,
      title: data.title,
      facts: data.facts,
      overview: data.overview,
      kicker: roles.join(' · ').toUpperCase(),
      item: item,
    );
  }

  /// No rows to browse: their header, Biography, and why there is nothing
  /// below.
  Widget _buildProfileOnly(
    TvShellMetrics metrics,
    EdgeInsets insets, {
    required String message,
  }) {
    final palette = TvPalette.of(context);
    return Padding(
      padding: insets,
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(left: TvDesign.focusOutset + 4),
              child: SizedBox(
                width: math.min(constraints.maxWidth, 620),
                height: constraints.maxHeight * 0.5,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: _PersonHeader(
                    name: _name,
                    profilePath: _person?.profilePath ?? widget.profilePath,
                    person: _person,
                    compact: metrics.compact,
                  ),
                ),
              ),
            ),
            SizedBox(height: metrics.compact ? 16 : 22),
            Padding(
              padding: const EdgeInsets.only(left: TvDesign.focusOutset),
              child: TvPillButton(
                label: tr('biography'),
                icon: PhosphorIcons.article(),
                semanticLabel:
                    tr('tv_biography_semantics', namedArgs: {'name': _name}),
                autofocus: true,
                prominent: true,
                scrollAlignment: null,
                onActivate: _readBiography,
              ),
            ),
            SizedBox(height: metrics.compact ? 22 : 30),
            Padding(
              padding: const EdgeInsets.only(left: TvDesign.focusOutset + 4),
              child: Text(
                message,
                style: TextStyle(
                  color: palette.mutedText,
                  fontFamily: 'Figtree',
                  fontSize: metrics.compact ? 16 : 19,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Their photo beside what they're known for, their name, when and where
/// they were born, and the start of their biography.
///
/// It fits the height it is given: the biography gives up lines first, then
/// the facts, then the kicker; the name stays.
class _PersonHeader extends StatelessWidget {
  const _PersonHeader({
    required this.name,
    required this.profilePath,
    required this.person,
    required this.compact,
  });

  final String name;
  final String? profilePath;
  final PersonDetails? person;
  final bool compact;

  /// Room held back from the budget, so rounding never tips it over.
  static const _slack = 2.0;

  List<String> _facts(BuildContext context) {
    final person = this.person;
    if (person == null) return const <String>[];
    final locale = Localizations.localeOf(context).toString();
    String date(DateTime day) {
      try {
        return DateFormat.yMMMd(locale).format(day);
      } catch (_) {
        // A locale without date symbols loaded yet.
        return DateFormat.yMMMd().format(day);
      }
    }

    final born = DateTime.tryParse(person.birthday ?? '');
    final died = DateTime.tryParse(person.deathday ?? '');
    final age = ageOf(born, died: died);
    final place = person.birthPlace?.trim() ?? '';
    return <String>[
      <String>[
        if (born != null) '${tr('born_on')} ${date(born)}',
        if (age != null) '${died != null ? tr('died_aged') : tr('age')} $age',
      ].join('  ·  '),
      if (place.isNotEmpty) '${tr('from')} $place',
    ].where((line) => line.isNotEmpty).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    return LayoutBuilder(
      builder: (context, constraints) => _buildFitted(context, constraints),
    );
  }

  Widget _buildFitted(BuildContext context, BoxConstraints constraints) {
    final palette = TvPalette.of(context);
    final colors = Theme.of(context).colorScheme;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    double lines(double fontSize, double height, int count) =>
        scaler.scale(fontSize) * height * count;

    final available = constraints.maxHeight - _slack;
    final portraitHeight = math.min(available, compact ? 168.0 : 228.0);
    final portraitWidth = portraitHeight * TvPersonPortrait.aspectRatio;
    final gap = compact ? 16.0 : 22.0;
    final textWidth = math.max(0.0, constraints.maxWidth - portraitWidth - gap);

    final kickerSize = compact ? 11.0 : 12.0;
    final factSize = compact ? 13.0 : 15.0;
    final bioSize = compact ? 13.0 : 15.0;
    final nameStyle = TextStyle(
      color: palette.foreground,
      fontFamily: 'FigtreeBold',
      fontSize: compact ? 30 : 40,
      height: 1.05,
      letterSpacing: -0.5,
    );
    final namePainter = TextPainter(
      text: TextSpan(text: name, style: nameStyle),
      maxLines: 2,
      textDirection: direction,
      textScaler: scaler,
    )..layout(maxWidth: textWidth);
    final nameHeight = namePainter.height;
    namePainter.dispose();

    final department = person?.department?.trim() ?? '';
    final facts = _facts(context);
    final biography = person?.biography?.trim() ?? '';

    var budget = available - nameHeight;
    final kickerHeight = lines(kickerSize, 1.2, 1) + 8;
    final showKicker = department.isNotEmpty && budget >= kickerHeight;
    if (showKicker) budget -= kickerHeight;
    final factHeight = 4 + lines(factSize, 1.3, 1);
    var factCount = 0;
    while (factCount < facts.length && budget >= factHeight) {
      budget -= factHeight;
      factCount++;
    }
    const bioGap = 10.0;
    final bioLines = biography.isEmpty
        ? 0
        : ((budget - bioGap) / lines(bioSize, 1.35, 1))
            .floor()
            .clamp(0, compact ? 4 : 5);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        TvPersonPortrait(profilePath: profilePath, width: portraitWidth),
        SizedBox(width: gap),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (showKicker) ...<Widget>[
                Text(
                  department.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.primary,
                    fontFamily: 'FigtreeSB',
                    fontSize: kickerSize,
                    height: 1.2,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: nameStyle,
              ),
              for (final fact in facts.take(factCount)) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  fact,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.secondaryText,
                    fontFamily: 'FigtreeSB',
                    fontSize: factSize,
                    height: 1.3,
                  ),
                ),
              ],
              if (bioLines > 0) ...<Widget>[
                const SizedBox(height: bioGap),
                Text(
                  biography,
                  maxLines: bioLines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.secondaryText,
                    fontSize: bioSize,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
