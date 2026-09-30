import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Makes one press of the remote's Back button one Back.
///
/// On Android TV a press reaches Flutter twice: as a goBack key event, which
/// TV screens act on (dialogs close, the player exits, the shell returns focus
/// to the rail), and as a system Back that pops through the navigator into
/// the shell's PopScope. Handling both is what left the player on the rail
/// and sent a single press from content all the way to the exit prompt.
///
/// The key is the richer signal, so it wins: a system Back is dropped when a
/// Back key the app handled belongs to the same press. The two arrive in
/// either order, so a system Back with no key yet waits briefly for one. A
/// press the app ignores, or a system Back with no key at all, still goes
/// back as before.
///
/// Must wrap the [WidgetsApp]: route pops go to binding observers in the
/// order they registered, and this one has to be asked before the
/// navigator's.
class TvBackKeyGuard extends StatefulWidget {
  const TvBackKeyGuard({required this.child, super.key});

  final Widget child;

  @override
  State<TvBackKeyGuard> createState() => _TvBackKeyGuardState();
}

class _TvBackKeyGuardState extends State<TvBackKeyGuard>
    with WidgetsBindingObserver {
  /// How long a system Back waits for the key event of the same press.
  static const _keyWait = Duration(milliseconds: 200);

  /// How long after the key-up a late system Back still counts as part of
  /// the same press.
  static const _pressTail = Duration(milliseconds: 400);

  static final _backKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.escape,
    LogicalKeyboardKey.goBack,
    LogicalKeyboardKey.browserBack,
  };

  bool _keyDown = false;
  bool _keyReachedRoot = false;
  bool? _recentPressHandled;
  Timer? _recentPressTimer;
  Timer? _heldSystemBack;
  bool _replaying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_trackBackKey);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_trackBackKey);
    _recentPressTimer?.cancel();
    _heldSystemBack?.cancel();
    super.dispose();
  }

  bool get _pressHandledByApp => !_keyReachedRoot;

  // Runs for every key before the focus tree sees it; never consumes.
  bool _trackBackKey(KeyEvent event) {
    if (!_backKeys.contains(event.logicalKey)) return false;
    if (event is KeyDownEvent) {
      _keyDown = true;
      _keyReachedRoot = false;
      if (_heldSystemBack != null) {
        // Settle the held system Back once the focus tree has had its say.
        scheduleMicrotask(_settleHeldSystemBack);
      }
    } else if (event is KeyUpEvent) {
      _keyDown = false;
      _recentPressHandled = _pressHandledByApp;
      _recentPressTimer?.cancel();
      _recentPressTimer = Timer(_pressTail, () => _recentPressHandled = null);
    }
    return false;
  }

  // Sees only the keys nothing below it handled.
  KeyEventResult _handleUnhandledKey(FocusNode node, KeyEvent event) {
    if (!_backKeys.contains(event.logicalKey)) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      _keyReachedRoot = true;
      return KeyEventResult.ignored;
    }
    // Keep the key-up of a handled press from the platform, which would
    // otherwise turn it into a system Back of its own.
    if (event is KeyUpEvent && _pressHandledByApp) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Future<bool> didPopRoute() async {
    if (_replaying) return false;
    if (_keyDown) return _pressHandledByApp;
    final recentPressHandled = _recentPressHandled;
    if (recentPressHandled != null) return recentPressHandled;
    _heldSystemBack?.cancel();
    _heldSystemBack = Timer(_keyWait, _releaseHeldSystemBack);
    return true;
  }

  void _settleHeldSystemBack() {
    if (_heldSystemBack == null) return;
    if (_pressHandledByApp) {
      _heldSystemBack?.cancel();
      _heldSystemBack = null;
    } else {
      _releaseHeldSystemBack();
    }
  }

  Future<void> _releaseHeldSystemBack() async {
    _heldSystemBack?.cancel();
    _heldSystemBack = null;
    if (!mounted) return;
    _replaying = true;
    try {
      // Replays the held Back through every observer exactly as the platform
      // message would have, including the fallback that exits the app.
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      await WidgetsBinding.instance.handlePopRoute();
    } finally {
      _replaying = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _handleUnhandledKey,
      child: widget.child,
    );
  }
}
