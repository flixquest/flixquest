import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../design/app_palette.dart';
import '../../../mobile/widgets/pill_button.dart';
import '../../../models/wellness.dart';
import '../../../models/wellness_insights.dart';
import '../../../widgets/wellness_charts.dart';

/// An entry into the report that explains the period in a few readable facts.
class InsightsSnapshot extends StatelessWidget {
  const InsightsSnapshot({
    required this.insights,
    required this.onTitles,
    required this.onTaste,
    required this.onPatterns,
    super.key,
  });

  final WellnessInsights insights;
  final VoidCallback onTitles;
  final VoidCallback onTaste;
  final VoidCallback onPatterns;

  @override
  Widget build(BuildContext context) {
    final peak = insights.peakHourOfWeek;
    final facts = <(IconData, String, String, String, VoidCallback)>[
      if (insights.topTitles.isNotEmpty)
        (
          PhosphorIcons.crown(),
          tr('ins_snapshot_title'),
          insights.topTitles.first.label,
          _duration(insights.topTitles.first.value),
          onTitles,
        ),
      if (insights.topGenres.isNotEmpty)
        (
          PhosphorIcons.palette(),
          tr('ins_snapshot_genre'),
          insights.topGenres.first.label,
          tr('ins_genre_share', namedArgs: {
            'share':
                _share(insights.topGenres.first.value, insights.sumPlaybackMs),
          }),
          onTaste,
        ),
      if (peak != null)
        (
          PhosphorIcons.clock(),
          tr('ins_snapshot_window'),
          DateFormat.EEEE(context.locale.toString())
              .format(DateTime(2024, 1, 1 + peak.$1)),
          '${DateFormat.Hm(context.locale.toString()).format(DateTime(2024, 1, 1, peak.$2))} – '
              '${DateFormat.Hm(context.locale.toString()).format(DateTime(2024, 1, 1, peak.$2 + 1))}',
          onPatterns,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('ins_snapshot'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 680 ? 3 : 1;
          final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
          final palette = AppPalette.of(context);
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final fact in facts)
                SizedBox(
                  width: width,
                  child: Material(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: fact.$5,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(fact.$1, size: 22, color: palette.mutedText),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(fact.$2, style: _muted(context)),
                                  const SizedBox(height: 3),
                                  Text(fact.$3,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  Text(fact.$4, style: _muted(context)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(PhosphorIcons.caretRight(),
                                size: 16, color: palette.mutedText),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }
}

class InsightsDiscoveryPanel extends StatelessWidget {
  const InsightsDiscoveryPanel({required this.insights, super.key});

  final WellnessInsights insights;

  @override
  Widget build(BuildContext context) => _ReportPanel(
        title: tr('ins_discovery'),
        description: tr('ins_discovery_desc'),
        child: Column(
          children: [
            _ShareRow(
              label: tr('ins_first_time'),
              value: '${insights.firstTimeTitles}',
              share: _share(insights.firstTimeTitles, insights.titlesStarted),
              fraction:
                  _ratio(insights.firstTimeTitles, insights.titlesStarted),
              slot: 0,
            ),
            const SizedBox(height: 16),
            _ShareRow(
              label: tr('ins_returning'),
              value: '${insights.returningTitles}',
              share: _share(insights.returningTitles, insights.titlesStarted),
              fraction:
                  _ratio(insights.returningTitles, insights.titlesStarted),
              slot: 1,
            ),
          ],
        ),
      );
}

class InsightsTasteBreadth extends StatelessWidget {
  const InsightsTasteBreadth({required this.insights, super.key});

  final WellnessInsights insights;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      (tr('genres'), insights.topGenres.length),
      (tr('ins_languages'), insights.topLanguages.length),
      (tr('ins_countries'), insights.topCountries.length),
      (tr('ins_decades'), insights.topDecades.length),
    ];
    return _ReportPanel(
      title: tr('ins_taste_breadth'),
      description: tr('ins_taste_breadth_desc'),
      child: LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 600 ? 4 : 2;
        return Wrap(
          spacing: 12,
          runSpacing: 16,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: (constraints.maxWidth - (columns - 1) * 12) / columns,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${metric.$2}',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        )),
                    Text(metric.$1, style: _muted(context)),
                  ],
                ),
              ),
          ],
        );
      }),
    );
  }
}

class InsightsPlaybackPanel extends StatelessWidget {
  const InsightsPlaybackPanel({required this.insights, super.key});

  final WellnessInsights insights;

  @override
  Widget build(BuildContext context) {
    final sources = [
      (WellnessPlaybackSource.streaming, tr('ins_streaming')),
      (WellnessPlaybackSource.offline, tr('ins_offline')),
      (WellnessPlaybackSource.live, tr('live_tv')),
    ];
    return _ReportPanel(
      title: tr('ins_playback_sources'),
      description: tr('ins_playback_sources_desc', namedArgs: {
        'n': '${insights.deviceCount}',
      }),
      child: Column(
        children: [
          for (var index = 0; index < sources.length; index++) ...[
            _ShareRow(
              label: sources[index].$2,
              value:
                  _duration(insights.sourceWatchedMs[sources[index].$1] ?? 0),
              share: _share(insights.sourceWatchedMs[sources[index].$1] ?? 0,
                  insights.sumPlaybackMs),
              fraction: _ratio(insights.sourceWatchedMs[sources[index].$1] ?? 0,
                  insights.sumPlaybackMs),
              slot: index,
            ),
            if (index < sources.length - 1) const SizedBox(height: 16),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Divider(height: 1),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(tr('ins_network_data'),
                style: Theme.of(context).textTheme.titleSmall),
          ),
          const SizedBox(height: 12),
          if (insights.hasNetworkUsage) ...[
            _ShareRow(
              label: tr('ins_measured_data'),
              value: _dataSize(insights.networkBytes),
              share: _share(insights.networkMeasuredMs, insights.sumPlaybackMs),
              fraction: insights.networkCoverage,
              slot: 0,
            ),
            const SizedBox(height: 10),
            Text(
              tr('ins_data_coverage', namedArgs: {
                'share':
                    _share(insights.networkMeasuredMs, insights.sumPlaybackMs),
                'rate': _dataSize(insights.networkBytesPerHour),
              }),
              style: _muted(context),
            ),
          ] else
            Text(tr('ins_data_unmeasured'), style: _muted(context)),
        ],
      ),
    );
  }
}

/// Every ranking stays compact initially, with access to the full data.
class InsightsRankedPanel extends StatefulWidget {
  const InsightsRankedPanel({
    required this.title,
    required this.values,
    required this.emptyMessage,
    this.valueLabel = _duration,
    super.key,
  });

  final String title;
  final List<WellnessRankedValue> values;
  final String emptyMessage;
  final String Function(int) valueLabel;

  @override
  State<InsightsRankedPanel> createState() => _InsightsRankedPanelState();
}

class _InsightsRankedPanelState extends State<InsightsRankedPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final values = _expanded ? widget.values : widget.values.take(5).toList();
    final max = widget.values.isEmpty ? 0 : widget.values.first.value;
    return _ReportPanel(
      title: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (values.isEmpty) Text(widget.emptyMessage, style: _muted(context)),
          for (var index = 0; index < values.length; index++) ...[
            _ShareRow(
              label: '${index + 1}. ${values[index].label}',
              value: widget.valueLabel(values[index].value),
              fraction: _ratio(values[index].value, max),
              slot: 0,
            ),
            if (index < values.length - 1) const SizedBox(height: 14),
          ],
          if (widget.values.length > 5) ...[
            const SizedBox(height: 16),
            PillButton(
              label: _expanded
                  ? tr('ins_show_less')
                  : tr('ins_show_all',
                      namedArgs: {'n': '${widget.values.length}'}),
              icon: _expanded
                  ? PhosphorIcons.caretUp()
                  : PhosphorIcons.caretDown(),
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReportPanel extends StatelessWidget {
  const _ReportPanel(
      {required this.title, required this.child, this.description});

  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppPalette.of(context).surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (description != null) ...[
              const SizedBox(height: 6),
              Text(description!, style: _muted(context)),
            ],
            const SizedBox(height: 18),
            child,
          ],
        ),
      );
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.label,
    required this.value,
    required this.fraction,
    required this.slot,
    this.share,
  });

  final String label;
  final String value;
  final String? share;
  final double fraction;
  final int slot;

  @override
  Widget build(BuildContext context) {
    final palette = WellnessChartPalette.of(context,
        surface: AppPalette.of(context).surface);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              Text([value, if (share != null) share!].join(' · '),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
            ],
          ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: fraction,
          minHeight: 5,
          borderRadius: BorderRadius.circular(99),
          color: palette.categorical[slot],
          backgroundColor: palette.emptyCell,
        ),
      ],
    );
  }
}

TextStyle? _muted(BuildContext context) => Theme.of(context)
    .textTheme
    .bodySmall
    ?.copyWith(color: AppPalette.of(context).mutedText);

double _ratio(int value, int total) =>
    total <= 0 ? 0 : (value / total).clamp(0.0, 1.0);
String _share(int value, int total) =>
    '${(_ratio(value, total) * 100).round()}%';
String _duration(int ms) => wellnessCompactDuration(ms);

String _dataSize(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(unit == 0 || value >= 10 ? 0 : 1)} ${units[unit]}';
}
