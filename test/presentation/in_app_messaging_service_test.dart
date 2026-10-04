import 'dart:async';
import 'package:flixquest/data/repositories/announcement_repository.dart';
import 'package:flixquest/presentation/notifications/in_app_message_controller.dart';
import 'package:flixquest/services/in_app_messaging_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fake_push_messaging.dart';
import '../support/session_harness.dart';

void main() {
  late SessionHarness h;
  late FakePushMessaging push;
  late InAppMessageController controller;
  setUp(() async {
    h = await SessionHarness.create();
    push = FakePushMessaging();
    controller = InAppMessageController(AnnouncementRepository(h.dio),
        h.preferences, InAppMessagingService.present);
  });
  tearDown(() async {
    InAppMessagingService.dispose();
    controller.dispose();
    await push.dispose();
    await h.dispose();
  });
  Widget app() => MaterialApp(
      navigatorKey: InAppMessagingService.navigatorKey,
      home: const Scaffold(body: Text('Home')));

  for (final type in ['modal', 'bottom_sheet', 'banner']) {
    testWidgets(
        'Laravel $type renders through the unchanged dialog and FCM cannot duplicate it',
        (tester) async {
      await tester.pumpWidget(app());
      InAppMessagingService.initialize(messages: controller, messaging: push);
      h.adapter.enqueueJson({
        'success': true,
        'messages': [
          {
            'id': 42,
            'title': 'Release $type',
            'body': 'Watch now',
            'display_type': type
          },
        ]
      });
      final polling = controller.boot();
      await tester.pumpAndSettle();
      expect(find.text('Release $type'), findsOneWidget);
      expect(find.text('Watch now'), findsOneWidget);
      expect(h.preferences.getStringList('notifications.announcements.shown'),
          ['42']);
      push.foreground.add({
        'type': 'in_app_message',
        'announcement_id': '42',
        'title': 'Duplicate'
      });
      push.opened.add({
        'type': 'in_app_message',
        'announcement_id': '42',
        'title': 'Duplicate tap'
      });
      await tester.pumpAndSettle();
      expect(find.text('Duplicate'), findsNothing);
      expect(find.text('Duplicate tap'), findsNothing);
      if (type == 'banner') {
        final context = InAppMessagingService.navigatorKey.currentContext!;
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      } else {
        InAppMessagingService.navigatorKey.currentState!.pop();
      }
      await tester.pumpAndSettle();
      await polling;
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
      'cold-start FCM waits for navigation and subscriptions are replaced and disposed',
      (tester) async {
    var hints = 0;
    push.initial = {
      'type': 'in_app_message',
      'announcement_id': '9',
      'title': 'Cold start'
    };
    InAppMessagingService.initialize(
        messages: controller,
        messaging: push,
        onConfigHint: (_) async {
          hints++;
          throw StateError('Config offline');
        });
    await tester.pump();
    expect(h.preferences.getStringList('notifications.announcements.shown'),
        isNull);
    await tester.pumpWidget(app());
    final presentation = controller.onReady();
    await tester.pumpAndSettle();
    expect(find.text('Cold start'), findsOneWidget);
    InAppMessagingService.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    await presentation;
    expect(hints, 1);
    InAppMessagingService.initialize(
        messages: controller,
        messaging: push,
        onConfigHint: (_) async {
          hints++;
        });
    await tester.pumpAndSettle();
    final before = hints;
    push.foreground.add({'type': 'config_updated'});
    await tester.pump();
    expect(hints, before + 1);
    InAppMessagingService.dispose();
    push.foreground.add({'title': 'Disposed'});
    push.opened.add({'title': 'Disposed tap'});
    await tester.pumpAndSettle();
    expect(hints, before + 1);
    expect(find.text('Disposed'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('flag-off delivery still renders legacy FCM data',
      (tester) async {
    await tester.pumpWidget(app());
    InAppMessagingService.initialize(messaging: push);
    push.foreground.add(
        {'notification_title': 'Legacy delivery', 'display_type': 'banner'});
    await tester.pumpAndSettle();
    expect(find.text('Legacy delivery'), findsOneWidget);
    ScaffoldMessenger.of(InAppMessagingService.navigatorKey.currentContext!)
        .hideCurrentMaterialBanner();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('disposing subscriptions rejects a late cold-start SDK response',
      (tester) async {
    final initial = Completer<Map<String, dynamic>?>();
    push.pendingInitial = initial.future;
    var hints = 0;
    await tester.pumpWidget(app());
    InAppMessagingService.initialize(
        messages: controller,
        messaging: push,
        onConfigHint: (_) async {
          hints++;
        });
    InAppMessagingService.dispose();
    initial.complete({'announcement_id': '50', 'title': 'Late cold start'});
    await tester.pumpAndSettle();
    expect(hints, 0);
    expect(find.text('Late cold start'), findsNothing);
    expect(h.preferences.getStringList('notifications.announcements.shown'),
        isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
