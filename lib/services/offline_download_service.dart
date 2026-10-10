import 'dart:async';

import 'package:flutter/services.dart';

import '../models/offline_download.dart';

abstract interface class OfflineDownloadGateway {
  Stream<List<OfflineDownload>> get downloadEvents;
  Future<List<OfflineDownload>> getDownloads();
  Future<void> enqueue(OfflineDownloadRequest request);
  Future<void> pause(String id);
  Future<void> resume(String id);
  Future<void> retry(String id);
  Future<void> remove(String id);
  Future<OfflineExportProgress> getExportProgress(String id);
  Future<void> openExternal(String id);
  Future<bool> saveCopy(String id);
}

class OfflineExportProgress {
  const OfflineExportProgress({required this.state, this.progress});

  final String state;
  final int? progress;

  bool get isAvailable => progress != null;

  factory OfflineExportProgress.fromMap(Map<Object?, Object?> map) {
    final rawProgress = map['progress'];
    final progress =
        rawProgress is num ? rawProgress.toInt().clamp(0, 100).toInt() : null;
    return OfflineExportProgress(
      state: map['state'] as String? ?? 'starting',
      progress: progress,
    );
  }
}

/// Whether a failed [OfflineDownloadGateway.enqueue] means the title is
/// already saved, which is not an error from the user's point of view.
bool isAlreadyDownloaded(Object error) =>
    error is PlatformException && error.code == 'ALREADY_DOWNLOADED';

/// A user-facing message for a failed [OfflineDownloadGateway.enqueue] of
/// [title].
String offlineEnqueueErrorMessage(Object error, {required String title}) {
  if (isAlreadyDownloaded(error)) {
    return '$title is already downloaded. Watch it in Downloads.';
  }
  if (error is PlatformException && error.code == 'PREPARE_FAILED') {
    return 'Could not reach this stream to download it. '
        'Try another quality or provider.';
  }
  return 'Could not start the download. Please try again.';
}

class OfflineDownloadService implements OfflineDownloadGateway {
  OfflineDownloadService._();

  static final OfflineDownloadService instance = OfflineDownloadService._();

  static const MethodChannel _methods =
      MethodChannel('dev.beamlak.flixquest/stream_downloads');
  static const EventChannel _events =
      EventChannel('dev.beamlak.flixquest/stream_download_events');

  Stream<List<OfflineDownload>>? _downloadEvents;

  @override
  Stream<List<OfflineDownload>> get downloadEvents =>
      _downloadEvents ??= _events
          .receiveBroadcastStream()
          .map(_decodeDownloads)
          .asBroadcastStream();

  @override
  Future<List<OfflineDownload>> getDownloads() async {
    final raw = await _methods.invokeListMethod<Object?>('getDownloads');
    return _decodeDownloads(raw ?? const []);
  }

  @override
  Future<void> enqueue(OfflineDownloadRequest request) {
    return _methods.invokeMethod<void>('enqueue', request.toMap());
  }

  @override
  Future<void> pause(String id) =>
      _methods.invokeMethod<void>('pause', {'id': id});

  @override
  Future<void> resume(String id) =>
      _methods.invokeMethod<void>('resume', {'id': id});

  @override
  Future<void> retry(String id) =>
      _methods.invokeMethod<void>('retry', {'id': id});

  @override
  Future<void> remove(String id) =>
      _methods.invokeMethod<void>('remove', {'id': id});

  @override
  Future<OfflineExportProgress> getExportProgress(String id) async {
    final raw = await _methods.invokeMapMethod<Object?, Object?>(
      'getExportProgress',
      {'id': id},
    );
    return OfflineExportProgress.fromMap(raw ?? const {});
  }

  @override
  Future<void> openExternal(String id) =>
      _methods.invokeMethod<void>('openExternal', {'id': id});

  @override
  Future<bool> saveCopy(String id) async =>
      await _methods.invokeMethod<bool>('saveCopy', {'id': id}) ?? false;

  List<OfflineDownload> _decodeDownloads(Object? event) {
    if (event is! List) return const [];
    return event
        .whereType<Map>()
        .map((item) => OfflineDownload.fromMap(item.cast<Object?, Object?>()))
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }
}
