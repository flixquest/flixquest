import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

import 'response_cache_store.dart';
import 'cache_policy.dart' as app;

/// Cache management shared by phone/TV and all clients in one app lifecycle.
class HttpCache {
  HttpCache(CacheStore backing) : store = _SafeCacheStore(backing);

  final CacheStore store;
  int generation = 0;
  Future<void> _mutations = Future<void>.value();

  Future<void> _mutate(Future<void> Function() work) {
    final operation = _mutations.then((_) => work());
    _mutations = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> clearScope(String scope) async {
    generation++;
    await _mutate(() async {
      final backing = (store as _SafeCacheStore).backing;
      if (backing is ResponseCacheStore) {
        await backing.clearScope(scope);
        return;
      }
      for (final entry in await backing.getFromPath(RegExp('.*'))) {
        final parts = ResponseCacheStore.keyParts(entry.key);
        if (scope == 'user'
            ? parts[1] != 'public'
            : scope.startsWith('user:')
                ? parts[1] == scope
                : parts[0] == scope) {
          await backing.delete(entry.key);
        }
      }
    });
  }

  Future<void> clearAll() async {
    generation++;
    await _mutate(() => (store as _SafeCacheStore).backing.clean());
  }

  Future<int> sizeBytes() async {
    final backing = (store as _SafeCacheStore).backing;
    if (backing is ResponseCacheStore) return backing.sizeBytes();
    return (await backing.getFromPath(RegExp('.*'))).fold<int>(
        0,
        (sum, entry) =>
            sum + (entry.content?.length ?? 0) + (entry.headers?.length ?? 0));
  }

  Future<void> pruneExpired() => store.clean(staleOnly: true);
  Future<void> close() async {
    await _mutations;
    await store.close();
  }

  CacheStore forRequest(app.CachePolicy policy) =>
      _RequestCacheStore(this, generation, policy);
}

/// Cache I/O failures must not turn an otherwise usable HTTP response into a
/// failed request. Expired fallback deadlines are checked for every lookup.
class _SafeCacheStore extends CacheStore {
  _SafeCacheStore(this.backing);
  final CacheStore backing;

  @override
  Future<CacheResponse?> get(String key) async {
    try {
      final entry = await backing.get(key);
      if (entry?.isStaled() == true) {
        await backing.delete(key);
        return null;
      }
      return entry;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> set(CacheResponse response) async {
    try {
      if (response.statusCode != 200 || response.cacheControl.noStore) return;
      final previous = await get(response.key);
      if (previous != null && previous.responseDate == response.responseDate) {
        response = response.copyWith(maxStale: previous.maxStale);
      }
      await backing.set(response);
    } catch (_) {/* Cache writes do not affect network availability. */}
  }

  @override
  Future<void> delete(String key, {bool staleOnly = false}) async {
    try {
      await backing.delete(key, staleOnly: staleOnly);
    } catch (_) {/* Best effort. */}
  }

  @override
  Future<bool> exists(String key) async => await get(key) != null;
  @override
  Future<List<CacheResponse>> getFromPath(RegExp pathPattern,
          {Map<String, String?>? queryParams}) =>
      backing.getFromPath(pathPattern, queryParams: queryParams);
  @override
  Future<void> deleteFromPath(RegExp pathPattern,
          {Map<String, String?>? queryParams}) =>
      backing.deleteFromPath(pathPattern, queryParams: queryParams);
  @override
  Future<void> clean(
          {CachePriority priorityOrBelow = CachePriority.high,
          bool staleOnly = false}) =>
      backing.clean(priorityOrBelow: priorityOrBelow, staleOnly: staleOnly);
  @override
  Future<void> close() => backing.close();
}

class _RequestCacheStore extends CacheStore {
  _RequestCacheStore(this.cache, this.generation, this.policy);
  final HttpCache cache;
  final int generation;
  final app.CachePolicy policy;
  @override
  Future<CacheResponse?> get(String key) => cache.store.get(key);
  @override
  Future<void> set(CacheResponse response) => cache._mutate(() async {
        if (generation != cache.generation) return;
        final control = response.cacheControl;
        final fresh = policy.fresh.inSeconds;
        final cappedControl = CacheControl(
          maxAge: control.maxAge < 0 || control.maxAge > fresh
              ? fresh
              : control.maxAge,
          privacy: control.privacy,
          noCache: control.noCache,
          noStore: control.noStore,
          mustRevalidate: control.mustRevalidate,
          other: control.other,
        );
        final deadline = policy.maxStale == null
            ? null
            : response.responseDate.add(policy.fresh + policy.maxStale!);
        await cache.store.set(CacheResponse(
          key: response.key,
          url: response.url,
          statusCode: response.statusCode,
          cacheControl: cappedControl,
          content: response.content,
          headers: response.headers,
          requestDate: response.requestDate,
          responseDate: response.responseDate,
          priority: response.priority,
          maxStale: deadline,
          expires: response.expires,
          date: policy.validators ? response.date : null,
          eTag: policy.validators ? response.eTag : null,
          lastModified: policy.validators ? response.lastModified : null,
        ));
      });

  @override
  Future<void> delete(String key, {bool staleOnly = false}) async {
    if (generation == cache.generation) {
      await cache.store.delete(key, staleOnly: staleOnly);
    }
  }

  @override
  Future<bool> exists(String key) => cache.store.exists(key);
  @override
  Future<List<CacheResponse>> getFromPath(RegExp pathPattern,
          {Map<String, String?>? queryParams}) =>
      cache.store.getFromPath(pathPattern, queryParams: queryParams);
  @override
  Future<void> deleteFromPath(RegExp pathPattern,
          {Map<String, String?>? queryParams}) =>
      cache.store.deleteFromPath(pathPattern, queryParams: queryParams);
  @override
  Future<void> clean(
          {CachePriority priorityOrBelow = CachePriority.high,
          bool staleOnly = false}) =>
      cache.store.clean(priorityOrBelow: priorityOrBelow, staleOnly: staleOnly);
  @override
  Future<void> close() async {}
}
