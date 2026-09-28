import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../design/skeleton.dart';
import 'pill_button.dart';

/// The parts every pushed page is built from, in the TV's language: the
/// page colour behind everything, ink for what's chosen, muted text for
/// what's secondary, and never the accent.

/// A pushed page's bar: the page colour, the title in heavy type with an
/// optional kicker above it, and whatever sits beneath (a switch, chips).
class PageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PageAppBar({
    required this.title,
    this.kicker,
    this.actions,
    this.bottom,
    super.key,
  });

  final String title;
  final String? kicker;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final kicker = this.kicker;
    return AppBar(
      backgroundColor: palette.page,
      surfaceTintColor: Colors.transparent,
      foregroundColor: palette.foreground,
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (kicker != null)
            Text(
              kicker.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.kicker.copyWith(color: palette.mutedText),
            ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.sectionHeader.copyWith(
              fontFamily: AppType.bold,
              color: palette.foreground,
            ),
          ),
        ],
      ),
      actions: <Widget>[...?actions, const SizedBox(width: 4)],
      bottom: bottom,
    );
  }
}

/// A search field in a soft pill, the text centred in it; the clear button
/// shows once there is something to clear.
class SearchPill extends StatelessWidget {
  const SearchPill({
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.focusNode,
    this.searching = false,
    this.autofocus = false,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

  /// After the field is emptied; [onChanged] also hears the empty text.
  final VoidCallback? onClear;
  final FocusNode? focusNode;

  /// A small spinner in the clear button's place while results come in.
  final bool searching;
  final bool autofocus;

  static const height = 48.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: palette.idleFill,
        borderRadius: BorderRadius.circular(AppRadii.hero),
      ),
      child: Row(
        children: <Widget>[
          const SizedBox(width: 14),
          Icon(
            PhosphorIcons.magnifyingGlass(),
            size: 20,
            color: palette.mutedText,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autofocus,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.center,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              style: AppType.body.copyWith(
                fontSize: 16,
                color: palette.foreground,
                // Figtree sits low in its line; even leading centres it.
                leadingDistribution: TextLeadingDistribution.even,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                // The theme pads fields for forms; this one is centred in
                // its pill instead.
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintText: hint,
                hintStyle: AppType.body.copyWith(
                  fontSize: 16,
                  color: palette.mutedText,
                  leadingDistribution: TextLeadingDistribution.even,
                ),
              ),
            ),
          ),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              if (searching) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.mutedText,
                    ),
                  ),
                );
              }
              if (controller.text.isEmpty) return const SizedBox(width: 8);
              return IconButton(
                tooltip: tr('clear'),
                color: palette.mutedText,
                iconSize: 18,
                onPressed: () {
                  controller.clear();
                  onChanged('');
                  onClear?.call();
                },
                icon: Icon(PhosphorIcons.xCircle(PhosphorIconsStyle.fill)),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// One option of a [SegmentSwitch].
class Segment<T> {
  const Segment(this.value, this.label, {this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Two or three views of one page as one control, the chosen part filled
/// with ink.
class SegmentSwitch<T> extends StatelessWidget {
  const SegmentSwitch({
    required this.segments,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<Segment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  static const height = 52.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      height: height,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: palette.idleFill,
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Row(
        children: <Widget>[
          for (final segment in segments)
            Expanded(
              child: Semantics(
                button: true,
                selected: segment.value == selected,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (segment.value == selected) return;
                    HapticFeedback.selectionClick();
                    onChanged(segment.value);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: segment.value == selected
                          ? palette.focusFill
                          : const Color(0x00000000),
                      borderRadius: BorderRadius.circular(AppRadii.chip - 2),
                    ),
                    child: _SegmentLabel(
                      segment: segment,
                      color: segment.value == selected
                          ? palette.onFocus
                          : palette.secondaryText,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel({required this.segment, required this.color});

  final Segment<Object?> segment;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final icon = segment.icon;
    // Scales down rather than clipping at large text sizes.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 8),
          ],
          Text(
            segment.label,
            maxLines: 1,
            style: AppType.cardTitle.copyWith(fontSize: 15, color: color),
          ),
        ],
      ),
    );
  }
}

/// A choice that fills with ink, with a check, when on.
class TogglePill extends StatelessWidget {
  const TogglePill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.check = true,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Whether a check marks the chosen pill; one-of-many rails leave it out.
  final bool check;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final foreground = selected ? palette.onFocus : palette.foreground;
    final marked = selected && check;
    void tap() {
      HapticFeedback.selectionClick();
      onTap();
    }

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: tap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            widthFactor: 1,
            child: Material(
              color: selected ? palette.focusFill : palette.idleFill,
              borderRadius: BorderRadius.circular(AppRadii.chip),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: tap,
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 160),
                  padding: EdgeInsetsDirectional.fromSTEB(
                    marked ? 11 : 15,
                    9,
                    15,
                    9,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (marked) ...<Widget>[
                        Icon(PhosphorIcons.check(),
                            size: 15, color: foreground),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        label,
                        style: AppType.cardTitle.copyWith(
                          fontSize: 14,
                          color: foreground,
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

/// A small uppercase label over a group: muted, never the accent.
class KickerHeading extends StatelessWidget {
  const KickerHeading(this.label, {this.padding, this.trailing, super.key});

  final String label;
  final EdgeInsetsGeometry? padding;

  /// A count or an action at the end of the line.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final trailing = this.trailing;
    return Padding(
      padding: padding ??
          EdgeInsetsDirectional.fromSTEB(gutter, AppSpace.xl, gutter, 10),
      child: Semantics(
        header: true,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.kicker.copyWith(color: palette.mutedText),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}

/// Keeps a page's text to a reading column, centred, on screens wider than
/// [maxWidth]; on a phone it changes nothing.
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({required this.child, this.maxWidth = 760, super.key});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}

/// [ReadableWidth] for a run of slivers.
class SliverReadableWidth extends StatelessWidget {
  const SliverReadableWidth({
    required this.slivers,
    this.maxWidth = 760,
    super.key,
  });

  final List<Widget> slivers;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final side = ((MediaQuery.sizeOf(context).width - maxWidth) / 2)
        .clamp(0.0, double.infinity);
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: side),
      sliver: SliverMainAxisGroup(slivers: slivers),
    );
  }
}

/// A page, or part of one, with nothing to show: an icon in muted text, a
/// title, one line, and an optional pill to act on it.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    super.key,
  });

  /// Something went wrong, with Retry when trying again could help.
  EmptyState.error({
    required String message,
    VoidCallback? onRetry,
    String? title,
    Key? key,
  }) : this(
          icon: PhosphorIcons.cloudSlash(),
          title: title ?? tr('something_went_wrong'),
          message: message,
          actionLabel: onRetry == null ? null : tr('retry'),
          actionIcon: PhosphorIcons.arrowClockwise(),
          onAction: onRetry,
          key: key,
        );

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final message = this.message;
    final actionLabel = this.actionLabel;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 40, color: palette.mutedText),
              const SizedBox(height: AppSpace.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppType.sectionHeader.copyWith(
                  fontFamily: AppType.bold,
                  color: palette.foreground,
                ),
              ),
              if (message != null) ...<Widget>[
                const SizedBox(height: AppSpace.sm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppType.body.copyWith(color: palette.mutedText),
                ),
              ],
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(height: AppSpace.xl),
                PillButton(
                  label: actionLabel,
                  icon: actionIcon,
                  onPressed: onAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A row in a list of places to go or things to set: an icon in muted
/// text, a label in the text colour with an optional line under it, and a
/// value or a caret at the end.
class ListRow extends StatelessWidget {
  const ListRow({
    required this.label,
    this.icon,
    this.leading,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.showsNext,
    this.leadingNumber,
    this.flush = false,
    super.key,
  });

  final String label;
  final IconData? icon;

  /// A picture where the icon would be, such as a flag.
  final Widget? leading;

  /// A place in an order, in a soft circle where the icon would be.
  final int? leadingNumber;

  /// For a row inside something already within the page's margins.
  final bool flush;
  final String? subtitle;

  /// The current choice, in muted text before the caret.
  final String? value;

  /// In place of the value and caret.
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Sign out, delete: the label in the theme's error colour.
  final bool destructive;

  /// A caret at the end; by default whenever the row can be pressed and has
  /// no [trailing].
  final bool? showsNext;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final icon = this.icon;
    final leading = this.leading;
    final subtitle = this.subtitle;
    final value = this.value;
    final trailing = this.trailing;
    final labelColor =
        destructive ? Theme.of(context).colorScheme.error : palette.foreground;
    final next = showsNext ?? (onTap != null && trailing == null);
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: flush ? 0 : gutter,
              vertical: 10,
            ),
            child: Row(
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(
                    icon,
                    size: 22,
                    color: destructive ? labelColor : palette.mutedText,
                  ),
                  const SizedBox(width: AppSpace.lg),
                ] else if (leading != null) ...<Widget>[
                  leading,
                  const SizedBox(width: AppSpace.lg),
                ] else if (leadingNumber case final number?) ...<Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: palette.idleFill,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$number',
                      style: AppType.cardTitle.copyWith(
                        fontSize: 15,
                        color: palette.foreground,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.lg),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        label,
                        style: AppType.cardTitle.copyWith(
                          fontSize: 15,
                          height: 1.3,
                          color: labelColor,
                        ),
                      ),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppType.metadata.copyWith(
                            fontSize: 13,
                            height: 1.35,
                            color: palette.mutedText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: AppSpace.md),
                  trailing,
                ] else if (value != null) ...<Widget>[
                  const SizedBox(width: AppSpace.md),
                  // Sized to itself, so it sits against the caret instead of
                  // taking half the row from the label.
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * .4,
                    ),
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: AppType.body.copyWith(color: palette.mutedText),
                    ),
                  ),
                ],
                if (next) ...<Widget>[
                  const SizedBox(width: AppSpace.sm),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? PhosphorIcons.caretLeft()
                        : PhosphorIcons.caretRight(),
                    size: 16,
                    color: palette.mutedText,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A bottom sheet in the app's style: the raised page colour, rounded top
/// corners and a handle.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool scrollControlled = true,
  bool useRootNavigator = true,
}) {
  final palette = AppPalette.of(context);
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: scrollControlled,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
    ),
    builder: builder,
  );
}

/// A list's shape while it loads: [rows] rows, each a leading block and two
/// lines of text.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({
    this.introLines = 0,
    this.rows = 6,
    this.leadingWidth = 44,
    this.leadingHeight = 44,
    this.circle = false,
    this.padding,
    this.scrolls = false,
    super.key,
  });

  /// Lines of a paragraph above the rows, for pages that open with one.
  final int introLines;
  final int rows;

  /// Zero for rows with no leading block.
  final double leadingWidth;
  final double leadingHeight;
  final bool circle;
  final EdgeInsetsGeometry? padding;

  /// Whether it fills a page on its own, rather than sitting in a list.
  final bool scrolls;

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpace.gutter(context);
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var i = 0; i < introLines; i++)
          Padding(
            padding: EdgeInsets.only(
              top: i == 0 ? AppSpace.xs : 0,
              bottom: i == introLines - 1 ? AppSpace.xxl : AppSpace.sm,
            ),
            child: FractionallySizedBox(
              widthFactor: i == introLines - 1 ? .6 : 1,
              child: const SkeletonBlock.line(height: 13),
            ),
          ),
        for (var i = 0; i < rows; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: <Widget>[
                if (leadingWidth > 0) ...<Widget>[
                  SkeletonBlock(
                    width: leadingWidth,
                    height: leadingHeight,
                    circle: circle,
                  ),
                  const SizedBox(width: AppSpace.lg),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      FractionallySizedBox(
                        widthFactor: i.isEven ? .62 : .48,
                        child: const SkeletonBlock.line(height: 14),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      FractionallySizedBox(
                        widthFactor: i.isEven ? .38 : .44,
                        child: const SkeletonBlock.line(height: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    final padded = Padding(
      padding: padding ?? EdgeInsets.symmetric(horizontal: gutter),
      child: column,
    );
    return SkeletonPulse(
      child: scrolls
          ? SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: padded,
            )
          : padded,
    );
  }
}
