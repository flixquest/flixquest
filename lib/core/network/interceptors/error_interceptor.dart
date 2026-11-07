import 'package:dio/dio.dart';
import 'package:flixquest/core/error/failure.dart';
import 'retry_interceptor.dart';

Failure failureForDio(DioException error) {
  if (error.error is Failure) return error.error as Failure;
  if ({
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout
  }.contains(error.type)) {
    return const Failure.timeout();
  }
  if (isTransportFailure(error)) return const Failure.network();
  final status = error.response?.statusCode;
  final body = error.response?.data;
  final message = body is Map
      ? (body['status_message'] ?? body['message'] ?? 'Request failed.')
          .toString()
      : 'Request failed.';
  return switch (status) {
    401 => Failure.unauthorized(message: message),
    403 => Failure.forbidden(message: message),
    404 => Failure.notFound(message: message),
    429 => Failure.rateLimited(
        retryAfter:
            int.tryParse(error.response?.headers.value('retry-after') ?? ''),
        message: message),
    final int code when code >= 500 =>
      Failure.server(status: code, message: message),
    _ => Failure.unknown(message: message),
  };
}

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) =>
      handler.next(err.copyWith(error: failureForDio(err)));
}
