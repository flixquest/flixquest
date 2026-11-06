import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Canonical form of a signing certificate's SHA-256, as keytool or
/// `PackageInfo.buildSignature` report it: 64 upper-case hex characters.
String normalizeCertificateHash(String value) {
  final hex = value.replaceAll(':', '').trim().toUpperCase();
  if (!RegExp(r'^[0-9A-F]{64}$').hasMatch(hex)) {
    throw const FormatException('Expected a SHA-256 certificate hash');
  }
  return hex;
}

/// What the native library signs. It is the only value that crosses into it,
/// so its secret never has to come back into Dart.
List<int> nativeMixInput({
  required String packageName,
  required String certificateHash,
}) =>
    utf8.encode('fq-v3-mix|$packageName|$certificateHash');

/// Derives the root key the scraper holds in `SCRAPER_V3_KEYS`.
///
/// The app and `tool/scraper_key.dart` share this, so the key the server is
/// given always matches the key the build computes. Its inputs live in three
/// places: the Dart fragment, the native library, and the APK's signature. A
/// copy re-signed with another certificate derives a different key.
Future<Uint8List> deriveScraperRootKey({
  required List<int> fragment,
  required List<int> nativeMix,
  required String certificateHash,
  required String packageName,
  required String kid,
}) async {
  final derived = await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
    secretKey: SecretKey(<int>[...fragment, ...nativeMix]),
    nonce: _hexBytes(certificateHash),
    info: utf8.encode('fq-v3-root|$packageName|$kid'),
  );
  return Uint8List.fromList(await derived.extractBytes());
}

List<int> _hexBytes(String hex) => <int>[
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ];
