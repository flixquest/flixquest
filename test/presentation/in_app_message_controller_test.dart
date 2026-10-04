import 'package:dio/dio.dart';
import 'dart:async';
import 'package:flixquest/data/repositories/announcement_repository.dart';
import 'package:flixquest/models/in_app_message_payload.dart';
import 'package:flixquest/presentation/notifications/in_app_message_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/session_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SessionHarness h;
  late InAppMessageController controller;
  late List<InAppMessagePayload> shown;
  InAppMessageController create({MessagePresenter? present}) =>
      InAppMessageController(
          AnnouncementRepository(h.dio),
          h.preferences,
          present ??
              (payload, acknowledge) async {
                shown.add(payload);
                await acknowledge();
                return true;
              });
  setUp(() async {
    h = await SessionHarness.create();
    shown = [];
    controller = create();
  });
  tearDown(() async {
    controller.dispose();
    await h.dispose();
  });
  test('API and FCM share durable announcement identities across app restarts',
      () async {
    h.adapter.enqueueJson({
      'success': true,
      'messages': [
        {'id': 42, 'title': 'Release', 'body': 'Watch now'}
      ]
    });
    await controller.boot();
    await controller.receive({
      'type': 'in_app_message',
      'announcement_id': '42',
      'title': 'Release'
    });
    expect(shown.map((p) => p.id), ['42']);
    controller.dispose();
    controller = create();
    h.adapter.enqueueJson({
      'success': true,
      'messages': [
        {'id': 42, 'title': 'Release'}
      ]
    });
    await controller.boot();
    await controller
        .receive({'announcementId': '42', 'notification_title': 'Release'});
    expect(shown.length, 1);
  });
  test(
      'unready navigation retains messages, skips expiry, and never consumes an unseen id',
      () async {
    var ready = false;
    var now = DateTime.utc(2026, 10, 4, 12);
    controller.dispose();
    controller =
        InAppMessageController(AnnouncementRepository(h.dio), h.preferences,
            (payload, acknowledge) async {
      if (!ready) return false;
      shown.add(payload);
      await acknowledge();
      return true;
    }, now: () => now);
    await controller.receive({
      'announcement_id': '4',
      'title': 'Pending',
      'ends_at': '2026-10-04T12:01:00Z'
    });
    await controller.receive({'announcement_id': '5', 'title': 'Still active'});
    expect(shown, isEmpty);
    expect(h.preferences.getStringList('notifications.announcements.shown'),
        isNull);
    now = now.add(const Duration(minutes: 2));
    ready = true;
    await controller.onReady();
    expect(shown.map((p) => p.id), ['5']);
    expect(h.preferences.getStringList('notifications.announcements.shown'),
        ['5']);
    await controller
        .receive({'announcement_id': '4', 'title': 'Now available'});
    expect(shown.map((p) => p.id), ['5', '4']);
  });

  test('queued dialogs are serialized and acknowledged before dismissal',
      () async {
    final dismissed = Completer<void>();
    final opened = Completer<void>();
    controller.dispose();
    controller = create(present: (payload, acknowledge) async {
      shown.add(payload);
      await acknowledge();
      if (payload.id == '1') {
        opened.complete();
        await dismissed.future;
      }
      return true;
    });
    final first =
        controller.receive({'announcement_id': '1', 'title': 'First'});
    await opened.future;
    final duplicate =
        controller.receive({'announcement_id': '1', 'title': 'Duplicate'});
    final second = controller.receive(
        {'announcement_id': '2', 'title': 'Second', 'display_type': 'banner'});
    expect(shown.map((p) => p.id), ['1']);
    expect(h.preferences.getStringList('notifications.announcements.shown'),
        ['1']);
    dismissed.complete();
    await Future.wait([first, duplicate, second]);
    expect(shown.map((p) => p.id), ['1', '2']);
    expect(shown.last.displayType, 'banner');
  });

  test(
      'config hints and blank or inactive payloads do not display; legacy aliases still display',
      () async {
    await controller.receive({'type': 'config_updated', 'version': '9'});
    await controller.receive({'type': 'in_app_message'});
    await controller
        .receive({'title': 'Expired', 'ends_at': '2000-01-01T00:00:00Z'});
    await controller
        .receive({'title': 'Future', 'starts_at': '2099-01-01T00:00:00Z'});
    await controller.receive({
      'notification_title': 'Legacy',
      'notification_body': 'Body',
      'displayType': 'BOTTOM_SHEET'
    });
    expect(shown.length, 1);
    expect(shown.single.title, 'Legacy');
    expect(shown.single.body, 'Body');
    expect(shown.single.displayType, 'bottom_sheet');
  });

  test('disposed controllers ignore future delivery and do not poll', () async {
    controller.dispose();
    await controller.boot();
    await controller.receive({'title': 'Late'});
    await controller.onReady();
    expect(h.adapter.requests, isEmpty);
    expect(shown, isEmpty);
  });
  test(
      'a poll that finishes after disposal never presents or acknowledges its messages',
      () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    h.adapter.enqueueJson({
      'success': true,
      'messages': [
        {'id': 20, 'title': 'Late response'}
      ]
    });
    h.dio.interceptors
        .add(InterceptorsWrapper(onRequest: (request, handler) async {
      entered.complete();
      await release.future;
      handler.next(request);
    }));
    final work = controller.boot();
    await entered.future;
    controller.dispose();
    release.complete();
    await work;
    expect(shown, isEmpty);
    expect(h.preferences.getStringList('notifications.announcements.shown'),
        isNull);
  });
}
