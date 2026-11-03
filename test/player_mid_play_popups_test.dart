import 'package:flixquest/screens/common/player/player_mid_play_popups.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Duration minutes(num value) =>
      Duration(milliseconds: (value * Duration.millisecondsPerMinute).round());

  group('slots', () {
    test('none under 15 minutes, one under 20', () {
      expect(MidPlayPopupSchedule.slotsFor(minutes(3)), isEmpty);
      expect(MidPlayPopupSchedule.slotsFor(minutes(14.99)), isEmpty);
      expect(MidPlayPopupSchedule.slotsFor(minutes(15)), [minutes(7.5)]);
      expect(MidPlayPopupSchedule.slotsFor(minutes(19.99)), hasLength(1));
      expect(MidPlayPopupSchedule.slotsFor(minutes(20)), hasLength(2));
    });

    test('two under 30 minutes, three under an hour, four from an hour', () {
      expect(MidPlayPopupSchedule.slotsFor(minutes(21)),
          [minutes(7), minutes(14)]);
      expect(MidPlayPopupSchedule.slotsFor(minutes(29.99)), hasLength(2));
      expect(MidPlayPopupSchedule.slotsFor(minutes(30)), hasLength(3));
      expect(MidPlayPopupSchedule.slotsFor(minutes(44)),
          [minutes(11), minutes(22), minutes(33)]);
      expect(MidPlayPopupSchedule.slotsFor(minutes(59.99)), hasLength(3));
      expect(MidPlayPopupSchedule.slotsFor(minutes(60)),
          [minutes(12), minutes(24), minutes(36), minutes(48)]);
      expect(MidPlayPopupSchedule.slotsFor(minutes(120)),
          [minutes(24), minutes(48), minutes(72), minutes(96)]);
    });

    test('an unknown length has none', () {
      expect(MidPlayPopupSchedule.slotsFor(Duration.zero), isEmpty);
    });
  });

  /// Plays from [from] to [to] one second per tick and returns where it fired.
  List<Duration> play(MidPlayPopupSchedule schedule, Duration from, Duration to,
      {bool eligible = true}) {
    final fired = <Duration>[];
    for (var at = from; at <= to; at += const Duration(seconds: 1)) {
      if (schedule.observe(at, eligible: eligible)) fired.add(at);
    }
    return fired;
  }

  test('fires once at each slot when played through', () {
    final schedule = MidPlayPopupSchedule(minutes(120));
    expect(play(schedule, Duration.zero, minutes(120)),
        [minutes(24), minutes(48), minutes(72), minutes(96)]);
  });

  test('a resume skips slots already behind it', () {
    final schedule = MidPlayPopupSchedule(minutes(120));
    expect(
        play(schedule, minutes(50), minutes(120)), [minutes(72), minutes(96)]);
  });

  test('a seek past a slot drops it; a rewind never brings it back', () {
    final schedule = MidPlayPopupSchedule(minutes(120));
    expect(play(schedule, Duration.zero, minutes(10)), isEmpty);
    // Seek from 10 to 30 minutes, over the 24-minute slot.
    expect(play(schedule, minutes(30), minutes(40)), isEmpty);
    // Rewind to 20 minutes and play through 24 again.
    expect(play(schedule, minutes(20), minutes(50)), [minutes(48)]);
  });

  test('2x speed still plays through a slot', () {
    final schedule = MidPlayPopupSchedule(minutes(21));
    final fired = <Duration>[];
    for (var at = Duration.zero;
        at <= minutes(21);
        at += const Duration(seconds: 2)) {
      if (schedule.observe(at, eligible: true)) fired.add(at);
    }
    expect(fired, hasLength(2));
  });

  test('a slot reached while not eligible is dropped', () {
    final schedule = MidPlayPopupSchedule(minutes(21));
    final first = schedule.slots.first;
    expect(
        play(schedule, first - const Duration(seconds: 3),
            first + const Duration(seconds: 3),
            eligible: false),
        isEmpty);
    expect(play(schedule, first + const Duration(seconds: 4), minutes(21)),
        hasLength(1));
  });

  test('fits a length within the tolerance only', () {
    final schedule = MidPlayPopupSchedule(minutes(60));
    expect(schedule.fits(minutes(60.4)), isTrue);
    expect(schedule.fits(minutes(61)), isFalse);
  });
}
