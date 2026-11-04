import '../../../models/mid_play_schedule_config.dart';

/// When the mid-play popup opens during a movie or episode. The built-in
/// [MidPlayScheduleConfig] opens none in a video shorter than 15 minutes, once
/// up to 20 minutes, twice up to 30, three times up to an hour, and four times
/// from an hour, at evenly spaced points between the start and the end. A
/// 16-minute episode gets 8:00; a 21-minute one gets 7:00 and 14:00; a 2-hour
/// movie gets 24, 48, 72 and 96 minutes.
///
/// A slot opens only when playback reaches it on its own. Slots the viewer
/// starts past (resuming) or seeks past are dropped, so a seek never lands on
/// a popup, and a rewind never brings a passed slot back.
class MidPlayPopupSchedule {
  MidPlayPopupSchedule(this.duration,
      {this.config = const MidPlayScheduleConfig()})
      : slots = slotsFor(duration, config: config);

  final Duration duration;
  final MidPlayScheduleConfig config;
  final List<Duration> slots;

  /// The furthest a player tick may move playback and still count as
  /// playing through a slot rather than seeking past it (2x speed, a late
  /// tick).
  static const maxStep = Duration(seconds: 5);

  /// A source switch can report a slightly different length for the same
  /// title; only a real change rebuilds the schedule.
  static const durationTolerance = Duration(seconds: 30);

  int _next = 0;
  Duration? _last;

  static List<Duration> slotsFor(Duration duration,
      {MidPlayScheduleConfig config = const MidPlayScheduleConfig()}) {
    final count = config.countFor(duration);
    if (count <= 0) return const [];
    return List.unmodifiable([
      for (var slot = 1; slot <= count; slot++) duration * slot ~/ (count + 1),
    ]);
  }

  /// Whether this schedule still describes a video of [other] length.
  bool fits(Duration other) => (other - duration).abs() <= durationTolerance;

  /// Call on every player tick. True when playback has just reached the next
  /// slot while [eligible] (playing, not buffering, in the foreground).
  bool observe(Duration position, {required bool eligible}) {
    final last = _last;
    _last = position;
    if (_next >= slots.length) return false;
    final step = last == null ? null : position - last;
    final playedThrough =
        step != null && !step.isNegative && step <= maxStep && eligible;
    var reached = false;
    while (_next < slots.length && slots[_next] <= position) {
      _next++;
      reached = true;
    }
    return reached && playedThrough;
  }
}
