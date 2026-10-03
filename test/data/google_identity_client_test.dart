import 'package:flixquest/data/sources/google_identity_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

class PluginAuth implements GoogleSignInAuthentication {
  PluginAuth({this.accessToken, this.idToken});
  @override
  final String? accessToken;
  @override
  final String? idToken;
  @override
  String? get serverAuthCode => null;
}

class PluginAccount implements GoogleSignInAccount {
  PluginAccount(this.auth);
  final GoogleSignInAuthentication auth;
  @override
  Future<GoogleSignInAuthentication> get authentication async => auth;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PluginClient extends GoogleSignIn {
  GoogleSignInAccount? account;
  int signOuts = 0;
  @override
  Future<GoogleSignInAccount?> signIn() async => account;
  @override
  Future<GoogleSignInAccount?> signOut() async {
    signOuts++;
    return null;
  }
}

void main() {
  test('prefers the OAuth access token when both Google tokens exist',
      () async {
    final plugin = PluginClient()
      ..account =
          PluginAccount(PluginAuth(accessToken: 'access', idToken: 'id'));
    expect(await PlatformGoogleIdentityClient(client: plugin).authenticate(),
        'access');
  });
  test('falls back to the ID token when the access token is empty', () async {
    final plugin = PluginClient()
      ..account = PluginAccount(PluginAuth(accessToken: '', idToken: 'id'));
    expect(await PlatformGoogleIdentityClient(client: plugin).authenticate(),
        'id');
  });
  test('cancel returns null without an exchange', () async {
    expect(
        await PlatformGoogleIdentityClient(client: PluginClient())
            .authenticate(),
        null);
  });
  test('missing Google tokens produce a useful error', () async {
    final plugin = PluginClient()..account = PluginAccount(PluginAuth());
    await expectLater(
        PlatformGoogleIdentityClient(client: plugin).authenticate(),
        throwsFormatException);
  });
  test('logout calls the Google plugin once', () async {
    final plugin = PluginClient();
    await PlatformGoogleIdentityClient(client: plugin).signOut();
    expect(plugin.signOuts, 1);
  });
}
