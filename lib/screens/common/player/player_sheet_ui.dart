import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../ui_components/app_ui_components.dart';

final Expando<ThemeData> _playerThemes = Expando<ThemeData>('playerTheme');

/// The player's look for everything it opens: black panels, white text and
/// white pills, in every theme mode, with the app's accent kept as `primary`
/// for progress alone. Shared with the controls' own panels.
ThemeData playerSheetTheme(BuildContext context) {
  final app = Theme.of(context);
  return _playerThemes[app] ??= betterPlayerPanelTheme(app);
}

/// Puts [child] in the player's dark theme, for the parts of the player
/// drawn in its own route (the portrait layout, error screens).
class PlayerTheme extends StatelessWidget {
  const PlayerTheme({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Theme(data: playerSheetTheme(context), child: child);
}

/// A sheet from the player: the dark panel over the picture, rounded at the
/// top and never wider than a tablet column.
Future<T?> showPlayerSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = false,
  bool isDismissible = true,
}) {
  final theme = playerSheetTheme(context);
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    useSafeArea: true,
    isScrollControlled: true,
    isDismissible: isDismissible,
    backgroundColor: BetterPlayerColors.panel,
    barrierColor: Colors.black54,
    constraints: const BoxConstraints(maxWidth: 720),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => Theme(data: theme, child: builder(sheetContext)),
  );
}

/// A player sheet's frame: a handle, the title with a muted line under it,
/// the sheet's own actions at the end, then its content and an optional
/// footer.
class PlayerSheetScaffold extends StatelessWidget {
  const PlayerSheetScaffold({
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.footer,
    this.showDragHandle = true,
    this.onHeaderVerticalDragUpdate,
    this.onHeaderVerticalDragEnd,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;
  final Widget? footer;
  final bool showDragHandle;
  final GestureDragUpdateCallback? onHeaderVerticalDragUpdate;
  final GestureDragEndCallback? onHeaderVerticalDragEnd;

  @override
  Widget build(BuildContext context) {
    return AppResponsiveContent(
      maxWidth: 760,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: onHeaderVerticalDragUpdate,
            onVerticalDragEnd: onHeaderVerticalDragEnd,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showDragHandle)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Container(
                      key: const Key('player_sheet_drag_handle'),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 8, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'FigtreeBold',
                                fontSize: 19,
                                height: 1.2,
                              ),
                            ),
                            if (subtitle?.isNotEmpty == true) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: BetterPlayerColors.muted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      ...actions,
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}

/// One choice in a player sheet: an optional picture at the start, the name,
/// a muted detail and two lines of description. The chosen one is lifted and
/// checked, in white; watch progress runs along the picture in the accent.
class PlayerChoiceCard extends StatelessWidget {
  const PlayerChoiceCard({
    required this.title,
    required this.onTap,
    this.thumbnail,
    this.subtitle,
    this.description,
    this.selected = false,
    this.progress,
    this.trailing,
    this.kicker,
    super.key,
  });

  final String title;
  final VoidCallback? onTap;
  final Widget? thumbnail;
  final String? subtitle;
  final String? description;
  final bool selected;
  final double? progress;
  final Widget? trailing;

  /// A small uppercase line over the title ("NOW PLAYING").
  final String? kicker;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Semantics(
      selected: selected,
      button: onTap != null,
      child: Material(
        color: selected ? const Color(0x14FFFFFF) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 12, 10),
            child: Row(
              children: [
                if (thumbnail != null) ...[
                  Stack(
                    children: [
                      thumbnail!,
                      if (progress != null)
                        PositionedDirectional(
                          start: 0,
                          end: 0,
                          bottom: 0,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(6),
                            ),
                            child: LinearProgressIndicator(
                              value: progress!.clamp(0, 1),
                              minHeight: 3,
                              color: accent,
                              backgroundColor: Colors.white24,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (kicker != null) ...[
                        Text(
                          kicker!.toUpperCase(),
                          style: const TextStyle(
                            color: BetterPlayerColors.muted,
                            fontFamily: 'FigtreeSB',
                            fontSize: 10.5,
                            letterSpacing: 1.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                      ],
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : BetterPlayerColors.secondary,
                          fontFamily: selected ? 'FigtreeBold' : 'FigtreeSB',
                          fontSize: 15,
                          height: 1.25,
                        ),
                      ),
                      if (subtitle?.isNotEmpty == true) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: BetterPlayerColors.muted,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                      if (description?.isNotEmpty == true) ...[
                        const SizedBox(height: 6),
                        Text(
                          description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: BetterPlayerColors.muted,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                trailing ??
                    (selected
                        ? Icon(
                            PhosphorIcons.check(PhosphorIconsStyle.bold),
                            color: Colors.white,
                            size: 20,
                          )
                        : onTap == null
                            ? const SizedBox.shrink()
                            : Icon(
                                PhosphorIcons.caretRight(),
                                color: BetterPlayerColors.muted,
                                size: 18,
                              )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A sheet's bottom bar: what is chosen, and the white pill that applies it.
class PlayerSheetFooter extends StatelessWidget {
  const PlayerSheetFooter({
    required this.label,
    required this.actionLabel,
    required this.onPressed,
    super.key,
  });

  final String label;
  final String actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: BetterPlayerColors.panel,
        border: Border(top: BorderSide(color: BetterPlayerColors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: BetterPlayerColors.secondary),
                ),
              ),
              FilledButton(onPressed: onPressed, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A picture in a player sheet: a still, a poster or a flag, on a dark tile
/// while it loads.
class PlayerThumbnail extends StatelessWidget {
  const PlayerThumbnail({
    required this.child,
    this.width = 112,
    this.height = 70,
    super.key,
  });

  final Widget child;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: ColoredBox(
        color: BetterPlayerColors.panelRaised,
        child: IconTheme(
          data: const IconThemeData(color: BetterPlayerColors.muted),
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    );
  }
}

/// A plain rounded icon button for a sheet's header.
class PlayerSheetAction extends StatelessWidget {
  const PlayerSheetAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      color: Colors.white,
      onPressed: onPressed,
      icon: busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
    );
  }
}
