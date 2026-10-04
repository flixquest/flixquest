import 'package:dio/dio.dart';
import 'package:flixquest/core/error/result.dart';
import 'package:flixquest/core/error/failure.dart';
import 'package:flixquest/core/network/interceptors/error_interceptor.dart';
import '../models/announcement.dart';

class AnnouncementRepository {
  AnnouncementRepository(this.dio, {DateTime Function()? now})
      : _now = now ?? DateTime.now;
  final Dio dio;
  final DateTime Function() _now;
  Future<Result<List<Announcement>>>? _inFlight;
  List<Announcement>? _cached;
  DateTime? _expiresAt;

  Future<Result<List<Announcement>>> fetchActive() {
    if (_cached != null && _expiresAt != null && _now().isBefore(_expiresAt!)) {
      return Future.value(Result.ok(_active(_cached!)));
    }
    return _inFlight ??= _fetch().whenComplete(() => _inFlight = null);
  }

  List<Announcement> _active(List<Announcement> messages) =>
      List.unmodifiable(messages.where((message) => message.isActive(_now())));

  Future<Result<List<Announcement>>> _fetch() async {
    try {
      final response = await dio.get<dynamic>('messages/active',
          options: Options(extra: {'authRequired': false}));
      final body = response.data;
      if (body is! Map ||
          body['success'] != true ||
          body['messages'] is! List) {
        return const Result.err(
            Failure.unknown(message: 'Invalid announcement response.'));
      }
      final messages = <Announcement>[];
      for (final row in body['messages'] as List) {
        try {
          messages.add(
              Announcement.fromJson(Map<String, dynamic>.from(row as Map)));
        } catch (_) {
          /* A malformed message must not hide valid announcements. */
        }
      }
      _cached = List.unmodifiable(messages);
      _expiresAt = _now().add(const Duration(minutes: 15));
      return Result.ok(_active(messages));
    } on DioException catch (error) {
      return Result.err(failureForDio(error));
    } catch (_) {
      return const Result.err(
          Failure.unknown(message: 'Announcements unavailable.'));
    }
  }
}
