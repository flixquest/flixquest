import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_download_manager/flutter_download_manager.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../design/skeleton.dart';
import '../../mobile/widgets/page_kit.dart';
import '../../mobile/widgets/pill_button.dart';
import '../../tv/focus/tv_keymap.dart';
import '../../tv/widgets/tv_dialog.dart';
import '../../tv/widgets/tv_update_widgets.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../../services/globle_method.dart';
import '../../services/app_update_service.dart';

class UpdateScreen extends StatefulWidget {
  const UpdateScreen(
      {super.key, required this.isForced, this.television = false});

  final bool isForced;
  final bool television;

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  final DownloadManager _downloadManager = DownloadManager();
  PackageInfo? _packageInfo;
  String _savedDir = '';
  Object? _error;
  bool _showingMandatoryDialog = false;

  bool get _forced {
    final config = context.read<AppDependencyProvider>();
    return widget.isForced ||
        (config.isForcedUpdate &&
            _packageInfo != null &&
            AppUpdateService.isAvailable(
                packageInfo: _packageInfo!,
                remoteVersion: config.latestAppVersion,
                latestBuildNumber: config.latestBuildNumber,
                minimumBuildNumber: config.minimumBuildNumber));
  }

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    setState(() {
      _error = null;
      _packageInfo = null;
    });
    try {
      final values = await Future.wait([
        PackageInfo.fromPlatform(),
        getTemporaryDirectory(),
      ]);
      if (!mounted) return;
      setState(() {
        _packageInfo = values[0] as PackageInfo;
        _savedDir = (values[1] as Directory).path;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
      GlobalMethods.showErrorScaffoldMessengerGeneral(error, context);
    }
  }

  Future<void> _showMustUpdateDialog() async {
    if (_showingMandatoryDialog) return;
    if (widget.television) {
      _showingMandatoryDialog = true;
      try {
        await showTvDialog<void>(
            context: context,
            title: 'Update required',
            content: const Text(
                'Update FlixQuest to continue watching. You can also exit the app.'),
            actions: [
              TvDialogAction(
                  label: 'Return to update',
                  autofocus: true,
                  onPressed: () => Navigator.pop(context)),
              TvDialogAction(label: 'Exit app', onPressed: SystemNavigator.pop),
            ]);
      } finally {
        _showingMandatoryDialog = false;
      }
      return;
    }
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(PhosphorIcons.warningCircle()),
        title: Text(tr('must_update')),
        actions: [
          TextButton(
            onPressed: SystemNavigator.pop,
            child: Text(
              tr('exit'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('update')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_forced,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _forced) _showMustUpdateDialog();
      },
      child: widget.television
          ? TvKeymap(
              onBack: () async {
                if (_forced) {
                  await _showMustUpdateDialog();
                } else {
                  await Navigator.of(context).maybePop();
                }
              },
              child: _buildTvBody())
          : Scaffold(
              backgroundColor: AppPalette.of(context).page,
              appBar: PageAppBar(title: tr('check_for_update')),
              body: SkeletonSwitcher(
                loading: _error == null && _packageInfo == null,
                alignment: Alignment.center,
                skeleton: const _UpdateSkeleton(),
                child: _buildBody(),
              ),
            ),
    );
  }

  Widget _buildTvBody() {
    final config = context.watch<AppDependencyProvider>();
    final available = _packageInfo != null &&
        AppUpdateService.isAvailable(
            packageInfo: _packageInfo!,
            remoteVersion: config.latestAppVersion,
            latestBuildNumber: config.latestBuildNumber,
            minimumBuildNumber: config.minimumBuildNumber);
    final version = AppUpdateService.displayVersion(
        config.latestAppVersion,
        AppUpdateService.effectiveBuildNumber(
            latestBuildNumber: config.latestBuildNumber,
            minimumBuildNumber: config.minimumBuildNumber));
    return TvUpdateLayout(
      title: _forced ? 'Update required' : 'App updates',
      message: _error != null
          ? 'Unable to prepare the update. Please try again.'
          : _packageInfo == null
              ? 'Checking your installed version…'
              : available
                  ? 'FlixQuest $version is available. Installed: ${_packageInfo!.version}. '
                      '${_forced ? 'Update to continue watching.' : 'Get the latest improvements for your TV.'}'
                  : 'You’re up to date. FlixQuest ${_packageInfo!.version}',
      children: [
        if (_error != null)
          TvUpdateAction(
              label: 'Retry',
              autofocus: true,
              primary: true,
              onPressed: _prepare)
        else if (_packageInfo == null)
          const Center(child: CircularProgressIndicator())
        else if (available) ...[
          if (config.appDownloadUrl.isNotEmpty)
            _DownloadCard(
                appVersion: version,
                url: config.appDownloadUrl,
                television: true,
                task: _downloadManager.getDownload(config.appDownloadUrl),
                onToggle: _toggleDownload,
                onOpen: _openDownload,
                onDelete: _deleteDownload)
          else ...[
            const Text(
                'The download link is not available yet. Please try again later.',
                style: TextStyle(color: Colors.white70, fontSize: 20)),
            const SizedBox(height: 16),
          ],
          if (config.changeLog.isNotEmpty) ...[
            const SizedBox(height: 16),
            TvUpdateChangelog(
                changeLog: config.changeLog,
                onPressed: () => _showChangelog(config.changeLog)),
          ],
        ],
        const SizedBox(height: 16),
        TvUpdateAction(
            label: _forced ? 'Exit app' : 'Back',
            autofocus: _error == null &&
                (_packageInfo != null &&
                    (!available || config.appDownloadUrl.isEmpty)),
            onPressed: () {
              if (_forced) {
                _showMustUpdateDialog();
              } else {
                Navigator.of(context).maybePop();
              }
            }),
      ],
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return EmptyState(
        icon: PhosphorIcons.wifiSlash(),
        title: tr('internet_problem'),
        message: tr('check_connection'),
        actionLabel: tr('retry'),
        actionIcon: PhosphorIcons.arrowsClockwise(),
        onAction: _prepare,
      );
    }
    if (_packageInfo == null) return const SizedBox.shrink();
    final config = context.watch<AppDependencyProvider>();
    if (!AppUpdateService.isAvailable(
      packageInfo: _packageInfo!,
      remoteVersion: config.latestAppVersion,
      latestBuildNumber: config.latestBuildNumber,
      minimumBuildNumber: config.minimumBuildNumber,
    )) {
      return EmptyState(
        icon: PhosphorIcons.checkCircle(),
        title: tr('no_update'),
        message: 'FlixQuest v${_packageInfo!.version}',
      );
    }
    final remoteBuild = AppUpdateService.effectiveBuildNumber(
      latestBuildNumber: config.latestBuildNumber,
      minimumBuildNumber: config.minimumBuildNumber,
    );
    final version = AppUpdateService.displayVersion(
      config.latestAppVersion,
      remoteBuild,
    );
    final downloadUrl = config.appDownloadUrl;
    final changeLog = config.changeLog;

    final palette = AppPalette.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: AppSpace.gutter(context)),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: palette.idleFill,
                shape: BoxShape.circle,
              ),
              child: Icon(
                PhosphorIcons.rocketLaunch(),
                size: 32,
                color: palette.foreground,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tr('update_available'),
              style: AppType.pageTitle.copyWith(color: palette.foreground),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              tr('new_version', namedArgs: {'v': version}),
              style: AppType.body.copyWith(color: palette.mutedText),
            ),
            if (changeLog.isNotEmpty) ...[
              const SizedBox(height: 18),
              PillButton(
                onPressed: () => _showChangelog(changeLog),
                icon: PhosphorIcons.listBullets(),
                label: tr('see_changelogs'),
              ),
            ],
            if (downloadUrl.isNotEmpty) ...[
              const SizedBox(height: 14),
              _DownloadCard(
                appVersion: version,
                url: downloadUrl,
                task: _downloadManager.getDownload(downloadUrl),
                onToggle: _toggleDownload,
                onOpen: _openDownload,
                onDelete: _deleteDownload,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showChangelog(String changeLog) {
    if (widget.television) {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => TvChangelogView(changeLog: changeLog),
      ));
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('changelogs')),
        content: SingleChildScrollView(child: Text(changeLog)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('confirm')),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleDownload(String url) async {
    try {
      final task = _downloadManager.getDownload(url);
      if (task == null || task.status.value.isCompleted) {
        await _downloadManager.addDownload(
          url,
          '$_savedDir/${_downloadManager.getFileNameFromUrl(url)}',
        );
      } else if (task.status.value == DownloadStatus.downloading ||
          task.status.value == DownloadStatus.queued) {
        await _downloadManager.pauseDownload(url);
      } else if (task.status.value == DownloadStatus.paused) {
        await _downloadManager.resumeDownload(url);
      }
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) _showDownloadError(error.toString());
    }
  }

  void _showDownloadError(String message) {
    if (widget.television) {
      showTvDialog<void>(
          context: context,
          title: 'Update could not complete',
          content: Text(message),
          actions: [
            TvDialogAction(label: 'OK', onPressed: () => Navigator.pop(context))
          ]);
    } else {
      GlobalMethods.showErrorScaffoldMessengerGeneral(
          Exception(message), context);
    }
  }

  Future<void> _openDownload(String url) async {
    final file = File('$_savedDir/${_downloadManager.getFileNameFromUrl(url)}');
    try {
      if (!await file.exists()) {
        throw const FileSystemException(
            'The downloaded file is missing. Delete it and download again.');
      }
      final result = await OpenFilex.open(file.path,
          type: 'application/vnd.android.package-archive');
      if (result.type != ResultType.done && mounted) {
        _showDownloadError(
            '${result.message}\nIf Android asks, allow FlixQuest to install apps, then select Install again.');
      }
    } catch (error) {
      if (mounted) _showDownloadError(error.toString());
    }
  }

  Future<void> _deleteDownload(String url) async {
    try {
      final file =
          File('$_savedDir/${_downloadManager.getFileNameFromUrl(url)}');
      if (await file.exists()) await file.delete();
      await _downloadManager.removeDownload(url);
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) _showDownloadError(error.toString());
    }
  }
}

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({
    required this.appVersion,
    required this.url,
    required this.task,
    required this.onToggle,
    required this.onOpen,
    required this.onDelete,
    this.television = false,
  });

  final bool television;
  final String appVersion;
  final String url;
  final DownloadTask? task;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onDelete;

  Widget _tvActions(BuildContext context, DownloadStatus? status) {
    final label = switch (status) {
      null => 'Download update',
      DownloadStatus.completed => 'Install',
      DownloadStatus.downloading || DownloadStatus.queued => 'Pause',
      DownloadStatus.paused => 'Resume',
      _ => 'Retry download',
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (status == DownloadStatus.failed)
        const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Download failed. Check your connection and retry.',
                style: TextStyle(fontSize: 20, color: Colors.white70))),
      TvUpdateAction(
          label: label,
          autofocus: true,
          primary: true,
          onPressed: () {
            if (status == DownloadStatus.completed) {
              onOpen(url);
            } else {
              if (status == null) {
                context
                    .read<SettingsProvider>()
                    .analytics
                    .trackAppUpdateDownload(appVersion);
              }
              onToggle(url);
            }
          }),
      if (status == DownloadStatus.completed) ...[
        const SizedBox(height: 12),
        TvUpdateAction(
            label: 'Delete download', onPressed: () => onDelete(url)),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (television) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (task != null) ...[
          ValueListenableBuilder<double>(
              valueListenable: task!.progress,
              builder: (_, progress, __) => Column(children: [
                    LinearProgressIndicator(
                        value: progress.isFinite ? progress.clamp(0, 1) : null),
                    const SizedBox(height: 8),
                    Text(
                        '${progress.isFinite ? (progress.clamp(0, 1) * 100).round() : 0}%',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 18)),
                  ])),
          const SizedBox(height: 12),
          ValueListenableBuilder<DownloadStatus>(
              valueListenable: task!.status,
              builder: (_, status, __) => _tvActions(context, status)),
        ] else
          _tvActions(context, null),
      ]);
    }
    final palette = AppPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.hero),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(PhosphorIcons.androidLogo(), color: palette.mutedText),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'FlixQuest v$appVersion',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (task != null) ...[
              const SizedBox(height: 14),
              ValueListenableBuilder<double>(
                valueListenable: task!.progress,
                builder: (context, progress, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor: palette.idleFill,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (task == null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: PillButton(
                  primary: true,
                  height: 46,
                  onPressed: () {
                    context
                        .read<SettingsProvider>()
                        .analytics
                        .trackAppUpdateDownload(appVersion);
                    onToggle(url);
                  },
                  icon: PhosphorIcons.downloadSimple(),
                  label: tr('download_action'),
                ),
              )
            else
              ValueListenableBuilder<DownloadStatus>(
                valueListenable: task!.status,
                builder: (context, status, _) {
                  if (status == DownloadStatus.completed) {
                    return Row(
                      children: [
                        Expanded(
                          child: PillButton(
                            primary: true,
                            height: 46,
                            onPressed: () => onOpen(url),
                            icon: PhosphorIcons.downloadSimple(),
                            label: tr('install_action'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        PillButton(
                          height: 46,
                          onPressed: () => onDelete(url),
                          icon: PhosphorIcons.trash(),
                          label: tr('remove'),
                        ),
                      ],
                    );
                  }
                  return PillButton(
                    height: 46,
                    onPressed: () => onToggle(url),
                    icon: status == DownloadStatus.downloading
                        ? PhosphorIcons.pause()
                        : PhosphorIcons.play(),
                    label: status == DownloadStatus.downloading
                        ? tr('pause_action')
                        : tr('resume_action'),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class UpdateBottom extends StatefulWidget {
  const UpdateBottom({this.television = false, super.key});

  final bool television;

  @override
  State<UpdateBottom> createState() => _UpdateBottomState();
}

class _UpdateBottomState extends State<UpdateBottom> {
  late final Future<PackageInfo> _packageInfo;
  bool _visible = false;
  String _notificationId = '';

  @override
  void initState() {
    super.initState();
    _packageInfo = PackageInfo.fromPlatform();
  }

  Future<void> _checkVisibility() async {
    PackageInfo packageInfo;
    try {
      packageInfo = await _packageInfo;
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final config = context.read<AppDependencyProvider>();
    final notificationId = AppUpdateService.notificationId(
      remoteVersion: config.latestAppVersion,
      latestBuildNumber: config.latestBuildNumber,
      minimumBuildNumber: config.minimumBuildNumber,
    );
    final ignored = sharedPrefsSingleton.getString('ignore_version') ?? '';

    setState(() {
      _notificationId = notificationId;
      _visible = notificationId.isNotEmpty &&
          ignored != notificationId &&
          AppUpdateService.isAvailable(
            packageInfo: packageInfo,
            remoteVersion: config.latestAppVersion,
            latestBuildNumber: config.latestBuildNumber,
            minimumBuildNumber: config.minimumBuildNumber,
          );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.watch<AppDependencyProvider>();
    _checkVisibility();
  }

  Future<void> _dismiss() async {
    if (_notificationId.isNotEmpty) {
      await sharedPrefsSingleton.setString('ignore_version', _notificationId);
    }
    if (mounted) {
      if (widget.television) FocusScope.of(context).nextFocus();
      setState(() => _visible = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final config = context.watch<AppDependencyProvider>();
    final remoteBuild = AppUpdateService.effectiveBuildNumber(
      latestBuildNumber: config.latestBuildNumber,
      minimumBuildNumber: config.minimumBuildNumber,
    );
    final version = AppUpdateService.displayVersion(
      config.latestAppVersion,
      remoteBuild,
    );
    final colors = Theme.of(context).colorScheme;
    if (widget.television) {
      return Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: colors.primary.withValues(alpha: 0.5))),
            child: Row(children: [
              Expanded(
                  child: Text('Update available • FlixQuest $version',
                      style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.w700))),
              const SizedBox(width: 16),
              TvUpdateAction(
                  label: 'Update',
                  primary: true,
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => const UpdateScreen(
                              isForced: false, television: true)))),
              const SizedBox(width: 12),
              TvUpdateAction(label: 'Not now', onPressed: _dismiss),
            ]),
          ));
    }

    // A quiet panel in the page's own tones: the accent only on the small
    // kicker, the action in ink, as on the rest of Home.
    final palette = AppPalette.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpace.gutter(context)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadii.hero),
          border: Border.all(color: palette.hairline),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 6, 14),
          child: Row(
            children: [
              Icon(
                PhosphorIcons.rocketLaunch(),
                size: 26,
                color: palette.foreground,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('update_available').toUpperCase(),
                      style: AppType.kicker.copyWith(color: colors.primary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tr('new_version', namedArgs: {'v': version}),
                      style: AppType.body.copyWith(
                        color: palette.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PillButton(
                primary: true,
                height: 36,
                label: tr('update'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UpdateScreen(isForced: false),
                  ),
                ),
              ),
              IconButton(
                onPressed: _dismiss,
                tooltip: tr('disable_notification_version'),
                color: palette.mutedText,
                icon: Icon(PhosphorIcons.x(), size: 18),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The update page while it finds the installed version.
class _UpdateSkeleton extends StatelessWidget {
  const _UpdateSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonPulse(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpace.gutter(context)),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SkeletonBlock(width: 72, height: 72, circle: true),
              SizedBox(height: 16),
              SkeletonBlock.line(width: 200, height: 26),
              SizedBox(height: 10),
              SkeletonBlock.line(width: 140),
              SizedBox(height: 24),
              SkeletonBlock(height: 120, radius: AppRadii.hero),
            ],
          ),
        ),
      );
}
