import 'dart:io';

import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/data/playlists/playlist_store.dart';
import 'package:flixquest/mobile/screens/my_flixquest_screen.dart';
import 'package:flixquest/provider/playlist_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/tv_localization.dart';

void main() {
  initializeTvTranslations();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('local watchlist edits survive closing and reopening storage', () async {
    final directory =
        await Directory.systemTemp.createTemp('flixquest-public-');
    addTearDown(() => directory.delete(recursive: true));
    var store =
        await PlaylistStore.open(owner: 'guest', directoryPath: directory.path);
    final provider = PlaylistProvider(openStore: (_) async => store);
    await provider.load();
    const movie = MediaItem(
        kind: MediaKind.movie,
        id: 42,
        title: 'A movie',
        overview: '',
        posterPath: null,
        backdropPath: null,
        rating: 8,
        releaseDate: '2026-01-01');
    final id = await provider.create('Watch later', first: movie);
    await provider.rename(id, 'Weekend', description: 'Saved on this device');
    await provider.add(id, movie);
    expect(provider.byId(id)!.entries, hasLength(1));
    provider.dispose();
    await store.database.close();

    store =
        await PlaylistStore.open(owner: 'guest', directoryPath: directory.path);
    addTearDown(store.database.close);
    final restored = PlaylistProvider(openStore: (_) async => store);
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.byId(id)!.name, 'Weekend');
    expect(restored.byId(id)!.description, 'Saved on this device');
    expect(restored.byId(id)!.entries.single.mediaId, 42);
    await restored.remove(id, movie);
    expect(restored.byId(id)!.entries, isEmpty);
    await restored.delete(id);
    expect(await store.read(), isEmpty);
  });

  testWidgets('public library opens without an account or billing session',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MyFlixQuestScreen())));
    expect(find.text('My FlixQuest'), findsOneWidget);
    expect(find.text('Your lists'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
