import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import 'page_kit.dart';
import 'pill_button.dart';

/// The parts the settings pages share, so every row of every settings page
/// lines up: icons in one column, labels in the next, controls at the end.

/// A titled block of rows on the raised surface, with hairlines between.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 10),
          child: Text(
            title.toUpperCase(),
            style: AppType.kicker.copyWith(color: palette.mutedText),
          ),
        ),
        Material(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: <Widget>[
              for (var i = 0; i < children.length; i++) ...<Widget>[
                children[i],
                if (i != children.length - 1)
                  Divider(height: 1, thickness: 1, color: palette.hairline),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The app's switch. The accent marks "on" (section 3.2 of the redesign
/// guide allows it on this one small control); "off" is plain ink.
class AppSwitch extends StatelessWidget {
  const AppSwitch({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    return Switch(
      value: value,
      onChanged: onChanged,
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : palette.mutedText,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? accent : palette.idleFill,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    );
  }
}

/// A row that turns something on or off; the whole row toggles.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.icon,
    this.subtitle,
    super.key,
  });

  final String label;
  final IconData? icon;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return MergeSemantics(
      child: Semantics(
        toggled: value,
        child: ListRow(
          icon: icon,
          label: label,
          subtitle: subtitle,
          showsNext: false,
          onTap: onChanged == null ? null : () => onChanged(!value),
          trailing: ExcludeSemantics(
            child: AppSwitch(value: value, onChanged: onChanged),
          ),
        ),
      ),
    );
  }
}

/// A row showing the current choice, which opens a sheet of the others.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.icon,
    this.subtitle,
    super.key,
  });

  final String label;
  final IconData? icon;
  final String? subtitle;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      icon: icon,
      label: label,
      subtitle: subtitle,
      value: options[value] ?? '',
      onTap: () => _choose(context),
    );
  }

  Future<void> _choose(BuildContext context) async {
    final selected = await showAppSheet<T>(
      context,
      builder: (sheetContext) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .75,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(sheetContext).bottom + AppSpace.lg,
            ),
            children: <Widget>[
              SheetTitle(label),
              for (final option in options.entries)
                SelectableRow(
                  label: option.value,
                  selected: option.key == value,
                  onTap: () => Navigator.pop(sheetContext, option.key),
                ),
            ],
          ),
        );
      },
    );
    if (selected != null) onChanged(selected);
  }
}

/// The heading at the top of a settings sheet.
class SheetTitle extends StatelessWidget {
  const SheetTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpace.gutter(context);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(gutter, 0, gutter, AppSpace.md),
      child: Text(
        title,
        style: AppType.sectionHeader.copyWith(
          fontFamily: AppType.bold,
          color: AppPalette.of(context).foreground,
        ),
      ),
    );
  }
}

/// A chosen colour, as a small ringed dot at the end of a row. It shows the
/// real colour on purpose.
class ColorDot extends StatelessWidget {
  const ColorDot(this.color, {super.key});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: palette.idleFillStrong, width: 1.5),
      ),
    );
  }
}

/// Opens a colour picker in a sheet; returns the saved colour, or null.
Future<Color?> showColorPickerSheet(
  BuildContext context, {
  required Color initialColor,
  required String title,
  bool enableAlpha = false,
}) =>
    showAppSheet<Color>(
      context,
      builder: (_) => _ColorPickerSheet(
        initialColor: initialColor,
        title: title,
        enableAlpha: enableAlpha,
      ),
    );

class _ColorPickerSheet extends StatefulWidget {
  const _ColorPickerSheet({
    required this.initialColor,
    required this.title,
    required this.enableAlpha,
  });

  final Color initialColor;
  final String title;
  final bool enableAlpha;

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late Color _color = widget.initialColor;

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpace.gutter(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SheetTitle(widget.title),
            Center(
              child: ColorPicker(
                pickerColor: _color,
                onColorChanged: (color) => setState(() => _color = color),
                enableAlpha: widget.enableAlpha,
                hexInputBar: true,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, AppSpace.xxl),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: PillButton(
                      label: tr('cancel'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: PillButton(
                      label: tr('save'),
                      primary: true,
                      onPressed: () => Navigator.pop(context, _color),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A language's flag, at the size of a row icon.
class LanguageFlag extends StatelessWidget {
  const LanguageFlag(this.asset, {super.key});

  final String asset;

  @override
  Widget build(BuildContext context) => ClipOval(
        child: Image.asset(asset, width: 24, height: 24, fit: BoxFit.cover),
      );
}

/// One of a list of options, with a check at the end on the chosen one.
class SelectableRow extends StatelessWidget {
  const SelectableRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.leading,
    super.key,
  });

  final String label;
  final String? subtitle;
  final Widget? leading;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Semantics(
      selected: selected,
      child: ListRow(
        label: label,
        subtitle: subtitle,
        leading: leading,
        showsNext: false,
        onTap: onTap,
        trailing: selected
            ? Icon(
                PhosphorIcons.check(PhosphorIconsStyle.bold),
                size: 20,
                color: palette.foreground,
              )
            : null,
      ),
    );
  }
}
