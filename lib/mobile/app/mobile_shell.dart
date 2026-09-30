import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/app_constants.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../provider/settings_provider.dart';
import '../../services/app_session_state_store.dart';
import '../screens/discover_screen.dart';
import '../screens/home_screen.dart';
import '../screens/my_flixquest_screen.dart';
import '../screens/new_and_hot_screen.dart';
import '../screens/search_screen.dart';
import 'mobile_nav_bar.dart';
import 'mobile_tabs.dart';

/// The phone app's frame: five tabs under a flush bottom bar, or beside a
/// side rail from tablet width.
///
/// Each tab is built the first time it is shown and kept alive after, so
/// switching back finds it as it was left. Back from any tab but Home goes to
/// Home; Back on Home leaves the app. Details pages are pushed on the root
/// navigator over whichever tab is showing, as deep links expect.
class MobileShell extends StatefulWidget {
  const MobileShell({this.tabBuilders, this.preferences, super.key});

  /// Tab bodies in place of the app's own, for tests.
  final Map<MobileTab, WidgetBuilder>? tabBuilders;

  /// Where the last tab is remembered; the app's preferences by default.
  final SharedPreferences? preferences;

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell>
    with SingleTickerProviderStateMixin, RestorationMixin {
  late final AppSessionStateStore _session;
  late final MobileTabController _tabs;
  late final RestorableString _restoredTab;
  late final AnimationController _fade;
  final Map<MobileTab, Widget> _bodies = <MobileTab, Widget>{};

  // Turning the device swaps the bar for the rail; the key carries the tabs,
  // and what they have loaded, across the swap.
  final GlobalKey _tabsKey = GlobalKey(debugLabel: 'MobileShell tabs');

  @override
  String get restorationId => 'handheld_home';

  @override
  void initState() {
    super.initState();
    _session = AppSessionStateStore(widget.preferences ?? sharedPrefsSingleton);
    final defaultHome = context.read<SettingsProvider>().defaultHome;
    final initial = MobileTab.fromId(_session.handheldDestination) ??
        MobileTab.forDefault(defaultHome);
    _restoredTab = RestorableString(initial.id);
    _tabs = MobileTabController(
      initial: initial,
      initialHomeFilter: homeFilterForDefault(defaultHome),
    )..addListener(_onTabChanged);
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: 1,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SettingsProvider>().analytics.trackNavigation(
            destination: _tabs.current.id,
            surface: 'standard',
            source: 'restored',
          );
    });
  }

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_restoredTab, 'selected_destination');
    final restored = MobileTab.fromId(
      AppSessionStateStore.legacyHandheldDestinations[_restoredTab.value] ??
          _restoredTab.value,
    );
    if (restored != null && restored != _tabs.current) {
      _tabs.restore(restored);
    }
  }

  void _onTabChanged() {
    final tab = _tabs.current;
    if (_restoredTab.value == tab.id) return;
    setState(() => _restoredTab.value = tab.id);
    _fade.forward(from: 0);
    context
        .read<SettingsProvider>()
        .analytics
        .trackNavigation(destination: tab.id, surface: 'standard');
    unawaited(_session.rememberHandheldDestination(tab.id));
  }

  @override
  void dispose() {
    _tabs
      ..removeListener(_onTabChanged)
      ..dispose();
    _restoredTab.dispose();
    _fade.dispose();
    super.dispose();
  }

  Widget _body(MobileTab tab) => _bodies.putIfAbsent(
        tab,
        () => KeyedSubtree(
          key: ValueKey<MobileTab>(tab),
          child: Builder(
            builder: widget.tabBuilders?[tab] ?? (_) => _AppTab(tab: tab),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final current = _tabs.current;
    return MobileTabScope(
      controller: _tabs,
      child: PopScope(
        canPop: current == MobileTab.home,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _tabs.select(MobileTab.home);
        },
        child: Builder(
          builder: (context) {
            final media = MediaQuery.of(context);
            final rail = media.size.width >= AppBreakpoints.tablet;
            final bodies = _tabStack(current);
            return Scaffold(
              backgroundColor: AppPalette.of(context).page,
              // The page runs under the translucent bar; tabs pad their ends
              // by MediaQuery's bottom padding, which includes the bar.
              extendBody: !rail,
              bottomNavigationBar: rail
                  ? null
                  : MobileNavBar(current: current, onSelect: _tabs.select),
              body: rail
                  ? Row(
                      children: <Widget>[
                        MobileNavRail(current: current, onSelect: _tabs.select),
                        Expanded(
                          child: MediaQuery(
                            data: _besideRail(context, media),
                            child: bodies,
                          ),
                        ),
                      ],
                    )
                  : bodies,
            );
          },
        ),
      ),
    );
  }

  /// [media] as the tabs beside the rail should see it: as wide as the space
  /// left, and without the inset on the rail's side, which the rail covers.
  MediaQueryData _besideRail(BuildContext context, MediaQueryData media) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    EdgeInsets clear(EdgeInsets insets) =>
        rtl ? insets.copyWith(right: 0) : insets.copyWith(left: 0);
    return media.copyWith(
      size: Size(
        media.size.width - MobileNavRail.extentOf(context),
        media.size.height,
      ),
      padding: clear(media.padding),
      viewPadding: clear(media.viewPadding),
      viewInsets: clear(media.viewInsets),
    );
  }

  Widget _tabStack(MobileTab current) => Stack(
        key: _tabsKey,
        fit: StackFit.expand,
        children: <Widget>[
          for (final tab in MobileTab.values)
            if (tab == current || _bodies.containsKey(tab))
              Offstage(
                key: ValueKey<MobileTab>(tab),
                offstage: tab != current,
                child: TickerMode(
                  enabled: tab == current,
                  child: FadeTransition(
                    opacity: tab == current ? _fade : kAlwaysCompleteAnimation,
                    child: _body(tab),
                  ),
                ),
              ),
        ],
      );
}

/// The app's own page for [tab].
class _AppTab extends StatelessWidget {
  const _AppTab({required this.tab});

  final MobileTab tab;

  @override
  Widget build(BuildContext context) {
    return switch (tab) {
      MobileTab.home => const HomeScreen(),
      MobileTab.newAndHot => const NewAndHotScreen(),
      MobileTab.discover => const DiscoverScreen(),
      MobileTab.search => const SearchScreen(),
      MobileTab.mine => const MyFlixQuestScreen(),
    };
  }
}
