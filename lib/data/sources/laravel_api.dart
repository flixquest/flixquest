import 'package:dio/dio.dart';
import 'package:flixquest/core/cache/cache_policy.dart';
import 'package:flixquest/core/error/failure.dart';
import 'package:flixquest/core/error/failure_exception.dart';
import '../models/api_error.dart';

class LaravelApi {
  const LaravelApi(this.dio);
  final Dio dio;
  Future<Map<String, dynamic>> request(String path,
      {String method = 'GET',
      Object? data,
      Map<String, dynamic>? query,
      bool authenticated = true}) async {
    final response = await dio.request<Object>(path,
        data: data,
        queryParameters: query,
        options: Options(method: method, extra: {
          'authRequired': authenticated,
          'cachePolicy': CachePolicy.noStore
        }));
    final body = response.data;
    if (body is! Map<String, dynamic> || body['success'] is! bool) {
      throw const FormatException('Invalid Laravel response');
    }
    if (body['success'] != true) {
      final error = ApiError.fromJson(body);
      throw FailureException(Failure.unknown(message: error.message));
    }
    return body;
  }
}
