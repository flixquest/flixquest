import 'dart:async';

import 'package:flixquest/mobile/widgets/pill_button.dart';
import 'package:flixquest/mobile/widgets/episode_row.dart';
import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/models/tv.dart';
import 'package:flixquest/screens/common/player/player_sheet_ui.dart';
import 'package:flixquest/screens/common/player/player_watch_page.dart';
import 'package:flixquest/tv/widgets/tv_content_row.dart';
import 'package:flixquest/tv/widgets/tv_pill_button.dart';
import 'package:flixquest/widgets/playback_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _playButton(String label, Future<void> Function() action) =>
    PlaybackAction(
      onStart: action,
      builder: (context, busy, start) => PillButton(
        label: label,
        busy: busy,
        onPressed: start,
      ),
    );

void main() {
  final cards = <String, Widget Function(Future<void> Function())>{
    'player menu': (play) => PlayerChoiceCard(title: 'Play', onTap: play),
    'up next': (play) => WatchUpNextCard(title: 'Play', onPlay: play),
    'player episode': (play) =>
        WatchEpisodeTile(number: 1, title: 'Play', onTap: play),
    'episode list': (play) => EpisodeRow(
          series: MediaItem.fromSeries(TV(id: 1, name: 'Series')),
          episode: EpisodeList(episodeId: 1, episodeNumber: 1, name: 'Play'),
          aired: true,
          progress: null,
          canPlay: true,
          canDownload: false,
          onPlay: play,
        ),
  };
  for (final entry in cards.entries) {
    testWidgets('${entry.key} shows progress and ignores rapid play taps',
        (tester) async {
      final pending = Completer<void>();
      var starts = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: entry.value(() {
          starts++;
          return pending.future;
        })),
      ));
      final tap = tester.widget<InkWell>(find.byType(InkWell).first).onTap!;
      tap();
      tap();
      await tester.pump();
      expect(starts, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  }

  testWidgets(
      'locks before a rebuild and blocks other play controls on the page',
      (tester) async {
    final pending = Completer<void>();
    var starts = 0;
    Future<void> play() {
      starts++;
      return pending.future;
    }

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: <Widget>[
          _playButton('Play', play),
          _playButton('Play from start', play),
        ]),
      ),
    ));
    final taps = tester.widgetList<InkWell>(find.byType(InkWell)).toList();
    taps.first.onTap!();
    taps.first.onTap!();
    taps.last.onTap!();
    expect(starts, 1);

    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<InkWell>(find.byType(InkWell).first).onTap, isNull);

    pending.complete();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text('Play from start'));
    await tester.pump();
    expect(starts, 2);
  });

  testWidgets('releases the guard when preparation fails', (tester) async {
    late BuildContext host;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        host = context;
        return const Scaffold();
      }),
    ));
    await expectLater(
      PlaybackAction.run(host, () async => throw StateError('offline')),
      throwsStateError,
    );
    var starts = 0;
    await PlaybackAction.run(host, () => starts++);
    expect(starts, 1);
  });

  testWidgets('an old callback cannot stack a loader after player handoff',
      (tester) async {
    late BuildContext host;
    late VoidCallback start;
    var starts = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PlaybackAction(
          onStart: () async {
            starts++;
            await Navigator.of(host).push<void>(MaterialPageRoute<void>(
              builder: (_) => Builder(builder: (loaderContext) {
                return TextButton(
                  onPressed: () {
                    final navigator = Navigator.of(loaderContext);
                    final loader = ModalRoute.of(loaderContext)!;
                    navigator.push<void>(MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(body: Text('Player')),
                    ));
                    navigator.removeRoute(loader);
                  },
                  child: const Text('Stream ready'),
                );
              }),
            ));
          },
          builder: (context, busy, activate) {
            host = context;
            start = activate;
            return PillButton(label: 'Play', busy: busy, onPressed: activate);
          },
        ),
      ),
    ));
    start();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stream ready'));
    await tester.pumpAndSettle();
    start();
    await tester.pump();
    expect(starts, 1);
    expect(find.text('Player'), findsOneWidget);

    Navigator.of(host).pop();
    await tester.pumpAndSettle();
    start();
    await tester.pumpAndSettle();
    expect(starts, 2);
  });

  testWidgets('completion after the control is disposed is safe',
      (tester) async {
    final pending = Completer<void>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: _playButton('Play', () => pending.future)),
    ));
    await tester.tap(find.text('Play'));
    await tester.pumpWidget(const SizedBox());
    pending.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'TV buttons show loading and keep focus during repeated OK presses',
      (tester) async {
    final pending = Completer<void>();
    final focus = FocusNode();
    addTearDown(focus.dispose);
    var starts = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TvPillButton(
          label: 'Play',
          focusNode: focus,
          autofocus: true,
          onActivate: () {
            starts++;
            return pending.future;
          },
        ),
      ),
    ));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(starts, 1);
    expect(focus.hasFocus, isTrue);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
      'TV continue and episode rows await playback instead of discarding it',
      (tester) async {
    final pending = Completer<void>();
    var starts = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TvContentRow<int>(
          title: 'Continue Watching',
          scopeId: 'continue',
          items: const <int>[1, 2],
          itemId: (item) => '$item',
          semanticLabel: (item) => 'Title $item',
          itemBuilder: (_, item) => SizedBox(
            width: 100,
            height: 80,
            child: Text('Title $item'),
          ),
          onItemActivated: (_) {
            starts++;
            return pending.future;
          },
        ),
      ),
    ));
    await tester.tap(find.text('Title 1'));
    await tester.tap(find.text('Title 2'));
    await tester.pump();
    expect(starts, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
