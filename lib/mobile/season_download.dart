import 'dart:async';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../catalog/details_controller.dart' show hasAired;
import '../catalog/media_item.dart';
import '../constants/api_constants.dart';
import '../data/ads/content_ads.dart';
import '../design/app_palette.dart';
import '../design/app_tokens.dart';
import '../functions/function.dart';
import '../functions/video_utils.dart';
import '../models/offline_download.dart';
import '../models/tv.dart';
import '../provider/app_dependency_provider.dart';
import '../provider/offline_download_provider.dart';
import '../provider/settings_provider.dart';
import '../screens/common/download_selection_sheets.dart';
import '../services/adsterra_playback_ads_service.dart';
import '../services/offline_download_service.dart';
import '../video_providers/common.dart';
import '../video_providers/names.dart';
import '../video_providers/provider_loader.dart';
import '../video_providers/scraper_api.dart';
import 'widgets/episode_row.dart' show seasonDisplayName;
import 'widgets/page_kit.dart';

/// Downloads [season] of [series], or every one of [seasons] when the viewer
/// picks that, at the preferred download quality: each aired episode not
/// already downloaded goes to the first provider, in the viewer's order, that
/// has the quality. A sheet shows the progress and can stop it.
Future<void> downloadSeasons(
  BuildContext context, {
  required MediaItem series,
  required Seasons season,
  required List<Seasons> seasons,
  required Future<List<EpisodeList>> Function(int seasonNumber) loadSeason,
}) async {
  if (!await checkConnection()) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('check_connection'))),
      );
    }
    return;
  }
  if (!context.mounted) return;
  final settings = context.read<SettingsProvider>();

  final numbered =
      seasons.where((season) => season.seasonNumber != null).toList();
  var chosen = <Seasons>[season];
  if (numbered.length > 1) {
    final all = await DownloadSelectionSheets.chooseSeasonScope(
      context,
      seasonName: seasonDisplayName(season),
      seasonCount: numbered.length,
    );
    if (all == null || !context.mounted) return;
    if (all) chosen = numbered;
  }

  var height =
      await DownloadSelectionSheets.preferredQuality(context, settings);
  if (height == null || !context.mounted) return;
  // A batch can't ask per episode, so "ask every time" asks once for it.
  if (height == SettingsProvider.downloadQualityAsk) {
    height =
        await DownloadSelectionSheets.chooseQuality(context, includeAsk: false);
    if (height == null || !context.mounted) return;
  }

  if (!await AdsterraPlaybackAdsService.instance.beforeLoader(context,
          download: true, content: AdContent.of(series)) ||
      !context.mounted) {
    return;
  }
  await showAppSheet<void>(
    context,
    builder: (_) => _SeasonDownloadSheet(
      series: series,
      seasons: chosen,
      loadSeason: loadSeason,
      height: height!,
      settings: settings,
      downloads: context.read<OfflineDownloadProvider>(),
      scraperApiUrl: context.read<AppDependencyProvider>().flixquestAPIURL,
    ),
  );
}

class _SeasonDownloadSheet extends StatefulWidget {
  const _SeasonDownloadSheet({
    required this.series,
    required this.seasons,
    required this.loadSeason,
    required this.height,
    required this.settings,
    required this.downloads,
    required this.scraperApiUrl,
  });

  final MediaItem series;
  final List<Seasons> seasons;
  final Future<List<EpisodeList>> Function(int seasonNumber) loadSeason;
  final int height;
  final SettingsProvider settings;
  final OfflineDownloadProvider downloads;
  final String scraperApiUrl;

  @override
  State<_SeasonDownloadSheet> createState() => _SeasonDownloadSheetState();
}

class _SeasonDownloadSheetState extends State<_SeasonDownloadSheet> {
  bool _stopped = false;
  bool _finished = false;
  String? _current;
  int _total = 0;
  int _done = 0;
  int _queued = 0;
  int _skipped = 0;
  int _notFound = 0;
  int _lowerQuality = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  @override
  void dispose() {
    // Swiping the sheet away stops what hasn't started.
    _stopped = true;
    super.dispose();
  }

  void _update(VoidCallback change) {
    if (mounted) setState(change);
  }

  Future<void> _run() async {
    try {
      final providers = await _providers();
      final episodes = <EpisodeList>[];
      for (final season in widget.seasons) {
        if (_stopped) return;
        final list = await widget.loadSeason(season.seasonNumber!);
        episodes.addAll(list.where(
          (episode) => episode.episodeNumber != null && hasAired(episode),
        ));
      }
      _update(() => _total = episodes.length);
      for (final episode in episodes) {
        if (_stopped) return;
        await _download(episode, providers);
        _update(() => _done++);
      }
    } finally {
      _update(() {
        _finished = true;
        _current = null;
      });
      if (_queued > 0) {
        widget.settings.analytics.trackDownload(
          action: 'enqueue_season',
          mediaType: 'tv',
          outcome: 'success',
          quality: '${widget.height}p',
        );
        if (mounted) {
          AdsterraPlaybackAdsService.instance.afterDownloadQueued(context);
        }
      }
    }
  }

  Future<List<VideoProvider>> _providers() async {
    final providers = <VideoProvider>[];
    try {
      providers.addAll(await ScraperApi(widget.scraperApiUrl).getProviders());
    } catch (error) {
      debugPrint('Unable to load scraper providers: $error');
    }
    providers.add(VideoProvider.directVixSrc);
    return widget.settings.orderStreamProviders(providers);
  }

  Future<void> _download(
    EpisodeList episode,
    List<VideoProvider> providers,
  ) async {
    final tvId = widget.series.id;
    final season = episode.seasonNumber ?? 0;
    final number = episode.episodeNumber!;
    final id = 'tv_${tvId}_s${season}_e$number';
    final code = 'S${season.toString().padLeft(2, '0')} • '
        'E${number.toString().padLeft(2, '0')}';
    if (widget.downloads.downloads.any((download) => download.id == id)) {
      _update(() => _skipped++);
      return;
    }
    _update(() => _current = '$code ${episode.name ?? ''}'.trim());

    final selection = await ProviderLoader.loadFirstSuccessful(
      providers: providers,
      load: (provider) => ProviderLoader.loadTVFromProvider(
        provider: provider,
        tvId: tvId,
        seasonNumber: season,
        episodeNumber: number,
        scraperApiUrl: widget.scraperApiUrl,
      ),
      accept: (result) =>
          VideoUtils.downloadSource(
            VideoUtils.convertVideoLinksToMap(result.videoLinks!),
            widget.height,
          )?.exact ==
          true,
    );
    if (selection == null) {
      _update(() => _notFound++);
      return;
    }
    final links = selection.result.videoLinks!;
    final sources = VideoUtils.convertVideoLinksToMap(links);
    final pick = VideoUtils.downloadSource(sources, widget.height)!;
    final quality = pick.entry.key;
    final url = pick.entry.value;
    final declaredFormat = VideoUtils.convertVideoFormatsToMap(links)[quality];
    final format = declaredFormat == BetterPlayerVideoFormat.dash
        ? 'dash'
        : declaredFormat == BetterPlayerVideoFormat.hls
            ? 'hls'
            : url.toLowerCase().contains('.mpd')
                ? 'dash'
                : 'hls';
    final providerName = selection.provider.displayName;
    final subtitle = _preferredSubtitle(selection.result.subtitleLinks);
    final posterPath = widget.series.posterPath;
    try {
      await widget.downloads.enqueue(
        OfflineDownloadRequest(
          id: id,
          url: url,
          format: format,
          title: widget.series.title,
          subtitle: '$code ${episode.name ?? ''} • $providerName',
          mediaType: 'episode',
          quality: quality,
          posterUrl: posterPath == null
              ? null
              : '${TMDB_BASE_IMAGE_URL}w500$posterPath',
          // An adaptive stream has no height of its own; the preference caps it.
          maxVideoHeight: VideoUtils.videoQualityHeight(quality) ??
              (widget.height > 0 ? widget.height : null),
          headers: VideoUtils.convertVideoHeadersToMap(links)[quality] ??
              VideoUtils.inferVideoHeaders(url) ??
              const <String, String>{},
          source: OfflineDownloadSource.forSelection(
            provider: selection.provider,
            apiBaseUrl: widget.scraperApiUrl,
            links: links,
            url: url,
          ),
          contentId: tvId,
          seasonNumber: season,
          episodeNumber: number,
          subtitleTrackUrl: subtitle?.url,
          subtitleTrackName: subtitle?.language,
          subtitleTrackHeaders: subtitle?.headers ?? const {},
        ),
      );
      _update(() {
        _queued++;
        if (!pick.exact) _lowerQuality++;
      });
    } catch (error) {
      if (isAlreadyDownloaded(error)) {
        _update(() => _skipped++);
      } else {
        debugPrint('[SeasonDownload] $id failed to queue: $error');
        _update(() => _notFound++);
      }
    }
  }

  /// The subtitle in the viewer's language, or the first one there is.
  RegularSubtitleLinks? _preferredSubtitle(
    List<RegularSubtitleLinks>? subtitles,
  ) {
    if (subtitles == null || subtitles.isEmpty) return null;
    final preferred = widget.settings.defaultSubtitleLanguage.toLowerCase();
    final usable =
        subtitles.where((subtitle) => subtitle.url?.isNotEmpty == true);
    for (final subtitle in usable) {
      final language = subtitle.language?.toLowerCase() ?? '';
      if (preferred.isNotEmpty &&
          (language.startsWith(preferred) ||
              (preferred == 'en' && language.startsWith('english')))) {
        return subtitle;
      }
    }
    return usable.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final quality =
        widget.height == 0 ? tr('download_quality_best') : '${widget.height}p';
    final seasonsLabel = widget.seasons.length == 1
        ? seasonDisplayName(widget.seasons.single)
        : tr('download_all_seasons');
    final summary = <String>[
      tr('season_download_queued', namedArgs: {'count': '$_queued'}),
      if (_skipped > 0)
        tr('season_download_skipped', namedArgs: {'count': '$_skipped'}),
      if (_notFound > 0)
        tr('season_download_not_found', namedArgs: {'count': '$_notFound'}),
      if (_lowerQuality > 0)
        tr('season_download_lower_quality', namedArgs: {
          'count': '$_lowerQuality',
          'quality': quality,
        }),
    ].join('\n');
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        gutter,
        AppSpace.md,
        gutter,
        AppSpace.xxl + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.series.title} · $seasonsLabel',
            style: AppType.sectionHeader.copyWith(
              fontFamily: AppType.bold,
              color: palette.foreground,
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            _finished
                ? tr(_stopped
                    ? 'season_download_stopped'
                    : 'season_download_done')
                : tr('season_download_progress', namedArgs: {
                    'done': '$_done',
                    'total': _total == 0 ? '…' : '$_total',
                    'quality': quality,
                  }),
            style: AppType.metadata.copyWith(color: palette.mutedText),
          ),
          const SizedBox(height: AppSpace.lg),
          LinearProgressIndicator(
            value: _finished
                ? 1
                : _total == 0
                    ? null
                    : _done / _total,
            color: palette.foreground,
            backgroundColor: palette.idleFill,
            minHeight: 3,
          ),
          if (_current != null) ...[
            const SizedBox(height: AppSpace.md),
            Text(
              tr('season_download_finding', namedArgs: {'episode': _current!}),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.metadata.copyWith(color: palette.secondaryText),
            ),
          ],
          const SizedBox(height: AppSpace.md),
          Text(
            summary,
            style: AppType.metadata.copyWith(color: palette.secondaryText),
          ),
          const SizedBox(height: AppSpace.lg),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: _finished
                  ? () => Navigator.pop(context)
                  : () => _update(() => _stopped = true),
              child: Text(tr(_finished ? 'close' : 'stop')),
            ),
          ),
        ],
      ),
    );
  }
}
