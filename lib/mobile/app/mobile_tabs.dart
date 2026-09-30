import 'package:flutter/widgets.dart';

import '../../catalog/home_feed_controller.dart';
import '../../models/default_home.dart';

/// The phone's bottom-bar destinations. [id] is what analytics and the
/// session store record.
enum MobileTab {
  home('home'),
  newAndHot('new'),
  discover('discover'),
  search('search'),
  mine('mine');

  const MobileTab(this.id);

  final String id;

  static MobileTab? fromId(String? id) {
    for (final tab in values) {
      if (tab.id == id) return tab;
    }
    return null;
  }

  static MobileTab forDefault(DefaultHome home) => switch (home) {
        DefaultHome.home ||
        DefaultHome.homeMovies ||
        DefaultHome.homeSeries =>
          MobileTab.home,
        DefaultHome.search => MobileTab.search,
        DefaultHome.mine => MobileTab.mine,
      };
}

/// Home's filter when the app opens on [home].
HomeFilter homeFilterForDefault(DefaultHome home) => switch (home) {
      DefaultHome.homeMovies => HomeFilter.movies,
      DefaultHome.homeSeries => HomeFilter.series,
      _ => HomeFilter.all,
    };

/// Which tab is showing, and what each tab does when its button is pressed
/// again: back to the top first, then back to how it started.
class MobileTabController extends ChangeNotifier {
  MobileTabController({
    required MobileTab initial,
    this.initialHomeFilter = HomeFilter.all,
  }) : _current = initial;

  MobileTab _current;
  MobileTab get current => _current;

  /// How many times the viewer has changed tab; none means the tab showing
  /// is the one the app opened on.
  int get switches => _switches;
  int _switches = 0;

  /// The filter Home opens with, from the default-home setting.
  final HomeFilter initialHomeFilter;

  final Map<MobileTab, ScrollController> _scrollControllers =
      <MobileTab, ScrollController>{};
  final Map<MobileTab, List<VoidCallback>> _resetListeners =
      <MobileTab, List<VoidCallback>>{};

  /// The controller for [tab]'s main scrollable, so pressing the tab again
  /// can take it to the top.
  ScrollController scrollController(MobileTab tab) =>
      _scrollControllers.putIfAbsent(
        tab,
        () => ScrollController(debugLabel: 'MobileTab ${tab.id}'),
      );

  /// Shows [tab]; pressing the one already showing calls [reselect].
  void select(MobileTab tab) {
    if (tab == _current) {
      reselect();
      return;
    }
    _current = tab;
    _switches++;
    notifyListeners();
  }

  /// Shows [tab] as the app's starting tab, as when Android brings the app
  /// back after closing it: not a switch the viewer made.
  void restore(MobileTab tab) {
    if (tab == _current) return;
    _current = tab;
    notifyListeners();
  }

  /// Scrolls the current tab to the top or, if it is already there, resets
  /// it: Home back to All, Search cleared.
  void reselect() {
    final controller = _scrollControllers[_current];
    final scrolled = controller != null &&
        controller.positions.any(
          (position) => position.pixels > position.minScrollExtent + 1,
        );
    if (scrolled) {
      controller.animateTo(
        0,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    for (final listener in List<VoidCallback>.of(
      _resetListeners[_current] ?? const <VoidCallback>[],
    )) {
      listener();
    }
  }

  void addResetListener(MobileTab tab, VoidCallback listener) =>
      _resetListeners.putIfAbsent(tab, () => <VoidCallback>[]).add(listener);

  void removeResetListener(MobileTab tab, VoidCallback listener) =>
      _resetListeners[tab]?.remove(listener);

  @override
  void dispose() {
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}

/// Gives the tabs their [MobileTabController].
class MobileTabScope extends InheritedNotifier<MobileTabController> {
  const MobileTabScope({
    required MobileTabController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static MobileTabController of(BuildContext context) => maybeOf(context)!;

  static MobileTabController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MobileTabScope>()?.notifier;
}
