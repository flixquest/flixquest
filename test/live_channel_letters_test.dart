import 'package:flutter_test/flutter_test.dart';
import 'package:flixquest/functions/live_channel_letters.dart';
import 'package:flixquest/models/live_tv.dart';

Channel _channel(String name) => Channel(id: name, name: name);

void main() {
  test('files channels under their first Latin letter, others under #', () {
    expect(channelLetter(_channel('  espn')), 'E');
    expect(channelLetter(_channel('beIN Sports')), 'B');
    expect(channelLetter(_channel('5 USA')), '#');
    expect(channelLetter(_channel('Ñ Deportes')), '#');
    expect(channelLetter(_channel('')), '#');
  });

  test('lists only letters in use, # last', () {
    expect(
      channelLetters(<Channel>[
        _channel('Sky Sports'),
        _channel('10 Sports'),
        _channel('ABC'),
        _channel('Setanta'),
      ]),
      <String>['A', 'S', '#'],
    );
  });
}
