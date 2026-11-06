import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// A sealed request body, plus the nonce needed to open its response.
class SealedScraperRequest {
  const SealedScraperRequest({required this.envelope, required this.nonce});

  final Map<String, String> envelope;
  final String nonce;
}

/// AES-256-GCM envelope for the scraper's `/api/v3` routes.
///
/// This must stay on the pure-Dart implementation. `cryptography_flutter`
/// would route the key through Android's Java crypto, where one hook reads it.
class ScraperCipher {
  ScraperCipher({required this.kid, required List<int> rootKey})
      : _rootKey = SecretKey(rootKey);

  static const _tagBytes = 16;
  static final _random = Random.secure();

  final String kid;
  final SecretKey _rootKey;
  final _aes = AesGcm.with256bits();
  final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  late final Future<SecretKey> _requestKey = _derive('fq-v3-request');
  late final Future<SecretKey> _responseKey = _derive('fq-v3-response');

  Future<SecretKey> _derive(String purpose) => _hkdf.deriveKey(
        secretKey: _rootKey,
        info: utf8.encode(purpose),
      );

  Future<SealedScraperRequest> seal(
    String path,
    Map<String, Object?> params, {
    required int timestampSeconds,
  }) async {
    final nonce = base64Encode(
      List<int>.generate(16, (_) => _random.nextInt(256)),
    );
    final box = await _aes.encrypt(
      utf8.encode(jsonEncode(<String, Object?>{
        'ts': timestampSeconds,
        'nonce': nonce,
        'params': params,
      })),
      secretKey: await _requestKey,
      aad: utf8.encode('POST $path $kid'),
    );
    return SealedScraperRequest(
      nonce: nonce,
      envelope: <String, String>{
        'kid': kid,
        'iv': base64Encode(box.nonce),
        'ct': base64Encode(<int>[...box.cipherText, ...box.mac.bytes]),
      },
    );
  }

  /// Decrypts a response to its JSON text.
  ///
  /// Throws [SecretBoxAuthenticationError] when it was altered, or was not the
  /// answer to the request that used [nonce].
  Future<String> open(
    String path,
    String nonce,
    Map<String, dynamic> envelope,
  ) async {
    final sealed = base64Decode(envelope['ct'] as String);
    if (sealed.length < _tagBytes) {
      throw const FormatException('Sealed response is too short');
    }
    final tagStart = sealed.length - _tagBytes;
    final gzipped = await _aes.decrypt(
      SecretBox(
        Uint8List.sublistView(sealed, 0, tagStart),
        nonce: base64Decode(envelope['iv'] as String),
        mac: Mac(Uint8List.sublistView(sealed, tagStart)),
      ),
      secretKey: await _responseKey,
      aad: utf8.encode('$path $nonce'),
    );
    return utf8.decode(gzip.decode(gzipped));
  }
}
