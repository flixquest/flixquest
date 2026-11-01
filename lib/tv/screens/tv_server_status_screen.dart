import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../provider/app_dependency_provider.dart';
import '../../video_providers/scraper_api.dart';
import '../app/tv_design.dart';
import '../widgets/tv_page_header.dart';
import '../widgets/tv_pill_button.dart';
import '../widgets/tv_state_panel.dart';

/// Whether the streaming sources are up, as the scraper last found them:
/// how many are online beside the list of them.
///
/// Check again holds focus; Up and Down scroll the list, so a long one reads
/// without stepping through rows that do nothing.
class TvServerStatusScreen extends StatefulWidget {
  const TvServerStatusScreen({this.load, super.key});

  /// Stands in for the scraper in tests.
  final Future<ProviderHealthSnapshot> Function(BuildContext context)? load;

  @override
  State<TvServerStatusScreen> createState() => _TvServerStatusScreenState();
}

class _TvServerStatusScreenState extends State<TvServerStatusScreen> {
  final ScrollController _list = ScrollController();
  ProviderHealthSnapshot? _snapshot;
  bool _checking = true;
  bool _failed = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _check();
  }

  @override
  void dispose() {
    _list.dispose();
    super.dispose();
  }

  Future<ProviderHealthSnapshot> _fetch() =>
      widget.load?.call(context) ??
      ScraperApi(context.read<AppDependencyProvider>().flixquestAPIURLV2)
          .getProviderHealthStatus();

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _failed = false;
    });
    try {
      final snapshot = await _fetch();
      if (mounted) setState(() => _snapshot = snapshot);
    } catch (error) {
      debugPrint('[TvServerStatus] check failed: $error');
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    final up = key == LogicalKeyboardKey.arrowUp;
    if (!up && key != LogicalKeyboardKey.arrowDown) {
      return KeyEventResult.ignored;
    }
    if (event is KeyUpEvent || !_list.hasClients) {
      return KeyEventResult.handled;
    }
    final position = _list.position;
    final step = position.viewportDimension * 0.6;
    _list.animateTo(
      (position.pixels + (up ? -step : step))
          .clamp(position.minScrollExtent, position.maxScrollExtent),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final palette = TvPalette.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final metrics = TvShellMetrics.fromConstraints(constraints);
          final inset = metrics.safeInset + metrics.contentPadding;
          final snapshot = _snapshot;
          return Padding(
            padding: EdgeInsets.all(inset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding:
                      const EdgeInsets.only(left: TvDesign.focusOutset + 4),
                  child: TvPageHeader(
                    kicker: tr('tv_server_status_kicker'),
                    title: tr('tv_server_status'),
                    compact: metrics.compact,
                  ),
                ),
                SizedBox(height: metrics.compact ? 16 : 24),
                Expanded(
                  child: snapshot == null && _failed
                      ? TvStatePanel(
                          title: tr('provider_health_unavailable'),
                          message: tr('tv_check_your_connection_and_try_again'),
                          icon: PhosphorIcons.warningCircle(),
                          actionLabel: tr('retry'),
                          onAction: _check,
                          autofocusAction: true,
                        )
                      : Focus(
                          canRequestFocus: false,
                          skipTraversal: true,
                          onKeyEvent: _handleKey,
                          child: _buildStatus(snapshot, metrics.compact),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatus(ProviderHealthSnapshot? snapshot, bool compact) {
    final palette = TvPalette.of(context);
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: compact ? 360 : 460,
          child: Padding(
            padding: const EdgeInsets.only(left: TvDesign.focusOutset + 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Overview(snapshot: snapshot, compact: compact),
                if (_failed) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    tr('tv_server_status_stale'),
                    style: TextStyle(
                      color: colors.error,
                      fontFamily: 'FigtreeSB',
                      fontSize: compact ? 14 : 16,
                    ),
                  ),
                ],
                SizedBox(height: compact ? 18 : 26),
                TvPillButton(
                  label: _checking ? tr('tv_checking') : tr('tv_check_again'),
                  semanticLabel: tr('tv_check_again'),
                  icon: PhosphorIcons.arrowsClockwise(),
                  autofocus: true,
                  prominent: true,
                  scrollAlignment: null,
                  // Stays focusable while checking, so the remote keeps
                  // something to hold; a press meanwhile does nothing.
                  onActivate: () {
                    if (!_checking) _check();
                  },
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: compact ? 32 : 48),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TvSectionLabel(
                snapshot == null
                    ? tr('provider_health_overview').toUpperCase()
                    : '${tr('provider_health_overview').toUpperCase()}'
                        ' · ${snapshot.providers.length}',
              ),
              Expanded(
                child: snapshot == null
                    ? const SizedBox.shrink()
                    : snapshot.providers.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(left: 16, top: 8),
                            child: Text(
                              tr('provider_health_empty'),
                              style: TextStyle(
                                color: palette.mutedText,
                                fontSize: compact ? 15 : 17,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _list,
                            itemCount: snapshot.providers.length,
                            itemBuilder: (context, index) => _ProviderRow(
                              provider: snapshot.providers[index],
                              compact: compact,
                            ),
                          ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The share of sources online as a ring, what that means, when it was
/// checked, and the counts.
class _Overview extends StatelessWidget {
  const _Overview({required this.snapshot, required this.compact});

  final ProviderHealthSnapshot? snapshot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    final error = Theme.of(context).colorScheme.error;
    final snapshot = this.snapshot;
    final ring = compact ? 76.0 : 96.0;
    if (snapshot == null) {
      return SizedBox(
        height: ring,
        child: Row(
          children: <Widget>[
            SizedBox.square(
              dimension: ring * 0.5,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: palette.mutedText,
              ),
            ),
            const SizedBox(width: 18),
            Text(
              tr('tv_checking'),
              style: TextStyle(
                color: palette.mutedText,
                fontFamily: 'FigtreeSB',
                fontSize: compact ? 17 : 20,
              ),
            ),
          ],
        ),
      );
    }
    final healthy = snapshot.offline == 0 && snapshot.total > 0;
    final down = snapshot.online == 0;
    final percentage = (snapshot.availability * 100).round();
    final updated = snapshot.updatedAt?.toLocal();
    final localizations = MaterialLocalizations.of(context);
    final interval = snapshot.interval.inMinutes;
    TextStyle meta() => TextStyle(
          color: palette.mutedText,
          fontSize: compact ? 13 : 15,
          height: 1.3,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            SizedBox.square(
              dimension: ring,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  SizedBox.square(
                    dimension: ring - 6,
                    child: CircularProgressIndicator(
                      value: snapshot.availability.clamp(0.0, 1.0),
                      strokeWidth: 7,
                      strokeCap: StrokeCap.round,
                      color: down ? error : palette.foreground,
                      backgroundColor: palette.idleFill,
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      color: palette.foreground,
                      fontFamily: 'FigtreeBold',
                      fontSize: compact ? 19 : 23,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: compact ? 18 : 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    healthy
                        ? tr('server_working')
                        : down
                            ? tr('server_down')
                            : tr('provider_health_degraded'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: down ? error : palette.foreground,
                      fontFamily: 'FigtreeBold',
                      fontSize: compact ? 20 : 25,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr('tv_sources_online', namedArgs: {
                      'online': '${snapshot.online}',
                      'total': '${snapshot.total}',
                    }),
                    style: meta(),
                  ),
                  if (updated != null)
                    Text(
                      '${tr('last_updated')}: '
                      '${localizations.formatMediumDate(updated)} · '
                      '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(updated))}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: meta(),
                    ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 14 : 20),
        Row(
          children: <Widget>[
            Expanded(
              child: _Metric(
                label: tr('provider_online'),
                value: snapshot.online,
                compact: compact,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Metric(
                label: tr('provider_offline'),
                value: snapshot.offline,
                warn: snapshot.offline > 0,
                compact: compact,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Metric(
                label: tr('provider_total'),
                value: snapshot.total,
                compact: compact,
              ),
            ),
          ],
        ),
        if (interval > 0) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            tr('provider_health_interval', namedArgs: {'minutes': '$interval'}),
            style: meta(),
          ),
        ],
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.compact,
    this.warn = false,
  });

  final String label;
  final int value;
  final bool compact;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    return Container(
      padding: EdgeInsets.symmetric(vertical: compact ? 8 : 12),
      decoration: BoxDecoration(
        color: palette.idleFill,
        borderRadius: BorderRadius.circular(TvDesign.cardRadius),
      ),
      child: Column(
        children: <Widget>[
          Text(
            '$value',
            style: TextStyle(
              color: warn
                  ? Theme.of(context).colorScheme.error
                  : palette.foreground,
              fontFamily: 'FigtreeBold',
              fontSize: compact ? 20 : 24,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: compact ? 12 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// One source: whether it answered, under its public name, and how fast.
class _ProviderRow extends StatelessWidget {
  const _ProviderRow({required this.provider, required this.compact});

  final ProviderHealthResult provider;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    final error = Theme.of(context).colorScheme.error;
    final online = provider.online;
    return Container(
      height: compact ? 52 : 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.hairline)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            online
                ? PhosphorIcons.checkCircle()
                : PhosphorIcons.warningCircle(),
            color: online ? palette.mutedText : error,
            size: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  provider.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.foreground,
                    fontFamily: 'FigtreeSB',
                    fontSize: compact ? 16 : 18,
                  ),
                ),
                Text(
                  tr('provider_response_time', namedArgs: {
                    'milliseconds': '${provider.requestTime.inMilliseconds}',
                  }),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: compact ? 12 : 14,
                  ),
                ),
              ],
            ),
          ),
          Text(
            online ? tr('provider_online') : tr('provider_offline'),
            style: TextStyle(
              color: online ? palette.mutedText : error,
              fontFamily: 'FigtreeSB',
              fontSize: compact ? 14 : 16,
            ),
          ),
        ],
      ),
    );
  }
}
