import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Scripts the HTTP transport while retaining Dio's real transforms/errors.
class FakeDioAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final _responses = Queue<ResponseBody Function(RequestOptions)>();
  bool _closed = false;

  void enqueueJson(
    Object? body, {
    int statusCode = 200,
    Map<String, List<String>> headers = const {},
  }) {
    _responses.add((_) => ResponseBody.fromString(
          statusCode == 304 ? '' : jsonEncode(body),
          statusCode,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
            ...headers
          },
        ));
  }

  void enqueue(Response<dynamic> response) => enqueueJson(
        response.data,
        statusCode: response.statusCode ?? 200,
        headers: response.headers.map,
      );

  void enqueueError({
    DioExceptionType type = DioExceptionType.connectionError,
    String message = 'Offline',
  }) {
    _responses.add((request) => throw DioException(
          requestOptions: request,
          type: type,
          message: message,
        ));
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (_closed) throw StateError('The adapter has been closed.');
    requests.add(options);
    if (_responses.isEmpty) {
      throw StateError(
          'No scripted response for ${options.method} ${options.uri.path}');
    }
    return _responses.removeFirst()(options);
  }

  @override
  void close({bool force = false}) => _closed = true;
}
