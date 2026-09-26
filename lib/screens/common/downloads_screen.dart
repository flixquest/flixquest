import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../models/offline_download.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/offline_download_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/offline_download_service.dart';
import '../../ui_components/app_ui_components.dart';
import 'offline_player_screen.dart';
import '../../video_providers/scraper_api.dart';
import '../../widgets/hosted_ads_banner.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OfflineDownloadProvider>();
    final content = RefreshIndicator(
      onRefresh: provider.refresh,
      child: provider.downloads.isEmpty
          ? _EmptyDownloads(loading: provider.loading)
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(
                16,
                embedded ? 20 : 12,
                16,
                112 + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: provider.downloads.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _DownloadCard(download: provider.downloads[index]),
            ),
    );

    if (embedded) {
      return SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                'Downloads',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            if (provider.error != null) _ErrorBanner(message: provider.error!),
            RemoteHostedAdsBanner(
              placement: 'downloads',
              loadAds: () => ScraperApi(
                context.read<AppDependencyProvider>().flixquestAPIURL,
              ).getAds(),
            ),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: Column(
        children: [
          if (provider.error != null) _ErrorBanner(message: provider.error!),
          RemoteHostedAdsBanner(
            placement: 'downloads',
            loadAds: () => ScraperApi(
              context.read<AppDependencyProvider>().flixquestAPIURL,
            ).getAds(),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }
}

class _EmptyDownloads extends StatelessWidget {
  const _EmptyDownloads({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * .18),
        Icon(
          loading ? PhosphorIcons.cloudArrowDown() : PhosphorIcons.download(),
          size: 72,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 20),
        Text(
          loading ? 'Loading downloads…' : 'No downloads yet',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (!loading) ...[
          const SizedBox(height: 8),
          Text(
            'Download a movie or episode from its details page to watch it offline.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }
}

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({required this.download});

  final OfflineDownload download;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final export =
        context.select<OfflineDownloadProvider, OfflineExportProgress?>(
      (provider) => provider.exportFor(download.id),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: download.isComplete ? () => _playOffline(context) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Poster(url: download.posterUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      download.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    if (download.subtitle?.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        download.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 7,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _StatusChip(download: download),
                        _DownloadMetadata(
                          icon: PhosphorIcons.gauge(),
                          label: download.quality,
                        ),
                        _DownloadMetadata(
                          icon: PhosphorIcons.hardDrive(),
                          label: _totalSizeText(download),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (export != null) ...[
                      Row(
                        children: [
                          Icon(
                            PhosphorIcons.filmReel(),
                            size: 14,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            export.progress == null
                                ? 'Preparing export…'
                                : 'Preparing export ${export.progress}%',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    LinearProgressIndicator(
                      value: export != null
                          ? export.progress == null
                              ? null
                              : export.progress! / 100
                          : download.isComplete
                              ? 1
                              : download.progress > 0
                                  ? download.progress / 100
                                  : null,
                      minHeight: 5,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _progressText(download),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ),
                        if (download.state ==
                            OfflineDownloadState.downloading) ...[
                          const SizedBox(width: 8),
                          Icon(
                            PhosphorIcons.speedometer(),
                            size: 14,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            download.networkRateBytesPerSecond > 0
                                ? '${_formatBytes(download.networkRateBytesPerSecond.round())}/s'
                                : 'Starting…',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              _DownloadActions(download: download),
            ],
          ),
        ),
      ),
    );
  }

  String _progressText(OfflineDownload item) {
    final downloaded = _formatBytes(item.bytesDownloaded);
    if (item.isComplete) return downloaded;
    if (item.progress > 0) {
      return '${item.progress.toStringAsFixed(0)}%  •  $downloaded downloaded';
    }
    return '$downloaded downloaded';
  }

  void _playOffline(BuildContext context) {
    AnalyticsService.instance.trackDownload(
      action: 'play_offline',
      mediaType: download.mediaType,
      outcome: 'started',
      quality: download.quality,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OfflinePlayerScreen(download: download),
      ),
    );
  }
}

class _DownloadMetadata extends StatelessWidget {
  const _DownloadMetadata({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: colors.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(child: Icon(PhosphorIcons.filmSlate(), size: 28)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(
        width: 76,
        height: 112,
        child: url == null || url!.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                placeholder: (_, __) => const AppCachedImagePlaceholder(),
                errorWidget: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.download});

  final OfflineDownload download;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (label, color) = switch (download.state) {
      OfflineDownloadState.completed => ('Downloaded', colors.primary),
      OfflineDownloadState.downloading => ('Downloading', colors.tertiary),
      OfflineDownloadState.queued => ('Queued', colors.secondary),
      OfflineDownloadState.stopped => ('Paused', colors.secondary),
      OfflineDownloadState.failed => ('Failed', colors.error),
      OfflineDownloadState.removing => ('Removing', colors.outline),
      OfflineDownloadState.restarting => ('Restarting', colors.tertiary),
      OfflineDownloadState.unknown => ('Unknown', colors.outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

class _DownloadActions extends StatelessWidget {
  const _DownloadActions({required this.download});

  final OfflineDownload download;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<OfflineDownloadProvider>();
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      key: ValueKey('download-actions-${download.id}'),
      tooltip: 'Download options',
      style: IconButton.styleFrom(
        backgroundColor: colors.surfaceContainerHighest.withValues(alpha: .7),
        foregroundColor: colors.onSurfaceVariant,
      ),
      icon: Icon(PhosphorIcons.dotsThreeVertical(PhosphorIconsStyle.bold)),
      onPressed: () async {
        final action = await showModalBottomSheet<_DownloadAction>(
          context: context,
          useSafeArea: true,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (_) => _DownloadActionsSheet(download: download),
        );
        switch (action) {
          case _DownloadAction.pause:
            await provider.pause(download.id);
            if (context.mounted) _track(context, 'pause', 'success');
          case _DownloadAction.resume:
            await provider.resume(download.id);
            if (context.mounted) _track(context, 'resume', 'success');
          case _DownloadAction.retry:
            await provider.retry(download.id);
            if (context.mounted) _track(context, 'retry', 'success');
          case _DownloadAction.openExternal:
            if (context.mounted) await _openExternal(context, provider);
          case _DownloadAction.saveCopy:
            if (context.mounted) await _saveCopy(context, provider);
          case _DownloadAction.delete:
            await provider.remove(download.id);
            if (context.mounted) _track(context, 'delete', 'success');
          case null:
            break;
        }
      },
    );
  }

  Future<void> _openExternal(
    BuildContext context,
    OfflineDownloadProvider provider,
  ) async {
    await _runExportAction(
      context,
      analyticsAction: 'open_external',
      operation: () async {
        await provider.openExternal(download.id);
        return false;
      },
    );
  }

  Future<void> _saveCopy(
    BuildContext context,
    OfflineDownloadProvider provider,
  ) async {
    await _runExportAction(
      context,
      analyticsAction: 'save_copy',
      operation: () => provider.saveCopy(download.id),
      successMessage: 'Video copy saved',
    );
  }

  Future<void> _runExportAction(
    BuildContext context, {
    required String analyticsAction,
    required Future<bool> Function() operation,
    String? successMessage,
  }) async {
    try {
      final completed = await operation();
      if (context.mounted) _track(context, analyticsAction, 'success');
      if (completed && successMessage != null && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (error) {
      if (context.mounted) {
        _track(context, analyticsAction, 'error', error: error);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_exportErrorMessage(error))));
    }
  }

  void _track(
    BuildContext context,
    String action,
    String outcome, {
    Object? error,
  }) {
    AnalyticsService.instance.trackDownload(
      action: action,
      mediaType: download.mediaType,
      outcome: outcome,
      quality: download.quality,
      error: error?.toString(),
    );
  }
}

enum _DownloadAction { pause, resume, retry, openExternal, saveCopy, delete }

String _exportErrorMessage(Object error) => error is PlatformException
    ? error.message ?? 'Could not prepare this video.'
    : 'Could not prepare this video.';

class _DownloadActionsSheet extends StatelessWidget {
  const _DownloadActionsSheet({required this.download});

  final OfflineDownload download;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .82,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    PhosphorIcons.downloadSimple(PhosphorIconsStyle.bold),
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        download.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${download.quality}  •  ${_totalSizeText(download)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            if (download.isComplete) ...[
              _DownloadActionTile(
                icon: PhosphorIcons.playCircle(PhosphorIconsStyle.fill),
                title: 'Open with another player',
                subtitle: 'Choose any compatible video player on this device',
                onTap: () =>
                    Navigator.pop(context, _DownloadAction.openExternal),
              ),
              const SizedBox(height: 10),
              _DownloadActionTile(
                icon: PhosphorIcons.folderOpen(PhosphorIconsStyle.bold),
                title: 'Save a copy',
                subtitle: 'Choose a folder using your device file explorer',
                onTap: () => Navigator.pop(context, _DownloadAction.saveCopy),
              ),
              const SizedBox(height: 10),
            ],
            if (download.isActive)
              _DownloadActionTile(
                icon: PhosphorIcons.pause(PhosphorIconsStyle.fill),
                title: 'Pause download',
                subtitle: 'You can continue from the same point later',
                onTap: () => Navigator.pop(context, _DownloadAction.pause),
              ),
            if (download.state == OfflineDownloadState.stopped)
              _DownloadActionTile(
                icon: PhosphorIcons.play(PhosphorIconsStyle.fill),
                title: 'Resume download',
                subtitle: 'Continue saving this video',
                onTap: () => Navigator.pop(context, _DownloadAction.resume),
              ),
            if (download.state == OfflineDownloadState.failed)
              _DownloadActionTile(
                icon: PhosphorIcons.arrowClockwise(PhosphorIconsStyle.bold),
                title: 'Retry download',
                subtitle: 'Try downloading this video again',
                onTap: () => Navigator.pop(context, _DownloadAction.retry),
              ),
            if (download.isActive ||
                download.state == OfflineDownloadState.stopped ||
                download.state == OfflineDownloadState.failed)
              const SizedBox(height: 10),
            _DownloadActionTile(
              icon: PhosphorIcons.trash(PhosphorIconsStyle.bold),
              title: 'Delete download',
              subtitle: download.isComplete
                  ? 'Remove the saved video from this device'
                  : 'Cancel and remove downloaded data',
              destructive: true,
              onTap: () => Navigator.pop(context, _DownloadAction.delete),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadActionTile extends StatelessWidget {
  const _DownloadActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = destructive ? colors.error : colors.primary;
    return Material(
      color: accent.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 21, color: accent),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: destructive ? colors.error : null,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                PhosphorIcons.caretRight(),
                size: 18,
                color: destructive ? colors.error : colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _totalSizeText(OfflineDownload download) {
  final total = download.totalBytes;
  if (total <= 0) return 'Calculating size';
  final prefix = download.totalBytesIsEstimated ? '~' : '';
  return '$prefix${_formatBytes(total)}';
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  return '${(mb / 1024).toStringAsFixed(2)} GB';
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      content: Text(message),
      leading: Icon(
        PhosphorIcons.warningCircle(),
        color: Theme.of(context).colorScheme.error,
      ),
      actions: [
        TextButton(
          onPressed: context.read<OfflineDownloadProvider>().refresh,
          child: const Text('Retry'),
        ),
      ],
    );
  }
}
