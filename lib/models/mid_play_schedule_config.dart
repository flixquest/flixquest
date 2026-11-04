import 'dart:convert';

import 'package:flutter/foundation.dart';

/// How many mid-play ads a video of a given length gets.
///
/// Ranges are half-open: [minimum] is included, [maximum] is excluded. A
/// missing maximum leaves the range open-ended.
@immutable
class MidPlayAdCountRange {
  const MidPlayAdCountRange({
    required this.minimum,
    this.maximum,
    required this.count,
  });

  final Duration minimum;
  final Duration? maximum;
  final int count;

  bool contains(Duration duration) =>
      duration >= minimum && (maximum == null || duration < maximum!);

  @override
  bool operator ==(Object other) =>
      other is MidPlayAdCountRange &&
      other.minimum == minimum &&
      other.maximum == maximum &&
      other.count == count;

  @override
  int get hashCode => Object.hash(minimum, maximum, count);
}

/// The mid-play ad counts published as `mid_play_popup_schedule`. Missing or
/// malformed JSON keeps the built-in ranges. An explicit empty `ranges` list
/// disables mid-play ads.
@immutable
class MidPlayScheduleConfig {
  const MidPlayScheduleConfig({this.ranges = defaultRanges});

  final List<MidPlayAdCountRange> ranges;

  static const maximumCount = 10;
  static const maximumMinutes = 1440;

  static const defaultRanges = <MidPlayAdCountRange>[
    MidPlayAdCountRange(
      minimum: Duration(minutes: 15),
      maximum: Duration(minutes: 20),
      count: 1,
    ),
    MidPlayAdCountRange(
      minimum: Duration(minutes: 20),
      maximum: Duration(minutes: 30),
      count: 2,
    ),
    MidPlayAdCountRange(
      minimum: Duration(minutes: 30),
      maximum: Duration(minutes: 60),
      count: 3,
    ),
    MidPlayAdCountRange(
      minimum: Duration(minutes: 60),
      count: 4,
    ),
  ];

  /// Ads for a video of [duration]; ranges outside every entry get none.
  int countFor(Duration duration) {
    for (final range in ranges) {
      if (range.contains(duration)) return range.count;
    }
    return 0;
  }

  static MidPlayScheduleConfig parse(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map || !json.containsKey('ranges')) {
        return const MidPlayScheduleConfig();
      }
      final rawRanges = json['ranges'];
      if (rawRanges is! List) return const MidPlayScheduleConfig();
      if (rawRanges.isEmpty) {
        return const MidPlayScheduleConfig(ranges: []);
      }
      final parsed = <MidPlayAdCountRange>[];
      for (final entry in rawRanges) {
        if (entry is! Map) return const MidPlayScheduleConfig();
        final minimum = _minutes(entry['min_duration_minutes']);
        final maximum = entry['max_duration_minutes'] == null
            ? null
            : _minutes(entry['max_duration_minutes']);
        final count = entry['count'];
        if (minimum == null ||
            (entry['max_duration_minutes'] != null && maximum == null) ||
            count is! int ||
            count < 0 ||
            count > maximumCount ||
            (maximum != null && maximum <= minimum)) {
          return const MidPlayScheduleConfig();
        }
        parsed.add(MidPlayAdCountRange(
          minimum: minimum,
          maximum: maximum,
          count: count,
        ));
      }
      parsed.sort((a, b) => a.minimum.compareTo(b.minimum));
      for (var index = 1; index < parsed.length; index++) {
        final previous = parsed[index - 1];
        if (previous.maximum == null ||
            parsed[index].minimum < previous.maximum!) {
          return const MidPlayScheduleConfig();
        }
      }
      return MidPlayScheduleConfig(ranges: List.unmodifiable(parsed));
    } catch (_) {
      return const MidPlayScheduleConfig();
    }
  }

  static Duration? _minutes(Object? value) {
    if (value is! num || !value.isFinite) return null;
    final minutes = value.toInt();
    if (minutes < 0 || minutes > maximumMinutes) return null;
    return Duration(minutes: minutes);
  }

  @override
  bool operator ==(Object other) =>
      other is MidPlayScheduleConfig && listEquals(other.ranges, ranges);

  @override
  int get hashCode => Object.hashAll(ranges);
}
