import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flixquest/core/network/interceptors/tmdb_proxy_interceptor.dart';

Dio scriptedDio(Future<ResponseBody> Function(RequestOptions) callback) => Dio()
  ..interceptors.add(TmdbProxyInterceptor())
  ..httpClientAdapter = CallbackDioAdapter(callback);

ResponseBody jsonResponse(String body, int statusCode) =>
    ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json']
      },
    );

class CallbackDioAdapter implements HttpClientAdapter {
  CallbackDioAdapter(this.callback);
  final Future<ResponseBody> Function(RequestOptions) callback;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) =>
      callback(options);
  @override
  void close({bool force = false}) {}
}
