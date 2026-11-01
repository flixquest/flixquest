import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/live_tv_database_controller.dart';
import 'daddylive_service.dart';
import 'ntv_service.dart';

/// The live TV catalogs offered side by side. Each keeps its own favourites,
/// recents and cached catalog.
enum LiveTvSource {
  daddyLive(
    id: 'daddylive',
    label: 'Awash',
    analyticsName: 'DaddyLive',
    reportId: 'dlhd',
  ),
  ntv(id: 'ntv', label: 'Abay', analyticsName: 'NTV', reportId: 'ntv');

  const LiveTvSource({
    required this.id,
    required this.label,
    required this.analyticsName,
    required this.reportId,
  });

  /// Names its local store; DaddyLive's predates the others and keeps its
  /// original name.
  final String id;

  /// The name viewers see. Like the movie sources' aliases from the scraper,
  /// an Ethiopian place rather than the upstream's brand.
  final String label;

  /// The upstream's own name, for analytics only.
  final String analyticsName;

  /// The provider named in stream reports.
  final String reportId;

  static const _lastUsedKey = 'live_tv_source_v1';

  /// The source a channel ID belongs to.
  static LiveTvSource forChannel(String channelId) =>
      channelId.startsWith(NtvService.idPrefix) ? ntv : daddyLive;

  LiveTvService createService(String baseUrl) => switch (this) {
        daddyLive => DaddyLiveService(baseUrl: baseUrl),
        ntv => NtvService(baseUrl: baseUrl),
      };

  LiveTVDatabaseController database() =>
      LiveTVDatabaseController(namespace: id);

  /// The source the viewer last browsed, DaddyLive at first.
  static Future<LiveTvSource> lastUsed() async {
    final preferences = await SharedPreferences.getInstance();
    final id = preferences.getString(_lastUsedKey);
    return values.where((source) => source.id == id).firstOrNull ?? daddyLive;
  }

  Future<void> remember() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_lastUsedKey, id);
  }
}
