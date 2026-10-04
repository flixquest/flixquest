import 'package:dio/dio.dart';
import 'package:flixquest/core/cache/cache_policy.dart';
import 'package:flixquest/core/error/failure.dart';
import 'package:flixquest/core/error/result.dart';
import 'package:flixquest/core/network/interceptors/error_interceptor.dart';

class DeviceRepository {
  const DeviceRepository(this.dio);
  final Dio dio;

  Future<Result<void>> register(
      String fcmToken, String platform, String appVersion,
      {required String owner}) async {
    try {
      final response = await dio.post<dynamic>('devices/register',
          data: {
            'fcm_token': fcmToken,
            'platform': platform,
            'app_version': appVersion
          },
          options: Options(extra: {
            'sessionOwner': owner,
            'cachePolicy': CachePolicy.noStore,
          }));
      if (response.data is! Map || response.data['success'] != true) {
        return const Result.err(
            Failure.unknown(message: 'Invalid device registration response.'));
      }
      return const Result.ok(null);
    } on DioException catch (error) {
      return Result.err(failureForDio(error));
    }
  }
}
