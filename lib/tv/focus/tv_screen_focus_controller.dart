import 'package:flutter/widgets.dart';

/// Lets the shell move focus into a destination's screen.
///
/// The screen's callback must move focus synchronously and report whether it
/// did. A post-frame callback is not enough: `addPostFrameCallback` does not
/// schedule a frame, and on an idle TV screen the next one only comes with the
/// next key press.
class TvScreenFocusController {
  Object? _owner;
  bool Function()? _requestFocus;
  bool _pendingRequest = false;
  FocusNode? _pendingOrigin;

  void attach(Object owner, bool Function() requestFocus) {
    _owner = owner;
    _requestFocus = requestFocus;
    if (_pendingRequest) {
      _pendingRequest = false;
      final origin = _pendingOrigin;
      _pendingOrigin = null;
      // Owners attach while mounting, before their focus targets are laid
      // out; mounting is itself a frame, so this callback is sure to run.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!identical(_owner, owner)) return;
        final focused = FocusManager.instance.primaryFocus;
        // The user moved on while the screen loaded; a scope means nothing
        // concrete holds focus, so there is nothing to take it away from.
        if (focused != origin && focused is! FocusScopeNode) return;
        requestFocus();
      });
    }
  }

  void detach(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _requestFocus = null;
  }

  bool get isAttached => _requestFocus != null;

  /// Returns whether focus moved into the screen. A screen that is not built
  /// yet (still loading) takes the request once it attaches, unless focus has
  /// moved on in the meantime.
  bool requestFocus() {
    final requestFocus = _requestFocus;
    if (requestFocus == null) {
      _pendingRequest = true;
      _pendingOrigin = FocusManager.instance.primaryFocus;
      return false;
    }
    return requestFocus();
  }
}
