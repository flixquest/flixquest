import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_session_controller.dart';

class _UsernameUnavailableException implements Exception {
  const _UsernameUnavailableException();
}

class FlixQuestAuthService {
  FlixQuestAuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? _defaultGoogleSignIn;

  static final GoogleSignIn _defaultGoogleSignIn = GoogleSignIn();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.toLowerCase().trim(),
      password: password.trim(),
    );
    AuthSessionController.instance.setAuthenticatedUserId(credential.user?.uid);
    return credential;
  }

  Future<UserCredential> signInAnonymously() async {
    final credential = await _auth.signInAnonymously();
    AuthSessionController.instance.setAuthenticatedUserId(credential.user?.uid);
    return credential;
  }

  Future<UserCredential?> signInWithGoogle() async {
    final googleAccount = await _googleSignIn.signIn();
    if (googleAccount == null) return null;

    final googleAuth = await googleAccount.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    await _ensureGoogleUserRecord(userCredential.user, googleAccount);
    AuthSessionController.instance
        .setAuthenticatedUserId(userCredential.user?.uid);
    return userCredential;
  }

  Future<void> _ensureGoogleUserRecord(
    User? user,
    GoogleSignInAccount googleAccount,
  ) async {
    if (user == null) return;
    final uid = user.uid;
    final userReference = _firestore.collection('users').doc(uid);
    if ((await userReference.get()).exists) return;

    final email = (user.email ?? googleAccount.email).toLowerCase().trim();
    final displayName = (user.displayName ?? googleAccount.displayName)
            ?.trim() ??
        email.split('@').first;
    final username = await _reserveAvailableUsername(email, uid);
    final batch = _firestore.batch();
    batch.set(userReference, <String, Object>{
      'id': uid,
      'name': displayName,
      'email': email,
      'profileId': 0,
      'username': username,
      'verified': true,
      'photoUrl': googleAccount.photoUrl ?? '',
      'provider': 'google',
      'joinedAt': DateTime.now().toString(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      _firestore.collection('bookmarks-v2.0').doc(uid),
      <String, Object>{
        'movies': <Object>[],
        'tvShows': <Object>[],
      },
    );
    await batch.commit();
  }

  Future<String> _reserveAvailableUsername(String email, String uid) async {
    var base = email.split('@').first.toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9_]'),
          '',
        );
    if (base.isEmpty) base = 'user';
    if (!RegExp(r'^[a-z]').hasMatch(base)) base = 'user_$base';
    if (base.length > 30) base = base.substring(0, 30);
    if (base.length < 5) base = base.padRight(5, '0');

    var suffix = 0;
    while (suffix < 500) {
      final username = suffix == 0
          ? base
          : _usernameWithSuffix(base, suffix);
      if (await _tryReserveUsername(username, uid)) {
        return username;
      }
      suffix++;
    }
    return _usernameWithSuffix(base, suffix);
  }

  String _usernameWithSuffix(String base, int suffix) {
    final candidate = '$base$suffix';
    if (candidate.length <= 30) return candidate;
    final keep = 30 - suffix.toString().length;
    return '${base.substring(0, keep)}$suffix';
  }

  Future<bool> _tryReserveUsername(String username, String uid) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final reference = _firestore.collection('usernames').doc(username);
        if ((await transaction.get(reference)).exists) {
          throw const _UsernameUnavailableException();
        }
        transaction.set(reference, <String, Object>{
          'uname': username,
          'uid': uid,
        });
      });
      return true;
    } on _UsernameUnavailableException {
      return false;
    }
  }

  static Future<void> signOutGoogle() async {
    try {
      await _defaultGoogleSignIn.signOut();
    } catch (_) {
      return;
    }
  }

  Future<UserCredential> createAccount({
    required String fullName,
    required String email,
    required String username,
    required String password,
    required int profileId,
    bool verified = false,
  }) async {
    final normalizedUsername = username.toLowerCase().trim();
    final usernameReference =
        _firestore.collection('usernames').doc(normalizedUsername);
    if ((await usernameReference.get()).exists) {
      throw FirebaseAuthException(
        code: 'username-already-in-use',
        message: 'That username is already in use.',
      );
    }

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.toLowerCase().trim(),
      password: password.trim(),
    );
    final user = credential.user!;
    final batch = _firestore.batch();
    batch.set(_firestore.collection('users').doc(user.uid), <String, Object>{
      'id': user.uid,
      'name': fullName.trim(),
      'email': email.toLowerCase().trim(),
      'profileId': profileId,
      'username': normalizedUsername,
      'verified': verified,
      'joinedAt': DateTime.now().toString(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(usernameReference, <String, Object>{
      'uname': normalizedUsername,
      'uid': user.uid,
    });
    batch.set(
      _firestore.collection('bookmarks-v2.0').doc(user.uid),
      <String, Object>{
        'movies': <Object>[],
        'tvShows': <Object>[],
      },
    );
    await batch.commit();
    AuthSessionController.instance.setAuthenticatedUserId(user.uid);
    return credential;
  }
}
