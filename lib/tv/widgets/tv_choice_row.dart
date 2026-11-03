import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../app/tv_design.dart';
import '../focus/tv_focusable.dart';

/// What sits at the end of a [TvChoiceRow].
enum TvChoiceMark {
  /// Nothing.
  none,

  /// A caret, for a row that opens more choices.
  caret,

  /// A box that fills with a check: one of several that can all be on.
  check,

  /// A dot: the one choice of several.
  radio,
}

/// A row in a list of choices: a picture, a label with an optional line
/// under it, and a mark for whether it is chosen. It turns white under
/// focus, the way the rail's destinations and Settings' rows do.
class TvChoiceRow extends StatefulWidget {
  const TvChoiceRow({
    required this.label,
    required this.onActivate,
    this.detail,
    this.leading,
    this.mark = TvChoiceMark.none,
    this.selected = false,
    this.focusNode,
    this.compact = false,
    super.key,
  });

  final String label;

  /// A line under the label in muted type, such as the current choice.
  final String? detail;

  /// An icon, flag or logo before the label, about 24 wide.
  final Widget? leading;
  final TvChoiceMark mark;
  final bool selected;
  final VoidCallback onActivate;
  final FocusNode? focusNode;
  final bool compact;

  /// How tall a row is in a list, with room for a [detail] line.
  static double heightFor({required bool compact}) => compact ? 56 : 62;

  @override
  State<TvChoiceRow> createState() => _TvChoiceRowState();
}

class _TvChoiceRowState extends State<TvChoiceRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    final foreground = _focused ? palette.onFocus : palette.foreground;
    final secondary = _focused ? palette.onFocusMuted : palette.mutedText;
    final detail = widget.detail;
    final leading = widget.leading;
    final checked = widget.selected &&
        (widget.mark == TvChoiceMark.check ||
            widget.mark == TvChoiceMark.radio);
    return TvFocusable(
      focusNode: widget.focusNode,
      semanticLabel: detail == null ? widget.label : '${widget.label}, $detail',
      selected: checked,
      onActivate: widget.onActivate,
      onFocusChanged: (hasFocus) {
        if (hasFocus != _focused) setState(() => _focused = hasFocus);
      },
      focusScale: 1,
      focusColor: Colors.transparent,
      borderRadius: BorderRadius.circular(TvDesign.cardRadius),
      // The list keeps the focused row in view itself.
      scrollAlignment: null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _focused ? palette.focusFill : Colors.transparent,
          borderRadius: BorderRadius.circular(TvDesign.cardRadius),
        ),
        child: Row(
          children: <Widget>[
            if (leading != null) ...<Widget>[
              IconTheme.merge(
                data: IconThemeData(color: secondary, size: 22),
                child: SizedBox(width: 28, child: Center(child: leading)),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontFamily: checked ? 'FigtreeBold' : 'FigtreeSB',
                      fontSize: widget.compact ? 16 : 18,
                      height: 1.15,
                    ),
                  ),
                  if (detail != null) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: secondary,
                        fontFamily: 'Figtree',
                        fontSize: widget.compact ? 13 : 14,
                        height: 1.15,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.mark != TvChoiceMark.none) ...<Widget>[
              const SizedBox(width: 10),
              _Mark(
                mark: widget.mark,
                selected: widget.selected,
                color: foreground,
                faint: secondary,
                // The mark's own ink: the page behind it, or the focus fill
                // behind a white row.
                ink: _focused ? palette.focusFill : palette.page,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({
    required this.mark,
    required this.selected,
    required this.color,
    required this.faint,
    required this.ink,
  });

  final TvChoiceMark mark;
  final bool selected;
  final Color color;
  final Color faint;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    switch (mark) {
      case TvChoiceMark.none:
        return const SizedBox.shrink();
      case TvChoiceMark.caret:
        return Icon(PhosphorIcons.caretRight(), color: faint, size: 18);
      case TvChoiceMark.check:
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: selected ? color : faint, width: 1.5),
          ),
          child: selected
              ? Icon(
                  PhosphorIcons.check(PhosphorIconsStyle.bold),
                  color: ink,
                  size: 14,
                )
              : null,
        );
      case TvChoiceMark.radio:
        return Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: selected ? color : faint, width: 1.5),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: selected ? 10 : 0,
            height: selected ? 10 : 0,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        );
    }
  }
}
