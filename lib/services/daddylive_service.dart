import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/live_tv.dart';
import 'dlhd_playback_proxy.dart';
import 'live_hls_probe.dart';

/// Traces DLHD stream extraction to the console so a failing channel shows
/// which step broke. Disabled in release builds: the logged URLs carry
/// short-lived access tokens. Uses `print` rather than `debugPrint` because
/// `tool/dlhd_live_smoke.dart` runs this service without Flutter.
void _log(String message) {
  if (const bool.fromEnvironment('dart.vm.product')) return;
  // ignore: avoid_print
  print('[DaddyLive] $message');
}

/// First [max] characters of [body] on one line, for logging odd responses.
String _snippet(String body, [int max = 160]) {
  final line = body.replaceAll(RegExp(r'\s+'), ' ').trim();
  return line.length <= max ? line : '${line.substring(0, max)}…';
}

class DaddyLiveException implements Exception {
  const DaddyLiveException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Converts network and API failures into copy that is safe to show in the
/// player UI. In particular, this keeps API URLs, platform exception details,
/// and stack-like messages out of the user-facing error state.
const liveTvUnavailableMessage =
    'Live TV is temporarily unavailable. Please try again.';

String friendlyLiveTvError(Object error) {
  const unavailable = liveTvUnavailableMessage;
  final raw =
      (error is DaddyLiveException ? error.message : error.toString()).trim();
  if (raw.isEmpty) return unavailable;

  final lower = raw.toLowerCase();
  if (lower.contains('timeout') || lower.contains('timed out')) {
    return 'Live TV is taking too long to respond. Please try again.';
  }
  if (lower.contains('socketexception') ||
      lower.contains('clientexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('connection reset') ||
      lower.contains('connection refused') ||
      lower.contains('network is unreachable')) {
    return 'Couldn’t connect to Live TV. Check your internet connection and try again.';
  }
  if (lower.contains('formatexception') ||
      lower.contains('invalid data') ||
      lower.contains('unexpected response') ||
      lower.contains('json')) {
    return 'Live TV returned an invalid response. Please try again later.';
  }
  if (RegExp(
    r'https?://|uri[=:]|platformexception|methodchannel|stack trace|flixquest',
    caseSensitive: false,
  ).hasMatch(raw)) {
    return unavailable;
  }

  final concise = raw
      .replaceFirst(
        RegExp(r'^(?:Bad state:\s*|[A-Za-z0-9_.]+(?:Exception|Error):\s*)'),
        '',
      )
      .split('\n')
      .first
      .trim();
  if (concise.isEmpty || concise.length > 140) return unavailable;
  return concise;
}

class DaddyLiveCatalog {
  const DaddyLiveCatalog({
    required this.channels,
    required this.epg,
    required this.categories,
  });

  final List<Channel> channels;
  final DaddyLiveEpg epg;
  final List<String> categories;
}

abstract interface class LiveTvService {
  Future<DaddyLiveCatalog> getCatalog({bool refresh = false});

  Future<DaddyLiveStream> getStream(String channelId);

  void close();
}

class DaddyLiveService implements LiveTvService {
  DaddyLiveService({required String baseUrl, http.Client? client})
      : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
        _client = client ?? http.Client();

  static const String _browserUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36';
  static const String _siteReferer = 'https://dlhd.st/';
  static const Duration _pageTimeout = Duration(seconds: 15);
  static const int _maxEmbedDepth = 3;

  final String _baseUrl;
  final http.Client _client;
  final Map<String, String> _watchUrlsByChannel = <String, String>{};
  final _discoveries = <LiveStreamDiscovery>{};
  final _loaderUrlsByEmbed = <String, Future<String>>{};
  final _loaderProxies = <DlhdPlaybackProxy>[];
  bool _closed = false;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$_baseUrl$path').replace(queryParameters: query);

  @override
  Future<DaddyLiveCatalog> getCatalog({bool refresh = false}) async {
    // The channel directory and guide are independent upstream pages. A DLHD
    // schedule outage must not take the 24/7 channel browser down with it.
    final channelsFuture = getChannels(refresh: refresh);
    final epgFuture = () async {
      try {
        return await getEpg(refresh: refresh);
      } catch (error) {
        _log('EPG failed, continuing without a guide: $error');
        return const DaddyLiveEpg(timezone: '', days: <DaddyLiveEpgDay>[]);
      }
    }();
    final channels = await channelsFuture;
    final epg = await epgFuture;
    final categoriesByChannel = <String, Set<String>>{};
    final eventsByChannel = <String, Set<String>>{};
    final nowPlayingByChannel = <String, String>{};
    final nowPlayingStart = <String, DateTime>{};
    final nextUpByChannel = <String, String>{};
    final nextUpStart = <String, DateTime>{};
    final categories = <String>{};
    final now = DateTime.now();
    for (final day in epg.days) {
      for (final category in day.categories) {
        categories.add(category.name);
        for (final event in category.events) {
          for (final channel in event.channels) {
            categoriesByChannel
                .putIfAbsent(channel.id, () => <String>{})
                .add(category.name);
            eventsByChannel
                .putIfAbsent(channel.id, () => <String>{})
                .add(event.title);
            final startsAt = event.startsAt;
            if (startsAt == null) continue;
            if (!startsAt.isAfter(now)) {
              if (nowPlayingStart[channel.id] == null ||
                  startsAt.isAfter(nowPlayingStart[channel.id]!)) {
                nowPlayingStart[channel.id] = startsAt;
                nowPlayingByChannel[channel.id] = event.title;
              }
            } else if (nextUpStart[channel.id] == null ||
                startsAt.isBefore(nextUpStart[channel.id]!)) {
              nextUpStart[channel.id] = startsAt;
              nextUpByChannel[channel.id] = event.title;
            }
          }
        }
      }
    }
    final enriched = channels
        .map(
          (channel) => channel.copyWith(
            categories: (categoriesByChannel[channel.id] ?? const <String>{})
                .toList(growable: false)
              ..sort(),
            eventTitles: (eventsByChannel[channel.id] ?? const <String>{})
                .toList(growable: false)
              ..sort(),
            nowPlaying: nowPlayingByChannel[channel.id],
            nextUp: nextUpByChannel[channel.id],
          ),
        )
        .toList(growable: false);
    final sortedCategories = categories.toList()..sort();
    return DaddyLiveCatalog(
      channels: enriched,
      epg: epg,
      categories: sortedCategories,
    );
  }

  Future<List<Channel>> getChannels({bool refresh = false}) async {
    final json = await _getJson(
      _uri('/api/v2/dlhd/channels', <String, String>{
        if (refresh) 'refresh': 'true',
      }),
    );
    final channels = Channels.fromJson(json).channels;
    for (final channel in channels) {
      final watchUrl = channel.watchUrl?.trim();
      if (watchUrl != null && watchUrl.isNotEmpty) {
        _watchUrlsByChannel[channel.id] = watchUrl;
      }
    }
    return channels;
  }

  Future<DaddyLiveEpg> getEpg({bool refresh = false}) async {
    final json = await _getJson(
      _uri('/api/v2/dlhd/epg', <String, String>{
        if (refresh) 'refresh': 'true',
      }),
    );
    return DaddyLiveEpg.fromJson(json);
  }

  /// Resolves the first locally playable DLHD player for [channelId].
  ///
  /// DLHD exposes several player buttons on each watch page. Its
  /// signed playlists are bound to the IP that opened the final embed, so URLs
  /// extracted by the metadata API are intentionally not trusted here. The
  /// device fetches the watch page, follows every player/iframe chain, and
  /// decodes the M3U8 configuration. Player 1 is tried first; later players are
  /// tried only if it fails. Once content playback starts, the returned
  /// discovery resolves the remaining players for selection and failover.
  @override
  Future<DaddyLiveStream> getStream(String channelId) async {
    final stopwatch = Stopwatch()..start();
    final knownWatchUrl = _watchUrlsByChannel[channelId];
    final watchUrl = knownWatchUrl ??
        'https://dlhd.st/watch.php?id=${Uri.encodeQueryComponent(channelId)}';
    _log(
      'channel $channelId: extracting from $watchUrl'
      '${knownWatchUrl == null ? ' (default mirror, not in catalog)' : ''}',
    );
    final watchPageStream = await _resolveFromWatchPage(watchUrl);
    if (watchPageStream != null) {
      _log(
        'channel $channelId: OK via watch page in '
        '${stopwatch.elapsedMilliseconds}ms, '
        '${watchPageStream.variants.length} variant(s) '
        '[${watchPageStream.variants.map((v) => v.title).join(', ')}]',
      );
      return watchPageStream;
    }
    _log('channel $channelId: watch page failed, trying scraper fallback');

    // If DLHD moved mirrors or refused its heavy watch page, ask the configured
    // scraper only for its final embed location. M3U8 extraction still happens
    // locally, so the signed token belongs to the playback device's IP.
    try {
      final json = await _getJson(
        _uri('/api/v2/dlhd/channels/${Uri.encodeComponent(channelId)}/stream'),
      );
      final metadata = DaddyLiveStream.fromJson(json);
      final embedUrl = metadata.embedUrl.trim();
      _log(
        'channel $channelId: scraper returned '
        'embedUrl=${embedUrl.isEmpty ? '<empty>' : embedUrl}',
      );
      if (embedUrl.isNotEmpty) {
        final resolved = await _resolvePlayer(
          _DlhdPlayer(label: 'Stream 1', url: embedUrl),
          referer: watchUrl,
          fallbackHeaders: _playbackHeaders(metadata.headers),
        );
        if (resolved != null) {
          _log(
            'channel $channelId: OK via scraper embed in '
            '${stopwatch.elapsedMilliseconds}ms',
          );
          return _streamFromResolvedPlayers(<_ResolvedDlhdPlayer>[resolved]);
        }
        _log('channel $channelId: scraper embed yielded no playable m3u8');
      }
    } catch (error) {
      // The local page walk already failed. Surface one stable message below.
      _log('channel $channelId: scraper fallback failed: $error');
    }
    _log(
      'channel $channelId: FAILED after ${stopwatch.elapsedMilliseconds}ms, '
      'no playable stream',
    );
    throw const DaddyLiveException('The channel returned no playable stream.');
  }

  Map<String, String> _playbackHeaders(Map<String, String> headers) {
    const allowedNames = <String, String>{
      'accept': 'Accept',
      'origin': 'Origin',
      'referer': 'Referer',
      'user-agent': 'User-Agent',
    };
    final result = <String, String>{};
    for (final entry in headers.entries) {
      final name = allowedNames[entry.key.trim().toLowerCase()];
      final value = entry.value.trim();
      if (name != null && value.isNotEmpty) result[name] = value;
    }
    return result;
  }

  Future<DaddyLiveStream?> _resolveFromWatchPage(String watchUrl) async {
    try {
      final response = await _getHtml(watchUrl, referer: _siteReferer);
      final finalWatchUrl = _canonicalWatchUrl(
        response.body,
        response.request?.url.toString() ?? watchUrl,
      );
      final players = _extractPlayers(response.body, finalWatchUrl);
      _log(
        'watch page ${response.statusCode}'
        '${finalWatchUrl == watchUrl ? '' : ' (redirected to $finalWatchUrl)'}'
        ', ${response.body.length} chars, ${players.length} player(s)',
      );
      for (final player in players) {
        _log('  ${player.label}: ${player.url}');
      }
      if (players.isEmpty) {
        _log('no player buttons or iframes on watch page: '
            '${_snippet(response.body)}');
        return null;
      }

      for (var index = 0; index < players.length && !_closed; index++) {
        final resolved = await _resolvePlayer(
          players[index],
          referer: finalWatchUrl,
        );
        if (resolved == null) continue;
        LiveStreamDiscovery? discovery;
        if (index + 1 < players.length) {
          discovery = LiveStreamDiscovery(
            initial: resolved.variant,
            backups: [
              for (final player in players.skip(index + 1))
                () async => (await _resolvePlayer(
                      player,
                      referer: finalWatchUrl,
                      cancelled: () => _closed || discovery!.isDisposed,
                    ))
                        ?.variant,
            ],
          );
          _discoveries.removeWhere((item) => item.isDisposed);
          _discoveries.add(discovery);
        }
        return _streamFromResolvedPlayers([resolved], discovery: discovery);
      }
      _log('every player on the watch page failed');
    } catch (error) {
      // A mirror refusal is handled by the metadata fallback in getStream().
      _log('watch page error: $error');
    }
    return null;
  }

  Future<_ResolvedDlhdPlayer?> _resolvePlayer(
    _DlhdPlayer player, {
    required String referer,
    Map<String, String> fallbackHeaders = const <String, String>{},
    bool Function()? cancelled,
  }) async {
    final queue = <({String url, String referer, int depth})>[
      (url: player.url, referer: referer, depth: 0),
    ];
    final visited = <String>{};
    while (queue.isNotEmpty && visited.length < 16) {
      if (_closed || cancelled?.call() == true) return null;
      final page = queue.removeAt(0);
      if (!visited.add(page.url)) continue;
      try {
        final response = await _getHtml(page.url, referer: page.referer);
        if (_closed || cancelled?.call() == true) return null;
        final finalUrl = response.request?.url.toString() ?? page.url;
        final headers = _headersForEmbed(finalUrl, fallbackHeaders);
        final loader = DlhdPlaybackProxy.fromEmbed(
          response.body,
          headers: headers,
          client: _client,
        );
        if (loader != null) {
          if (_closed) return null;
          final pending = _loaderUrlsByEmbed.putIfAbsent(finalUrl, () {
            _loaderProxies.add(loader);
            return loader.start();
          });
          try {
            final localUrl = await pending;
            if (_closed || cancelled?.call() == true) {
              if (identical(_loaderUrlsByEmbed[finalUrl], pending)) {
                _loaderUrlsByEmbed.remove(finalUrl);
              }
              loader.close();
              return null;
            }
            _log(
                '${player.label}: signed DLHD loader ready for ${loader.channel}');
            return _ResolvedDlhdPlayer(
              embedUrl: finalUrl,
              variant: LiveStreamVariant(
                url: localUrl,
                headers: const {},
                mediaType: 'hls',
                title: player.label,
              ),
            );
          } catch (_) {
            if (identical(_loaderUrlsByEmbed[finalUrl], pending)) {
              _loaderUrlsByEmbed.remove(finalUrl);
            }
            loader.close();
            rethrow;
          }
        }
        final candidates = _extractM3u8Urls(response.body, finalUrl);
        _log(
          '${player.label} depth ${page.depth}: $finalUrl -> '
          '${candidates.length} m3u8 candidate(s)',
        );
        for (final candidate in candidates) {
          if (_closed || cancelled?.call() == true) return null;
          final playableUrl = await _playableUrl(candidate, headers);
          if (playableUrl != null) {
            if (_closed || cancelled?.call() == true) return null;
            _log('${player.label}: playable $candidate');
            return _ResolvedDlhdPlayer(
              embedUrl: finalUrl,
              variant: LiveStreamVariant(
                url: playableUrl,
                headers: headers,
                mediaType: 'hls',
                title: player.label,
              ),
            );
          }
        }
        if (page.depth >= _maxEmbedDepth) {
          _log(
            '${player.label}: max embed depth reached at $finalUrl: '
            '${_snippet(response.body)}',
          );
          continue;
        }
        final frames = _extractIframeUrls(response.body, finalUrl)
          ..sort((a, b) {
            final aPreferred = a.contains('/premiumtv/') ? 0 : 1;
            final bPreferred = b.contains('/premiumtv/') ? 0 : 1;
            return aPreferred.compareTo(bPreferred);
          });
        if (frames.isEmpty && candidates.isEmpty) {
          _log(
            '${player.label}: no iframes or m3u8 at $finalUrl: '
            '${_snippet(response.body)}',
          );
        }
        queue.addAll(
          frames.map(
            (url) => (url: url, referer: finalUrl, depth: page.depth + 1),
          ),
        );
      } catch (error) {
        // One DLHD player failing must not prevent later players from resolving.
        _log('${player.label}: ${page.url} failed: $error');
      }
    }
    _log('${player.label}: unresolved');
    return null;
  }

  DaddyLiveStream _streamFromResolvedPlayers(
    List<_ResolvedDlhdPlayer> players, {
    LiveStreamDiscovery? discovery,
  }) {
    final first = players.first;
    return DaddyLiveStream(
      url: first.variant.url,
      headers: first.variant.headers,
      embedUrl: first.embedUrl,
      expiresAt: _streamExpiry(first.variant.url),
      mediaType: first.variant.mediaType,
      clearKey: first.variant.clearKey,
      title: first.variant.title,
      // Preserve the watch page's Player 1..N entries even when two providers
      // currently point at the same CDN URL. Their referer/origin headers can
      // differ, and they remain distinct failover routes.
      variants: players.map((player) => player.variant).toList(growable: false),
      discovery: discovery,
    );
  }

  Future<http.Response> _getHtml(String url, {required String referer}) async {
    final response = await _client.get(
      Uri.parse(url),
      headers: <String, String>{
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Referer': referer,
        'User-Agent': _browserUserAgent,
      },
    ).timeout(_pageTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DaddyLiveException('DLHD page returned ${response.statusCode}.');
    }
    return response;
  }

  String _canonicalWatchUrl(String html, String responseUrl) {
    for (final match
        in RegExp(r'<link\b[^>]*>', caseSensitive: false).allMatches(html)) {
      final tag = match.group(0)!;
      if (_htmlAttribute(tag, 'rel')?.toLowerCase() != 'canonical') continue;
      final href = _htmlAttribute(tag, 'href');
      final canonical = href == null
          ? null
          : _absoluteHttpUrl(_decodeHtml(href), responseUrl);
      if (canonical != null) return canonical;
    }
    return responseUrl;
  }

  List<_DlhdPlayer> _extractPlayers(String html, String pageUrl) {
    final players = <_DlhdPlayer>[];
    final buttonPattern = RegExp(
      r'<button\b[^>]*>',
      caseSensitive: false,
    );
    for (final match in buttonPattern.allMatches(html)) {
      final tag = match.group(0)!;
      final classes = _htmlAttribute(tag, 'class') ?? '';
      if (!classes.toLowerCase().split(RegExp(r'\s+')).contains('player-btn')) {
        continue;
      }
      final rawUrl = _htmlAttribute(tag, 'data-url');
      if (rawUrl == null || rawUrl.trim().isEmpty) continue;
      final absolute = _absoluteHttpUrl(_decodeHtml(rawUrl), pageUrl);
      if (absolute == null) continue;
      final title = _htmlAttribute(tag, 'title')?.trim();
      players.add(
        _DlhdPlayer(
          label: title == null || title.isEmpty
              ? 'Stream ${players.length + 1}'
              : title.replaceFirst(
                  RegExp(r'^player', caseSensitive: false),
                  'Stream',
                ),
          url: absolute,
        ),
      );
    }
    if (players.isNotEmpty) return players;
    final frame = _extractIframeUrls(html, pageUrl).firstOrNull;
    return frame == null
        ? const <_DlhdPlayer>[]
        : <_DlhdPlayer>[_DlhdPlayer(label: 'Stream 1', url: frame)];
  }

  List<String> _extractIframeUrls(String html, String pageUrl) {
    final urls = <String>[];
    final seen = <String>{};
    final pattern = RegExp(r'<iframe\b[^>]*>', caseSensitive: false);
    for (final match in pattern.allMatches(html)) {
      final rawUrl = _htmlAttribute(match.group(0)!, 'src');
      if (rawUrl == null) continue;
      final absolute = _absoluteHttpUrl(_decodeHtml(rawUrl), pageUrl);
      if (absolute != null && seen.add(absolute)) urls.add(absolute);
    }
    return urls;
  }

  String? _htmlAttribute(String tag, String name) {
    final escapedName = RegExp.escape(name);
    final pattern = RegExp(
      '$escapedName\\s*=\\s*(?:"([^"]*)"|\'([^\']*)\'|([^\\s>]+))',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(tag);
    return match?.group(1) ?? match?.group(2) ?? match?.group(3);
  }

  String _decodeHtml(String value) => value
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&#x2F;', '/');

  String? _absoluteHttpUrl(String value, String pageUrl) {
    try {
      final parsed = Uri.parse(value.trim());
      final absolute =
          parsed.hasScheme ? parsed : Uri.parse(pageUrl).resolveUri(parsed);
      if ((absolute.scheme == 'http' || absolute.scheme == 'https') &&
          absolute.host.isNotEmpty) {
        return absolute.toString();
      }
    } on FormatException {
      // Ignore malformed markup candidates.
    }
    return null;
  }

  Map<String, String> _headersForEmbed(
    String embedUrl,
    Map<String, String> fallback,
  ) {
    final uri = Uri.parse(embedUrl);
    return <String, String>{
      ...fallback,
      'Accept': '*/*',
      'Origin': '${uri.scheme}://${uri.authority}',
      'Referer': embedUrl,
      'User-Agent': fallback['User-Agent'] ?? _browserUserAgent,
    };
  }

  Future<String?> _playableUrl(
    String url,
    Map<String, String> headers,
  ) async {
    try {
      final playable = await probeLiveHls(
        Uri.parse(url),
        client: _client,
        headers: headers,
      );
      return playable.toString();
    } catch (error) {
      _log('m3u8 rejected, $error: $url');
      return null;
    }
  }

  DateTime? _streamExpiry(String url) {
    final uri = Uri.parse(url);
    final timestamps = <String?>[
      uri.queryParameters['e'],
      ...RegExp(r'(?:^|/)(\d{10})(?:/|$)')
          .allMatches(uri.path)
          .map((match) => match.group(1)),
    ];
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (final value in timestamps) {
      final seconds = int.tryParse(value ?? '');
      if (seconds != null && seconds > now - 86400 && seconds < now + 2592000) {
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
      }
    }
    return null;
  }

  /// The embed stores four shuffled base64 chunks, each with an inserted
  /// character at offset 3. Decode data only; the config can also contain ads.
  List<String> _decodeConfigSources(String encoded) {
    try {
      final raw = latin1.decode(base64Decode(encoded));
      final partLength = raw.length ~/ 4;
      if (partLength < 4 || raw.length % 4 != 0) return const <String>[];
      const order = <int>[2, 0, 3, 1];
      final parts = List<String>.filled(4, '');
      for (var index = 0; index < 4; index++) {
        final part =
            raw.substring(index * partLength, (index + 1) * partLength);
        parts[order[index]] = latin1.decode(
          base64Decode(part.substring(0, 3) + part.substring(4)),
        );
      }
      final config = jsonDecode(utf8.decode(base64Decode(parts.join())));
      if (config is! Map<String, dynamic>) return const <String>[];
      return <dynamic>[config['stream_url'], config['stream_url_nop2p']]
          .whereType<String>()
          .toList(growable: false);
    } on Object {
      return const <String>[];
    }
  }

  /// Extracts candidate m3u8 URLs from an embed page, mirroring the scraper's
  /// parsing: `_econfig`, base64 literals in `atob(...)`, and raw URLs.
  List<String> _extractM3u8Urls(String html, String pageUrl) {
    final candidates = <String>[];
    final configPattern = RegExp(
      r'''window(?:\._econfig|\[['"]_econfig['"]\])\s*=\s*['"]([^'"]+)['"]''',
      caseSensitive: false,
    );
    for (final match in configPattern.allMatches(html)) {
      candidates.addAll(_decodeConfigSources(match.group(1)!));
    }
    final atobPattern = RegExp(
      r'''atob\(\s*['"]([^'"]+)['"]\s*\)''',
      caseSensitive: false,
    );
    for (final match in atobPattern.allMatches(html)) {
      try {
        final decoded = utf8.decode(base64Decode(match.group(1)!)).trim();
        if (decoded.isNotEmpty) candidates.add(decoded);
      } on FormatException {
        // Ignore unrelated base64 payloads.
      }
    }
    final unescaped = html
        .replaceAll(r'\/', '/')
        .replaceAll('&amp;', '&')
        .replaceAll(r'\u0026', '&');
    final rawUrlPattern = RegExp(
      r'''(?:https?:)?//[^\s'"<>]+\.m3u8(?:\?[^\s'"<>]*)?''',
      caseSensitive: false,
    );
    for (final match in rawUrlPattern.allMatches(unescaped)) {
      candidates.add(match.group(0)!);
    }
    final resolved = <String>[];
    for (final candidate in candidates) {
      try {
        final uri = Uri.parse(candidate);
        final absolute =
            uri.hasScheme ? uri : Uri.parse(pageUrl).resolveUri(uri);
        if ((absolute.scheme == 'http' || absolute.scheme == 'https') &&
            absolute.host.isNotEmpty) {
          resolved.add(absolute.toString());
        }
      } on FormatException {
        // Ignore malformed candidates.
      }
    }
    return resolved
        .where((url) =>
            RegExp(r'\.m3u8(?:$|[?#])', caseSensitive: false).hasMatch(url))
        .toSet()
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response =
        await _client.get(uri).timeout(const Duration(seconds: 60));
    final dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      _log(
        'scraper ${response.statusCode} non-JSON from ${uri.path}: '
        '${_snippet(response.body)}',
      );
      throw const DaddyLiveException(
          'The live TV service returned invalid data.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _log(
        'scraper ${response.statusCode} from ${uri.path}: '
        '${_snippet(response.body)}',
      );
      final message = decoded is Map<String, dynamic>
          ? decoded['message']?.toString() ?? decoded['error']?.toString()
          : null;
      throw DaddyLiveException(
          message ?? 'Live TV request failed (${response.statusCode}).');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const DaddyLiveException(
          'The live TV service returned an unexpected response.');
    }
    if (decoded['success'] == false) {
      _log(
          'scraper success=false from ${uri.path}: ${_snippet(response.body)}');
      throw DaddyLiveException(
          decoded['message']?.toString() ?? 'Live TV request failed.');
    }
    return decoded;
  }

  @override
  void close() {
    _closed = true;
    for (final discovery in _discoveries) {
      discovery.dispose();
    }
    _discoveries.clear();
    for (final proxy in _loaderProxies) {
      proxy.close();
    }
    _loaderProxies.clear();
    _loaderUrlsByEmbed.clear();
    _client.close();
  }
}

class _DlhdPlayer {
  const _DlhdPlayer({required this.label, required this.url});

  final String label;
  final String url;
}

class _ResolvedDlhdPlayer {
  const _ResolvedDlhdPlayer({
    required this.embedUrl,
    required this.variant,
  });

  final String embedUrl;
  final LiveStreamVariant variant;
}
