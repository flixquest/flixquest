import 'package:flixquest/core/json/json_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('snake/camel aliases preserve false and zero while skipping null', () {
    final json =
        JsonReader({'profile_id': null, 'profileId': '12', 'enabled': false});
    expect(JsonReader.asInt(json.firstOf(['profile_id', 'profileId'])), 12);
    expect(json.firstOf(['enabled']), false);
    expect(JsonReader.asInt('garbage'), isNull);
  });

  test('nullable typed reads reject malformed payloads without throwing', () {
    expect(JsonReader.asInt(3.5), isNull);
    expect(JsonReader.asInt(double.infinity), isNull);
    expect(JsonReader.asDouble('2.2'), 2.2);
    expect(JsonReader.asDouble('NaN'), isNull);
    expect(JsonReader.asBool('FALSE'), isFalse);
    expect(JsonReader.asBool('1'), isTrue);
    expect(JsonReader.asBool('maybe'), isNull);
    expect(JsonReader.asString(12), '12');
    expect(JsonReader.asString({}), isNull);
    expect(JsonReader.asList(null), isNull);
    expect(JsonReader.asList([1, 'two']), [1, 'two']);
    expect(JsonReader.asMap({1: 'bad key'}), isNull);
    expect(JsonReader.asMap({'id': 7}), {'id': 7});
  });
}
