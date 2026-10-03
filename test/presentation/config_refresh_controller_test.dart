import 'package:dio/dio.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/core/storage/kv_store.dart';
import 'package:flixquest/data/repositories/config_repository.dart';
import 'package:flixquest/presentation/config/bootstrap_view_model.dart';
import 'package:flixquest/presentation/config/refresh_controller.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/fake_dio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeDioAdapter adapter;
  late Dio dio;
  late AppDependencyProvider provider;
  late RefreshController controller;
  late DateTime now;
  setUp(() async {
    dotenv.testLoad(
        fileInput:
            'TMDB_API_KEY=test\nMIXPANEL_API_KEY=test\nFLIXQUEST_API_URL=https://fallback.test');
    SharedPreferences.setMockInitialValues({});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
    adapter = FakeDioAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://backend.test/api/v1/'))
      ..httpClientAdapter = adapter;
    now = DateTime.utc(2026, 10, 3);
    provider = AppDependencyProvider();
    final vm = BootstrapViewModel(
        ConfigRepository(dio, KvStore(sharedPrefsSingleton), now: () => now),
        provider);
    controller = RefreshController(vm, now: () => now);
  });
  tearDown(() {
    controller.dispose();
    provider.dispose();
    dio.close();
  });
  test('boot fetches config and resume revalidates only after one hour',
      () async {
    adapter.enqueueJson({
      'success': true,
      'data': {}
    }, headers: {
      'etag': ['"v1"']
    });
    await controller.boot();
    now = now.add(const Duration(hours: 1));
    await controller.onResume();
    expect(adapter.requests.length, 1);
    now = now.add(const Duration(milliseconds: 1));
    adapter.enqueueJson(null, statusCode: 304);
    await controller.onResume();
    expect(adapter.requests.last.headers['If-None-Match'], '"v1"');
    await controller.onResume();
    expect(adapter.requests.length, 2);
  });
  test('config push hints refresh immediately while unrelated messages do not',
      () async {
    adapter.enqueueJson({'success': true, 'data': {}});
    await controller.boot();
    await controller.onPushData({'type': 'in_app_message'});
    expect(adapter.requests.length, 1);
    adapter.enqueueJson({
      'success': true,
      'data': {
        'features': {'enable_live_tv': false}
      }
    });
    await controller.onPushData({'type': 'config_updated'});
    expect(provider.displayLiveTV, isFalse);
    adapter.enqueueJson({
      'success': true,
      'data': {
        'features': {'enable_live_tv': true}
      }
    });
    await controller.onPushData({'refresh_config': 'true'});
    expect(provider.displayLiveTV, isTrue);
  });
  test('concurrent boot and resume share a refresh', () async {
    adapter.enqueueJson({'success': true, 'data': {}});
    await Future.wait(
        [controller.boot(), controller.onResume(), controller.onResume()]);
    expect(adapter.requests.length, 1);
  });
  test(
      'a config hint during a refresh triggers revalidation after it completes',
      () async {
    adapter.enqueueJson({
      'success': true,
      'data': {}
    }, headers: {
      'etag': ['"v1"']
    });
    adapter.enqueueJson({
      'success': true,
      'data': {
        'features': {'enable_stream': false}
      }
    }, headers: {
      'etag': ['"v2"']
    });
    await Future.wait([
      controller.boot(),
      controller.onPushData({'type': 'config_refresh'})
    ]);
    expect(provider.displayWatchNowButton, isFalse);
    expect(adapter.requests.last.headers['If-None-Match'], '"v1"');
  });
  test('failed validation can retry on resume without waiting one hour',
      () async {
    adapter.enqueueError();
    await controller.boot();
    expect(provider.displayWatchNowButton, isTrue);
    adapter.enqueueJson({
      'success': true,
      'data': {
        'features': {'enable_stream': false}
      }
    });
    await controller.onResume();
    expect(provider.displayWatchNowButton, isFalse);
  });
  test('disposed controller ignores late responses and future triggers',
      () async {
    adapter.enqueueJson({
      'success': true,
      'data': {
        'features': {'enable_stream': false}
      }
    });
    final pending = controller.boot();
    controller.dispose();
    await pending;
    expect(provider.displayWatchNowButton, isTrue);
    await controller.onResume();
    await controller.onPushData({'type': 'config_updated'});
    expect(adapter.requests.length, 1);
  });
}
