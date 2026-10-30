import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as image;

import 'live_hls_probe.dart';

/// Adapts DLHD's browser-only loader to the native HLS player. All upstream
/// requests, including viewer-bound token requests, originate on this device.
class DlhdPlaybackProxy {
  DlhdPlaybackProxy._({
    required this.source,
    required this.channel,
    required this.headers,
    required http.Client client,
  }) : _client = client;

  static DlhdPlaybackProxy? fromEmbed(
    String html, {
    required Map<String, String> headers,
    required http.Client client,
  }) {
    // Ordinary HLS providers must keep using their existing direct URL path.
    if (!html.contains('/api/playlist-token?slug=') ||
        !html.contains('class LiveLoader')) {
      return null;
    }
    String? constant(String name) => RegExp(
          'const\\s+$name\\s*=\\s*[\'"]([^\'"]+)[\'"]',
        ).firstMatch(html)?.group(1);
    final source = Uri.tryParse(constant('SRC') ?? '');
    final edge = Uri.tryParse(constant('EDGE') ?? '');
    final channel = constant('CHANNEL');
    if (source == null ||
        !source.hasAuthority ||
        !const ['http', 'https'].contains(source.scheme) ||
        edge == null ||
        !edge.hasAuthority ||
        !const ['http', 'https'].contains(edge.scheme) ||
        edge.origin != source.origin ||
        channel == null ||
        channel.isEmpty) {
      throw const FormatException('Invalid DLHD loader configuration');
    }
    return DlhdPlaybackProxy._(
      source: source,
      channel: channel,
      headers: Map.unmodifiable(headers),
      client: client,
    );
  }

  final Uri source;
  final String channel;
  final Map<String, String> headers;
  final http.Client _client;
  HttpServer? _server;
  bool _closed = false;
  String? _token;
  DateTime? _renewAt;
  Future<String>? _tokenFlight;
  final _resources = <String, _Resource>{};
  final _pathsByResource = <String, String>{};
  int _nextResource = 0;

  /// Validates the signed playlist and media before exposing a loopback URL.
  Future<String> start() async {
    if (_closed || _server != null) {
      throw StateError('DLHD playback session already started or closed');
    }
    final playable = await probeLiveHls(
      source,
      client: _client,
      headers: headers,
      loadPlaylist: _playlist,
      decodeSegment: (bytes) => Isolate.run(() => unwrapDlhdSegment(bytes)),
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    if (_closed) {
      await server.close(force: true);
      throw StateError('DLHD playback session closed');
    }
    _server = server;
    _resources['/index.m3u8'] = _Resource(playable, _ResourceKind.playlist);
    server.listen((request) => unawaited(_serve(request)));
    return 'http://127.0.0.1:${server.port}/index.m3u8';
  }

  Future<String> _playlistToken({bool refresh = false}) {
    final pending = _tokenFlight;
    if (pending != null) return pending;
    if (!refresh &&
        _token != null &&
        _renewAt != null &&
        DateTime.now().isBefore(_renewAt!)) {
      return Future.value(_token);
    }
    final future = () async {
      final uri = source.resolve('/api/playlist-token').replace(
        queryParameters: {'slug': channel},
      );
      final response = await _client.get(uri, headers: {
        ...headers,
        'Cache-Control': 'no-cache',
      }).timeout(const Duration(seconds: 10));
      _requireSuccess(response);
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final token = json['token'];
      if (token is! String || token.isEmpty) {
        throw const FormatException('DLHD returned no playlist token');
      }
      final ttl = (json['ttl'] as num?)?.toInt() ?? 120;
      if (ttl <= 0) throw const FormatException('Invalid DLHD token lifetime');
      _token = token;
      _renewAt = DateTime.now().add(Duration(milliseconds: ttl * 500));
      return token;
    }();
    _tokenFlight = future;
    return future.whenComplete(() => _tokenFlight = null);
  }

  Future<http.Response> _playlist(Uri uri) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final token = await _playlistToken(refresh: attempt > 0);
      final signed = uri.replace(queryParameters: {
        ...uri.queryParameters,
        't': token,
        '_': DateTime.now().millisecondsSinceEpoch.toString(),
      });
      final response = await _client.get(signed, headers: {
        ...headers,
        'Cache-Control': 'no-cache',
      }).timeout(const Duration(seconds: 30));
      if (response.statusCode == 403 && attempt == 0) continue;
      _requireSuccess(response);
      return response;
    }
    throw StateError('DLHD playlist authorization failed');
  }

  static void _requireSuccess(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('DLHD upstream returned ${response.statusCode}');
    }
  }

  static void _requirePlaylist(http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    if (!body.trimLeft().startsWith('#EXTM3U') ||
        !(body.contains('#EXTINF') || body.contains('#EXT-X-STREAM-INF'))) {
      throw const FormatException('DLHD returned an invalid playlist');
    }
  }

  String _register(Uri uri, _ResourceKind kind) {
    if (!const ['http', 'https'].contains(uri.scheme) || !uri.hasAuthority) {
      throw const FormatException('Invalid HLS resource URL');
    }
    final key = '${kind.name}:$uri';
    final existing = _pathsByResource[key];
    if (existing != null) {
      final resource = _resources.remove(existing)!;
      _resources[existing] = resource;
      return existing;
    }
    final extension = switch (kind) {
      _ResourceKind.playlist => 'm3u8',
      _ResourceKind.segment || _ResourceKind.encryptedSegment => 'ts',
      _ResourceKind.binary => 'bin',
    };
    final path = '/media/${_nextResource++}.$extension';
    _resources[path] = _Resource(uri, kind);
    _pathsByResource[key] = path;
    // Keep several live windows without retaining every segment of a long
    // viewing session. The root playlist is never evicted.
    if (_pathsByResource.length > 2048) {
      final oldest = _resources.keys.firstWhere((p) => p != '/index.m3u8');
      final removed = _resources.remove(oldest)!;
      _pathsByResource.remove('${removed.kind.name}:${removed.uri}');
    }
    return path;
  }

  String _rewritePlaylist(String body, Uri base) {
    var nextIsPlaylist = false;
    var encrypted = false;
    return const LineSplitter().convert(body).map((line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) return line;
      if (trimmed.startsWith('#')) {
        if (trimmed.startsWith('#EXT-X-KEY:')) {
          encrypted = !RegExp(r'METHOD=NONE(?:,|$)').hasMatch(trimmed);
        }
        if (trimmed.startsWith('#EXT-X-STREAM-INF:')) nextIsPlaylist = true;
        final kind = trimmed.startsWith('#EXT-X-MEDIA:') ||
                trimmed.startsWith('#EXT-X-I-FRAME-STREAM-INF:') ||
                trimmed.startsWith('#EXT-X-RENDITION-REPORT:')
            ? _ResourceKind.playlist
            : trimmed.startsWith('#EXT-X-PART:') ||
                    trimmed.startsWith('#EXT-X-PRELOAD-HINT:')
                ? (encrypted
                    ? _ResourceKind.encryptedSegment
                    : _ResourceKind.segment)
                : _ResourceKind.binary;
        return line.replaceAllMapped(RegExp('URI="([^"]+)"'), (match) {
          return 'URI="${_register(base.resolve(match.group(1)!), kind)}"';
        });
      }
      final uri = base.resolve(trimmed);
      final kind = nextIsPlaylist || uri.path.endsWith('.m3u8')
          ? _ResourceKind.playlist
          : (encrypted
              ? _ResourceKind.encryptedSegment
              : _ResourceKind.segment);
      nextIsPlaylist = false;
      return _register(uri, kind);
    }).join('\n');
  }

  Future<void> _serve(HttpRequest request) async {
    try {
      if (request.method != 'GET' && request.method != 'HEAD') {
        request.response.statusCode = HttpStatus.methodNotAllowed;
        return;
      }
      final resource = _resources[request.uri.path];
      if (resource == null || _closed) {
        request.response.statusCode = HttpStatus.notFound;
        return;
      }
      final isPlaylist = resource.kind == _ResourceKind.playlist;
      final response = isPlaylist
          ? await _playlist(resource.uri)
          : await _client
              .get(resource.uri, headers: headers)
              .timeout(const Duration(seconds: 30));
      _requireSuccess(response);
      List<int> bytes = response.bodyBytes;
      if (isPlaylist) {
        _requirePlaylist(response);
        bytes = utf8.encode(_rewritePlaylist(
          utf8.decode(response.bodyBytes),
          response.request?.url ?? resource.uri,
        ));
      } else if (resource.kind == _ResourceKind.segment) {
        final wrapped = response.bodyBytes;
        // Pixel and gzip decoding can otherwise block Flutter's UI isolate.
        bytes = await Isolate.run(() => unwrapDlhdSegment(wrapped));
      }
      request.response.headers
        ..set(HttpHeaders.cacheControlHeader, 'no-store')
        ..set(
            HttpHeaders.contentTypeHeader,
            isPlaylist
                ? 'application/vnd.apple.mpegurl'
                : 'application/octet-stream');
      request.response.contentLength = bytes.length;
      if (request.method != 'HEAD') request.response.add(bytes);
    } catch (_) {
      // Do not forward upstream bodies or signed URLs to the media player.
      request.response.statusCode = HttpStatus.badGateway;
    } finally {
      await request.response.close();
    }
  }

  void close() {
    _closed = true;
    unawaited(_server?.close(force: true));
    _resources.clear();
    _pathsByResource.clear();
  }
}

enum _ResourceKind { playlist, segment, encryptedSegment, binary }

class _Resource {
  const _Resource(this.uri, this.kind);
  final Uri uri;
  final _ResourceKind kind;
}

/// Matches the transport wrappers used by DLHD's LiveLoader. This is transport
/// decoding, before the native player demuxes the MPEG-TS packets.
Uint8List unwrapDlhdSegment(Uint8List bytes) {
  bool isTs(Uint8List data, [int offset = 0]) =>
      offset + 188 < data.length &&
      data[offset] == 0x47 &&
      data[offset + 188] == 0x47;
  Uint8List checked(List<int> payload) {
    final result = Uint8List.fromList(payload);
    if (!isTs(result)) throw const FormatException('Invalid DLHD TS payload');
    return result;
  }

  if (isTs(bytes)) return bytes;
  final data = ByteData.sublistView(bytes);
  String tagAt(int offset, int length) =>
      String.fromCharCodes(bytes.sublist(offset, offset + length));
  if (bytes.length >= 12 && tagAt(0, 4) == 'RIFF' && tagAt(8, 4) == 'WEBP') {
    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final tag = tagAt(offset, 4);
      final size = data.getUint32(offset + 4, Endian.little);
      offset += 8;
      if (size > bytes.length - offset) break;
      if (tag == 'EXIF') {
        return checked(bytes.sublist(offset, offset + size));
      }
      offset += size + (size & 1);
    }
    throw const FormatException('DLHD WebP has no TS payload');
  }
  const pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length >= 8 &&
      List.generate(8, (i) => bytes[i] == pngSignature[i]).every((b) => b)) {
    var offset = 8;
    while (offset + 12 <= bytes.length) {
      final size = data.getUint32(offset);
      if (size > bytes.length - offset - 12) break;
      final tag = tagAt(offset + 4, 4);
      offset += size + 12;
      if (tag == 'IEND') {
        if (isTs(bytes, offset)) return checked(bytes.sublist(offset));
        break;
      }
    }
    final decoded = image.decodePng(bytes);
    if (decoded == null) throw const FormatException('Invalid DLHD PNG');
    final rgb = decoded.getBytes(order: image.ChannelOrder.rgb);
    if (rgb.length >= 12 &&
        String.fromCharCodes(rgb.sublist(0, 8)) == 'TIKTIKPX') {
      final size = ByteData.sublistView(rgb).getUint32(8);
      if (size <= rgb.length - 12) {
        return checked(gzip.decode(rgb.sublist(12, 12 + size)));
      }
    }
    throw const FormatException('DLHD PNG has no TS payload');
  }
  for (final marker in ['TIKTIKRAW', 'TIKTIKTSGZ']) {
    final signature = ascii.encode(marker);
    for (var offset = 0; offset + signature.length < bytes.length; offset++) {
      if (!List.generate(
              signature.length, (i) => bytes[offset + i] == signature[i])
          .every((b) => b)) {
        continue;
      }
      final payload = bytes.sublist(offset + signature.length);
      return checked(marker == 'TIKTIKRAW' ? payload : gzip.decode(payload));
    }
  }
  for (var offset = 0; offset + 188 < bytes.length; offset++) {
    if (isTs(bytes, offset)) return checked(bytes.sublist(offset));
  }
  throw const FormatException('DLHD segment has no TS payload');
}
