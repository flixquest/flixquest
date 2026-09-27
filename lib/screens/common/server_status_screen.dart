// ignore_for_file: use_build_context_synchronously

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../provider/app_dependency_provider.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../design/skeleton.dart';
import '../../mobile/widgets/details_parts.dart';
import '../../mobile/widgets/page_kit.dart';
import '../../video_providers/scraper_api.dart';

class ServerStatusScreen extends StatefulWidget {
  const ServerStatusScreen({super.key});

  @override
  State<ServerStatusScreen> createState() => _ServerStatusScreenState();
}

class _ServerStatusScreenState extends State<ServerStatusScreen> {
  bool _checking = true;
  String? _error;
  ProviderHealthSnapshot? _snapshot;
  final Set<String> _revealedProviderIds = <String>{};

  @override
  void initState() {
    super.initState();
    _checkServer();
  }

  Future<void> _checkServer() async {
    if (mounted) {
      setState(() {
        _checking = true;
        _error = null;
      });
    }

    try {
      final scraperApiUrl =
          context.read<AppDependencyProvider>().flixquestAPIURLV2;
      final snapshot =
          await ScraperApi(scraperApiUrl).getProviderHealthStatus();
      if (!mounted) return;
      setState(() => _snapshot = snapshot);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      appBar: PageAppBar(
        title: tr('check_server'),
        actions: [
          IconButton(
            onPressed: _checking ? null : _checkServer,
            tooltip: tr('check'),
            icon: Icon(PhosphorIcons.arrowsClockwise()),
          ),
        ],
      ),
      body: SkeletonSwitcher(
        loading: _snapshot == null && _checking,
        skeleton: const _StatusSkeleton(),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final snapshot = _snapshot;
    if (snapshot == null) {
      return EmptyState.error(
        title: tr('provider_health_unavailable'),
        message: tr('check_connection'),
        onRetry: _checkServer,
      );
    }
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    return RefreshIndicator(
      color: palette.foreground,
      backgroundColor: palette.raisedSurface,
      onRefresh: _checkServer,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: AppSpace.xs,
          bottom: AppSpace.xxxl + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          if (_error != null)
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, AppSpace.md),
              child: DetailsMessage(
                message: tr('check_connection'),
                onRetry: _checkServer,
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: _buildOverview(snapshot),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: () {
              setState(() {
                if (_revealedProviderIds.length == snapshot.providers.length) {
                  _revealedProviderIds.clear();
                } else {
                  _revealedProviderIds
                      .addAll(snapshot.providers.map((p) => p.id));
                }
              });
            },
            child: KickerHeading(
              tr('provider_health_overview'),
              padding: EdgeInsetsDirectional.fromSTEB(
                gutter,
                AppSpace.xxl,
                gutter,
                AppSpace.xs,
              ),
              trailing: Text(
                '${snapshot.providers.length}',
                style: AppType.metadata.copyWith(color: palette.mutedText),
              ),
            ),
          ),
          if (snapshot.providers.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: DetailsMessage(message: tr('provider_health_empty')),
            )
          else
            for (final provider in snapshot.providers)
              _buildProviderRow(provider),
        ],
      ),
    );
  }

  Widget _buildOverview(ProviderHealthSnapshot snapshot) {
    final palette = AppPalette.of(context);
    final error = Theme.of(context).colorScheme.error;
    final healthy = snapshot.offline == 0 && snapshot.total > 0;
    final unavailable = snapshot.online == 0;
    final statusText = healthy
        ? tr('server_working')
        : unavailable
            ? tr('server_down')
            : tr('provider_health_degraded');
    final percentage = (snapshot.availability * 100).round();
    final updatedAt = snapshot.updatedAt?.toLocal();
    final localizations = MaterialLocalizations.of(context);
    final updatedText = updatedAt == null
        ? null
        : '${localizations.formatMediumDate(updatedAt)} · '
            '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(updatedAt))}';
    final intervalMinutes = snapshot.interval.inMinutes;
    return Container(
      padding: const EdgeInsets.all(AppSpace.xl),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox.square(
                dimension: 84,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.square(
                      dimension: 78,
                      child: CircularProgressIndicator(
                        value: snapshot.availability.clamp(0.0, 1.0),
                        strokeWidth: 7,
                        strokeCap: StrokeCap.round,
                        color: unavailable ? error : palette.foreground,
                        backgroundColor: palette.idleFill,
                      ),
                    ),
                    Text(
                      '$percentage%',
                      style: AppType.sectionHeader.copyWith(
                        fontFamily: AppType.bold,
                        color: palette.foreground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.xl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: AppType.sectionHeader.copyWith(
                        fontFamily: AppType.bold,
                        fontSize: 20,
                        color: unavailable ? error : palette.foreground,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      tr(
                        'provider_availability',
                        namedArgs: {'percentage': '$percentage'},
                      ),
                      style: AppType.body.copyWith(color: palette.mutedText),
                    ),
                    if (updatedText != null) ...[
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        '${tr('last_updated')}: $updatedText',
                        style: AppType.metadata.copyWith(
                          color: palette.mutedText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xl),
          Row(
            children: [
              Expanded(
                child: _buildMetric(tr('provider_online'), snapshot.online),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: _buildMetric(
                  tr('provider_offline'),
                  snapshot.offline,
                  warn: snapshot.offline > 0,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: _buildMetric(tr('provider_total'), snapshot.total),
              ),
            ],
          ),
          if (intervalMinutes > 0) ...[
            const SizedBox(height: AppSpace.lg),
            Text(
              tr(
                'provider_health_interval',
                namedArgs: {'minutes': '$intervalMinutes'},
              ),
              style: AppType.metadata.copyWith(color: palette.mutedText),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetric(String label, int value, {bool warn = false}) {
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: palette.idleFill,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: AppType.sectionHeader.copyWith(
              fontFamily: AppType.bold,
              color: warn
                  ? Theme.of(context).colorScheme.error
                  : palette.foreground,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.metadata.copyWith(color: palette.mutedText),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderRow(ProviderHealthResult provider) {
    final palette = AppPalette.of(context);
    final error = Theme.of(context).colorScheme.error;
    final revealed = _revealedProviderIds.contains(provider.id);
    return GestureDetector(
      onDoubleTap: () => setState(() {
        if (!_revealedProviderIds.remove(provider.id)) {
          _revealedProviderIds.add(provider.id);
        }
      }),
      child: ListRow(
        icon: provider.online
            ? PhosphorIcons.checkCircle()
            : PhosphorIcons.warningCircle(),
        label: revealed ? provider.originalName : provider.displayName,
        subtitle: tr(
          'provider_response_time',
          namedArgs: {
            'milliseconds': '${provider.requestTime.inMilliseconds}',
          },
        ),
        trailing: Text(
          provider.online ? tr('provider_online') : tr('provider_offline'),
          style: AppType.cardTitle.copyWith(
            fontSize: 13,
            color: provider.online ? palette.mutedText : error,
          ),
        ),
      ),
    );
  }
}

/// The status page's shape while the first check runs.
class _StatusSkeleton extends StatelessWidget {
  const _StatusSkeleton();

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpace.gutter(context);
    return SkeletonPulse(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, AppSpace.xs, gutter, 0),
              child: const SkeletonBlock(height: 210, radius: AppRadii.hero),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                gutter,
                AppSpace.xxl,
                gutter,
                AppSpace.sm,
              ),
              child: const SkeletonBlock.line(width: 120, height: 11),
            ),
            const ListSkeleton(
              rows: 6,
              leadingWidth: 22,
              leadingHeight: 22,
              circle: true,
            ),
          ],
        ),
      ),
    );
  }
}
