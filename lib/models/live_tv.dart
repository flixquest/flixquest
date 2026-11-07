import 'dart:async';

import 'package:intl/intl.dart';

class Channels {
  const Channels({required this.channels});

  factory Channels.fromJson(Map<String, dynamic> json) {
    final items = json['channels'] as List<dynamic>? ?? const <dynamic>[];
    return Channels(
      channels: items
          .whereType<Map<String, dynamic>>()
          .map(Channel.fromJson)
          .toList(growable: false),
    );
  }

  final List<Channel> channels;
}

class Channel {
  const Channel({
    required this.id,
    required this.name,
    this.letter,
    this.watchUrl,
    this.playerUrl,
    this.categories = const <String>[],
    this.eventTitles = const <String>[],
    this.nowPlaying,
    this.nextUp,
    this.logo,
    this.startsAt,
    this.endsAt,
    this.formatCount = 0,
  });

  factory Channel.fromJson(Map<String, dynamic> json) => Channel(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Unknown channel',
        letter: json['letter']?.toString(),
        watchUrl: json['watchUrl']?.toString(),
        playerUrl: json['playerUrl']?.toString(),
        categories: (json['categories'] as List<dynamic>? ?? const <dynamic>[])
            .map((item) => item.toString())
            .toList(growable: false),
        eventTitles:
            (json['eventTitles'] as List<dynamic>? ?? const <dynamic>[])
                .map((item) => item.toString())
                .toList(growable: false),
        nowPlaying: json['nowPlaying']?.toString(),
        nextUp: json['nextUp']?.toString(),
        logo: json['logo']?.toString(),
        startsAt: DateTime.tryParse(json['startsAt']?.toString() ?? ''),
        endsAt: DateTime.tryParse(json['endsAt']?.toString() ?? ''),
        formatCount: int.tryParse(json['formatCount']?.toString() ?? '') ?? 0,
      );

  final String id;
  final String name;
  final String? letter;
  final String? watchUrl;
  final String? playerUrl;
  final List<String> categories;

  /// Event titles airing on this channel (used for searching by teams etc.).
  final List<String> eventTitles;

  /// Title of the event currently airing on this channel, when known.
  final String? nowPlaying;

  /// Title of the next upcoming event on this channel, when known.
  final String? nextUp;
  final String? logo;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int formatCount;

  Channel copyWith({
    List<String>? categories,
    List<String>? eventTitles,
    String? nowPlaying,
    String? nextUp,
  }) =>
      Channel(
        id: id,
        name: name,
        letter: letter,
        watchUrl: watchUrl,
        playerUrl: playerUrl,
        categories: categories ?? this.categories,
        eventTitles: eventTitles ?? this.eventTitles,
        nowPlaying: nowPlaying ?? this.nowPlaying,
        nextUp: nextUp ?? this.nextUp,
        logo: logo,
        startsAt: startsAt,
        endsAt: endsAt,
        formatCount: formatCount,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        if (letter != null) 'letter': letter,
        if (watchUrl != null) 'watchUrl': watchUrl,
        if (playerUrl != null) 'playerUrl': playerUrl,
        'categories': categories,
        if (eventTitles.isNotEmpty) 'eventTitles': eventTitles,
        if (nowPlaying != null) 'nowPlaying': nowPlaying,
        if (nextUp != null) 'nextUp': nextUp,
        if (logo != null) 'logo': logo,
        if (startsAt != null) 'startsAt': startsAt!.toIso8601String(),
        if (endsAt != null) 'endsAt': endsAt!.toIso8601String(),
        if (formatCount > 0) 'formatCount': formatCount,
      };
}

class DaddyLiveStream {
  const DaddyLiveStream({
    required this.url,
    required this.headers,
    required this.embedUrl,
    this.expiresAt,
    this.mediaType = 'hls',
    this.clearKey,
    this.title,
    this.variants = const <LiveStreamVariant>[],
    this.discovery,
  });

  factory DaddyLiveStream.fromJson(Map<String, dynamic> json) {
    final stream = json['stream'] as Map<String, dynamic>? ?? json;
    final rawHeaders =
        stream['headers'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return DaddyLiveStream(
      url: stream['url']?.toString() ?? '',
      headers: rawHeaders.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
      embedUrl: stream['embedUrl']?.toString() ?? '',
      expiresAt: DateTime.tryParse(stream['expiresAt']?.toString() ?? ''),
      mediaType: stream['mediaType']?.toString() ??
          (stream['isM3U8'] == false ? 'dash' : 'hls'),
      clearKey: stream['clearKey']?.toString(),
      title: stream['title']?.toString(),
      variants: (json['streams'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(LiveStreamVariant.fromJson)
          .toList(growable: false),
    );
  }

  final String url;
  final Map<String, String> headers;
  final String embedUrl;
  final DateTime? expiresAt;
  final String mediaType;
  final String? clearKey;
  final String? title;
  final List<LiveStreamVariant> variants;
  final LiveStreamDiscovery? discovery;
}

class LiveStreamVariant {
  const LiveStreamVariant({
    required this.url,
    required this.headers,
    required this.mediaType,
    this.clearKey,
    this.title,
    this.logo,
  });

  factory LiveStreamVariant.fromJson(Map<String, dynamic> json) {
    final headers = (json['headers'] as Map<String, dynamic>? ?? const {})
        .map((key, value) => MapEntry(key, value.toString()));
    return LiveStreamVariant(
      url: json['url']?.toString() ?? '',
      headers: headers,
      mediaType: json['mediaType']?.toString() ??
          (json['isM3U8'] == false ? 'dash' : 'hls'),
      clearKey: json['clearKey']?.toString(),
      title: json['title']?.toString(),
      logo: json['logo']?.toString(),
    );
  }

  final String url;
  final Map<String, String> headers;
  final String mediaType;
  final String? clearKey;
  final String? title;
  final String? logo;
}

class LiveStreamDiscovery {
  LiveStreamDiscovery({
    required LiveStreamVariant initial,
    required List<Future<LiveStreamVariant?> Function()> backups,
  })  : _resolved = {0: initial},
        _backups = backups;

  final List<Future<LiveStreamVariant?> Function()> _backups;
  final Map<int, LiveStreamVariant> _resolved;
  final Map<int, Future<LiveStreamVariant?>> _pending = {};
  final _updates = StreamController<List<LiveStreamVariant>>.broadcast();
  bool _started = false;
  bool _disposed = false;
  int _nextFallback = 0;
  Duration _lastPosition = Duration.zero;

  Stream<List<LiveStreamVariant>> get updates => _updates.stream;
  bool get isDisposed => _disposed;
  bool get hasNext => !_disposed && _nextFallback < _backups.length;
  List<LiveStreamVariant> get variants {
    final keys = _resolved.keys.toList()..sort();
    return List.unmodifiable(keys.map((key) => _resolved[key]!));
  }

  void observePlayback({
    required Duration position,
    required bool isPlaying,
    required bool isBuffering,
    required bool isAd,
  }) {
    if (_disposed || _started) return;
    if (isAd) {
      _lastPosition = Duration.zero;
      return;
    }
    final advanced = position > _lastPosition;
    _lastPosition = position;
    if (advanced && isPlaying && !isBuffering) start();
  }

  /// The caller has observed content playback. Each successful backup is
  /// published independently, so one slow server never holds up the others.
  void start() {
    if (_disposed || _started) return;
    _started = true;
    for (var index = 0; index < _backups.length; index++) {
      unawaited(_resolve(index));
    }
  }

  /// Before playback, recovery tries only as far as the next working server.
  /// Already-running resolutions are shared with background discovery.
  Future<void> resolveNext() async {
    while (hasNext) {
      final result = await _resolve(_nextFallback++);
      if (_disposed || result != null) return;
    }
  }

  Future<LiveStreamVariant?> _resolve(int index) {
    if (_disposed) return Future.value(null);
    return _pending.putIfAbsent(index, () async {
      try {
        final variant = await _backups[index]();
        if (_disposed || variant == null) return null;
        _resolved[index + 1] = variant;
        _updates.add(variants);
        return variant;
      } catch (_) {
        // A failed backup must never interrupt the playing server.
        return null;
      }
    });
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_updates.close());
  }
}

class DaddyLiveEpg {
  const DaddyLiveEpg({required this.timezone, required this.days});

  factory DaddyLiveEpg.fromJson(Map<String, dynamic> json) => DaddyLiveEpg(
        timezone: json['timezone']?.toString() ?? '',
        days: (json['days'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(DaddyLiveEpgDay.fromJson)
            .toList(growable: false),
      );

  final String timezone;
  final List<DaddyLiveEpgDay> days;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (timezone.isNotEmpty) 'timezone': timezone,
        'days': days.map((day) => day.toJson()).toList(growable: false),
      };
}

class DaddyLiveEpgDay {
  const DaddyLiveEpgDay({required this.label, required this.categories});

  factory DaddyLiveEpgDay.fromJson(Map<String, dynamic> json) =>
      DaddyLiveEpgDay(
        label: json['label']?.toString() ?? '',
        categories: (json['categories'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(DaddyLiveEpgCategory.fromJson)
            .toList(growable: false),
      );

  final String label;
  final List<DaddyLiveEpgCategory> categories;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (label.isNotEmpty) 'label': label,
        'categories': categories.map((category) => category.toJson()).toList(),
      };
}

class DaddyLiveEpgCategory {
  const DaddyLiveEpgCategory({required this.name, required this.events});

  factory DaddyLiveEpgCategory.fromJson(Map<String, dynamic> json) =>
      DaddyLiveEpgCategory(
        name: json['name']?.toString() ?? 'Other',
        events: (json['events'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(DaddyLiveEpgEvent.fromJson)
            .toList(growable: false),
      );

  final String name;
  final List<DaddyLiveEpgEvent> events;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (name.isNotEmpty) 'name': name,
        'events': events.map((event) => event.toJson()).toList(),
      };
}

class DaddyLiveEpgEvent {
  const DaddyLiveEpgEvent({
    required this.time,
    required this.title,
    required this.channels,
    this.startsAt,
  });

  factory DaddyLiveEpgEvent.fromJson(Map<String, dynamic> json) =>
      DaddyLiveEpgEvent(
        time: json['time']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        startsAt: DateTime.tryParse(json['startsAt']?.toString() ?? ''),
        channels: (json['channels'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(Channel.fromJson)
            .toList(growable: false),
      );

  final String time;
  final String title;
  final DateTime? startsAt;
  final List<Channel> channels;

  /// Returns the event start time formatted for the user's phone local timezone.
  String get displayTime {
    if (startsAt != null) {
      final local = startsAt!.toLocal();
      return DateFormat.jm().format(local);
    }
    final raw = time.trim();
    if (raw.isEmpty) return '';
    final parts = raw.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]);
      final minutePart = parts[1].split(' ').first;
      final minute = int.tryParse(minutePart);
      if (hour != null && minute != null) {
        final now = DateTime.now().toUtc();
        final utcDateTime =
            DateTime.utc(now.year, now.month, now.day, hour, minute);
        final localDateTime = utcDateTime.toLocal();
        return DateFormat.jm().format(localDateTime);
      }
    }
    return raw;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (time.isNotEmpty) 'time': time,
        'title': title,
        if (startsAt != null) 'startsAt': startsAt!.toIso8601String(),
        'channels': channels.map((channel) => channel.toJson()).toList(),
      };
}
