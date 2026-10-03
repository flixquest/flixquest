import 'package:flixquest/core/storage/secure_token_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('token survives a new wrapper and logout removes only the session token',
      () async {
    final values = <String, String>{'unrelated': 'keep'};
    const channel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = Map<String, dynamic>.from(call.arguments as Map);
      final key = args['key'] as String;
      switch (call.method) {
        case 'write':
          values[key] = args['value'] as String;
          return null;
        case 'read':
          return values[key];
        case 'delete':
          values.remove(key);
          return null;
      }
      throw StateError('Unexpected secure storage method');
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final store = SecureTokenStore();
    await store.write('sanitized-session-token');
    expect(await SecureTokenStore().read(), 'sanitized-session-token');
    await store.clear();
    expect(await store.read(), isNull);
    expect(values['unrelated'], 'keep');
  });

  test('empty credentials cannot become a stored session', () {
    expect(() => SecureTokenStore().write('  '), throwsArgumentError);
  });
}
