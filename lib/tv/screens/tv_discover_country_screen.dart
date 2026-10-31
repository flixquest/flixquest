import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../catalog/discover_query.dart';
import '../app/tv_design.dart';
import '../widgets/tv_choice_row.dart';
import '../widgets/tv_focus_list.dart';
import '../widgets/tv_page_header.dart';
import '../widgets/tv_search_keyboard.dart';

/// Discover's search over every country, the way Search looks: the keyboard
/// on the left and, on the right, the countries the letters find.
///
/// Before anything is typed the list holds the chosen countries, then the
/// popular ones, then the rest A to Z. Each OK takes effect at once, so the
/// results behind are already up to date; Back returns to them. Right off
/// the keyboard enters the list, and Left off the list returns to it.
class TvDiscoverCountryScreen extends StatefulWidget {
  const TvDiscoverCountryScreen({
    required this.countries,
    required this.selected,
    required this.onToggle,
    super.key,
  });

  final Future<List<DiscoverCountry>> countries;

  /// The codes chosen; [onToggle] changes them.
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  State<TvDiscoverCountryScreen> createState() =>
      _TvDiscoverCountryScreenState();
}

class _TvDiscoverCountryScreenState extends State<TvDiscoverCountryScreen> {
  final GlobalKey<TvSearchKeyboardState> _keyboard =
      GlobalKey<TvSearchKeyboardState>();
  GlobalKey<TvFocusListState> _list = GlobalKey<TvFocusListState>();
  String _query = '';

  /// The choices as the screen opened. The list is ordered by them, not by
  /// the live ones, so a row never moves out from under the remote.
  late final Set<String> _chosenAtOpen = <String>{...widget.selected};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _keyboard.currentState?.requestFocus();
    });
  }

  void _setQuery(String query) {
    if (query == _query) return;
    setState(() {
      _query = query;
      // A new list for new matches: its rows start from the top.
      _list = GlobalKey<TvFocusListState>();
    });
  }

  void _type(String character) {
    if (character == ' ' && (_query.isEmpty || _query.endsWith(' '))) return;
    _setQuery('$_query$character');
  }

  void _delete() {
    if (_query.isEmpty) return;
    _setQuery(_query.substring(0, _query.length - 1));
  }

  void _toggle(String code) {
    widget.onToggle(code);
    setState(() {});
  }

  bool _focusList() => _list.currentState?.focus() ?? false;

  KeyEventResult _handleListKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey != LogicalKeyboardKey.arrowLeft) {
      return KeyEventResult.ignored;
    }
    return (_keyboard.currentState?.requestFocus() ?? false)
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final palette = TvPalette.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final metrics = TvShellMetrics.fromConstraints(constraints);
          final compact = metrics.compact;
          final keyboardWidth = compact ? 246.0 : 300.0;
          final chosen = widget.selected.length;
          return Padding(
            padding: EdgeInsets.all(metrics.safeInset + metrics.railGap),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: keyboardWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TvPageHeader(
                        kicker: tr('browse_with_filters').toUpperCase(),
                        title: tr('country'),
                        compact: compact,
                      ),
                      SizedBox(height: compact ? 14 : 22),
                      TvSearchQueryField(
                        query: _query,
                        hint: tr('search_countries'),
                        compact: compact,
                      ),
                      SizedBox(height: compact ? 14 : 20),
                      TvSearchKeyboard(
                        key: _keyboard,
                        width: keyboardWidth,
                        onType: _type,
                        onDelete: _delete,
                        onClear: () => _setQuery(''),
                        onExitRight: _focusList,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: compact ? 24 : 36),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(
                        height: compact ? 30 : 36,
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start: 14,
                            ),
                            child: Text(
                              chosen == 0
                                  ? tr('tv_discover_country_hint')
                                  : tr(
                                      'n_selected',
                                      namedArgs: <String, String>{
                                        'n': '$chosen',
                                      },
                                    ),
                              style: TextStyle(
                                color: palette.mutedText,
                                fontFamily: 'FigtreeSB',
                                fontSize: compact ? 14 : 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Focus(
                          canRequestFocus: false,
                          skipTraversal: true,
                          onKeyEvent: _handleListKey,
                          child: _buildList(compact),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildList(bool compact) {
    final palette = TvPalette.of(context);
    return FutureBuilder<List<DiscoverCountry>>(
      future: widget.countries,
      initialData: DiscoverQuery.featuredCountries,
      builder: (context, snapshot) {
        final all = snapshot.data ?? DiscoverQuery.featuredCountries;
        final countries = _query.trim().isEmpty
            ? DiscoverQuery.browseCountries(all, _chosenAtOpen)
            : DiscoverQuery.matchCountries(all, _query);
        if (countries.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  PhosphorIcons.globeHemisphereWest(),
                  color: palette.mutedText,
                  size: 44,
                ),
                const SizedBox(height: 14),
                Text(
                  tr('no_countries_match'),
                  style: TextStyle(
                    color: palette.foreground,
                    fontFamily: 'FigtreeBold',
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          );
        }
        return TvFocusList(
          key: _list,
          debugLabel: 'TV country',
          itemCount: countries.length,
          itemExtent: TvChoiceRow.heightFor(compact: compact),
          itemBuilder: (context, index, node) {
            final country = countries[index];
            return TvDiscoverCountryRow(
              country: country,
              focusNode: node,
              compact: compact,
              selected: widget.selected.contains(country.code),
              onActivate: () => _toggle(country.code),
            );
          },
        );
      },
    );
  }
}

/// A country to choose: its flag, its name, and its English name under it
/// when the app's language calls it something else.
class TvDiscoverCountryRow extends StatelessWidget {
  const TvDiscoverCountryRow({
    required this.country,
    required this.selected,
    required this.onActivate,
    this.focusNode,
    this.compact = false,
    super.key,
  });

  final DiscoverCountry country;
  final bool selected;
  final VoidCallback onActivate;
  final FocusNode? focusNode;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final flag = DiscoverQuery.flag(country.code);
    return TvChoiceRow(
      focusNode: focusNode,
      compact: compact,
      label: country.name,
      detail: country.englishName == country.name ? null : country.englishName,
      leading: flag == null
          ? Icon(PhosphorIcons.globeHemisphereWest())
          : Text(flag, style: const TextStyle(fontSize: 22, height: 1.1)),
      mark: TvChoiceMark.check,
      selected: selected,
      onActivate: onActivate,
    );
  }
}
