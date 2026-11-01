import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/live_tv.dart';
import 'daddylive_service.dart';

/// NTV's channels and sports schedule, through the scraper.
///
/// Unlike DaddyLive, NTV's stream URLs are not tied to the IP that resolved
/// them, so the scraper's validated URL is played as it comes.
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

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$_baseUrl/api/v2/ntv$path').replace(queryParameters: query);

  @override
  Future<DaddyLiveCatalog> getCatalog({bool refresh = false}) async {
    final query = <String, String>{if (refresh) 'refresh': 'true'};
    final channelsFuture = _getJson(
      _uri('/channels', query),
      failure: liveTvUnavailableMessage,
    );
    // The schedule is extra. Its outage must not take the channels down.
    final epgFuture = () async {
      try {
        return await _getJson(
          _uri('/epg', query),
          failure: liveTvUnavailableMessage,
        );
      } catch (error) {
        debugPrint('[NTV] schedule failed, continuing without it: $error');
        return const <String, dynamic>{};
      }
    }();
    final channelsJson = await channelsFuture;
    final epgJson = await epgFuture;
    final channels = <Channel>[
      for (final item in channelsJson['channels'] as List<dynamic>? ?? [])
        if (item is Map<String, dynamic> && _offered(item))
          _namespaced(Channel.fromJson(item)),
    ];
    return DaddyLiveCatalog.fromGuide(channels, _guide(epgJson));
  }

  @override
  Future<DaddyLiveStream> getStream(String channelId) async {
    final id = channelId.startsWith(idPrefix)
        ? channelId.substring(idPrefix.length)
        : channelId;
    final stream = DaddyLiveStream.fromJson(await _getJson(
      _uri('/channels/${Uri.encodeComponent(id)}/stream'),
      failure: _noStream,
    ));
    if (stream.url.isEmpty) throw const DaddyLiveException(_noStream);
    return stream;
  }

  static bool _offered(Map<String, dynamic> json) =>
      !_relayedServers.contains(json['server']?.toString());

  static Channel _namespaced(Channel channel, {String? name}) => Channel(
        id: '$idPrefix${channel.id}',
        name: name ?? channel.name,
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

  /// The schedule without DaddyLive's relayed events, today first and the
  /// undated 24/7 events last, so it opens on what is on now.
  static DaddyLiveEpg _guide(Map<String, dynamic> json) {
    final days = <({String? date, DaddyLiveEpgDay day})>[];
    for (final dayJson in json['days'] as List<dynamic>? ?? const []) {
      if (dayJson is! Map<String, dynamic>) continue;
      final categories = <DaddyLiveEpgCategory>[];
      for (final categoryJson
          in dayJson['categories'] as List<dynamic>? ?? const []) {
        if (categoryJson is! Map<String, dynamic>) continue;
        final events = <DaddyLiveEpgEvent>[
          for (final eventJson
              in categoryJson['events'] as List<dynamic>? ?? const [])
            if (eventJson is Map<String, dynamic> && _offered(eventJson))
              _event(DaddyLiveEpgEvent.fromJson(eventJson)),
        ]..removeWhere((event) => event.channels.isEmpty);
        if (events.isEmpty) continue;
        categories.add(DaddyLiveEpgCategory(
          name: categoryJson['name']?.toString() ?? 'Other',
          events: events,
        ));
      }
      if (categories.isEmpty) continue;
      days.add((
        date: dayJson['date']?.toString(),
        day: DaddyLiveEpgDay(
          label: dayJson['label']?.toString() ?? '',
          categories: categories,
        ),
      ));
    }
    days.sort((a, b) {
      final left = a.date, right = b.date;
      if (left == null || right == null) {
        return (left == null ? 1 : 0) - (right == null ? 1 : 0);
      }
      return left.compareTo(right);
    });
    return DaddyLiveEpg(
      timezone: json['timezone']?.toString() ?? '',
      days: <DaddyLiveEpgDay>[for (final item in days) item.day],
    );
  }

  /// [event] with its channels namespaced. An event's own streams carry its
  /// title as their name, so streams sharing a name are numbered.
  static DaddyLiveEpgEvent _event(DaddyLiveEpgEvent event) {
    final counts = <String, int>{};
    for (final channel in event.channels) {
      counts[channel.name] = (counts[channel.name] ?? 0) + 1;
    }
    final numbers = <String, int>{};
    final channels = <Channel>[];
    for (final channel in event.channels) {
      if ((counts[channel.name] ?? 0) < 2) {
        channels.add(_namespaced(channel));
        continue;
      }
      final number = numbers[channel.name] = (numbers[channel.name] ?? 0) + 1;
      channels.add(_namespaced(
        channel,
        name: channel.name == event.title
            ? 'Stream $number'
            : '${channel.name} $number',
      ));
    }
    return DaddyLiveEpgEvent(
      time: event.time,
      title: event.title,
      startsAt: event.startsAt,
      channels: channels,
    );
  }

  /// The JSON body of a successful reply. Anything else is reported as
  /// [failure]: the scraper's own reason when it gives one, since its error
  /// pages can arrive as the CDN's HTML rather than JSON.
  Future<Map<String, dynamic>> _getJson(
    Uri uri, {
    required String failure,
  }) async {
    final response =
        await _client.get(uri).timeout(const Duration(seconds: 60));
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      decoded = null;
    }
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        decoded is Map<String, dynamic> &&
        decoded['success'] != false) {
      return decoded;
    }
    debugPrint('[NTV] ${response.statusCode} from ${uri.path}');
    throw DaddyLiveException(failure);
  }

  @override
  void close() => _client.close();
}
