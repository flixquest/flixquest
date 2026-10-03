import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// The app-wide authentication identity used by the root presentation gate.
///
/// Firebase's native auth callback can arrive after a successful sign-in
/// future completes. Authentication actions update this controller directly,
/// while [userChanges] keeps it correct for startup, sign-out, and token/user
/// changes.
class AuthSessionController {
  AuthSessionController._();

  static final AuthSessionController instance = AuthSessionController._();

  final ValueNotifier<String?> userId = ValueNotifier<String?>(null);
  StreamSubscription<User?>? _authSubscription;

  void initialize([FirebaseAuth? firebaseAuth]) {
    if (_authSubscription != null) return;

    final auth = firebaseAuth ?? FirebaseAuth.instance;
    setAuthenticatedUserId(auth.currentUser?.uid);
    _authSubscription = auth.userChanges().listen(
      (_) => setAuthenticatedUserId(auth.currentUser?.uid),
      onError: (_) => setAuthenticatedUserId(auth.currentUser?.uid),
    );
  }

  void setAuthenticatedUserId(String? value) {
    userId.value = value;
  }
}
