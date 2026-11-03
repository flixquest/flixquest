import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Proves that an HLS server delivers media, not just a plausible manifest.
/// Signed loaders supply their own playlist authorization and segment decoder.
Future<Uri> probeLiveHls(
  Uri source, {
  required http.Client client,
  required Map<String, String> headers,
  Future<http.Response> Function(Uri)? loadPlaylist,
  FutureOr<Uint8List> Function(Uint8List)? decodeSegment,
}) async {
  final visited = <Uri>{};
  Future<http.Response> get(Uri uri) async {
    final response = await client
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('HLS resource returned HTTP ${response.statusCode}');
    }
    return response;
  }

  Uri resolve(Uri base, String value) {
    final uri = base.resolve(value);
    if (!const ['http', 'https'].contains(uri.scheme) || !uri.hasAuthority) {
      throw const FormatException('Invalid HLS resource URL');
    }
    return uri;
  }

  Future<Uri> probe(Uri uri, int depth) async {
    if (depth > 3 || visited.length >= 16 || !visited.add(uri)) {
      throw const FormatException('HLS playlist nesting limit reached');
    }
    final response = await (loadPlaylist?.call(uri) ?? get(uri));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('HLS playlist returned HTTP ${response.statusCode}');
    }
    final body = utf8.decode(response.bodyBytes).trimLeft();
    if (!body.startsWith('#EXTM3U')) {
      throw const FormatException('Invalid HLS playlist');
    }
    final base = response.request?.url ?? uri;
    final lines = const LineSplitter()
        .convert(body)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (body.contains('#EXT-X-STREAM-INF:')) {
      final variants = <Uri>[];
      for (var i = 0; i + 1 < lines.length; i++) {
        if (lines[i].startsWith('#EXT-X-STREAM-INF:') &&
            !lines[i + 1].startsWith('#')) {
          variants.add(resolve(base, lines[i + 1]));
        }
      }
      for (final variant in variants.take(4)) {
        try {
          final playable = await probe(variant, depth + 1);
          // Preserve external audio/subtitle renditions for the native player.
          // Flattening these masters to a video URL would discard their audio.
          return RegExp(r'#EXT-X-MEDIA:.*URI=').hasMatch(body)
              ? base
              : playable;
        } catch (_) {
          // A failed rendition must not conceal a working rendition.
        }
      }
      throw const FormatException('HLS master has no playable rendition');
    }
    if (!body.contains('#EXTINF:')) {
      throw const FormatException('HLS playlist contains no media');
    }
    String? keyLine;
    String? mapLine;
    String? segment;
    String? segmentKey;
    String? segmentMap;
    for (final line in lines) {
      if (line.startsWith('#EXT-X-KEY:')) keyLine = line;
      if (line.startsWith('#EXT-X-MAP:')) mapLine = line;
      if (!line.startsWith('#')) {
        segment = line;
        segmentKey = keyLine;
        segmentMap = mapLine;
      }
    }
    if (segment == null) {
      throw const FormatException('Empty HLS media playlist');
    }
    final encrypted = segmentKey != null &&
        !RegExp(r'METHOD=NONE(?:,|$)').hasMatch(segmentKey);
    if (encrypted) {
      final key = RegExp('URI="([^"]+)"').firstMatch(segmentKey)?.group(1);
      if (key == null ||
          !RegExp(r'(?:^|[:,])METHOD=AES-128(?:,|$)').hasMatch(segmentKey)) {
        throw const FormatException('Unsupported HLS encryption');
      }
      if ((await get(resolve(base, key))).bodyBytes.length != 16) {
        throw const FormatException('Invalid HLS encryption key');
      }
    }
    if (segmentMap != null) {
      final init = RegExp('URI="([^"]+)"').firstMatch(segmentMap)?.group(1);
      if (init == null || (await get(resolve(base, init))).bodyBytes.isEmpty) {
        throw const FormatException('Invalid HLS initialization segment');
      }
    }
    var bytes = (await get(resolve(base, segment))).bodyBytes;
    if (encrypted) {
      if (bytes.length < 16 || bytes.length % 16 != 0) {
        throw const FormatException('Invalid encrypted HLS segment');
      }
      return base;
    }
    if (decodeSegment != null) bytes = await decodeSegment(bytes);
    final ts = bytes.length >= 188 * 3 &&
        bytes[0] == 0x47 &&
        bytes[188] == 0x47 &&
        bytes[376] == 0x47;
    final mp4 = bytes.length >= 12 &&
        const ['ftyp', 'styp', 'moof'].contains(ascii.decode(
          bytes.sublist(4, 8),
          allowInvalid: true,
        ));
    if (!ts && !mp4) {
      throw const FormatException('HLS server returned invalid media');
    }
    return base;
  }

  return probe(source, 0);
}
