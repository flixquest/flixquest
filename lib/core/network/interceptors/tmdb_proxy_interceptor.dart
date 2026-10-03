import 'package:dio/dio.dart';

class TmdbProxyInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final request = options;
    if (request.extra['tmdbOriginalUrl'] == null &&
        request.uri.host == 'api.themoviedb.org' &&
        request.extra['tmdbProxyEnabled'] == true) {
      final proxy = request.extra['tmdbProxyUrl'] as String? ?? '';
      if (proxy.isNotEmpty) {
        final original = request.uri.toString();
        final uri = Uri.parse(proxy);
        request.extra['tmdbOriginalUrl'] = original;
        request.path = uri.replace(queryParameters: {
          ...uri.queryParameters,
          'destination': original,
        }).toString();
        request.baseUrl = '';
        request.queryParameters = {};
      }
    }
    handler.next(request);
  }
}
