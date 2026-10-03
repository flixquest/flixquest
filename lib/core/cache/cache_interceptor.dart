import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart' as cache;
import 'package:flixquest/core/network/interceptors/retry_interceptor.dart';

import 'cache_request.dart';
import 'response_cache_store.dart';
import 'http_cache.dart';

/// App policy surrounding the package's HTTP validator/serialization engine.
class CacheInterceptor extends cache.DioCacheInterceptor {
  CacheInterceptor(this.dio, this.httpCache, {this.defaultScope})
      : super(options: cache.CacheOptions(store: httpCache.store));
  final Dio dio;
  final HttpCache httpCache;
  final String? defaultScope;
  final _refreshing = <String, Future<void>>{};

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final request = options;
    try {
      final selection =
          CacheRequest.select(request, defaultScope: defaultScope);
      request.extra['cacheSelection'] = selection;
      if (selection == null) {
        handler.next(request);
        return;
      }
      request.extra.addAll(cache.CacheOptions(
        store: request.extra.putIfAbsent(
                'cacheStoreView', () => httpCache.forRequest(selection.policy))
            as cache.CacheStore,
        hitCacheOnNetworkFailure: true,
        keyBuilder: ({required url, headers, body}) => selection.key,
      ).toExtra());
      final existing = await httpCache.store.get(selection.key);
      if (existing != null &&
          request.extra['refreshStale'] == true &&
          existing.isExpired(cache.CacheControl())) {
        _refreshing.putIfAbsent(selection.key, () {
          final future = dio
              .fetch<dynamic>(request.copyWith(extra: {
                ...request.extra,
                'refreshStale': false,
              }))
              .then<void>((_) {}, onError: (Object _) {});
          unawaited(
              future.whenComplete(() => _refreshing.remove(selection.key)));
          return future;
        });
        final response = existing.toResponse(request)..extra['cache'] = 'stale';
        handler.resolve(response, true);
        return;
      }
      super.onRequest(request, handler);
    } catch (error, stack) {
      handler.reject(
          DioException(
              requestOptions: request, error: error, stackTrace: stack),
          true);
    }
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    final selection =
        response.requestOptions.extra['cacheSelection'] as CacheRequest?;
    if (selection == null) {
      handler.next(response);
      return;
    }
    if (response.extra[cache.extraCacheKey] != null) {
      response.extra['cache'] ??=
          response.extra[cache.extraFromNetworkKey] == false ? 'hit' : 'miss';
      super.onResponse(response, handler);
      return;
    }
    final control =
        cache.CacheControl.fromHeader(response.headers['cache-control']);
    final uncacheable = control.noStore ||
        (control.privacy == 'private' && cacheOwnerIsPublic(selection.key)) ||
        response.headers['set-cookie'] != null ||
        response.headers
                .value('vary')
                ?.split(',')
                .any((part) => part.trim() == '*') ==
            true;
    if (uncacheable) {
      await httpCache.store.delete(selection.key);
      handler.next(response);
      return;
    }
    if (response.statusCode != 200 && response.statusCode != 304) {
      handler.next(response);
      return;
    }
    final fresh = selection.policy.fresh.inSeconds;
    response.headers.set(
        'cache-control',
        cache.CacheControl(
          maxAge: control.maxAge < 0 || control.maxAge > fresh
              ? fresh
              : control.maxAge,
          privacy: control.privacy,
          noCache: control.noCache,
          mustRevalidate: control.mustRevalidate,
          other: control.other,
        ).toHeader());
    response.extra['cache'] =
        response.statusCode == 304 ? 'revalidated' : 'miss';
    super.onResponse(
        response,
        response.statusCode == 304
            ? _CacheResponseHandler(handler, 'revalidated')
            : handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final error = err;
    if (error.requestOptions.extra['cacheSelection'] == null ||
        (!isTransportFailure(error) && error.response?.statusCode != 304) ||
        error.type == DioExceptionType.cancel) {
      handler.next(error);
      return;
    }
    if (error.response?.statusCode == 304) {
      final response = error.response!;
      final control =
          cache.CacheControl.fromHeader(response.headers['cache-control']);
      final selection =
          error.requestOptions.extra['cacheSelection'] as CacheRequest;
      if (control.noStore ||
          (control.privacy == 'private' && cacheOwnerIsPublic(selection.key)) ||
          response.headers['set-cookie'] != null ||
          response.headers.value('vary')?.trim() == '*') {
        final stored = await httpCache.store.get(selection.key);
        await httpCache.store.delete(selection.key);
        if (stored != null) {
          handler.resolve(stored.toResponse(error.requestOptions)
            ..extra['cache'] = 'revalidated');
        } else {
          handler.next(error);
        }
        return;
      }
    }
    super.onError(
        error,
        _CacheErrorHandler(handler,
            error.response?.statusCode == 304 ? 'revalidated' : 'stale'));
  }
}

bool cacheOwnerIsPublic(String key) =>
    ResponseCacheStore.keyParts(key)[1] == 'public';

class _CacheErrorHandler extends ErrorInterceptorHandler {
  _CacheErrorHandler(this.delegate, this.diagnostic);
  final ErrorInterceptorHandler delegate;
  final String diagnostic;
  @override
  void resolve(Response response) {
    response.extra['cache'] = diagnostic;
    delegate.resolve(response);
  }

  @override
  void next(DioException error) => delegate.next(error);
}

class _CacheResponseHandler extends ResponseInterceptorHandler {
  _CacheResponseHandler(this.delegate, this.diagnostic);
  final ResponseInterceptorHandler delegate;
  final String diagnostic;
  @override
  void next(Response response) {
    response.extra['cache'] = diagnostic;
    delegate.next(response);
  }

  @override
  void reject(DioException error,
          [bool callFollowingErrorInterceptor = false]) =>
      delegate.reject(error, callFollowingErrorInterceptor);
}
