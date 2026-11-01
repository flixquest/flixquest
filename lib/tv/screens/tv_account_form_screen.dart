import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../services/flixquest_auth_service.dart';
import '../app/tv_design.dart';
import '../widgets/tv_form_field_tile.dart';
import '../widgets/tv_form_keyboard.dart';
import '../widgets/tv_pill_button.dart';

/// One field of a [TvAccountFormScreen].
class TvFormFieldSpec {
  const TvFormFieldSpec({
    required this.id,
    required this.label,
    required this.icon,
    this.initialValue = '',
    this.secret = false,
    this.hint,
    this.validate,
    this.accepts,
    this.maxLength = 128,
  });

  final String id;
  final String label;
  final IconData icon;
  final String initialValue;

  /// Typed as dots until revealed, such as a password.
  final bool secret;

  /// What the field needs, shown above the keyboard while it is filled.
  final String? hint;

  /// The field's problem given every field's [values], or null when it is
  /// fine.
  final String? Function(String value, Map<String, String> values)? validate;

  /// Whether a character may be typed here at all.
  final bool Function(String character)? accepts;
  final int maxLength;
}

/// An account form on the TV (edit profile, change email…), laid out like
/// sign-in: the fields on the left, FlixQuest's keyboard on the right.
///
/// Whichever field was last focused is the one being typed into; the
/// keyboard's wide key steps to the next field and, on the last, sends the
/// form. Field problems show once a send has been tried; what the server
/// says shows under the fields. Back leaves without saving.
class TvAccountFormScreen extends StatefulWidget {
  const TvAccountFormScreen({
    required this.title,
    required this.subtitle,
    required this.fields,
    required this.submitLabel,
    required this.submitIcon,
    required this.onSubmit,
    this.extra,
    super.key,
  });

  final String title;
  final String subtitle;
  final List<TvFormFieldSpec> fields;
  final String submitLabel;
  final IconData submitIcon;

  /// Sends the form with every field's value. An [AuthActionException]
  /// shows its message; anything else, that the server could not be reached.
  final Future<void> Function(Map<String, String> values) onSubmit;

  /// Sits under the fields, such as a profile picture picker.
  final Widget Function(BuildContext context, bool compact)? extra;

  @override
  State<TvAccountFormScreen> createState() => _TvAccountFormScreenState();
}

class _TvAccountFormScreenState extends State<TvAccountFormScreen> {
  final _keyboard = GlobalKey<TvFormKeyboardState>();
  late final Map<String, String> _values = <String, String>{
    for (final field in widget.fields) field.id: field.initialValue,
  };
  late final Map<String, FocusNode> _nodes = <String, FocusNode>{
    for (final field in widget.fields)
      field.id: FocusNode(debugLabel: 'TV account ${field.id}'),
  };

  /// The field the keyboard fills, by id: the specs are rebuilt whenever
  /// the screen around this one rebuilds.
  late String _activeId = widget.fields.first.id;
  bool _reveal = false;
  bool _attempted = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _keyboard.currentState?.requestFocus();
    });
  }

  @override
  void dispose() {
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  TvFormFieldSpec get _active => widget.fields.firstWhere(
        (field) => field.id == _activeId,
        orElse: () => widget.fields.first,
      );

  String? _validate(TvFormFieldSpec field) =>
      field.validate?.call(_values[field.id]!, _values);

  void _type(String text) {
    if (_submitting) return;
    final accepts = _active.accepts;
    final typed = text
        .split('')
        .where((character) => accepts == null || accepts(character));
    final value = _values[_active.id]! + typed.join();
    if (typed.isEmpty || value.length > _active.maxLength) return;
    setState(() => _values[_active.id] = value);
  }

  void _delete() {
    if (_submitting) return;
    setState(() => _values[_active.id] =
        _values[_active.id]!.characters.skipLast(1).toString());
  }

  void _clear() {
    if (_submitting) return;
    setState(() => _values[_active.id] = '');
  }

  void _activate(TvFormFieldSpec field) {
    if (field.id != _activeId) setState(() => _activeId = field.id);
  }

  /// The keyboard's wide key: the next field, or send on the last.
  void _next() {
    final index = widget.fields.indexWhere((field) => field.id == _activeId);
    if (index == widget.fields.length - 1) {
      _submit();
    } else {
      _activate(widget.fields[index + 1]);
    }
  }

  bool _focusKeyboard() => _keyboard.currentState?.requestFocus() ?? false;

  bool _focusActiveField() {
    _nodes[_active.id]!.requestFocus();
    return true;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final invalid = widget.fields.where((field) => _validate(field) != null);
    if (invalid.isNotEmpty) {
      setState(() {
        _attempted = true;
        _activeId = invalid.first.id;
      });
      return;
    }
    setState(() {
      _attempted = true;
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSubmit(Map<String, String>.unmodifiable(_values));
    } on AuthActionException catch (error) {
      if (mounted) setState(() => _error = tvAccountErrorMessage(error));
    } catch (_) {
      if (mounted) {
        setState(() => _error = tr('tv_unable_to_connect_please_try_again'));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final palette = TvPalette.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: TvDesign.surfaceFor(context),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.9, -1),
            radius: 1.4,
            colors: <Color>[
              accent.withValues(alpha: palette.dark ? 0.16 : 0.08),
              palette.page.withValues(alpha: 0),
            ],
          ),
        ),
        child: SafeArea(
          minimum: const EdgeInsets.symmetric(horizontal: 48, vertical: 28),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 650;
              final keyboardWidth = <double>[
                constraints.maxWidth * 0.5,
                TvFormKeyboard.widthFor(
                  constraints.maxHeight - (compact ? 64 : 84),
                ),
                620,
              ].reduce((a, b) => a < b ? a : b);
              return Row(
                children: <Widget>[
                  Expanded(child: _form(context, compact)),
                  SizedBox(width: compact ? 32 : 48),
                  _keyboardPanel(context, keyboardWidth, compact),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _form(BuildContext context, bool compact) {
    final palette = TvPalette.of(context);
    final colors = Theme.of(context).colorScheme;
    final gap = compact ? 10.0 : 14.0;
    final extra = widget.extra;
    return FocusTraversalGroup(
      child: SingleChildScrollView(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.all(TvDesign.focusOutset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.title,
              style: TextStyle(
                color: palette.foreground,
                fontFamily: 'FigtreeBold',
                fontSize: compact ? 28 : 36,
                letterSpacing: -0.45,
                height: 1.1,
              ),
            ),
            SizedBox(height: compact ? 6 : 10),
            Text(
              widget.subtitle,
              style: TextStyle(
                color: palette.mutedText,
                fontSize: compact ? 15 : 18,
                height: 1.3,
              ),
            ),
            SizedBox(height: compact ? 16 : 24),
            for (final field in widget.fields) ...<Widget>[
              TvFormFieldTile(
                focusNode: _nodes[field.id]!,
                label: field.label,
                icon: field.icon,
                value: _values[field.id]!,
                obscured: field.secret && !_reveal,
                active: field.id == _activeId,
                compact: compact,
                error: _attempted ? _validate(field) : null,
                onFocused: () => _activate(field),
                onActivate: _focusKeyboard,
                trailing: field.secret
                    ? TvRevealPasswordButton(
                        revealed: _reveal,
                        onActivate: () => setState(() => _reveal = !_reveal),
                        onExitTowardKeyboard: _focusKeyboard,
                      )
                    : null,
              ),
              SizedBox(height: gap),
            ],
            if (extra != null) ...<Widget>[
              extra(context, compact),
              SizedBox(height: gap),
            ],
            if (_error case final error?) ...<Widget>[
              Text(
                error,
                style: TextStyle(
                  color: colors.error,
                  fontFamily: 'FigtreeSB',
                  fontSize: compact ? 15 : 17,
                ),
              ),
              SizedBox(height: gap),
            ],
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                TvPillButton(
                  label:
                      _submitting ? tr('tv_please_wait') : widget.submitLabel,
                  semanticLabel: widget.submitLabel,
                  icon: widget.submitIcon,
                  enabled: !_submitting,
                  prominent: true,
                  height: compact ? 46 : 52,
                  onActivate: _submit,
                ),
                TvPillButton(
                  label: tr('cancel'),
                  icon: PhosphorIcons.x(),
                  enabled: !_submitting,
                  height: compact ? 46 : 52,
                  onActivate: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _keyboardPanel(BuildContext context, double width, bool compact) {
    final palette = TvPalette.of(context);
    final last = _activeId == widget.fields.last.id;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return SizedBox(
      width: width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(_active.icon, color: palette.foreground, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _active.label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.foreground,
                    fontFamily: 'FigtreeBold',
                    fontSize: compact ? 14 : 16,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _active.hint ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: compact ? 14 : 16,
            ),
          ),
          SizedBox(height: compact ? 10 : 16),
          TvFormKeyboard(
            key: _keyboard,
            width: width,
            onType: _type,
            onDelete: _delete,
            onClear: _clear,
            onAction: _next,
            actionLabel: last
                ? (_submitting ? tr('tv_please_wait') : widget.submitLabel)
                : tr('tv_keyboard_next'),
            actionIcon: last ? widget.submitIcon : PhosphorIcons.arrowRight(),
            // The fields sit on the keyboard's left, or its right in RTL.
            onExitLeft: rtl ? null : _focusActiveField,
            onExitRight: rtl ? _focusActiveField : null,
          ),
        ],
      ),
    );
  }
}

/// What an account change's failure means to the viewer: the TV's words
/// for the common cases, else what the server said, which is how a wrong
/// current password comes back.
String tvAccountErrorMessage(AuthActionException error) => switch (error.code) {
      'email-already-in-use' => tr('tv_that_email_is_already_registered'),
      'username-already-in-use' => tr('tv_that_username_is_already_in_use'),
      'network-request-failed' =>
        tr('tv_check_your_internet_connection_and_retry'),
      _ => error.message,
    };
