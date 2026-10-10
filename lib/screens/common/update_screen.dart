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
          : _buildMobile(),
    );
  }

  /// The version to offer, or null while checking, after an error, or when
  /// the installed one is current.
  String? _availableVersion(AppDependencyProvider config) {
    final packageInfo = _packageInfo;
    if (_error != null ||
        packageInfo == null ||
        !AppUpdateService.isAvailable(
          packageInfo: packageInfo,
          remoteVersion: config.latestAppVersion,
          latestBuildNumber: config.latestBuildNumber,
          minimumBuildNumber: config.minimumBuildNumber,
        )) {
      return null;
    }
    return AppUpdateService.displayVersion(
      config.latestAppVersion,
      AppUpdateService.effectiveBuildNumber(
        latestBuildNumber: config.latestBuildNumber,
        minimumBuildNumber: config.minimumBuildNumber,
      ),
    );
  }

  Widget _buildMobile() {
    final config = context.watch<AppDependencyProvider>();
    final version = _availableVersion(config);
    final downloadUrl = config.appDownloadUrl;
    return Scaffold(
      backgroundColor: AppPalette.of(context).page,
      appBar: PageAppBar(title: tr('check_for_update')),
      body: SkeletonSwitcher(
        loading: _error == null && _packageInfo == null,
        alignment: Alignment.topCenter,
        skeleton: const _UpdateSkeleton(),
        child: _buildBody(config, version),
      ),
      // The action stays in reach however long the release notes run.
      bottomNavigationBar: version != null && downloadUrl.isNotEmpty
          ? _UpdateActionBar(
              appVersion: version,
              url: downloadUrl,
              task: _downloadManager.getDownload(downloadUrl),
              onToggle: _toggleDownload,
              onOpen: _openDownload,
              onDelete: _deleteDownload,
            )
          : null,
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

  Widget _buildBody(AppDependencyProvider config, String? version) {
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
    final packageInfo = _packageInfo;
    if (packageInfo == null) return const SizedBox.shrink();
    if (version == null) {
      return EmptyState(
        icon: PhosphorIcons.checkCircle(),
        title: tr('update_up_to_date'),
        message: tr(
          'update_up_to_date_message',
          namedArgs: {'v': packageInfo.version},
        ),
      );
    }
    final gutter = AppSpace.gutter(context);
    return ReadableWidth(
      maxWidth: 600,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          gutter,
          AppSpace.sm,
          gutter,
          AppSpace.xxxl,
        ),
        children: [
          _UpdateHero(installed: packageInfo.version, latest: version),
          if (_forced) ...[
            const SizedBox(height: AppSpace.md),
            _UpdateNotice(
              icon: PhosphorIcons.warningCircle(),
              message: tr('update_required_note'),
              warning: true,
            ),
          ],
          if (config.appDownloadUrl.isEmpty) ...[
            const SizedBox(height: AppSpace.md),
            _UpdateNotice(
              icon: PhosphorIcons.clockCountdown(),
              message: tr('update_link_unavailable'),
            ),
          ],
          if (config.changeLog.trim().isNotEmpty) ...[
            KickerHeading(
              tr('update_whats_new'),
              padding: const EdgeInsets.only(top: AppSpace.xxl, bottom: 10),
            ),
            _WhatsNew(changeLog: config.changeLog),
          ],
        ],
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

/// The TV's download progress and actions; phones use [_UpdateActionBar].
class _DownloadCard extends StatelessWidget {
  const _DownloadCard({
    required this.appVersion,
    required this.url,
    required this.task,
    required this.onToggle,
    required this.onOpen,
    required this.onDelete,
  });

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
                          fontFeatures: const [FontFeature.tabularFigures()])),
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
                padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 14, 14),
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
                            style:
                                AppType.kicker.copyWith(color: colors.primary),
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
                      onPressed: () => _openUpdatePage(context),
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

void _openUpdatePage(BuildContext context) => Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const UpdateScreen(isForced: false),
      ),
    );

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
                            style:
                                AppType.body.copyWith(color: palette.mutedText),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        more > 0
                            ? '${tr('see_changelogs')} (+$more)'
                            : tr('see_changelogs'),
                        style:
                            AppType.kicker.copyWith(color: palette.foreground),
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

/// The new version against the installed one, under the app's mark.
class _UpdateHero extends StatelessWidget {
  const _UpdateHero({required this.installed, required this.latest});

  final String installed;
  final String latest;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.hero),
        border: Border.all(color: palette.hairline),
        // A wash of the accent from one corner: the only colour on the page.
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            Color.alphaBlend(accent.withValues(alpha: .2), palette.surface),
            palette.surface,
          ],
          stops: const [0, .65],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppPalette.logoPlate,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset('assets/images/logo.png'),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('update_new_version_kicker').toUpperCase(),
                        style: AppType.kicker.copyWith(color: accent),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'FlixQuest $latest',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.pageTitle.copyWith(
                          fontSize: 24,
                          height: 28 / 24,
                          color: palette.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.xl),
            Row(
              children: [
                Expanded(
                  child: _VersionTile(
                    label: tr('update_installed'),
                    version: installed,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    PhosphorIcons.arrowRight(),
                    size: 18,
                    color: palette.mutedText,
                  ),
                ),
                Expanded(
                  child: _VersionTile(
                    label: tr('update_latest'),
                    version: latest,
                    current: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VersionTile extends StatelessWidget {
  const _VersionTile({
    required this.label,
    required this.version,
    this.current = false,
  });

  final String label;
  final String version;

  /// The version being offered, filled more strongly.
  final bool current;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: current ? palette.idleFill : palette.idleFillFaint,
        borderRadius: BorderRadius.circular(AppRadii.hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.kicker.copyWith(color: palette.mutedText),
          ),
          const SizedBox(height: 4),
          Text(
            'v$version',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.sectionHeader.copyWith(
              color: current ? palette.foreground : palette.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

/// One line the reader should know before updating.
class _UpdateNotice extends StatelessWidget {
  const _UpdateNotice({
    required this.icon,
    required this.message,
    this.warning = false,
  });

  final IconData icon;
  final String message;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final error = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warning ? error.withValues(alpha: .1) : palette.idleFillFaint,
        borderRadius: BorderRadius.circular(AppRadii.hero),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: warning ? error : palette.mutedText),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: AppType.body.copyWith(color: palette.secondaryText),
            ),
          ),
        ],
      ),
    );
  }
}

/// The release notes in full: `#` lines as headings, the rest as bullets.
class _WhatsNew extends StatelessWidget {
  const _WhatsNew({required this.changeLog});

  final String changeLog;

  static final _heading = RegExp(r'^#+\s*');
  static final _marker = RegExp(r'^(?:[-*•·]|\d+[.)])\s+');

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final lines = changeLog
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.hero),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, line) in lines.indexed)
            if (_heading.hasMatch(line))
              Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : 14, bottom: 6),
                child: Text(
                  line.replaceFirst(_heading, ''),
                  style: AppType.cardTitle.copyWith(
                    fontSize: 15,
                    color: palette.foreground,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 7),
                      decoration: BoxDecoration(
                        color: palette.mutedText,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        line.replaceFirst(_marker, ''),
                        style: AppType.body.copyWith(
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

/// The phone's download, pause, install and retry, pinned under the page.
class _UpdateActionBar extends StatelessWidget {
  const _UpdateActionBar({
    required this.appVersion,
    required this.url,
    required this.task,
    required this.onToggle,
    required this.onOpen,
    required this.onDelete,
  });

  final String appVersion;
  final String url;
  final DownloadTask? task;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final task = this.task;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.page,
        border: Border(top: BorderSide(color: palette.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: gutter,
            vertical: AppSpace.md,
          ),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: Alignment.bottomCenter,
                child: task == null
                    ? _download(context)
                    : ValueListenableBuilder<DownloadStatus>(
                        valueListenable: task.status,
                        builder: (context, status, _) =>
                            _forStatus(context, task, status),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _download(BuildContext context) => SizedBox(
        width: double.infinity,
        child: PillButton(
          primary: true,
          icon: PhosphorIcons.downloadSimple(),
          label: tr('update_download'),
          onPressed: () {
            context
                .read<SettingsProvider>()
                .analytics
                .trackAppUpdateDownload(appVersion);
            onToggle(url);
          },
        ),
      );

  Widget _forStatus(
    BuildContext context,
    DownloadTask task,
    DownloadStatus status,
  ) {
    final palette = AppPalette.of(context);
    switch (status) {
      case DownloadStatus.completed:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: PillButton(
                    primary: true,
                    icon: PhosphorIcons.package(),
                    label: tr('install_action'),
                    onPressed: () => onOpen(url),
                  ),
                ),
                const SizedBox(width: 10),
                PillButton(
                  icon: PhosphorIcons.trash(),
                  label: tr('remove'),
                  onPressed: () => onDelete(url),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(PhosphorIcons.info(), size: 16, color: palette.mutedText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('update_install_hint'),
                    style: AppType.metadata.copyWith(color: palette.mutedText),
                  ),
                ),
              ],
            ),
          ],
        );
      case DownloadStatus.failed:
      case DownloadStatus.canceled:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('update_download_failed'),
              style: AppType.body.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 10),
            PillButton(
              primary: true,
              icon: PhosphorIcons.arrowClockwise(),
              label: tr('retry'),
              onPressed: () => onToggle(url),
            ),
          ],
        );
      case DownloadStatus.queued:
      case DownloadStatus.downloading:
      case DownloadStatus.paused:
        final paused = status == DownloadStatus.paused;
        return Row(
          children: [
            Expanded(
              child: ValueListenableBuilder<double>(
                valueListenable: task.progress,
                builder: (context, progress, _) {
                  final value =
                      progress.isFinite ? progress.clamp(0.0, 1.0) : 0.0;
                  final percent = '${(value * 100).round()}%';
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              paused
                                  ? tr('update_paused')
                                  : tr('update_downloading'),
                              style: AppType.cardTitle.copyWith(
                                color: palette.foreground,
                              ),
                            ),
                          ),
                          Text(
                            percent,
                            style: AppType.cardTitle.copyWith(
                              color: palette.mutedText,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: status == DownloadStatus.queued && value == 0
                              ? null
                              : value,
                          minHeight: 6,
                          color: palette.foreground,
                          backgroundColor: palette.idleFill,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            PillButton(
              icon: paused ? PhosphorIcons.play() : PhosphorIcons.pause(),
              label: paused ? tr('resume_action') : tr('pause_action'),
              onPressed: () => onToggle(url),
            ),
          ],
        );
    }
  }
}

/// The update page while it finds the installed version.
class _UpdateSkeleton extends StatelessWidget {
  const _UpdateSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonPulse(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpace.gutter(context),
            AppSpace.sm,
            AppSpace.gutter(context),
            0,
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBlock(height: 172, radius: AppRadii.hero),
              SizedBox(height: AppSpace.xxl),
              SkeletonBlock.line(width: 90),
              SizedBox(height: 12),
              SkeletonBlock(height: 160, radius: AppRadii.hero),
            ],
          ),
        ),
      );
}
