import 'dart:async';

import 'package:flixquest/catalog/catalog_controller.dart';
import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/design/skeleton.dart';
import 'package:flixquest/tv/app/tv_design.dart';
import 'package:flixquest/tv/screens/tv_collection_screen.dart';
import 'package:flixquest/tv/widgets/tv_loading_skeletons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const metrics = TvShellMetrics(
    compact: true,
    safeInset: 16,
    railWidth: 56,
    railGap: 8,
    contentPadding: 14,
    navItemHeight: 42,
    navItemGap: 2,
    mediaCardWidth: 140,
  );

  void configureTv(WidgetTester tester) {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('genre and provider collections start with a poster grid',
      (tester) async {
    configureTv(tester);
    final pending = Completer<List<MediaItem>>();
    await tester.pumpWidget(
      MaterialApp(
        home: TvCollectionScreen(
          collection: MediaCollection(
            id: 'provider-8-movie',
            title: 'Netflix',
            kicker: 'STREAMING SERVICE',
            loadPage: (_) => pending.future,
          ),
          onOpenMedia: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(TvCollectionGridSkeleton), findsOneWidget);
    expect(find.byType(SkeletonBlock), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('remaining TV page loaders are content-shaped skeletons',
      (tester) async {
    configureTv(tester);
    final loaders = <Widget>[
      const TvLiveSkeleton(metrics: metrics),
      const SingleChildScrollView(
        child: TvInsightsSkeleton(metrics: metrics),
      ),
      const Center(
        child: SizedBox(width: 700, child: TvUpdateSkeleton()),
      ),
    ];

    for (final loader in loaders) {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: loader)));
      await tester.pump();
      expect(find.byType(SkeletonBlock), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
