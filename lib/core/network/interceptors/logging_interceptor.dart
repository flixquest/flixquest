import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Logs no query values, headers or bodies, which can contain credentials.
class LoggingInterceptor extends Interceptor {
  LoggingInterceptor({void Function(String)? log}) : _log = log ?? debugPrint;
  final void Function(String) _log;
  String _label(RequestOptions request) =>
      '${request.method} ${request.uri.host}${request.uri.path}';
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final request = options;
    _log('[HTTP] ${_label(request)}');
    handler.next(request);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _log('[HTTP] ${response.statusCode} ${_label(response.requestOptions)}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final error = err;
    _log(
        '[HTTP] ${error.response?.statusCode ?? error.type.name} ${_label(error.requestOptions)}');
    handler.next(error);
  }
}
