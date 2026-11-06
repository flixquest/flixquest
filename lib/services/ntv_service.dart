import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/network/scraper_v3/scraper_v3_client.dart';
import '../models/live_tv.dart';
import 'daddylive_service.dart';

/// NTV's channels, through the scraper.
///
/// Unlike DaddyLive, NTV's stream URLs are not tied to the IP that resolved
/// them, so the scraper's validated URL is played as it comes. NTV's
/// schedule is left out: most of its events come from a server the scraper
/// cannot play.
class NtvService implements LiveTvService {
  NtvService({required String baseUrl, http.Client? client})
      : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
        _client = client ?? http.Client();

  /// Marks NTV's channel IDs, which would otherwise collide with DaddyLive's
  /// in favourites, recents and the player.
  static const idPrefix = 'ntv:';

  /// NTV relays DaddyLive itself as its phoenix server; the DaddyLive source
  /// already has those channels.
  static const _relayedServers = <String>{'phoenix'};

  static const _noStream = 'The channel returned no playable stream.';

  final String _baseUrl;
  final http.Client _client;
  late final ScraperV3Client _v3 = ScraperV3Client.http(_client);

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$_baseUrl/api/v2/ntv$path').replace(queryParameters: query);

  @override
  Future<DaddyLiveCatalog> getCatalog({bool refresh = false}) async {
    final json = await _getJson(
      _uri('/channels', <String, String>{if (refresh) 'refresh': 'true'}),
      failure: liveTvUnavailableMessage,
    );
    return DaddyLiveCatalog(
      channels: <Channel>[
        for (final item in json['channels'] as List<dynamic>? ?? [])
          if (item is Map<String, dynamic> && _offered(item))
            _namespaced(Channel.fromJson(item)),
      ],
      epg: const DaddyLiveEpg(timezone: '', days: <DaddyLiveEpgDay>[]),
      categories: const <String>[],
    );
  }

  @override
  Future<DaddyLiveStream> getStream(String channelId) async {
    final id = channelId.startsWith(idPrefix)
        ? channelId.substring(idPrefix.length)
        : channelId;
    final response =
        await _v3.post(_baseUrl, '/ntv/stream', <String, String>{'id': id});
    final stream = DaddyLiveStream.fromJson(_decodeJson(
      '/ntv/stream',
      response.statusCode,
      response.body,
      failure: _noStream,
    ));
    if (stream.url.isEmpty) throw const DaddyLiveException(_noStream);
    return stream;
  }

  static bool _offered(Map<String, dynamic> json) =>
      !_relayedServers.contains(json['server']?.toString());

  static Channel _namespaced(Channel channel) => Channel(
        id: '$idPrefix${channel.id}',
        name: channel.name,
        letter: channel.letter,
        watchUrl: channel.watchUrl,
        playerUrl: channel.playerUrl,
        categories: channel.categories,
        eventTitles: channel.eventTitles,
        nowPlaying: channel.nowPlaying,
        nextUp: channel.nextUp,
        logo: channel.logo,
        startsAt: channel.startsAt,
        endsAt: channel.endsAt,
        formatCount: channel.formatCount,
      );

  /// The JSON body of a successful reply. Anything else is reported as
  /// [failure]: the scraper's own reason when it gives one, since its error
  /// pages can arrive as the CDN's HTML rather than JSON.
  Future<Map<String, dynamic>> _getJson(
    Uri uri, {
    required String failure,
  }) async {
    final response =
        await _client.get(uri).timeout(const Duration(seconds: 60));
    return _decodeJson(
      uri.path,
      response.statusCode,
      utf8.decode(response.bodyBytes),
      failure: failure,
    );
  }

  Map<String, dynamic> _decodeJson(
    String path,
    int statusCode,
    String body, {
    required String failure,
  }) {
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      decoded = null;
    }
    if (statusCode >= 200 &&
        statusCode < 300 &&
        decoded is Map<String, dynamic> &&
        decoded['success'] != false) {
      return decoded;
    }
    debugPrint('[NTV] $statusCode from $path');
    throw DaddyLiveException(failure);
  }

  @override
  void close() => _client.close();
}
