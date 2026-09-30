import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';

/// One of Home's chips: a filter that stays selected, or an action such as
/// Live TV or Categories that opens something.
class FilterChipSpec {
  const FilterChipSpec({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.dropdown = false,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  /// Opens a list (Categories ▾).
  final bool dropdown;
  final IconData? icon;
}

/// Home's filter row: pills that fill with ink when selected, the way the
/// TV lights its focused chip.
class FilterChips extends StatelessWidget {
  const FilterChips({required this.chips, super.key});

  final List<FilterChipSpec> chips;

  /// The row's height: the pill's own 34 dp inside a 48 dp target.
  static const height = 48.0;
  static const pillHeight = 34.0;

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpace.gutter(context);
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: gutter),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpace.sm),
        itemBuilder: (context, index) => ChoicePill(spec: chips[index]),
      ),
    );
  }
}

/// One pill: a filter that stays selected, or an action. Laid out by
/// [FilterChips] in a row, or on its own in a wrap of choices.
class ChoicePill extends StatelessWidget {
  const ChoicePill({required this.spec, super.key});

  final FilterChipSpec spec;

  void _tap() {
    HapticFeedback.selectionClick();
    spec.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final selected = spec.selected;
    final foreground = selected ? palette.onFocus : palette.foreground;
    final icon = spec.icon;
    return Semantics(
      button: true,
      selected: selected,
      label: spec.label,
      onTap: _tap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: SizedBox(
          height: FilterChips.height,
          child: Center(
            widthFactor: 1,
            child: SizedBox(
              height: FilterChips.pillHeight,
              child: Material(
                color: selected ? palette.focusFill : palette.idleFill,
                borderRadius: BorderRadius.circular(AppRadii.chip),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _tap,
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      icon == null ? 14 : 11,
                      0,
                      spec.dropdown ? 10 : 14,
                      0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (icon != null) ...<Widget>[
                          Icon(icon, size: 16, color: foreground),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          spec.label,
                          style: TextStyle(
                            fontFamily: AppType.semiBold,
                            fontSize: 14,
                            height: 1.1,
                            color: foreground,
                          ),
                        ),
                        if (spec.dropdown) ...<Widget>[
                          const SizedBox(width: 4),
                          Icon(PhosphorIcons.caretDown(),
                              size: 14, color: foreground),
                        ],
                      ],
                    ),
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
