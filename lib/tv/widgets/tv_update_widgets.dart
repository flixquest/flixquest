import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/app_update_service.dart';
import '../focus/tv_keymap.dart';

import '../app/tv_design.dart';
import '../focus/tv_focusable.dart';
import 'tv_pill_button.dart';

class TvUpdateAction extends StatelessWidget {
  const TvUpdateAction(
      {required this.label,
      required this.onPressed,
      this.autofocus = false,
      this.primary = false,
      this.focusNode,
      super.key});
  final String label;
  final VoidCallback onPressed;
  final bool autofocus;
  final bool primary;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return TvPillButton(
      label: label,
      focusNode: focusNode,
      autofocus: autofocus,
      prominent: primary,
      height: 48,
      onActivate: onPressed,
    );
  }
}

class TvUpdateChangelog extends StatelessWidget {
  const TvUpdateChangelog({
    required this.changeLog,
    required this.onPressed,
    this.focusNode,
    super.key,
  });

  final String changeLog;
  final VoidCallback onPressed;
  final FocusNode? focusNode;

  /// Entries shown on the card; the rest are a press away.
  static const _previewItems = 4;

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    final items = AppUpdateService.changelogItems(changeLog);
    final more = items.length - _previewItems;
    return TvFocusable(
      semanticLabel: 'What’s new',
      focusNode: focusNode,
      onActivate: onPressed,
      focusScale: 1,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(TvDesign.cardRadius),
          border: Border.all(color: palette.hairline.withValues(alpha: .6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: <Widget>[
                Container(
                  width: 3,
                  height: 24,
                  color: palette.mutedText,
                ),
                const SizedBox(width: 12),
                Text(
                  'What’s new',
                  style: TextStyle(
                    color: palette.foreground,
                    fontFamily: 'FigtreeBold',
                    fontSize: 21,
                    letterSpacing: -0.25,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final item in items.take(_previewItems))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 11, right: 14),
                      decoration: BoxDecoration(
                        color: palette.mutedText,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.mutedText,
                          fontSize: 19,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (more > 0) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                '+$more more · Select to read all',
                style: TextStyle(
                  color: palette.foreground,
                  fontFamily: 'FigtreeSB',
                  fontSize: 16,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class TvUpdateLayout extends StatelessWidget {
  const TvUpdateLayout(
      {required this.title,
      required this.message,
      required this.children,
      super.key});
  final String title;
  final String message;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: <Color>[
                    palette.foreground.withValues(alpha: 0.05),
                    palette.page,
                    palette.page,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(TvDesign.focusOutset),
                  child: FocusTraversalGroup(
                    policy: ReadingOrderTraversalPolicy(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'FLIXQUEST FOR TV',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontFamily: 'FigtreeBold',
                            fontSize: 13,
                            letterSpacing: 2.1,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          title,
                          style: TextStyle(
                            color: palette.foreground,
                            fontFamily: 'FigtreeBold',
                            fontSize: 38,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          message,
                          style: TextStyle(
                            color: palette.mutedText,
                            fontSize: 20,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 25),
                        ...children,
                      ],
                    ),
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

/// Release notes are a document, with remote scrolling independent of buttons.
class TvChangelogView extends StatefulWidget {
  const TvChangelogView({required this.changeLog, super.key});
  final String changeLog;

  @override
  State<TvChangelogView> createState() => _TvChangelogViewState();
}

class _TvChangelogViewState extends State<TvChangelogView> {
  final _scroll = ScrollController();
  final _notesFocus = FocusNode(debugLabel: 'Release notes');
  final _backFocus = FocusNode(debugLabel: 'Back from release notes');

  @override
  void dispose() {
    _scroll.dispose();
    _notesFocus.dispose();
    _backFocus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.arrowDown &&
        key != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }
    if (_backFocus.hasFocus) {
      if (key == LogicalKeyboardKey.arrowUp) _notesFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (!_scroll.hasClients) return KeyEventResult.handled;
    final position = _scroll.position;
    final down = key == LogicalKeyboardKey.arrowDown;
    if (down && position.extentAfter < 1) {
      _backFocus.requestFocus();
    } else {
      _scroll.animateTo(
          (position.pixels + (down ? 120 : -120))
              .clamp(0, position.maxScrollExtent),
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    return TvKeymap(
      onBack: () => Navigator.of(context).pop(),
      child: Focus(
        focusNode: _notesFocus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          backgroundColor: palette.page,
          body: SafeArea(
            minimum: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
            child: Center(
                child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.all(TvDesign.focusOutset),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RELEASE NOTES',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontFamily: 'FigtreeBold',
                          fontSize: 13,
                          letterSpacing: 2.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'What’s new',
                        style: TextStyle(
                          color: palette.foreground,
                          fontFamily: 'FigtreeBold',
                          fontSize: 36,
                          letterSpacing: -0.7,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Use ↑ ↓ to scroll',
                          style: TextStyle(
                              color: palette.mutedText, fontSize: 16)),
                      const SizedBox(height: 24),
                      Expanded(
                          child: Scrollbar(
                              controller: _scroll,
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                controller: _scroll,
                                padding: const EdgeInsets.only(
                                    right: 24, bottom: 16),
                                child: Text(widget.changeLog,
                                    style: TextStyle(
                                        color: palette.foreground,
                                        fontSize: 21,
                                        height: 1.6)),
                              ))),
                      const SizedBox(height: 16),
                      TvUpdateAction(
                          label: 'Back',
                          focusNode: _backFocus,
                          onPressed: () => Navigator.of(context).pop()),
                    ]),
              ),
            )),
          ),
        ),
      ),
    );
  }
}
