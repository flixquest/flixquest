import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flixquest/core/config/scraper_secrets.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'scraper_cipher.dart';
import 'scraper_key_derivation.dart';

/// Rebuilds the scraper key from the Dart fragment, the native library and the
/// certificate this APK was actually signed with.
Future<ScraperCipher> loadScraperCipher() async {
  final info = await PackageInfo.fromPlatform();
  final certificateHash = normalizeCertificateHash(info.buildSignature);
  final kid = kReleaseMode ? ScraperSecrets.prodKid : ScraperSecrets.devKid;
  final fragment =
      kReleaseMode ? ScraperSecrets.prodFragment : ScraperSecrets.devFragment;

  final rootKey = await deriveScraperRootKey(
    fragment: base64Decode(fragment),
    nativeMix: _nativeMix(
      nativeMixInput(
        packageName: info.packageName,
        certificateHash: certificateHash,
      ),
    ),
    certificateHash: certificateHash,
    packageName: info.packageName,
    kid: kid,
  );
  return ScraperCipher(kid: kid, rootKey: rootKey);
}

final _reportedFallbacks = <String>{};

/// A broken key can leave devices silently unencrypted while the server is in
/// open mode, so this is reported once per reason per session. It carries only
/// the reason, never the request.
void reportPlainFallback(String reason) {
  if (!_reportedFallbacks.add(reason)) return;
  try {
    FirebaseCrashlytics.instance
        .recordError(
          StateError('Scraper v3 fell back to plain: $reason'),
          StackTrace.current,
          fatal: false,
        )
        .catchError((Object _) {});
  } catch (_) {
    // Firebase may not be up, and reporting must never break a stream lookup.
  }
}

typedef _MixNative = Int32 Function(Pointer<Uint8>, IntPtr, Pointer<Uint8>);
typedef _MixDart = int Function(Pointer<Uint8>, int, Pointer<Uint8>);

/// Called through FFI rather than a platform channel, whose messages can be
/// read from the Java side.
Uint8List _nativeMix(List<int> input) {
  const outputLength = 32;
  final mix = DynamicLibrary.open('libfqcore.so')
      .lookupFunction<_MixNative, _MixDart>('fqc_h');
  final inputPointer = malloc<Uint8>(input.length);
  final outputPointer = malloc<Uint8>(outputLength);
  try {
    inputPointer.asTypedList(input.length).setAll(0, input);
    if (mix(inputPointer, input.length, outputPointer) != 0) {
      throw StateError('Native key mix failed');
    }
    return Uint8List.fromList(outputPointer.asTypedList(outputLength));
  } finally {
    malloc.free(inputPointer);
    malloc.free(outputPointer);
  }
}
