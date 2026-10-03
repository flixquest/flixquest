import 'package:dio/dio.dart';
import 'package:flixquest/core/cache/cache_request.dart';

/// Shares the complete inner pipeline, including retries and cache fallback.
class SingleFlightInterceptor extends Interceptor {
  SingleFlightInterceptor(this.dio, {this.defaultScope});
  final Dio dio;
  final String? defaultScope;
  final _pending = <String, Future<Response<dynamic>>>{};

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final request = options;
    final selection = CacheRequest.select(request, defaultScope: defaultScope);
    if (selection == null || request.extra['singleFlightOwner'] == true) {
      handler.next(request);
      return;
    }
    final key = '${selection.key}:${request.responseType.name}';
    final operation = _pending.putIfAbsent(
        key,
        () => dio.fetch<dynamic>(
              request.copyWith(
                  extra: {...request.extra, 'singleFlightOwner': true},
                  cancelToken: CancelToken()),
            ));
    try {
      final response = await operation;
      handler.resolve(Response<dynamic>(
          data: response.data,
          headers: response.headers,
          statusCode: response.statusCode,
          statusMessage: response.statusMessage,
          requestOptions: request,
          extra: {...response.extra}));
    } on DioException catch (error) {
      handler.reject(error.copyWith(requestOptions: request));
    } catch (error, stack) {
      handler.reject(
          DioException(
              requestOptions: request, error: error, stackTrace: stack),
          true);
    } finally {
      if (identical(_pending[key], operation)) _pending.remove(key);
    }
  }
}
