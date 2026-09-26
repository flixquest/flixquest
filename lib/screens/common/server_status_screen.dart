// ignore_for_file: use_build_context_synchronously

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../provider/app_dependency_provider.dart';
import '../../ui_components/app_ui_components.dart';
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
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('check_server')),
        actions: [
          IconButton(
            onPressed: _checking ? null : _checkServer,
            tooltip: tr('check'),
            icon: Icon(PhosphorIcons.arrowsClockwise()),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AppResponsiveContent(
        maxWidth: 760,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        child: Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _checking
                  ? const LinearProgressIndicator(key: ValueKey('loading'))
                  : const SizedBox(height: 4, key: ValueKey('idle')),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildBody(colors)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ColorScheme colors) {
    final snapshot = _snapshot;
    if (snapshot == null) {
      if (_checking) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                tr('checking_server'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        );
      }
      return _buildErrorState(colors);
    }

    return RefreshIndicator(
      onRefresh: _checkServer,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_error != null) ...[
            _buildRefreshError(colors),
            const SizedBox(height: 12),
          ],
          _buildOverview(snapshot, colors),
          const SizedBox(height: 24),
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
            child: Row(
              children: [
                Text(
                  tr('provider_health_overview'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                Text(
                  '${snapshot.providers.length}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (snapshot.providers.isEmpty)
            _buildEmptyProviders(colors)
          else
            for (var index = 0; index < snapshot.providers.length; index++) ...[
              _buildProviderCard(snapshot.providers[index], colors),
              if (index != snapshot.providers.length - 1)
                const SizedBox(height: 10),
            ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildOverview(
    ProviderHealthSnapshot snapshot,
    ColorScheme colors,
  ) {
    final healthy = snapshot.offline == 0 && snapshot.total > 0;
    final unavailable = snapshot.online == 0;
    final statusColor = healthy
        ? colors.tertiary
        : unavailable
            ? colors.error
            : colors.primary;
    final statusText = healthy
        ? tr('server_working')
        : unavailable
            ? tr('server_down')
            : tr('provider_health_degraded');
    final percentage = (snapshot.availability * 100).round();
    final updatedAt = snapshot.updatedAt;
    final materialLocalizations = MaterialLocalizations.of(context);
    final localUpdatedAt = updatedAt?.toLocal();
    final updatedText = localUpdatedAt == null
        ? null
        : '${materialLocalizations.formatMediumDate(localUpdatedAt)} • '
            '${materialLocalizations.formatTimeOfDay(TimeOfDay.fromDateTime(localUpdatedAt))}';
    final intervalMinutes = snapshot.interval.inMinutes;

    return Card(
      margin: EdgeInsets.zero,
      color: colors.surfaceContainerHighest.withValues(alpha: .55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: statusColor.withValues(alpha: .28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox.square(
                  dimension: 92,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.square(
                        dimension: 84,
                        child: CircularProgressIndicator(
                          value: snapshot.availability.clamp(0.0, 1.0),
                          strokeWidth: 9,
                          strokeCap: StrokeCap.round,
                          color: statusColor,
                          backgroundColor: colors.surfaceContainerHighest,
                        ),
                      ),
                      Text(
                        '$percentage%',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusText,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr(
                          'provider_availability',
                          namedArgs: {'percentage': '$percentage'},
                        ),
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      if (updatedText != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              PhosphorIcons.clock(),
                              size: 16,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${tr('last_updated')}: $updatedText',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildMetric(
                    tr('provider_online'),
                    snapshot.online,
                    colors.tertiary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetric(
                    tr('provider_offline'),
                    snapshot.offline,
                    colors.error,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetric(
                    tr('provider_total'),
                    snapshot.total,
                    colors.primary,
                  ),
                ),
              ],
            ),
            if (intervalMinutes > 0) ...[
              const SizedBox(height: 16),
              Text(
                tr(
                  'provider_health_interval',
                  namedArgs: {'minutes': '$intervalMinutes'},
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard(
    ProviderHealthResult provider,
    ColorScheme colors,
  ) {
    final color = provider.online ? colors.tertiary : colors.error;
    final isRevealed = _revealedProviderIds.contains(provider.id);
    final providerTitle =
        isRevealed ? provider.originalName : provider.displayName;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(color: colors.outline.withValues(alpha: .14)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onDoubleTap: () {
          setState(() {
            if (_revealedProviderIds.contains(provider.id)) {
              _revealedProviderIds.remove(provider.id);
            } else {
              _revealedProviderIds.add(provider.id);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  provider.online
                      ? PhosphorIcons.checkCircle()
                      : PhosphorIcons.warningCircle(),
                  color: color,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      providerTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      tr(
                        'provider_response_time',
                        namedArgs: {
                          'milliseconds':
                              '${provider.requestTime.inMilliseconds}',
                        },
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  provider.online
                      ? tr('provider_online')
                      : tr('provider_offline'),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshError(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: .65),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(PhosphorIcons.warningCircle(), color: colors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: colors.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                PhosphorIcons.cloudSlash(),
                size: 36,
                color: colors.error,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              tr('provider_health_unavailable'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? tr('check_connection'),
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _checkServer,
              icon: Icon(PhosphorIcons.arrowsClockwise()),
              label: Text(tr('retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyProviders(ColorScheme colors) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(
              PhosphorIcons.info(),
              color: colors.onSurfaceVariant,
              size: 30,
            ),
            const SizedBox(height: 12),
            Text(
              tr('provider_health_empty'),
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
