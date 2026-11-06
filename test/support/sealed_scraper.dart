import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flixquest/core/network/scraper_v3/scraper_cipher.dart';
import 'package:flixquest/core/network/scraper_v3/scraper_v3_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'callback_dio.dart';

const testScraperKid = 'test-kid';
final List<int> testScraperRootKey = List<int>.filled(32, 7);

/// Replaces the device-derived key, which needs a signed APK.
void useTestScraperCipher() {
  ScraperV3Client.reset();
  ScraperV3Client.fallbackReporter = (_) {};
  ScraperV3Client.cipherLoader = () async =>
      ScraperCipher(kid: testScraperKid, rootKey: testScraperRootKey);
}

final _aes = AesGcm.with256bits();

Future<SecretKey> _key(String purpose) =>
    Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: SecretKey(testScraperRootKey),
      info: utf8.encode(purpose),
    );

class OpenedTestRequest {
  const OpenedTestRequest(this.path, this.timestamp, this.nonce, this.params);

  final String path;
  final int timestamp;
  final String nonce;
  final Map<String, dynamic> params;
}

/// Plays the server's side of the envelope.
Future<OpenedTestRequest> openTestRequest(
  String path,
  Map<String, dynamic> envelope,
) async {
  final sealed = base64Decode(envelope['ct'] as String);
  final plain = await _aes.decrypt(
    SecretBox(
      sealed.sublist(0, sealed.length - 16),
      nonce: base64Decode(envelope['iv'] as String),
      mac: Mac(sealed.sublist(sealed.length - 16)),
    ),
    secretKey: await _key('fq-v3-request'),
    aad: utf8.encode('POST $path ${envelope['kid']}'),
  );
  final decoded = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
  return OpenedTestRequest(
    path,
    decoded['ts'] as int,
    decoded['nonce'] as String,
    decoded['params'] as Map<String, dynamic>,
  );
}

Future<String> sealTestResponse(
  String path,
  String nonce,
  List<int> jsonBytes,
) async {
  final random = Random.secure();
  final box = await _aes.encrypt(
    gzip.encode(jsonBytes),
    secretKey: await _key('fq-v3-response'),
    nonce: List<int>.generate(12, (_) => random.nextInt(256)),
    aad: utf8.encode('$path $nonce'),
  );
  return jsonEncode(<String, String>{
    'iv': base64Encode(box.nonce),
    'ct': base64Encode(<int>[...box.cipherText, ...box.mac.bytes]),
  });
}

/// A [MockClient] whose handler sees sealed v3 calls as plain ones, with the
/// decrypted params on the query string.
http.Client sealedMockClient(
  Future<http.Response> Function(http.Request request) handler,
) {
  useTestScraperCipher();
  return MockClient((request) async {
    if (!request.url.path.startsWith('/api/v3/')) return handler(request);
    final opened = await openTestRequest(
      request.url.path,
      jsonDecode(request.body) as Map<String, dynamic>,
    );
    final response = await handler(http.Request(
      'POST',
      request.url.replace(queryParameters: _queryOf(opened)),
    ));
    return http.Response(
      await sealTestResponse(opened.path, opened.nonce, response.bodyBytes),
      response.statusCode,
    );
  });
}

/// Seals what another adapter answers to v3 calls, so tests can keep scripting
/// plain JSON while the real client and interceptors run.
class SealingDioAdapter implements HttpClientAdapter {
  SealingDioAdapter(this.inner);

  final HttpClientAdapter inner;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final response = await inner.fetch(options, requestStream, cancelFuture);
    if (!options.uri.path.startsWith('/api/v3/')) return response;
    final opened = await openTestRequest(
      options.uri.path,
      Map<String, dynamic>.from(options.data as Map),
    );
    final bytes = BytesBuilder();
    await response.stream.forEach(bytes.add);
    return jsonResponse(
      await sealTestResponse(opened.path, opened.nonce, bytes.takeBytes()),
      response.statusCode,
    );
  }

  @override
  void close({bool force = false}) => inner.close(force: force);
}

/// The Dio counterpart of [sealedMockClient].
Dio sealedScriptedDio(
  Future<ResponseBody> Function(RequestOptions request) callback,
) {
  useTestScraperCipher();
  return scriptedDio((request) async {
    if (!request.uri.path.startsWith('/api/v3/')) return callback(request);
    final opened = await openTestRequest(
      request.uri.path,
      Map<String, dynamic>.from(request.data as Map),
    );
    final response = await callback(request.copyWith(
      path: request.uri.replace(queryParameters: _queryOf(opened)).toString(),
    ));
    final bytes = BytesBuilder();
    await response.stream.forEach(bytes.add);
    return jsonResponse(
      await sealTestResponse(opened.path, opened.nonce, bytes.takeBytes()),
      response.statusCode,
    );
  });
}

Map<String, String> _queryOf(OpenedTestRequest opened) => <String, String>{
      for (final entry in opened.params.entries)
        entry.key: entry.value.toString(),
    };
