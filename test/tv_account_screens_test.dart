import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/data/models/auth_requests.dart';
import 'package:flixquest/presentation/session/auth_runtime.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/services/in_app_messaging_service.dart';
import 'package:flixquest/tv/app/tv_design.dart';
import 'package:flixquest/tv/screens/tv_account_screens.dart';
import 'package:flixquest/tv/screens/tv_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/session_harness.dart';
import 'support/tv_localization.dart';

Future<SessionHarness> _signIn() async {
  final harness = await SessionHarness.create();
  AuthRuntime.configure(harness.session);
  harness.adapter.enqueueJson(authFixture());
  await harness.session.signIn(
    const LoginRequest(email: 'beamlak@example.com', password: 'secret123'),
  );
  sharedPrefsSingleton = await SharedPreferences.getInstance();
  return harness;
}

String? get _focused => FocusManager.instance.primaryFocus?.debugLabel;

/// Opens [page] over a plain home, as the profile does.
Future<void> _pump(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(960, 540);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ChangeNotifierProvider(create: (_) => AppDependencyProvider()),
    ],
    child: MaterialApp(
      navigatorKey: InAppMessagingService.navigatorKey,
      home: const Scaffold(body: Text('home')),
    ),
  ));
  InAppMessagingService.navigatorKey.currentState!
      .push(MaterialPageRoute<void>(builder: (_) => page));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String text) async {
  for (final character in text.split('')) {
    final lower = character.toLowerCase();
    if (character != lower) {
      await tester.tap(find.byKey(const ValueKey('tv-form-key-shift')));
      await tester.pump();
    }
    final id = character == ' ' ? 'space' : lower;
    await tester.tap(find.byKey(ValueKey('tv-form-key-$id')));
    await tester.pump();
  }
}

/// Lets a request the session sends (on the real clock, where it was made)
/// come back, pumping frames between, without waiting on a spinner that
/// turns until it does.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _key(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(ValueKey('tv-form-key-$id')));
  await _settle(tester);
}

Map<String, dynamic> _userJson({String name = 'Beamlak Aschalew'}) =>
    <String, dynamic>{
      'success': true,
      'user': <String, dynamic>{
        ...(authFixture()['user'] as Map<String, dynamic>),
        'name': name,
        'fullName': name,
      },
    };

void main() {
  initializeTvTranslations();
  late SessionHarness harness;

  setUpAll(() {
    dotenv.testLoad(fileInput: 'FLIXQUEST_API_URL=http://scraper.test\n');
  });

  Future<void> signIn(WidgetTester tester) async {
    harness = (await tester.runAsync(_signIn))!;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      // Signing out leaves cache work on the test clock; it has to finish
      // before the harness, which waits on it, can close.
      final disposed = tester.runAsync(harness.dispose);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      await disposed;
    });
  }

  dynamic lastBody() => harness.adapter.requests.last.data;
  String lastPath() => harness.adapter.requests.last.uri.path;

  testWidgets('the profile opens Manage account, which lists every change',
      (tester) async {
    await signIn(tester);
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final metrics = TvShellMetrics.fromConstraints(
      const BoxConstraints.tightFor(width: 960, height: 540),
    );
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AppDependencyProvider()),
      ],
      child: MaterialApp(
        home: Scaffold(body: TvProfileScreen(metrics: metrics)),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Manage account'));
    await tester.pumpAndSettle();
    expect(find.byType(TvManageAccountScreen), findsOneWidget);
    expect(_focused, 'TV account edit profile');
    expect(find.text('Beamlak Aschalew · @beamlak'), findsOneWidget);
    expect(find.text('beamlak@example.com'), findsOneWidget);
    for (final label in <String>[
      'Edit profile',
      'Change email',
      'Change password',
      'Delete account',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.byType(TvChangeEmailScreen), findsOneWidget);
  });

  testWidgets('editing the profile saves the name and the picture chosen',
      (tester) async {
    await signIn(tester);
    await _pump(tester, const TvEditProfileScreen());
    expect(find.text('Beamlak Aschalew'), findsOneWidget);
    expect(find.text('beamlak'), findsOneWidget);

    await _key(tester, 'clear');
    await _type(tester, 'Bea A');
    // Picked as the remote would reach it: scrolled into the row's view.
    final picture = find.byKey(const ValueKey('tv-edit-profile-pictures:5'));
    await tester.ensureVisible(picture);
    await tester.pumpAndSettle();
    await tester.tap(picture);
    await tester.pumpAndSettle();
    expect(find.text('Bea A'), findsOneWidget);

    harness.adapter.enqueueJson(_userJson(name: 'Bea A'));
    // Next to the username, then Save from the last field.
    await _key(tester, 'action');
    await _key(tester, 'action');

    expect(lastPath(), endsWith('user/profile'));
    expect(lastBody(), <String, dynamic>{
      'name': 'Bea A',
      'username': 'beamlak',
      'profile_id': 5,
      'photo_url': '',
    });
    expect(find.byType(TvEditProfileScreen), findsNothing);
    expect(find.text('Profile updated'), findsOneWidget);
    expect(AuthRuntime.session.user?.name, 'Bea A');
  });

  testWidgets('a username someone else has is refused before saving',
      (tester) async {
    await signIn(tester);
    await _pump(tester, const TvEditProfileScreen());
    await _key(tester, 'action');
    await _type(tester, '2');

    harness.adapter
        .enqueueJson(<String, dynamic>{'success': true, 'available': false});
    await _key(tester, 'action');

    expect(lastPath(), endsWith('users/check-username'));
    expect(find.text('That username is already in use.'), findsOneWidget);
    expect(find.byType(TvEditProfileScreen), findsOneWidget);
  });

  testWidgets(
      'changing the password checks the repeat, then signs out to sign in '
      'with it', (tester) async {
    await signIn(tester);
    await _pump(tester, const TvChangePasswordScreen());
    final before = harness.adapter.requests.length;

    await _type(tester, 'secret123');
    await _key(tester, 'action');
    await _type(tester, 'newsecret1');
    await _key(tester, 'action');
    await _type(tester, 'newsecret2');
    await _key(tester, 'action');
    expect(find.text("The passwords don't match."), findsOneWidget);
    expect(harness.adapter.requests.length, before, reason: 'nothing sent');

    await _key(tester, 'delete');
    await _type(tester, '1');
    harness.adapter.enqueueJson(<String, dynamic>{'success': true});
    await _key(tester, 'action');

    expect(lastPath(), endsWith('user/change-password'));
    expect(lastBody(), <String, dynamic>{
      'current_password': 'secret123',
      'password': 'newsecret1',
    });
    expect(harness.tokens.value, isNull);
    expect(find.byType(TvChangePasswordScreen), findsNothing);
    expect(
      find.text('Password changed. Sign in again with your new password.'),
      findsOneWidget,
    );
  });

  testWidgets('a wrong current password shows what the server says',
      (tester) async {
    await signIn(tester);
    await _pump(tester, const TvChangeEmailScreen());

    await _type(tester, 'wrong');
    await _key(tester, 'action');
    await _type(tester, 'new@example.com');
    await _key(tester, 'action');
    await _type(tester, 'new@example.com');
    harness.adapter.enqueueJson(<String, dynamic>{
      'success': false,
      'message': 'The current password is incorrect.',
      'errors': <String, dynamic>{
        'current_password': <String>['The current password is incorrect.'],
      },
    }, statusCode: 422);
    await _key(tester, 'action');

    expect(lastPath(), endsWith('user/change-email'));
    expect(find.text('The current password is incorrect.'), findsOneWidget);
    expect(find.byType(TvChangeEmailScreen), findsOneWidget);
    expect(_focused, isNotNull);
  });

  testWidgets('changing the email sends the new address', (tester) async {
    await signIn(tester);
    await _pump(tester, const TvChangeEmailScreen());

    await _type(tester, 'secret123');
    await _key(tester, 'action');
    await _type(tester, 'New@example.com');
    await _key(tester, 'action');
    await _type(tester, 'other@example.com');
    await _key(tester, 'action');
    expect(find.text("The email addresses don't match."), findsOneWidget);

    await _key(tester, 'clear');
    await _type(tester, 'new@example.com');
    harness.adapter.enqueueJson(_userJson());
    await _key(tester, 'action');

    expect(lastBody(), <String, dynamic>{
      'current_password': 'secret123',
      'email': 'new@example.com',
    });
    expect(find.byType(TvChangeEmailScreen), findsNothing);
    expect(find.text('Email changed. Check your inbox to verify it.'),
        findsOneWidget);
  });

  testWidgets('deleting asks for DELETE, and again about wallet credit',
      (tester) async {
    await signIn(tester);
    await _pump(tester, const TvDeleteAccountScreen());
    final before = harness.adapter.requests.length;

    await _type(tester, 'delet');
    await _key(tester, 'action');
    expect(find.text('Type DELETE to confirm.'), findsWidgets);
    expect(harness.adapter.requests.length, before);

    await _type(tester, 'e');
    harness.adapter.enqueueJson(<String, dynamic>{
      'success': false,
      'message': 'Your FlixQuest balance still has credit.',
      'code': 'wallet_credit_remaining',
    }, statusCode: 409);
    await _key(tester, 'action');
    expect(find.text('Your balance still has credit'), findsOneWidget);
    expect(_focused, 'Cancel', reason: 'the safe choice has focus');

    harness.adapter.enqueueJson(<String, dynamic>{'success': true});
    await tester.tap(find.text('Delete anyway'));
    await _settle(tester);

    expect(lastPath(), endsWith('user/account'));
    expect(lastBody(), <String, dynamic>{'acknowledge_wallet_credit': true});
    expect(AuthRuntime.session.user, isNull);
    expect(find.byType(TvDeleteAccountScreen), findsNothing);
    expect(find.text('Your account was deleted'), findsOneWidget);
  });

  testWidgets('cancelling the credit question keeps the account',
      (tester) async {
    await signIn(tester);
    await _pump(tester, const TvDeleteAccountScreen());
    await _type(tester, 'DELETE');
    harness.adapter.enqueueJson(<String, dynamic>{
      'success': false,
      'message': 'Your FlixQuest balance still has credit.',
      'code': 'wallet_credit_remaining',
    }, statusCode: 409);
    await _key(tester, 'action');
    final sent = harness.adapter.requests.length;

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await _settle(tester);
    expect(harness.adapter.requests.length, sent);
    expect(AuthRuntime.session.user, isNotNull);
    expect(find.byType(TvDeleteAccountScreen), findsOneWidget);
  });
}
