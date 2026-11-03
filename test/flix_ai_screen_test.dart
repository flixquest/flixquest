import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/data/models/flix_ai.dart';
import 'package:flixquest/mobile/screens/flix_ai_screen.dart';
import 'package:flixquest/presentation/flix_ai/flix_ai_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'presentation/flix_ai_controller_test.dart' show FakeFlixAiRepository;
import 'support/tv_localization.dart';

void main() {
  initializeTvTranslations();

  Future<FlixAiController> pumpChat(WidgetTester tester,
      {String? owner = 'user:1',
      FakeFlixAiRepository? repository,
      void Function(BuildContext, MediaItem)? open,
      Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final account = ValueNotifier(owner);
    final chat = FlixAiController(repository ?? FakeFlixAiRepository(),
        owner: account, language: () => 'en');
    addTearDown(() {
      chat.dispose();
      account.dispose();
    });
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: FlixAiScreen(controller: chat, onOpenTitle: open)));
    await tester.pumpAndSettle();
    return chat;
  }

  testWidgets('guests see a sign in prompt and cannot send', (tester) async {
    final chat = await pumpChat(tester, owner: null);
    expect(
        find.text(
            'Sign in or create a free account to discover your next favorite with FlixAI.'),
        findsOneWidget);
    expect(chat.canSend, false);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recommendation cards open the matching real title',
      (tester) async {
    final repository = FakeFlixAiRepository();
    repository.answers.add(() async => FlixAiReply(
        const FlixAiTurn(
            id: 'turn-1',
            conversationId: 'chat-1',
            message: 'Romance',
            reply: 'Warm romances for your evening.',
            keywords: [
              'romantic comedy'
            ],
            recommendations: [
              MediaItem(
                  kind: MediaKind.movie,
                  id: 1581,
                  title: 'The Holiday',
                  overview: 'A warm romance.',
                  posterPath: null,
                  backdropPath: null,
                  rating: 7.1,
                  releaseDate: '2006-12-08')
            ]),
        FakeFlixAiRepository.usage()));
    final opened = <int>[];
    await pumpChat(tester,
        repository: repository, open: (_, item) => opened.add(item.id));
    await tester.enterText(find.byType(TextField), 'Romance');
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();

    expect(find.text('Warm romances for your evening.'), findsOneWidget);
    expect(find.text('romantic comedy'), findsOneWidget);
    await tester.tap(find.text('The Holiday'));
    expect(opened, [1581]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the latest reply stays in view when the keyboard opens',
      (tester) async {
    final repository = FakeFlixAiRepository();
    for (var index = 1; index <= 4; index++) {
      repository.answers.add(() async => FlixAiReply(
          FlixAiTurn(
              id: 'turn-$index',
              conversationId: 'chat-1',
              message: 'Ask $index',
              reply: 'Reply $index. ${'A long, thoughtful answer. ' * 12}',
              recommendations: const []),
          FakeFlixAiRepository.usage(remaining: 9)));
    }
    await pumpChat(tester, repository: repository);
    for (var index = 1; index <= 4; index++) {
      await tester.enterText(find.byType(TextField), 'Ask $index');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
    }

    tester.view.viewInsets = const FakeViewPadding(bottom: 340);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    final latest = tester.getRect(find.textContaining('Reply 4.'));
    final composer = tester.getRect(find.byType(TextField));
    expect(latest.bottom, lessThanOrEqualTo(composer.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the quota state and input fit a narrow phone and a wide screen',
      (tester) async {
    for (final size in [const Size(320, 720), const Size(1280, 720)]) {
      final repository = FakeFlixAiRepository();
      repository.available =
          FlixAiAvailability(true, FakeFlixAiRepository.usage(remaining: 0));
      final chat = await pumpChat(tester, repository: repository, size: size);
      expect(find.text('0 of 5 requests left today'), findsOneWidget);
      expect(chat.canSend, false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('deleting a chat from history asks first', (tester) async {
    final repository = FakeFlixAiRepository();
    final chat = await pumpChat(tester, repository: repository);
    chat.conversations = const [
      FlixAiConversation(id: 'chat-1', title: 'Cosy mysteries')
    ];
    await tester.tap(find.byTooltip('Your chats'));
    await tester.pumpAndSettle();
    expect(find.text('Cosy mysteries'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete chat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.deleted, isEmpty);

    await tester.tap(find.byTooltip('Delete chat'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Delete chat').last);
    await tester.pumpAndSettle();
    expect(repository.deleted, ['chat-1']);
    expect(tester.takeException(), isNull);
  });
}
