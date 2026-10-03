import 'package:dio/dio.dart';
import 'package:flixquest/core/config/app_environment.dart';

/// F0 construction only. Feature interceptors are added by their owning phases.
Dio createPublicDio(AppEnvironment environment, {Dio? dio}) {
  final client = dio ?? Dio();
  client.options.connectTimeout = environment.connectTimeout;
  client.options.receiveTimeout = environment.receiveTimeout;
  client.options.headers['Accept'] = 'application/json';
  return client;
}

Dio createLaravelDio(AppEnvironment environment, {Dio? dio}) {
  final client = createPublicDio(environment, dio: dio);
  client.options.baseUrl = environment.laravelApiUrl;
  return client;
}
