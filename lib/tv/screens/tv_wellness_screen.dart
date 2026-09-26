import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../models/wellness_insights.dart';
import '../../models/wellness_time_series.dart';
import '../../provider/wellness_provider.dart';
import '../../widgets/wellness_charts.dart';
import '../app/tv_design.dart';
import '../focus/tv_focusable.dart';
import '../focus/tv_screen_focus_controller.dart';

class TvWellnessScreen extends StatelessWidget {
  const TvWellnessScreen(
      {required this.metrics, this.focusController, super.key});

  final TvShellMetrics metrics;
  final TvScreenFocusController? focusController;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WellnessProvider>();
    return TvWellnessContent(
      metrics: metrics,
      insights: provider.insights,
      range: provider.range,
      loading: provider.loading,
      onRangeSelected: provider.setRange,
      focusController: focusController,
    );
  }
}

/// Separated from storage so TV layout and D-pad behavior can be tested with
/// deterministic viewing sessions.
class TvWellnessContent extends StatefulWidget {
  const TvWellnessContent({
    required this.metrics,
    required this.insights,
    required this.range,
    required this.loading,
    required this.onRangeSelected,
    this.focusController,
    super.key,
  });

  final TvShellMetrics metrics;
  final WellnessInsights insights;
  final WellnessRange range;
  final bool loading;
  final ValueChanged<WellnessRange> onRangeSelected;
  final TvScreenFocusController? focusController;

  @override
  State<TvWellnessContent> createState() => _TvWellnessContentState();
}

class _TvWellnessContentState extends State<TvWellnessContent> {
  late final FocusNode _entry = FocusNode(debugLabel: 'TV insights week');
  final Map<String, GlobalKey> _sections = <String, GlobalKey>{
    'Time': GlobalKey(),
    'Titles': GlobalKey(),
    'Taste': GlobalKey(),
    'Patterns': GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    widget.focusController?.attach(this, _requestEntryFocus);
  }

  @override
  void didUpdateWidget(TvWellnessContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusController != widget.focusController) {
      oldWidget.focusController?.detach(this);
      widget.focusController?.attach(this, _requestEntryFocus);
    }
  }

  @override
  void dispose() {
    widget.focusController?.detach(this);
    _entry.dispose();
    super.dispose();
  }

  bool _requestEntryFocus() {
    if (_entry.context == null || !_entry.canRequestFocus) return false;
    _entry.requestFocus();
    return true;
  }

  void _jumpTo(String section) {
    final target = _sections[section]?.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final insights = widget.insights;
    final series = WellnessTimeSeries.forRange(insights, widget.range);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: <Color>[
            colors.primary.withValues(alpha: 0.045),
            TvDesign.pageBackground,
            TvDesign.pageBackground,
          ],
        ),
      ),
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(widget.metrics.contentPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'YOUR VIEWING STORY',
                style: TextStyle(
                  color: colors.primary,
                  fontFamily: 'FigtreeBold',
                  fontSize: 13,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Viewing Insights',
                style: TextStyle(
                  color: TvDesign.foreground,
                  fontFamily: 'FigtreeBold',
                  fontSize: widget.metrics.compact ? 31 : 37,
                ),
              ),
              const Text(
                'Active playback only · private to this profile',
                style: TextStyle(color: TvDesign.mutedText, fontSize: 15),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  for (final range in WellnessRange.values)
                    TvFocusable(
                      key: Key('tv-insights-range-${range.name}'),
                      focusNode: range == WellnessRange.week ? _entry : null,
                      semanticLabel: '${_rangeLabel(range)} viewing range',
                      selected: widget.range == range,
                      onActivate: () => widget.onRangeSelected(range),
                      focusScale: 1,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 108),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: widget.range == range
                              ? colors.primary.withValues(alpha: 0.23)
                              : TvDesign.raisedSurface,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          _rangeLabel(range),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: TvDesign.foreground,
                            fontFamily: 'FigtreeBold',
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (widget.loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 100),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (insights.isEmpty)
                const _InsightPanel(
                  title: 'Your story starts here',
                  child: Text(
                    'Watch something and your private viewing insights will appear here. Try a different range to see older activity.',
                  ),
                )
              else ...<Widget>[
                _InsightPanel(
                  title: 'Active playback',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _duration(insights.totalWatchedMs),
                        style: TextStyle(
                          color: TvDesign.foreground,
                          fontFamily: 'FigtreeBold',
                          fontSize: widget.metrics.compact ? 40 : 50,
                        ),
                      ),
                      WellnessBarChart(
                        data: <WellnessBarDatum>[
                          for (final bucket in series.buckets)
                            WellnessBarDatum(
                              label: bucket.label,
                              fullLabel: bucket.fullLabel,
                              value: bucket.totalMs,
                            ),
                        ],
                        averageMs: series.averageMs,
                        color: colors.primary,
                        height: widget.metrics.compact ? 156 : 190,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${series.activeBuckets} active ${series.unitLabel}${series.activeBuckets == 1 ? '' : 's'} · Average active day ${_duration(insights.averageActiveDayMs)}',
                      ),
                      if (series.indexOfBusiest() >= 0)
                        Text(
                          'Busiest ${series.unitLabel}: ${series.buckets[series.indexOfBusiest()].fullLabel} · ${_duration(series.buckets[series.indexOfBusiest()].totalMs)}',
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _statGrid(insights),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    for (final section in _sections.keys)
                      TvFocusable(
                        semanticLabel: 'Jump to $section insights',
                        onActivate: () => _jumpTo(section),
                        focusScale: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 17,
                            vertical: 12,
                          ),
                          color: TvDesign.raisedSurface,
                          child: Text(
                            section,
                            style: const TextStyle(
                              color: TvDesign.foreground,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                _heading('Your viewing rhythm', _sections['Time']!),
                _columns(<Widget>[
                  _facts('Consistency', <(String, String)>[
                    (
                      'Active days',
                      '${insights.activeDays} of ${insights.periodDays}'
                    ),
                    ('Current streak', '${insights.currentStreakDays()} days'),
                    ('Longest streak', '${insights.longestStreakDays} days'),
                    (
                      'Typical active day',
                      _duration(insights.medianActiveDayMs)
                    ),
                  ]),
                  _facts('What you watched', <(String, String)>[
                    ('Movies', _duration(insights.movieMs)),
                    ('Episodes', _duration(insights.episodeMs)),
                    ('Live TV', _duration(insights.liveMs)),
                    ('Longest session', _duration(insights.longestSessionMs)),
                  ]),
                ]),
                _heading('What held your attention', _sections['Titles']!),
                _columns(<Widget>[
                  _facts('Follow-through', <(String, String)>[
                    ('Started', '${insights.titlesStarted} titles'),
                    (
                      'Finished',
                      '${insights.completedTitles} · ${_percent(insights.completionRate)}'
                    ),
                    ('Sampled', '${insights.sampledTitles}'),
                    ('Rewatched', '${insights.rewatches}'),
                    ('Average session', _duration(insights.averageSessionMs)),
                  ]),
                  _ranked('Most watched', insights.topTitles),
                  if (insights.topSeriesEpisodes.isNotEmpty)
                    _ranked(
                      'Series you kept going',
                      insights.topSeriesEpisodes,
                      format: (value) => '$value episodes',
                    ),
                  _facts('Recent viewing', <(String, String)>[
                    for (final session in insights.sessions.take(5))
                      (
                        session.title,
                        '${_duration(session.watchedMs)} · ${session.viewingStatus}',
                      ),
                  ]),
                ]),
                _heading('The shape of your taste', _sections['Taste']!),
                _columns(<Widget>[
                  _ranked('Genres', insights.topGenres),
                  _ranked('Languages', insights.topLanguages),
                  _ranked('Countries', insights.topCountries),
                  _ranked('Release decades', insights.topDecades),
                  _ranked('Stream providers', insights.topProviders),
                ]),
                _heading('When stories fit your day', _sections['Patterns']!),
                _InsightPanel(
                  title: 'Weekly rhythm',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                          'Viewing by weekday and hour across this range'),
                      const SizedBox(height: 14),
                      WellnessHeatmap(
                        values: insights.hourOfWeekMs,
                        rowHeight: widget.metrics.compact ? 18 : 22,
                        surfaceColor: TvDesign.surfaceFor(context),
                      ),
                      if (insights.peakHourOfWeek case final peak?)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Busiest window: ${_weekdays[peak.$1]} at ${_hourLabel(peak.$2)} · ${_duration(peak.$3)}',
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _columns(<Widget>[
                  _facts('Days of the week', <(String, String)>[
                    for (var day = 0; day < 7; day++)
                      (
                        _weekdays[day],
                        _duration(insights.weekdayTotalsMs[day])
                      ),
                  ]),
                  _facts('Parts of the day', <(String, String)>[
                    for (var part = 0; part < 4; part++)
                      (_dayParts[part], _duration(insights.partOfDayMs[part])),
                  ]),
                  _facts('Viewing patterns', <(String, String)>[
                    ('Weekdays', _duration(insights.weekdayWatchedMs)),
                    ('Weekends', _duration(insights.weekendWatchedMs)),
                    ('Late night', _duration(insights.lateNightMs)),
                  ]),
                ]),
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

const _weekdays = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _dayParts = <String>['Morning', 'Afternoon', 'Evening', 'Late night'];

String _rangeLabel(WellnessRange range) => switch (range) {
      WellnessRange.week => 'Week',
      WellnessRange.month => 'Month',
      WellnessRange.year => 'Year',
      WellnessRange.allTime => 'All time',
    };

String _duration(int milliseconds) {
  final minutes = Duration(milliseconds: milliseconds).inMinutes;
  return '${minutes ~/ 60}h ${minutes % 60}m';
}

String _percent(double value) => '${(value * 100).round()}%';

String _hourLabel(int hour) {
  final h = hour % 12 == 0 ? 12 : hour % 12;
  return '$h ${hour < 12 ? 'am' : 'pm'}';
}

Widget _heading(String title, Key key) => Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(0, 34, 0, 14),
      child: Text(
        title,
        style: const TextStyle(
          color: TvDesign.foreground,
          fontFamily: 'FigtreeBold',
          fontSize: 25,
        ),
      ),
    );

Widget _columns(List<Widget> children) => LayoutBuilder(
      builder: (context, constraints) {
        const gap = 14.0;
        final columns = constraints.maxWidth >= 700 ? 2 : 1;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );

Widget _statGrid(WellnessInsights insights) => LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final columns = constraints.maxWidth >= 800 ? 3 : 2;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        final stats = <(String, String, IconData)>[
          ('Movies', '${insights.completedMovies}', PhosphorIcons.filmSlate()),
          (
            'Episodes',
            '${insights.completedEpisodes}',
            PhosphorIcons.television()
          ),
          ('Series', '${insights.uniqueSeries}', PhosphorIcons.stack()),
          ('Sessions', '${insights.sessionCount}', PhosphorIcons.playCircle()),
          (
            'Active days',
            '${insights.activeDays}',
            PhosphorIcons.calendarDots()
          ),
          (
            'Rewatches',
            '${insights.rewatches}',
            PhosphorIcons.arrowCounterClockwise()
          ),
        ];
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final stat in stats)
              SizedBox(
                width: width,
                child: _InsightPanel(
                  title: stat.$1,
                  child: Row(
                    children: <Widget>[
                      Icon(stat.$3,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        stat.$2,
                        style: const TextStyle(
                          color: TvDesign.foreground,
                          fontFamily: 'FigtreeBold',
                          fontSize: 26,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );

Widget _facts(String title, List<(String, String)> rows) => _InsightPanel(
      title: title,
      child: Column(
        children: <Widget>[
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      row.$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      row.$2,
                      textAlign: TextAlign.end,
                      style: const TextStyle(color: TvDesign.foreground),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

Widget _ranked(
  String title,
  List<WellnessRankedValue> values, {
  String Function(int)? format,
}) =>
    _facts(
      title,
      values.isEmpty
          ? <(String, String)>[('More viewing will reveal this insight.', '')]
          : <(String, String)>[
              for (final value in values.take(5))
                (value.label, (format ?? _duration)(value.value)),
            ],
    );

/// Read-only panels are focusable so arrow keys reveal each part of the
/// scrollable report, including sections below the first TV viewport.
class _InsightPanel extends StatefulWidget {
  const _InsightPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  State<_InsightPanel> createState() => _InsightPanelState();
}

class _InsightPanelState extends State<_InsightPanel> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => Focus(
        onFocusChange: (focused) {
          setState(() => _focused = focused);
          if (focused) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Scrollable.ensureVisible(
                context,
                duration: const Duration(milliseconds: 220),
                alignment: 0.12,
              );
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: TvDesign.surfaceFor(context),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _focused ? Colors.white : TvDesign.hairline,
              width: _focused ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.title,
                style: const TextStyle(
                  color: TvDesign.foreground,
                  fontFamily: 'FigtreeBold',
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 14),
              DefaultTextStyle(
                style: const TextStyle(color: TvDesign.mutedText, fontSize: 16),
                child: widget.child,
              ),
            ],
          ),
        ),
      );
}
