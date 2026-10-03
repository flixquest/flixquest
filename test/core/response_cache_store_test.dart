import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flixquest/core/cache/response_cache_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

CacheResponse entry(String key, {DateTime? responseDate}) {
  final now = responseDate ?? DateTime.now().toUtc();
  return CacheResponse(
    key: key,
    url: 'https://api.themoviedb.org/3/movie/7',
    statusCode: 200,
    cacheControl: CacheControl(maxAge: 900),
    content: utf8.encode('{"title":"Example"}'),
    headers: utf8.encode('{"etag":["v1"],"content-type":["application/json"]}'),
    eTag: 'v1',
    lastModified: null,
    date: null,
    expires: null,
    requestDate: now,
    responseDate: now,
    maxStale: now.add(const Duration(days: 7)),
    priority: CachePriority.normal,
  );
}

void main() {
  setUpAll(sqfliteFfiInit);

  test('HTTP responses survive closing and reopening the SQLite store',
      () async {
    final directory = await Directory.systemTemp.createTemp('flixquest-cache-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/cache.db';
    final store =
        await ResponseCacheStore.open(factory: databaseFactoryFfi, path: path);
    await store.set(entry(
        '["tmdb","public","GET","https://api.themoviedb.org/3/movie/7"]'));
    await store.close();
    final reopened =
        await ResponseCacheStore.open(factory: databaseFactoryFfi, path: path);
    addTearDown(reopened.close);
    final cached = await reopened
        .get('["tmdb","public","GET","https://api.themoviedb.org/3/movie/7"]');
    expect(cached?.toResponse(RequestOptions(path: '/')).data,
        {'title': 'Example'});
    expect(cached?.eTag, 'v1');
  });
  String key(String id, {String scope = 'tmdb', String owner = 'public'}) =>
      jsonEncode([scope, owner, 'GET', 'https://example.com/$id']);

  Future<ResponseCacheStore> open(
      {int maxEntries = 5000,
      int maxBytes = 50000000,
      int memoryEntries = 300,
      int memoryBytes = 16000000,
      DateTime Function()? now}) async {
    final directory = await Directory.systemTemp.createTemp('flixquest-cache-');
    addTearDown(() => directory.delete(recursive: true));
    final store = await ResponseCacheStore.open(
        factory: databaseFactoryFfi,
        path: '${directory.path}/cache.db',
        maxEntries: maxEntries,
        maxBytes: maxBytes,
        memoryEntries: memoryEntries,
        memoryBytes: memoryBytes,
        now: now);
    addTearDown(store.close);
    return store;
  }

  for (final memoryEntries in [0, 1, 300]) {
    test('LRU count eviction also invalidates memory ($memoryEntries entries)',
        () async {
      var now = DateTime.now();
      final store = await open(
          maxEntries: 2, memoryEntries: memoryEntries, now: () => now);
      await store.put(entry(key('a')));
      now = now.add(const Duration(seconds: 1));
      await store.put(entry(key('b')));
      now = now.add(const Duration(seconds: 1));
      await store.get(key('a'));
      now = now.add(const Duration(seconds: 1));
      await store.put(entry(key('c')));
      expect(await store.get(key('b')), isNull);
      expect(await store.get(key('a')), isNotNull);
      expect(await store.get(key('c')), isNotNull);
    });
  }

  test('byte limit evicts oldest and rejects an oversized body', () async {
    final rowBytes =
        entry(key('a')).content!.length + entry(key('a')).headers!.length;
    final store = await open(maxBytes: rowBytes + 1, memoryBytes: 1);
    await store.put(entry(key('a')));
    await store.put(entry(key('b')));
    expect(await store.get(key('a')), isNull);
    expect(await store.get(key('b')), isNotNull);
    await store
        .put(entry(key('c')).copyWith(content: List.filled(rowBytes + 2, 1)));
    expect(await store.get(key('c')), isNull);
    expect(await store.sizeBytes(), rowBytes);
  });

  test('scope and user clearing preserve unrelated public/private entries',
      () async {
    final store = await open();
    final tmdb = key('tmdb');
    final scraper = key('scraper', scope: 'scraper');
    final a = key('a', scope: 'laravel', owner: 'user:a');
    final b = key('b', scope: 'laravel', owner: 'user:b');
    for (final k in [tmdb, scraper, a, b]) {
      await store.put(entry(k));
    }
    await store.clearScope('tmdb');
    expect(await store.get(tmdb), isNull);
    expect(await store.get(scraper), isNotNull);
    await store.clearScope('user:a');
    expect(await store.get(a), isNull);
    expect(await store.get(b), isNotNull);
    await store.clearScope('user');
    expect(await store.get(b), isNull);
    expect(await store.get(scraper), isNotNull);
    await store.clearAll();
    expect(await store.sizeBytes(), 0);
  });

  test('pruning honors deadlines, while bootstrap can survive indefinitely',
      () async {
    final store = await open();
    final now = DateTime.now();
    await store.put(entry(key('expired'))
        .copyWith(maxStale: now.subtract(const Duration(seconds: 1))));
    final sample = entry(key('bootstrap', scope: 'laravel'));
    await store.put(CacheResponse(
        key: sample.key,
        url: sample.url,
        statusCode: 200,
        cacheControl: sample.cacheControl,
        content: sample.content,
        headers: sample.headers,
        requestDate: now,
        responseDate: now,
        priority: sample.priority,
        date: null,
        expires: null,
        eTag: null,
        lastModified: null,
        maxStale: null));
    await store.pruneExpired();
    expect(await store.get(key('expired')), isNull);
    expect(await store.get(sample.key), isNotNull);
    expect(await store.sizeBytes(),
        sample.content!.length + sample.headers!.length);
  });

  test(
      'touch refreshes timestamps/deadline; non-200 and no-store never persist',
      () async {
    final store = await open();
    final original = entry(key('a'));
    await store.put(original);
    final later = original.responseDate.add(const Duration(minutes: 1));
    await store.touch(original.key, later);
    expect((await store.get(original.key))!.responseDate, later);
    expect((await store.get(original.key))!.maxStale,
        original.maxStale!.add(const Duration(minutes: 1)));
    await store.evict(original.key);
    expect(await store.get(original.key), isNull);
    await store.put(original.copyWith(statusCode: 404));
    await store
        .put(original.copyWith(cacheControl: CacheControl(noStore: true)));
    expect(await store.sizeBytes(), 0);
  });
  test('LRU keeps access ordering when wall-clock timestamps tie', () async {
    final now = DateTime.now();
    final store = await open(maxEntries: 2, now: () => now);
    await store.put(entry(key('a')));
    await store.put(entry(key('b')));
    await store.get(key('a'));
    await store.put(entry(key('c')));
    expect(await store.get(key('a')), isNotNull);
    expect(await store.get(key('b')), isNull);
  });
}
