import 'dart:ui' show ImageFilter;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import 'mobile_tabs.dart';

/// The phone's bottom bar: flush with the screen's edge, the page showing
/// faintly through it, the current tab in ink with a filled icon.
class MobileNavBar extends StatelessWidget {
  const MobileNavBar({
    required this.current,
    required this.onSelect,
    super.key,
  });

  final MobileTab current;
  final ValueChanged<MobileTab> onSelect;

  static const height = 60.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final media = MediaQuery.of(context);
    // Blur costs a frame budget some phones don't have; those that ask for
    // less motion get a solid bar instead.
    final solid = media.disableAnimations;
    final bar = DecoratedBox(
      decoration: BoxDecoration(
        color: solid ? palette.page : palette.scrim(0.94),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: media.padding.bottom),
        child: SizedBox(
          height: height,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: Row(
              children: <Widget>[
                for (final tab in MobileTab.values)
                  Expanded(
                    child: _NavItem(
                      tab: tab,
                      selected: tab == current,
                      onTap: () => onSelect(tab),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (solid) return bar;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: bar,
      ),
    );
  }
}

/// The tablet's side bar: the same destinations as [MobileNavBar], stacked
/// at the start edge, the current one in ink with a filled icon and no
/// indicator.
class MobileNavRail extends StatelessWidget {
  const MobileNavRail({
    required this.current,
    required this.onSelect,
    super.key,
  });

  final MobileTab current;
  final ValueChanged<MobileTab> onSelect;

  static const width = 88.0;
  static const _itemHeight = 68.0;

  /// The space the rail takes at [context]'s start edge, the display cutout
  /// on that side included.
  static double extentOf(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return width + (rtl ? padding.right : padding.left);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final padding = MediaQuery.paddingOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return SizedBox(
      width: extentOf(context),
      child: ColoredBox(
        color: palette.page,
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: rtl ? padding.right : padding.left,
            top: padding.top,
            bottom: padding.bottom,
          ),
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      for (final tab in MobileTab.values)
                        SizedBox(
                          width: width,
                          height: _itemHeight,
                          child: _NavItem(
                            tab: tab,
                            selected: tab == current,
                            onTap: () => onSelect(tab),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final MobileTab tab;
  final bool selected;
  final VoidCallback onTap;

  (IconData, IconData, String) get _look => switch (tab) {
        MobileTab.home => (
            PhosphorIcons.house(),
            PhosphorIcons.house(PhosphorIconsStyle.fill),
            'home',
          ),
        MobileTab.newAndHot => (
            PhosphorIcons.fire(),
            PhosphorIcons.fire(PhosphorIconsStyle.fill),
            'new_and_hot',
          ),
        MobileTab.discover => (
            PhosphorIcons.compass(),
            PhosphorIcons.compass(PhosphorIconsStyle.fill),
            'discover',
          ),
        MobileTab.search => (
            PhosphorIcons.magnifyingGlass(),
            PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold),
            'search',
          ),
        MobileTab.mine => (
            PhosphorIcons.userCircle(),
            PhosphorIcons.userCircle(PhosphorIconsStyle.fill),
            'my_flixquest',
          ),
      };

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final (icon, selectedIcon, labelKey) = _look;
    final color = selected ? palette.foreground : palette.mutedText;
    return Semantics(
      button: true,
      selected: selected,
      label: tr(labelKey),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(selected ? selectedIcon : icon, size: 24, color: color),
            const SizedBox(height: 3),
            Text(
              tr(labelKey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppType.semiBold,
                fontSize: 11,
                height: 14 / 11,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
