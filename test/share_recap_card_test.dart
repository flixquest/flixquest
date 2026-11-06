import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flixquest/models/wellness.dart';
import 'package:flixquest/models/wellness_insights.dart';
import 'package:flixquest/models/wellness_recap.dart';
import 'package:flixquest/models/wellness_recap_story.dart';
import 'package:flixquest/screens/wellness/widgets/share_recap_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(initializeDateFormatting);

  void loadLocale(String language) => Localization.load(
        Locale(language),
        translations: Translations(
          jsonDecode(
                  File('assets/translations/$language.json').readAsStringSync())
              as Map<String, dynamic>,
        ),
      );

  setUp(() => loadLocale('en'));

  final now = DateTime(2026, 11, 6, 21);
  final periods = <WellnessRecapPeriod>[
    WellnessRecapPeriod.today(DateTime(2026, 10, 3, 23)),
    WellnessRecapPeriod.week(DateTime(2026, 10, 7, 23)),
    WellnessRecapPeriod.month(DateTime(2026, 10), now),
    WellnessRecapPeriod.year(2026),
  ];

  WellnessRecapStory storyOf(
    List<WellnessViewingSession> sessions,
    WellnessRecapPeriod period,
  ) =>
      WellnessRecapStory.of(
        WellnessInsights.fromSessions(
          sessions,
          period: period.wellnessPeriod,
        ),
        period,
      );

  Widget card(
    WellnessRecapStory story, {
    ShareRecapFormat format = ShareRecapFormat.post,
    ShareRecapStyle style = ShareRecapStyle.dark,
    bool titles = true,
    bool habits = true,
    TextDirection direction = TextDirection.ltr,
    double textScale = 1,
    GlobalKey? boundary,
  }) =>
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Directionality(
          textDirection: direction,
          child: Center(
            child: SizedBox(
              width: 320,
              child: RepaintBoundary(
                key: boundary,
                child: AspectRatio(
                  aspectRatio: format.aspectRatio,
                  child: ShareRecapCard(
                    story: story,
                    format: format,
                    style: style,
                    includeTitles: titles,
                    includeHabits: habits,
                    artFor: (path, kind) => MemoryImage(_pixel),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  void useTallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  for (final format in ShareRecapFormat.values) {
    for (final language in ['en', 'ar', 'es', 'hi', 'it', 'fr']) {
      testWidgets('${format.name} fits every period in $language',
          (tester) async {
        useTallView(tester);
        loadLocale(language);
        final direction =
            language == 'ar' ? TextDirection.rtl : TextDirection.ltr;
        final histories = <List<WellnessViewingSession>>[
          const [],
          [_film('one', DateTime(2026, 10, 3, 20), poster: '/a.jpg')],
          _busyHistory(),
          [
            _film('no art', DateTime(2026, 10, 3, 20)),
            _film('live', DateTime(2026, 10, 3, 22),
                type: WellnessMediaType.live),
          ],
        ];
        for (final period in periods) {
          for (final history in histories) {
            final story = storyOf(history, period);
            for (final (titles, habits) in [
              (true, true),
              (false, false),
              (true, false),
              (false, true),
            ]) {
              await tester.pumpWidget(card(
                story,
                format: format,
                titles: titles,
                habits: habits,
                direction: direction,
              ));
              expect(
                tester.takeException(),
                isNull,
                reason: '${period.id} ${history.length} sessions '
                    'titles=$titles habits=$habits',
              );
            }
          }
        }
      });
    }

    testWidgets('${format.name} exports at 1080 pixels wide on any phone',
        (tester) async {
      useTallView(tester);
      final key = GlobalKey();
      final story = storyOf(_busyHistory(), periods[2]);
      await tester.pumpWidget(card(story, format: format, boundary: key));
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      expect(boundary.size.width, 320);
      final image = await tester.runAsync(() => boundary.toImage(
            pixelRatio: format.pixelRatioFor(boundary.size.width),
          ));
      addTearDown(image!.dispose);
      expect(image.width, ShareRecapFormat.exportWidth);
      expect(
        image.height,
        (ShareRecapFormat.exportWidth / format.aspectRatio).round(),
      );
    });
  }

  testWidgets('system text size does not change the exported layout',
      (tester) async {
    useTallView(tester);
    final story = storyOf(_busyHistory(), periods[2]);
    await tester.pumpWidget(card(story, textScale: 2.5));
    expect(tester.takeException(), isNull);
    final context = tester.element(find.text('FLIXQUEST'));
    expect(MediaQuery.textScalerOf(context), TextScaler.noScaling);
  });

  group('privacy', () {
    final october = WellnessRecapPeriod.month(DateTime(2026, 10), now);

    testWidgets('titles off removes every title and all artwork',
        (tester) async {
      useTallView(tester);
      final story = storyOf(_busyHistory(), october);
      await tester.pumpWidget(card(
        story,
        format: ShareRecapFormat.story,
        titles: false,
      ));
      expect(find.textContaining('Top film'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(ShareRecapCard),
          matching: find.byWidgetPredicate(
            (widget) => widget is Image && widget.image is MemoryImage,
          ),
        ),
        findsNothing,
      );
      expect(
        ShareRecapCard.artworkOf(
          story: story,
          format: ShareRecapFormat.story,
          includeTitles: false,
          artFor: (path, kind) => MemoryImage(_pixel),
        ),
        isEmpty,
      );
    });

    testWidgets('habits off removes the viewer type, genres and busiest day',
        (tester) async {
      useTallView(tester);
      final story = storyOf(_busyHistory(), october);
      expect(story.profile?.type, WellnessViewerType.nightOwl);

      await tester.pumpWidget(card(story, format: ShareRecapFormat.story));
      expect(find.text('The Night Owl'), findsOneWidget);
      expect(find.text('Thriller'), findsOneWidget);
      expect(find.textContaining('Busiest day'), findsOneWidget);

      await tester.pumpWidget(card(
        story,
        format: ShareRecapFormat.story,
        habits: false,
      ));
      expect(find.text('The Night Owl'), findsNothing);
      expect(find.textContaining('late at night'), findsNothing);
      expect(find.text('Thriller'), findsNothing);
      expect(find.textContaining('Busiest day'), findsNothing);
    });

    testWidgets('habits off hides the hours of a single day', (tester) async {
      useTallView(tester);
      final day = periods.first;
      final story = storyOf(
        [_film('one', DateTime(2026, 10, 3, 23), poster: '/a.jpg')],
        day,
      );
      bool hasChart() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .any((paint) =>
              paint.painter.runtimeType.toString() == '_RhythmPainter');

      await tester.pumpWidget(card(story));
      expect(hasChart(), isTrue);
      await tester.pumpWidget(card(story, habits: false));
      expect(hasChart(), isFalse);
    });
  });

  testWidgets('a poster that fails to load falls back to the title',
      (tester) async {
    useTallView(tester);
    final story = storyOf(
      [_film('Broken art', DateTime(2026, 10, 3, 20), poster: '/a.jpg')],
      periods.first,
    );
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 320,
            child: AspectRatio(
              aspectRatio: ShareRecapFormat.post.aspectRatio,
              child: ShareRecapCard(
                story: story,
                format: ShareRecapFormat.post,
                style: ShareRecapStyle.dark,
                includeTitles: true,
                includeHabits: true,
                artFor: (path, kind) => null,
              ),
            ),
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('Broken art'), findsOneWidget);
  });

  test('a fan of four posters drops to a balanced three', () {
    final story = storyOf([
      for (var i = 0; i < 4; i++)
        _film('Film $i', DateTime(2026, 10, 2 + i, 20), poster: '/$i.jpg'),
    ], periods[2]);
    // Three posters and the backdrop.
    expect(
      ShareRecapCard.artworkOf(
        story: story,
        format: ShareRecapFormat.story,
        includeTitles: true,
        artFor: (path, kind) => MemoryImage(_pixel),
      ),
      hasLength(4),
    );
  });
}

/// Every kind of fact the card can show, with long text in the awkward spots.
List<WellnessViewingSession> _busyHistory() => [
      for (var day = 1; day <= 28; day += 2) ...[
        _film(
          'Top film',
          DateTime(2026, 10, day, 23),
          minutes: 150,
          poster: '/top.jpg',
          contentId: 'top',
          completed: true,
          genres: const ['Thriller', 'Science Fiction', 'Documentary'],
        ),
        _film(
          'An extremely long title that cannot possibly fit on a single line '
          'of this card',
          DateTime(2026, 10, day + 1, 1),
          minutes: 70,
          poster: '/long.jpg',
        ),
        _film('Third', DateTime(2026, 10, day, 15), minutes: 20),
      ],
    ];

WellnessViewingSession _film(
  String title,
  DateTime localStart, {
  int minutes = 95,
  String? poster,
  String? contentId,
  bool completed = true,
  List<String> genres = const <String>[],
  WellnessMediaType type = WellnessMediaType.movie,
}) {
  final end = localStart.add(Duration(minutes: minutes));
  final watchedMs = minutes * 60000;
  return WellnessViewingSession(
    id: '$title-${localStart.millisecondsSinceEpoch}',
    ownerId: 'guest',
    deviceId: 'device',
    mediaType: type,
    source: type == WellnessMediaType.live
        ? WellnessPlaybackSource.live
        : WellnessPlaybackSource.streaming,
    contentId: contentId ?? title,
    title: title,
    startedAtUtc: localStart.toUtc(),
    endedAtUtc: end.toUtc(),
    timezoneOffsetMinutes: localStart.timeZoneOffset.inMinutes,
    watchedMs: watchedMs,
    durationMs: watchedMs,
    progressEndMs: watchedMs,
    completed: completed,
    posterPath: poster,
    backdropPath: poster,
    genres: genres,
    segments: [
      WellnessPlaybackSegment(
        startedAtUtc: localStart.toUtc(),
        endedAtUtc: end.toUtc(),
      ),
    ],
    updatedAtUtc: end.toUtc(),
  );
}

/// A 1×1 transparent PNG.
final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8'
  'AAAAASUVORK5CYII=',
);
