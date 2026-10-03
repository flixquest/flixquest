import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';

bool isTransportFailure(DioException error) =>
    [
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    ].contains(error.type) ||
    error.error is SocketException ||
    error.error is TimeoutException;

class RetryInterceptor extends Interceptor {
  RetryInterceptor(this.dio,
      {this.retries = 2, Future<void> Function(Duration)? delay})
      : _delay = delay ?? Future<void>.delayed;
  final Dio dio;
  final int retries;
  final Future<void> Function(Duration) _delay;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final error = err;
    final request = error.requestOptions;
    final attempt = request.extra['retryAttempt'] as int? ?? 0;
    final limit =
        (request.extra['retryLimit'] as int? ?? retries).clamp(0, retries);
    final status = error.response?.statusCode;
    final retryable =
        isTransportFailure(error) || (status != null && status >= 500);
    if (request.method.toUpperCase() != 'GET' ||
        attempt >= limit ||
        !retryable ||
        request.cancelToken?.isCancelled == true ||
        error.type == DioExceptionType.cancel) {
      handler.next(error);
      return;
    }
    try {
      await _delay(Duration(milliseconds: 300 * (1 << attempt)));
      if (request.cancelToken?.isCancelled == true) {
        handler.next(request.cancelToken!.cancelError!);
        return;
      }
      final response = await dio.fetch<dynamic>(request.copyWith(
        extra: {...request.extra, 'retryAttempt': attempt + 1},
      ));
      handler.resolve(response);
    } on DioException catch (error) {
      handler.next(error);
    } catch (error, stack) {
      handler.next(DioException(
          requestOptions: request, error: error, stackTrace: stack));
    }
  }
}
