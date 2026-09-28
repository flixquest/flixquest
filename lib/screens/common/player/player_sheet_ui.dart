import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../ui_components/app_ui_components.dart';

final Expando<ThemeData> _playerThemes = Expando<ThemeData>('playerTheme');
final Expando<ThemeData> _videoThemes = Expando<ThemeData>('videoTheme');

/// The player's look for what it opens (sheets, the portrait page): it
/// follows the app, light in Light and dark otherwise, with ink pills and the
/// accent kept for progress. Shared with the controls' own panels.
ThemeData playerSheetTheme(BuildContext context) {
  final app = Theme.of(context);
  return _playerThemes[app] ??= betterPlayerPanelTheme(app);
}

/// The dark panel theme whatever the mode, for anything drawn over the video
/// itself (error screens), which is dark in every theme.
ThemeData playerVideoTheme(BuildContext context) {
  final app = Theme.of(context);
  return _videoThemes[app] ??= betterPlayerPanelTheme(app, dark: true);
}

/// Puts [child] in the player's theme: the one that follows the app, or with
/// [onVideo] the dark one for things drawn over the picture.
class PlayerTheme extends StatelessWidget {
  const PlayerTheme({required this.child, this.onVideo = false, super.key});

  final Widget child;
  final bool onVideo;

  @override
  Widget build(BuildContext context) => Theme(
        data: onVideo ? playerVideoTheme(context) : playerSheetTheme(context),
        child: child,
      );
}

/// A sheet from the player: a panel in the app's mode, rounded at the top
/// and never wider than a tablet column.
Future<T?> showPlayerSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = false,
  bool isDismissible = true,
}) {
  final theme = playerSheetTheme(context);
  final colors = theme.extension<BetterPlayerPanelColors>() ??
      BetterPlayerPanelColors.dark;
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    useSafeArea: true,
    isScrollControlled: true,
    isDismissible: isDismissible,
    backgroundColor: colors.panel,
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
    final colors = BetterPlayerPanelColors.of(context);
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
                        color: colors.track,
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
                              style: TextStyle(
                                color: colors.foreground,
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
                                style: TextStyle(
                                  color: colors.muted,
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
/// checked in ink; watch progress runs along the picture in the accent.
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
    final colors = BetterPlayerPanelColors.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    return Semantics(
      selected: selected,
      button: onTap != null,
      child: Material(
        color: selected ? colors.selectedFill : Colors.transparent,
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
                              // On the still, which is artwork in every mode.
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
                          style: TextStyle(
                            color: colors.muted,
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
                          color: selected ? colors.foreground : colors.secondary,
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
                          style: TextStyle(color: colors.muted, fontSize: 12.5),
                        ),
                      ],
                      if (description?.isNotEmpty == true) ...[
                        const SizedBox(height: 6),
                        Text(
                          description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.muted,
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
                            color: colors.foreground,
                            size: 20,
                          )
                        : onTap == null
                            ? const SizedBox.shrink()
                            : Icon(
                                PhosphorIcons.caretRight(),
                                color: colors.muted,
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

/// A sheet's bottom bar: what is chosen, and the ink pill that applies it.
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
    final colors = BetterPlayerPanelColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.panel,
        border: Border(top: BorderSide(color: colors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: TextStyle(color: colors.secondary)),
              ),
              FilledButton(onPressed: onPressed, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A picture in a player sheet: a still, a poster or a flag, on a raised tile
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
    final colors = BetterPlayerPanelColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: ColoredBox(
        color: colors.raised,
        child: IconTheme(
          data: IconThemeData(color: colors.muted),
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    );
  }
}

/// A plain icon button for a sheet's header.
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
      color: BetterPlayerPanelColors.of(context).foreground,
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
