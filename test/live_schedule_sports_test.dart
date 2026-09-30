import 'package:flutter_test/flutter_test.dart';
import 'package:flixquest/functions/live_schedule_sports.dart';
import 'package:flixquest/models/live_tv.dart';

DaddyLiveEpgEvent _event(String title, {String time = '12:00', int? hour}) =>
    DaddyLiveEpgEvent(
      time: time,
      title: title,
      channels: const <Channel>[],
      startsAt: hour == null ? null : DateTime.utc(2026, 9, 26, hour),
    );

DaddyLiveEpgCategory _category(String name, List<DaddyLiveEpgEvent> events) =>
    DaddyLiveEpgCategory(name: name, events: events);

Map<String, List<String>> _summary(DaddyLiveEpgDay day) =>
    <String, List<String>>{
      for (final section in groupScheduleBySport(day))
        section.label: section.events.map((e) => e.title).toList(),
    };

void main() {
  test('merges league categories into sports named from upstream data', () {
    final day =
        DaddyLiveEpgDay(label: 'Sat', categories: <DaddyLiveEpgCategory>[
      _category('All Soccer Events ⚽', <DaddyLiveEpgEvent>[
        _event('⚽ 🇸🇰 Slovakia - 1. liga : A vs B', time: '1'),
        // No title emoji: the category marker decides.
        _event('Brazil Serie B : C vs D', time: '2'),
      ]),
      _category('NWSL Soccer ⚽', <DaddyLiveEpgEvent>[
        _event('⚽ 🇺🇸 United States - NWSL : E vs F'),
      ]),
      _category('USL Championship ⚽', <DaddyLiveEpgEvent>[
        _event('⚽ 🇺🇸 USL Championship : G vs H'),
      ]),
      _category('Tennis 🎾 ATP - Singles: Chengdu (China)', <DaddyLiveEpgEvent>[
        _event('🎾 ATP - Singles: I vs J'),
      ]),
      _category('Tennis 🎾', <DaddyLiveEpgEvent>[_event('🎾 🇰🇷 Seoul-WTA')]),
      _category('Ice Hockey (NHL) 🏒', <DaddyLiveEpgEvent>[
        _event('🏒 🇺🇸 NHL : K vs L'),
      ]),
      // Emoji-less league bucket: the title marker still files it under hockey.
      _category('OHL', <DaddyLiveEpgEvent>[_event('🏒 🇨🇦 OHL : M vs N')]),
      _category('OHL Ice Hockey 🏒', <DaddyLiveEpgEvent>[
        _event('🏒 🇨🇦 OHL : O vs P'),
      ]),
    ]);

    expect(
        _summary(day).keys, <String>['⚽ Soccer', '🎾 Tennis', '🏒 Ice Hockey']);
    expect(_summary(day)['⚽ Soccer'], hasLength(4));
    expect(_summary(day)['🏒 Ice Hockey'], hasLength(3));
  });

  test('title markers split sports that share a category emoji', () {
    final day =
        DaddyLiveEpgDay(label: 'Sat', categories: <DaddyLiveEpgCategory>[
      _category('Boxing 🥊', <DaddyLiveEpgEvent>[_event('🥊 DREAM Boxing')]),
      _category('MMA 🥊👊', <DaddyLiveEpgEvent>[
        _event('🥋 🇪🇪 RWS : Q vs R'),
        _event('🥋 🇹🇭 ONE Friday Fights'),
      ]),
      _category('UFC Fight Night 🥊👊', <DaddyLiveEpgEvent>[
        _event('🥋 🇧🇷 UFC Fight Night Prelims'),
      ]),
    ]);

    expect(_summary(day).keys, <String>['🥊 Boxing', '🥋 MMA']);
    expect(_summary(day)['🥋 MMA'], hasLength(3));
  });

  test(
      'bucket categories file marked events under their sport and keep the rest',
      () {
    final day =
        DaddyLiveEpgDay(label: 'Fri', categories: <DaddyLiveEpgCategory>[
      _category('PPV Events', <DaddyLiveEpgEvent>[
        _event('Weekly Racing at Stafford Speedway'),
        _event('🏋️ Mr. Olympia 2026'),
      ]),
      _category('Upcoming Events', <DaddyLiveEpgEvent>[
        _event('🏎️🇦🇿 Formula 1 Grand Prix Baku – Race', hour: 11),
      ]),
      _category('Motorsport 🏎️🏁', <DaddyLiveEpgEvent>[
        _event('🏎️ 🇦🇿 Formula 2 : Sprint Race', hour: 8),
        // Listed twice upstream; shown once.
        _event('🏎️ 🇦🇿 Formula 2 : Sprint Race', hour: 8),
      ]),
    ]);

    expect(_summary(day), <String, List<String>>{
      'PPV Events': <String>[
        'Weekly Racing at Stafford Speedway',
        '🏋️ Mr. Olympia 2026',
      ],
      '🏎️ Motorsport': <String>[
        '🏎️ 🇦🇿 Formula 2 : Sprint Race',
        '🏎️🇦🇿 Formula 1 Grand Prix Baku – Race',
      ],
    });
  });
}
