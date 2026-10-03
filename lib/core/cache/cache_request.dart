import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart'
    show CacheControl;

import 'cache_key.dart';
import 'cache_policies.dart';
import 'cache_policy.dart';

class CacheRequest {
  const CacheRequest(this.policy, this.key);
  final CachePolicy policy;
  final String key;

  static CacheRequest? select(RequestOptions request, {String? defaultScope}) {
    if (request.method.toUpperCase() != 'GET' ||
        request.responseType == ResponseType.stream) {
      return null;
    }
    final control = CacheControl.fromString(request.headers.entries
        .where((entry) => entry.key.toLowerCase() == 'cache-control')
        .map((entry) => '${entry.value}')
        .firstOrNull);
    if (control.noStore) return null;
    final policy = request.extra['cachePolicy'] as CachePolicy? ??
        CachePolicies.forUrl(originalUrl(request),
            scope: request.extra['cacheScope'] as String? ?? defaultScope);
    if (!policy.enabled) return null;
    final authScope = request.extra['authScope'] as String? ?? 'public';
    final hasCredentials = request.headers.keys
        .any((key) => ['authorization', 'cookie'].contains(key.toLowerCase()));
    if (authScope != 'public' &&
        (!authScope.startsWith('user:') || authScope.length <= 5)) {
      return null;
    }
    if (policy.scope == 'laravel' && hasCredentials && authScope == 'public') {
      return null;
    }
    return CacheRequest(policy,
        normalizedCacheKey(request, scope: policy.scope, authScope: authScope));
  }
}
