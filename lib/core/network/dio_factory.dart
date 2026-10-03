import 'package:dio/dio.dart';
import 'package:flixquest/core/cache/cache_interceptor.dart';
import 'package:flixquest/core/cache/http_cache.dart';
import 'package:flixquest/core/config/app_environment.dart';
import 'package:flutter/foundation.dart';

import 'interceptors/error_interceptor.dart';
import 'interceptors/header_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/retry_interceptor.dart';
import 'interceptors/single_flight_interceptor.dart';
import 'interceptors/tmdb_proxy_interceptor.dart';

Dio createPublicDio(AppEnvironment environment, {
  Dio? dio, HttpCache? httpCache, bool? debugLogging,
  Future<void> Function(Duration)? retryDelay,
}) => _create(environment, dio: dio, httpCache: httpCache,
    debugLogging: debugLogging, retryDelay: retryDelay);

Dio createLaravelDio(AppEnvironment environment, {
  Dio? dio, HttpCache? httpCache, bool? debugLogging,
  Future<void> Function(Duration)? retryDelay,
}) {
  final client = _create(environment, dio: dio, httpCache: httpCache,
      scope: 'laravel', debugLogging: debugLogging, retryDelay: retryDelay);
  client.options.baseUrl = environment.laravelApiUrl;
  return client;
}

Dio _create(AppEnvironment environment, {Dio? dio, HttpCache? httpCache,
  String? scope, bool? debugLogging, Future<void> Function(Duration)? retryDelay}) {
  final client = dio ?? Dio();
  client.options.connectTimeout = environment.connectTimeout;
  client.options.receiveTimeout = environment.receiveTimeout;
  if (client.interceptors.any((interceptor) => interceptor is HeaderInterceptor)) {
    return client;
  }
  client.interceptors.add(HeaderInterceptor());
  client.interceptors.add(TmdbProxyInterceptor());
  if (httpCache != null) {
    client.interceptors.add(SingleFlightInterceptor(client, defaultScope: scope));
  }
  client.interceptors.add(RetryInterceptor(client, delay: retryDelay));
  if (httpCache != null) {
    client.interceptors.add(CacheInterceptor(client, httpCache, defaultScope: scope));
  }
  if (kDebugMode && (debugLogging ?? environment.debugLogging)) {
    client.interceptors.add(LoggingInterceptor());
  }
  client.interceptors.add(ErrorInterceptor());
  return client;
}
