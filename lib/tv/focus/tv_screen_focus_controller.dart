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

  void attach(Object owner, bool Function() requestFocus) {
    _owner = owner;
    _requestFocus = requestFocus;
    if (_pendingRequest) {
      _pendingRequest = false;
      // Owners attach while mounting, before their focus targets are laid
      // out; mounting is itself a frame, so this callback is sure to run.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (identical(_owner, owner)) requestFocus();
      });
    }
  }

  void detach(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _requestFocus = null;
  }

  bool get isAttached => _requestFocus != null;

  /// Returns whether focus moved into the screen.
  bool requestFocus() {
    final requestFocus = _requestFocus;
    if (requestFocus == null) {
      _pendingRequest = true;
      return false;
    }
    return requestFocus();
  }
}
