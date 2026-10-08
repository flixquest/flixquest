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

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../design/skeleton.dart';
import '../../mobile/widgets/page_kit.dart';
import '../../mobile/widgets/pill_button.dart';
import '../../mobile/widgets/settings_kit.dart' show SheetTitle;
import '../../tv/app/tv_design.dart' show TvDesign, TvPalette;
import '../../tv/focus/tv_keymap.dart';
import '../../tv/widgets/tv_dialog.dart';
import '../../tv/widgets/tv_loading_skeletons.dart';
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
    _showingMandatoryDialog = true;
    try {
      final update = await showConfirmDialog(
        context,
        icon: PhosphorIcons.rocketLaunch(),
        title: tr('update_available'),
        message: tr('must_update'),
        cancelLabel: tr('exit'),
        confirmLabel: tr('update'),
      );
      if (update == false) await SystemNavigator.pop();
    } finally {
      _showingMandatoryDialog = false;
    }
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
          const TvUpdateSkeleton()
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
            Text(
                'The download link is not available yet. Please try again later.',
                style: TextStyle(
                    color: TvPalette.of(context).mutedText, fontSize: 20)),
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
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
    showChangelogSheet(context, changeLog);
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
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Download failed. Check your connection and retry.',
                style: TextStyle(
                    fontSize: 20, color: Theme.of(context).colorScheme.error))),
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
      final palette = TvPalette.of(context);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (task != null) ...[
          ValueListenableBuilder<double>(
              valueListenable: task!.progress,
              builder: (_, progress, __) {
                final value = progress.isFinite ? progress.clamp(0.0, 1.0) : 0.0;
                return Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress.isFinite ? value : null,
                        minHeight: 6,
                        backgroundColor: palette.idleFill,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 56,
                    child: Text('${(value * 100).round()}%',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                            color: palette.mutedText,
                            fontFamily: 'FigtreeSB',
                            fontSize: 18,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ])),
                  ),
                ]);
              }),
          const SizedBox(height: 18),
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
                    style: AppType.cardTitle.copyWith(
                      fontSize: 15,
                      color: palette.foreground,
                    ),
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
                            onPressed: () => onOpen(url),
                            icon: PhosphorIcons.downloadSimple(),
                            label: tr('install_action'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        PillButton(
                          onPressed: () => onDelete(url),
                          icon: PhosphorIcons.trash(),
                          label: tr('remove'),
                        ),
                      ],
                    );
                  }
                  return PillButton(
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

/// The release notes in a sheet, one bulleted entry per line, with the
/// version under the title when it's known.
Future<void> showChangelogSheet(
  BuildContext context,
  String changeLog, {
  String? version,
}) =>
    showAppSheet<void>(
      context,
      builder: (_) => _ChangelogSheet(changeLog: changeLog, version: version),
    );

class _ChangelogSheet extends StatelessWidget {
  const _ChangelogSheet({required this.changeLog, this.version});

  final String changeLog;
  final String? version;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final items = AppUpdateService.changelogItems(changeLog);
    final version = this.version;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .75,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + AppSpace.xxl,
        ),
        children: [
          SheetTitle(tr('changelogs')),
          if (version != null)
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                gutter,
                0,
                gutter,
                AppSpace.md,
              ),
              child: Text(
                tr('new_version', namedArgs: {'v': version}),
                style: AppType.body.copyWith(color: palette.mutedText),
              ),
            ),
          for (final item in items.isEmpty ? [changeLog.trim()] : items)
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(gutter, 7, gutter, 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    // Sits on the first line's x-height.
                    margin: const EdgeInsetsDirectional.only(top: 7, end: 12),
                    decoration: BoxDecoration(
                      color: palette.mutedText,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: AppType.body.copyWith(
                        fontSize: 15,
                        height: 1.4,
                        color: palette.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
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

    setState(() {
      _visible = AppUpdateService.isAvailable(
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
    final items = AppUpdateService.changelogItems(config.changeLog);
    if (widget.television) {
      // The TV's panel: the page's surface with a hairline, the accent only
      // on the kicker (as on the page headers), the notes muted.
      final palette = TvPalette.of(context);
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(TvDesign.cardRadius),
            border: Border.all(color: palette.hairline),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: palette.idleFill,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PhosphorIcons.rocketLaunch(),
                  size: 22,
                  color: palette.foreground,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'UPDATE AVAILABLE',
                      style: TextStyle(
                        color: colors.primary,
                        fontFamily: 'FigtreeSB',
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'FlixQuest $version',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.foreground,
                        fontFamily: 'FigtreeBold',
                        fontSize: 21,
                        letterSpacing: -0.25,
                      ),
                    ),
                    if (items.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      DefaultTextStyle.merge(
                        style: TextStyle(
                          color: palette.mutedText,
                          fontSize: 16,
                          height: 1.35,
                        ),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                items.take(2).join('  ·  '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Kept whole however long the notes before it.
                            if (items.length > 2)
                              Text('  ·  +${items.length - 2} more'),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              TvUpdateAction(
                label: 'Update',
                primary: true,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const UpdateScreen(isForced: false, television: true),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.hero),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(16, 14, 14, 14),
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
                            style: AppType.kicker
                                .copyWith(color: colors.primary),
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
                      label: tr('update'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const UpdateScreen(isForced: false),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (items.isNotEmpty)
                _ChangelogPreview(
                  items: items,
                  onTap: () => showChangelogSheet(
                    context,
                    config.changeLog,
                    version: version,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The first few changelog entries under the update banner: one ellipsized
/// line each, so the banner grows by a fixed amount however long the notes
/// are. Tapping opens all of them.
class _ChangelogPreview extends StatelessWidget {
  const _ChangelogPreview({required this.items, required this.onTap});

  static const _maxItems = 3;

  final List<String> items;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final more = items.length - _maxItems;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: palette.hairline)),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final item in items.take(_maxItems))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1.5),
                          child: Text(
                            '•  $item',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.body
                                .copyWith(color: palette.mutedText),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        more > 0
                            ? '${tr('see_changelogs')} (+$more)'
                            : tr('see_changelogs'),
                        style: AppType.kicker
                            .copyWith(color: palette.foreground),
                      ),
                    ],
                  ),
                ),
                Icon(
                  PhosphorIcons.caretRight(),
                  size: 16,
                  color: palette.mutedText,
                ),
              ],
            ),
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
