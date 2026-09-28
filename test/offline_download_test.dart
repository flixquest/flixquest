import 'dart:async';

import 'package:flixquest/models/offline_download.dart';
import 'package:flixquest/functions/video_utils.dart';
import 'package:flixquest/provider/offline_download_provider.dart';
import 'package:flixquest/screens/common/downloads_screen.dart';
import 'package:flixquest/screens/common/download_selection_sheets.dart';
import 'package:flixquest/services/offline_download_service.dart';
import 'package:flixquest/video_providers/names.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  group('OfflineDownload', () {
    test('decodes progress, metadata, and state from the platform map', () {
      final item = OfflineDownload.fromMap({
        'id': 'movie_42',
        'title': 'Example',
        'subtitle': 'Director cut',
        'mediaType': 'movie',
        'quality': '1080p',
        'state': 'downloading',
        'progress': 47.5,
        'bytesDownloaded': 1024,
        'contentLength': 4096,
        'createdAt': 1234,
        'posterUrl': 'https://example.test/poster.jpg',
      });

      expect(item.id, 'movie_42');
      expect(item.state, OfflineDownloadState.downloading);
      expect(item.progress, 47.5);
      expect(item.isActive, isTrue);
      expect(item.isComplete, isFalse);
      expect(item.createdAt.millisecondsSinceEpoch, 1234);
      expect(item.totalBytes, 4096);
      expect(item.totalBytesIsEstimated, isFalse);
    });

    test('normalizes invalid platform progress', () {
      final item = OfflineDownload.fromMap({
        'id': 'movie_1',
        'progress': 140,
        'state': 'completed',
      });

      expect(item.progress, 100);
      expect(item.isComplete, isTrue);
    });

    test('estimates adaptive stream size while content length is unknown', () {
      final item = OfflineDownload.fromMap({
        'id': 'movie_2',
        'progress': 25,
        'bytesDownloaded': 50 * 1024 * 1024,
        'contentLength': -1,
        'state': 'downloading',
      });

      expect(item.totalBytes, 200 * 1024 * 1024);
      expect(item.totalBytesIsEstimated, isTrue);
    });

    test('encodes every source field needed by the native downloader', () {
      const request = OfflineDownloadRequest(
        id: 'tv_7_s1_e2',
        url: 'https://example.test/master.m3u8',
        format: 'hls',
        title: 'Example show',
        subtitle: 'S01 • E02',
        mediaType: 'episode',
        quality: '720p',
        maxVideoHeight: 720,
        headers: {'Referer': 'https://provider.test/'},
      );

      expect(request.toMap(), containsPair('format', 'hls'));
      expect(request.toMap(), containsPair('maxVideoHeight', 720));
      expect(
        request.toMap()['headers'],
        {'Referer': 'https://provider.test/'},
      );
    });
  });

  test('streaming and downloads share provider header inference', () {
    expect(
      VideoUtils.inferVideoHeaders(
          'https://vixsrc.to/playlist/123')?['referer'],
      'https://vixsrc.to/',
    );
    expect(
      VideoUtils.inferVideoHeaders('https://cdn.example.test/master.m3u8'),
      isNull,
    );
  });

  group('OfflineDownloadProvider', () {
    test('loads, sorts, and receives live progress updates', () async {
      final gateway = _FakeGateway([
        _download('older', createdAt: 1),
        _download('newer', createdAt: 2),
      ]);
      final provider = OfflineDownloadProvider(service: gateway);

      await provider.initialize();
      expect(provider.downloads.map((item) => item.id), ['newer', 'older']);

      gateway.emit([
        _download(
          'newer',
          createdAt: 2,
          state: OfflineDownloadState.downloading,
          progress: 60,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(provider.downloads.single.progress, 60);
      expect(provider.downloads.single.isActive, isTrue);
      provider.dispose();
    });

    test('forwards queue controls to the platform gateway', () async {
      final gateway = _FakeGateway(const []);
      final provider = OfflineDownloadProvider(service: gateway);
      await provider.initialize();

      await provider.pause('a');
      await provider.resume('a');
      await provider.retry('a');
      await provider.remove('a');

      expect(
          gateway.operations, ['pause:a', 'resume:a', 'retry:a', 'remove:a']);
      provider.dispose();
    });
  });

  testWidgets('downloads page displays progress and exposes pause control',
      (tester) async {
    final gateway = _FakeGateway([
      _download(
        'movie_9',
        createdAt: 10,
        state: OfflineDownloadState.downloading,
        progress: 42,
        bytesDownloaded: 42 * 1024 * 1024,
        contentLength: 100 * 1024 * 1024,
        networkRateBytesPerSecond: 2 * 1024 * 1024,
      ),
    ]);
    final provider = OfflineDownloadProvider(service: gateway);
    await provider.initialize();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: DownloadsScreen()),
      ),
    );

    expect(find.text('movie_9'), findsOneWidget);
    expect(find.textContaining('42%'), findsOneWidget);
    expect(find.text('Downloading'), findsOneWidget);
    expect(find.text('100.0 MB'), findsOneWidget);
    expect(find.text('2.0 MB/s'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('download-actions-movie_9')));
    await tester.pumpAndSettle();
    expect(find.text('Pause download'), findsOneWidget);
    expect(find.text('Delete download'), findsOneWidget);
    await tester.tap(find.text('Pause download'));
    await tester.pumpAndSettle();

    expect(gateway.operations, contains('pause:movie_9'));
    provider.dispose();
  });

  testWidgets('completed download exposes external player and save actions',
      (tester) async {
    final gateway = _FakeGateway([
      _download(
        'movie_10',
        createdAt: 10,
        state: OfflineDownloadState.completed,
        progress: 100,
        bytesDownloaded: 100 * 1024 * 1024,
        contentLength: 100 * 1024 * 1024,
      ),
    ]);
    final provider = OfflineDownloadProvider(service: gateway);
    await provider.initialize();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: DownloadsScreen()),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('download-actions-movie_10')));
    await tester.pumpAndSettle();
    expect(find.text('Open with another player'), findsOneWidget);
    expect(find.text('Save a copy'), findsOneWidget);

    await tester.tap(find.text('Open with another player'));
    await tester.pumpAndSettle();
    expect(gateway.operations, contains('openExternal:movie_10'));
    provider.dispose();
  });

  testWidgets('status chips are neutral, except a failure in the error colour',
      (tester) async {
    final gateway = _FakeGateway([
      _download(
        'movie_11',
        createdAt: 11,
        state: OfflineDownloadState.completed,
        progress: 100,
      ),
      _download('movie_12', createdAt: 12, state: OfflineDownloadState.failed),
    ]);
    final provider = OfflineDownloadProvider(service: gateway);
    await provider.initialize();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: DownloadsScreen()),
      ),
    );

    final colors =
        Theme.of(tester.element(find.byType(DownloadsScreen))).colorScheme;
    final downloaded = tester.widget<Text>(find.text('Downloaded'));
    final failed = tester.widget<Text>(find.text('Failed'));
    expect(downloaded.style?.color, isNot(colors.primary));
    expect(failed.style?.color, colors.error);
    provider.dispose();
  });

  testWidgets('download sheets return the selected provider and resolution',
      (tester) async {
    VideoProvider? selectedProvider;
    String? selectedResolution;
    final providers = [
      VideoProvider.scraper(id: 'alpha', name: 'Provider Alpha'),
      VideoProvider.directVixSrc,
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () async {
                    selectedProvider =
                        await DownloadSelectionSheets.showProvider(
                      context,
                      providers: providers,
                    );
                  },
                  child: const Text('Select provider'),
                ),
                TextButton(
                  onPressed: () async {
                    selectedResolution =
                        await DownloadSelectionSheets.showResolution(
                      context,
                      resolutions: const ['1080p', '720p'],
                      providerName: 'Provider Alpha',
                      estimatedSizes: const {
                        '1080p': 1610612736,
                        '720p': null,
                      },
                    );
                  },
                  child: const Text('Select resolution'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Select provider'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Provider Alpha'));
    await tester.pumpAndSettle();
    expect(selectedProvider?.codeName, 'scraper:alpha');

    await tester.tap(find.text('Select resolution'));
    await tester.pumpAndSettle();
    // Translated strings come back as their keys in tests.
    expect(find.text('download_from_provider'), findsOneWidget);
    expect(find.text('~1.5 GB'), findsOneWidget);
    expect(find.text('size_unknown'), findsOneWidget);
    await tester.tap(find.text('720p'));
    await tester.pumpAndSettle();
    expect(selectedResolution, '720p');
  });
}

OfflineDownload _download(
  String id, {
  required int createdAt,
  OfflineDownloadState state = OfflineDownloadState.queued,
  double progress = 0,
  int bytesDownloaded = 0,
  int contentLength = -1,
  double networkRateBytesPerSecond = 0,
}) {
  return OfflineDownload(
    id: id,
    title: id,
    mediaType: 'movie',
    quality: '720p',
    state: state,
    progress: progress,
    bytesDownloaded: bytesDownloaded,
    contentLength: contentLength,
    createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
    networkRateBytesPerSecond: networkRateBytesPerSecond,
  );
}

class _FakeGateway implements OfflineDownloadGateway {
  _FakeGateway(this.items);

  List<OfflineDownload> items;
  final operations = <String>[];
  final _events = StreamController<List<OfflineDownload>>.broadcast();

  void emit(List<OfflineDownload> downloads) => _events.add(downloads);

  @override
  Stream<List<OfflineDownload>> get downloadEvents => _events.stream;

  @override
  Future<List<OfflineDownload>> getDownloads() async => items;

  @override
  Future<void> enqueue(OfflineDownloadRequest request) async {
    operations.add('enqueue:${request.id}');
  }

  @override
  Future<void> pause(String id) async => operations.add('pause:$id');

  @override
  Future<void> remove(String id) async => operations.add('remove:$id');

  @override
  Future<void> resume(String id) async => operations.add('resume:$id');

  @override
  Future<void> retry(String id) async => operations.add('retry:$id');

  @override
  Future<OfflineExportProgress> getExportProgress(String id) async =>
      const OfflineExportProgress(state: 'idle');

  @override
  Future<void> openExternal(String id) async =>
      operations.add('openExternal:$id');

  @override
  Future<bool> saveCopy(String id) async {
    operations.add('saveCopy:$id');
    return true;
  }
}
