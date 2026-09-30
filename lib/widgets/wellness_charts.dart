import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'wellness_chart_palette.dart';

export 'wellness_chart_palette.dart' show WellnessChartPalette;

/// Compact duration for axis ticks and direct labels: "0", "45m", "2h",
/// "2h 20m".
String wellnessCompactDuration(int milliseconds) {
  if (milliseconds <= 0) return '0';
  final minutes = (milliseconds / 60000).round();
  if (minutes < 60) return '${minutes}m';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (hours >= 10 || remainder == 0) return '${hours}h';
  return '${hours}h ${remainder}m';
}

/// One bar.
@immutable
class WellnessBarDatum {
  const WellnessBarDatum({
    required this.label,
    required this.value,
    String? fullLabel,
  }) : fullLabel = fullLabel ?? label;

  /// Axis label. The painter drops labels rather than overlapping them, so
  /// this can be a whole abbreviation.
  final String label;

  /// Spoken and called-out label.
  final String fullLabel;

  final int value;
}

/// A tappable bar chart of one measure over time.
///
/// One series, so one color and no legend — the panel title names the measure.
/// Selection is owned by the caller: the chart reports taps and paints
/// [selectedIndex], so the detail shown next to it can never drift out of sync
/// with the bar that is highlighted.
class WellnessBarChart extends StatefulWidget {
  const WellnessBarChart({
    required this.data,
    super.key,
    this.selectedIndex,
    this.onSelected,
    this.height = 212,
    this.averageMs,
    this.color,
    this.surfaceColor,
    this.valueLabel = wellnessCompactDuration,
    this.semanticsLabel,
  });

  final List<WellnessBarDatum> data;

  /// Highlighted bar, or null for none.
  final int? selectedIndex;

  /// Called with the tapped bar, or null when the selection is cleared by
  /// tapping it again.
  final ValueChanged<int?>? onSelected;

  final double height;

  /// Drawn as a solid hairline across the plot when set.
  final double? averageMs;

  /// Overrides the computed mark color. Set this only when the chart sits on a
  /// colored plate rather than a neutral surface — the theme's own ink would be
  /// dark text on a saturated background — and every mark and label is then
  /// derived from it instead.
  final Color? color;

  /// The color the chart sits on. Gaps between bars are cut to it.
  final Color? surfaceColor;

  final String Function(int milliseconds) valueLabel;

  final String? semanticsLabel;

  @override
  State<WellnessBarChart> createState() => _WellnessBarChartState();
}

class _WellnessBarChartState extends State<WellnessBarChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _grow = AnimationController(
    duration: const Duration(milliseconds: 460),
    vsync: this,
  )..forward();

  @override
  void didUpdateWidget(WellnessBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.length != widget.data.length) {
      _grow
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _grow.dispose();
    super.dispose();
  }

  void _handlePointer(Offset position, Size size, {required bool isTap}) {
    final metrics = _BarMetrics.of(size, widget.data.length);
    final index = metrics.indexAt(position.dx);
    if (index == null) return;
    final selected = widget.selectedIndex;
    final next = isTap && selected == index ? null : index;
    if (next == selected) return;
    HapticFeedback.selectionClick();
    widget.onSelected?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final palette = WellnessChartPalette.of(
      context,
      surface: widget.surfaceColor,
    );
    final maxValue = widget.data.fold<int>(0, (best, d) => math.max(best, d.value));
    final selected = widget.selectedIndex;
    final peak = _peakIndex();
    final semantics = widget.semanticsLabel ??
        (widget.data.isEmpty || maxValue == 0
            ? 'No viewing recorded'
            : 'Busiest ${widget.data[peak].fullLabel}, '
                '${widget.valueLabel(widget.data[peak].value)}');

    return Semantics(
      label: 'Viewing time chart. $semantics',
      child: ExcludeSemantics(
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, widget.height);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) =>
                    _handlePointer(details.localPosition, size, isTap: true),
                onHorizontalDragStart: (details) =>
                    _handlePointer(details.localPosition, size, isTap: false),
                onHorizontalDragUpdate: (details) =>
                    _handlePointer(details.localPosition, size, isTap: false),
                child: AnimatedBuilder(
                  animation: _grow,
                  builder: (context, _) => CustomPaint(
                    size: size,
                    painter: _BarChartPainter(
                      data: widget.data,
                      maxValue: maxValue,
                      selectedIndex: selected,
                      averageMs: widget.averageMs,
                      palette: palette,
                      onPlate: widget.color,
                      progress: Curves.easeOutCubic.transform(_grow.value),
                      valueLabel: widget.valueLabel,
                      textDirection: Directionality.of(context),
                      labelStyle: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  int _peakIndex() {
    var peak = 0;
    for (var i = 1; i < widget.data.length; i++) {
      if (widget.data[i].value > widget.data[peak].value) peak = i;
    }
    return peak;
  }
}

/// Plot geometry, shared by the painter and the hit test so a tap can never
/// select a bar other than the one under the finger.
class _BarMetrics {
  const _BarMetrics({
    required this.plotLeft,
    required this.plotWidth,
    required this.plotHeight,
    required this.count,
  });

  factory _BarMetrics.of(Size size, int count) => _BarMetrics(
        plotLeft: gutterWidth,
        plotWidth: math.max(1, size.width - gutterWidth),
        plotHeight: math.max(1, size.height - labelBandHeight - valueBandHeight),
        count: count,
      );

  /// Left gutter holding the y tick labels.
  static const double gutterWidth = 38;

  /// Bottom band holding the x labels — inside the height, so the axis is
  /// never clipped by the parent.
  static const double labelBandHeight = 22;

  /// Head room above the tallest bar for the selected bar's direct label.
  static const double valueBandHeight = 18;

  final double plotLeft;
  final double plotWidth;
  final double plotHeight;
  final int count;

  double get slot => count == 0 ? plotWidth : plotWidth / count;

  /// Bars stay thin and always leave a 2px gap to their neighbour.
  double get barWidth => math.max(3, math.min(24, slot - 2));

  double centerOf(int index) => plotLeft + slot * (index + .5);

  double get baseline => valueBandHeight + plotHeight;

  int? indexAt(double dx) {
    if (count == 0) return null;
    final local = dx - plotLeft;
    if (local < -slot / 2 || local > plotWidth + slot / 2) return null;
    return (local / slot).floor().clamp(0, count - 1);
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.data,
    required this.maxValue,
    required this.selectedIndex,
    required this.averageMs,
    required this.palette,
    required this.onPlate,
    required this.progress,
    required this.valueLabel,
    required this.textDirection,
    required this.labelStyle,
  });

  final List<WellnessBarDatum> data;
  final int maxValue;
  final int? selectedIndex;
  final double? averageMs;
  final WellnessChartPalette palette;

  /// See [WellnessBarChart.color]: when set, the plate's foreground replaces
  /// every palette slot so nothing is drawn in theme ink the plate would swallow.
  final Color? onPlate;
  final double progress;
  final String Function(int milliseconds) valueLabel;
  final TextDirection textDirection;
  final TextStyle? labelStyle;

  Color get _mark => onPlate ?? palette.primaryMark;
  Color get _labelInk => onPlate ?? palette.labelInk;
  Color get _axisInk => onPlate?.withValues(alpha: .8) ?? palette.axisInk;
  Color get _grid => onPlate?.withValues(alpha: .26) ?? palette.grid;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final metrics = _BarMetrics.of(size, data.length);
    final scaleMax = _niceMax(maxValue);
    final gridPaint = Paint()
      ..color = _grid
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Gridlines: solid hairlines, four of them, with the baseline a touch
    // stronger so the bars have something to sit on.
    for (var line = 0; line <= 3; line++) {
      final y = _BarMetrics.valueBandHeight + metrics.plotHeight * (line / 3);
      canvas.drawLine(
        Offset(metrics.plotLeft, y),
        Offset(size.width, y),
        line == 3
            ? (Paint()
              ..color = _grid.withValues(alpha: .9)
              ..strokeWidth = 1)
            : gridPaint,
      );
      final tickValue = (scaleMax * (1 - line / 3)).round();
      _paintText(
        canvas,
        valueLabel(tickValue),
        Offset(metrics.plotLeft - 6, y),
        align: _Align.right,
        anchor: _Anchor.middle,
        color: _axisInk,
        size: 10,
      );
    }

    // Selection band behind the bar: a wash the width of the slot, so the
    // highlight survives even when the bar itself is 3px of a quiet day.
    final selected = selectedIndex;
    if (selected != null && selected >= 0 && selected < data.length) {
      final center = metrics.centerOf(selected);
      final bandWidth = math.min(metrics.slot, 44.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            center - bandWidth / 2,
            _BarMetrics.valueBandHeight - 2,
            center + bandWidth / 2,
            metrics.baseline + 4,
          ),
          const Radius.circular(8),
        ),
        Paint()..color = _mark.withValues(alpha: .1),
      );
    }

    for (var index = 0; index < data.length; index++) {
      final datum = data[index];
      final center = metrics.centerOf(index);
      final isSelected = index == selected;
      final ratio = scaleMax == 0 ? 0.0 : datum.value / scaleMax;
      final full = metrics.plotHeight * ratio.clamp(0.0, 1.0);
      final height = full * progress;
      final left = center - metrics.barWidth / 2;
      final right = center + metrics.barWidth / 2;
      if (datum.value <= 0) {
        // An empty bucket still gets a mark, so "nothing watched" reads as a
        // measured zero rather than a gap in the data.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(left, metrics.baseline - 2, right, metrics.baseline),
            const Radius.circular(1),
          ),
          Paint()..color = _grid,
        );
        continue;
      }
      final top = metrics.baseline - math.max(height, 2);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(left, top, right, metrics.baseline),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        ),
        Paint()
          ..color = selected == null || isSelected
              ? _mark
              : _mark.withValues(alpha: .42),
      );
      if (isSelected && progress > .6) {
        _paintText(
          canvas,
          valueLabel(datum.value),
          Offset(
            center.clamp(
              metrics.plotLeft + 18,
              size.width - 18,
            ),
            top - 5,
          ),
          align: _Align.center,
          anchor: _Anchor.bottom,
          color: _labelInk,
          size: 11,
          weight: FontWeight.w700,
        );
      }
    }

    // The average earns a line only when there is more than one filled bucket
    // to compare against it.
    final average = averageMs;
    if (average != null && average > 0 && scaleMax > 0) {
      final y = metrics.baseline - metrics.plotHeight * (average / scaleMax);
      if (y > _BarMetrics.valueBandHeight && y < metrics.baseline - 2) {
        canvas.drawLine(
          Offset(metrics.plotLeft, y),
          Offset(size.width, y),
          Paint()
            ..color = _axisInk.withValues(alpha: .55)
            ..strokeWidth = 1.5,
        );
      }
    }

    _paintAxisLabels(canvas, size, metrics);
  }

  /// Draws as many x labels as fit, thinning by a stride rather than
  /// overlapping or clipping them.
  void _paintAxisLabels(Canvas canvas, Size size, _BarMetrics metrics) {
    final selected = selectedIndex;
    var widest = 0.0;
    for (final datum in data) {
      widest = math.max(widest, _measure(datum.label, 10).width);
    }
    final stride = math.max(1, ((widest + 8) / metrics.slot).ceil());
    final lastIndex = data.length - 1;
    // The final label is worth keeping, but not on top of its neighbour.
    final lastFits = lastIndex % stride == 0 ||
        (lastIndex - lastIndex ~/ stride * stride) * metrics.slot >= widest + 8;
    for (var index = 0; index < data.length; index++) {
      final isSelected = index == selected;
      final onStride =
          index % stride == 0 || (index == lastIndex && lastFits);
      if (!onStride && !isSelected) continue;
      // The selected label is drawn off-stride, so a neighbour that would land
      // under it yields: the label the reader pointed at is the one to keep.
      if (!isSelected && selected != null) {
        final gap =
            (metrics.centerOf(index) - metrics.centerOf(selected)).abs();
        if (gap < widest + 6) continue;
      }
      _paintText(
        canvas,
        data[index].label,
        Offset(
          metrics.centerOf(index).clamp(2.0, size.width - 2),
          metrics.baseline + 6,
        ),
        align: _Align.center,
        anchor: _Anchor.top,
        color: isSelected ? _labelInk : _axisInk,
        size: 10,
        weight: isSelected ? FontWeight.w700 : null,
      );
    }
  }

  Size _measure(String text, double size) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: (labelStyle ?? const TextStyle()).copyWith(fontSize: size),
      ),
      textDirection: textDirection,
    )..layout();
    return painter.size;
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset position, {
    required _Align align,
    required _Anchor anchor,
    required Color color,
    required double size,
    FontWeight? weight,
  }) =>
      _paintChartText(
        canvas,
        text,
        position,
        align: align,
        anchor: anchor,
        color: color,
        size: size,
        weight: weight,
        base: labelStyle,
        textDirection: textDirection,
      );

  /// Rounds the scale up to a readable step so ticks land on real durations.
  static int _niceMax(int maxValue) {
    if (maxValue <= 0) return 0;
    const steps = [
      Duration.millisecondsPerMinute * 5,
      Duration.millisecondsPerMinute * 15,
      Duration.millisecondsPerMinute * 30,
      Duration.millisecondsPerHour,
      Duration.millisecondsPerHour * 2,
      Duration.millisecondsPerHour * 3,
      Duration.millisecondsPerHour * 6,
      Duration.millisecondsPerHour * 12,
      Duration.millisecondsPerHour * 24,
    ];
    for (final step in steps) {
      if (maxValue <= step * 3) return step * 3;
    }
    final days = (maxValue / (Duration.millisecondsPerHour * 24)).ceil();
    return days * Duration.millisecondsPerHour * 24;
  }

  @override
  bool shouldRepaint(_BarChartPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.maxValue != maxValue ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.averageMs != averageMs ||
      oldDelegate.progress != progress ||
      oldDelegate.palette != palette ||
      oldDelegate.onPlate != onPlate;
}

enum _Align { left, center, right }

enum _Anchor { top, middle, bottom }

/// Shared one-line text painter. Every chart label goes through this so
/// alignment and anchoring behave identically across painters.
void _paintChartText(
  Canvas canvas,
  String text,
  Offset position, {
  required _Align align,
  required _Anchor anchor,
  required Color color,
  required double size,
  required TextDirection textDirection,
  TextStyle? base,
  FontWeight? weight,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: (base ?? const TextStyle()).copyWith(
        color: color,
        fontSize: size,
        fontWeight: weight,
        height: 1.1,
      ),
    ),
    textDirection: textDirection,
    maxLines: 1,
  )..layout();
  final dx = switch (align) {
    _Align.left => position.dx,
    _Align.center => position.dx - painter.width / 2,
    _Align.right => position.dx - painter.width,
  };
  final dy = switch (anchor) {
    _Anchor.top => position.dy,
    _Anchor.middle => position.dy - painter.height / 2,
    _Anchor.bottom => position.dy - painter.height,
  };
  painter.paint(canvas, Offset(dx, dy));
}

/// One ring segment.
@immutable
class WellnessDonutSlice {
  const WellnessDonutSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

/// Part-to-whole ring. Tapping a segment reports it; the caller decides what
/// the middle says, so the ring and the text below it always agree.
class WellnessDonutChart extends StatefulWidget {
  const WellnessDonutChart({
    required this.slices,
    required this.centerLabel,
    super.key,
    this.centerCaption,
    this.selectedIndex,
    this.onSelected,
    this.size = 148,
    this.surfaceColor,
  });

  final List<WellnessDonutSlice> slices;
  final String centerLabel;
  final String? centerCaption;
  final int? selectedIndex;
  final ValueChanged<int?>? onSelected;
  final double size;
  final Color? surfaceColor;

  @override
  State<WellnessDonutChart> createState() => _WellnessDonutChartState();
}

class _WellnessDonutChartState extends State<WellnessDonutChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _grow = AnimationController(
    duration: const Duration(milliseconds: 520),
    vsync: this,
  )..forward();

  @override
  void dispose() {
    _grow.dispose();
    super.dispose();
  }

  /// [box] is the size the painter was handed, not [WellnessDonutChart.size]:
  /// a tight parent constraint can stretch the widget, and a hit test measured
  /// against the requested size would then select a slice other than the one
  /// under the finger.
  void _handleTap(Offset position, Size box) {
    final total = widget.slices.fold<int>(0, (sum, s) => sum + s.value);
    if (total <= 0) return;
    final center = box.center(Offset.zero);
    final offset = position - center;
    final radius = offset.distance;
    final stroke = box.shortestSide * .15;
    final outer = box.shortestSide / 2;
    if (radius < outer - stroke - 6 || radius > outer + 4) return;
    var angle = math.atan2(offset.dy, offset.dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;
    var swept = 0.0;
    int? last;
    for (var index = 0; index < widget.slices.length; index++) {
      if (widget.slices[index].value <= 0) continue;
      final sweep = 2 * math.pi * widget.slices[index].value / total;
      if (angle >= swept && angle <= swept + sweep) {
        _select(index);
        return;
      }
      swept += sweep;
      last = index;
    }
    // Accumulated sweeps can land a hair short of a full turn, so a tap on the
    // very last seam would otherwise do nothing at all.
    if (last != null) _select(last);
  }

  void _select(int index) {
    final next = widget.selectedIndex == index ? null : index;
    HapticFeedback.selectionClick();
    widget.onSelected?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final palette = WellnessChartPalette.of(
      context,
      surface: widget.surfaceColor,
    );
    final theme = Theme.of(context);
    return Semantics(
      label: '${widget.centerLabel} ${widget.centerCaption ?? ''}'.trim(),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The painter is handed the laid-out box, so the hit test measures
            // against that too — a tight parent can stretch the widget past
            // the requested size.
            final box = constraints.biggest;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => _handleTap(details.localPosition, box),
              child: AnimatedBuilder(
                animation: _grow,
                builder: (context, _) => CustomPaint(
                  painter: _DonutPainter(
                    slices: widget.slices,
                    selectedIndex: widget.selectedIndex,
                    palette: palette,
                    progress: Curves.easeOutCubic.transform(_grow.value),
                  ),
                  child: Center(
                    child: ExcludeSemantics(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.centerLabel,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          if (widget.centerCaption case final caption?)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                caption,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.1,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.slices,
    required this.selectedIndex,
    required this.palette,
    required this.progress,
  });

  final List<WellnessDonutSlice> slices;
  final int? selectedIndex;
  final WellnessChartPalette palette;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<int>(0, (sum, slice) => sum + slice.value);
    final stroke = size.shortestSide * .15;
    final radius = (size.shortestSide - stroke) / 2;
    final center = size.center(Offset.zero);
    if (total <= 0) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = palette.emptyCell
          ..strokeWidth = stroke
          ..style = PaintingStyle.stroke,
      );
      return;
    }
    // A 2px gap of surface between segments, expressed as the angle that arc
    // length subtends at this radius.
    final gap = 2 / radius;
    var start = -math.pi / 2;
    for (var index = 0; index < slices.length; index++) {
      final slice = slices[index];
      if (slice.value <= 0) continue;
      final sweep = 2 * math.pi * slice.value / total * progress;
      final isSelected = index == selectedIndex;
      final width = isSelected ? stroke * 1.22 : stroke;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start + gap / 2,
        math.max(0, sweep - gap),
        false,
        Paint()
          ..color = selectedIndex == null || isSelected
              ? slice.color
              : slice.color.withValues(alpha: .42)
          ..strokeWidth = width
          ..strokeCap = StrokeCap.butt
          ..style = PaintingStyle.stroke,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.slices != slices ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.progress != progress ||
      oldDelegate.palette != palette;
}

/// Week × hour grid: 7 rows (Monday first) × 24 columns, binned onto the
/// ordinal ramp. Zero cells are painted as [WellnessChartPalette.emptyCell] so
/// "nothing watched" can never read as a small value.
class WellnessHeatmap extends StatelessWidget {
  const WellnessHeatmap({
    required this.values,
    super.key,
    this.selectedCell,
    this.onSelected,
    this.dayLabels,
    this.rowHeight = 17,
    this.surfaceColor,
  });

  /// `values[weekday][hour]` in ms, weekday 0 = Monday.
  final List<List<int>> values;

  final (int day, int hour)? selectedCell;
  final ValueChanged<(int day, int hour)?>? onSelected;

  /// Row labels, Monday first. Defaults to the locale's narrow weekday names.
  final List<String>? dayLabels;

  final double rowHeight;
  final Color? surfaceColor;

  static const double _gutter = 30;
  static const double _hourBandHeight = 16;
  static const int _bins = 5;

  int get _maxValue => values.fold<int>(
        0,
        (best, row) => math.max(best, row.fold<int>(0, math.max)),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = WellnessChartPalette.of(context, surface: surfaceColor);
    final labels = dayLabels ?? _defaultDayLabels(context);
    final maxValue = _maxValue;
    final gridHeight = rowHeight * 7;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: _semanticsLabel(labels, maxValue),
          child: SizedBox(
            height: gridHeight + _hourBandHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final metrics = _HeatmapMetrics(
                  width: constraints.maxWidth,
                  rowHeight: rowHeight,
                );
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    final cell = metrics.cellAt(details.localPosition);
                    if (cell == null) return;
                    final next = selectedCell == cell ? null : cell;
                    HapticFeedback.selectionClick();
                    onSelected?.call(next);
                  },
                  child: ExcludeSemantics(
                    child: CustomPaint(
                      painter: _HeatmapPainter(
                        values: values,
                        maxValue: maxValue,
                        dayLabels: labels,
                        selectedCell: selectedCell,
                        palette: palette,
                        metrics: metrics,
                        labelStyle: theme.textTheme.labelSmall,
                        textDirection: Directionality.of(context),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        _RampLegend(palette: palette, steps: _bins, maxValue: maxValue),
      ],
    );
  }

  String _semanticsLabel(List<String> labels, int maxValue) {
    if (maxValue <= 0) return 'Weekly rhythm grid. No viewing recorded yet.';
    var day = 0;
    var hour = 0;
    for (var d = 0; d < values.length; d++) {
      for (var h = 0; h < values[d].length; h++) {
        if (values[d][h] == maxValue) {
          day = d;
          hour = h;
        }
      }
    }
    final name = day < labels.length ? labels[day] : '';
    return 'Weekly rhythm grid, 7 days by 24 hours. Busiest cell $name at '
        '${_hourLabel(hour)}, ${wellnessCompactDuration(maxValue)}.';
  }
}

class _HeatmapMetrics {
  const _HeatmapMetrics({required this.width, required this.rowHeight});

  final double width;
  final double rowHeight;

  double get cellWidth =>
      math.max(1, (width - WellnessHeatmap._gutter) / 24);

  Rect cellRect(int day, int hour) => Rect.fromLTWH(
        WellnessHeatmap._gutter + hour * cellWidth,
        day * rowHeight,
        cellWidth,
        rowHeight,
      );

  (int day, int hour)? cellAt(Offset position) {
    if (position.dx < WellnessHeatmap._gutter) return null;
    final hour = ((position.dx - WellnessHeatmap._gutter) / cellWidth).floor();
    final day = (position.dy / rowHeight).floor();
    if (hour < 0 || hour > 23 || day < 0 || day > 6) return null;
    return (day, hour);
  }
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({
    required this.values,
    required this.maxValue,
    required this.dayLabels,
    required this.selectedCell,
    required this.palette,
    required this.metrics,
    required this.labelStyle,
    required this.textDirection,
  });

  final List<List<int>> values;
  final int maxValue;
  final List<String> dayLabels;
  final (int day, int hour)? selectedCell;
  final WellnessChartPalette palette;
  final _HeatmapMetrics metrics;
  final TextStyle? labelStyle;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..style = PaintingStyle.fill;
    for (var day = 0; day < 7; day++) {
      final row = day < values.length ? values[day] : const <int>[];
      for (var hour = 0; hour < 24; hour++) {
        final value = hour < row.length ? row[hour] : 0;
        // A 1px inset on each side leaves a 2px run of surface between
        // neighbouring cells, so adjacent bins never bleed into one another.
        final rect = metrics.cellRect(day, hour).deflate(1);
        if (rect.width <= 0 || rect.height <= 0) continue;
        fill.color = maxValue <= 0
            ? palette.emptyCell
            : palette.rampStep(value / maxValue,
                steps: WellnessHeatmap._bins);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          fill,
        );
      }
    }
    final cell = selectedCell;
    if (cell != null) {
      final rect = metrics.cellRect(cell.$1, cell.$2).deflate(1);
      // Cut to surface first, then ring: the mark stays legible whichever bin
      // its neighbours landed in.
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(1), const Radius.circular(3)),
        Paint()
          ..color = palette.surface
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()
          ..color = palette.labelInk
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
    }
    for (var day = 0; day < 7; day++) {
      if (day >= dayLabels.length) break;
      _paintChartText(
        canvas,
        dayLabels[day],
        Offset(0, metrics.cellRect(day, 0).center.dy),
        align: _Align.left,
        anchor: _Anchor.middle,
        color: palette.axisInk,
        size: 10,
        base: labelStyle,
        textDirection: textDirection,
      );
    }
    final bandTop = metrics.rowHeight * 7 + 4;
    for (final hour in const [0, 6, 12, 18]) {
      _paintChartText(
        canvas,
        _hourLabel(hour),
        Offset(metrics.cellRect(0, hour).left, bandTop),
        align: _Align.left,
        anchor: _Anchor.top,
        color: palette.axisInk,
        size: 10,
        base: labelStyle,
        textDirection: textDirection,
      );
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.maxValue != maxValue ||
      oldDelegate.selectedCell != selectedCell ||
      oldDelegate.palette != palette ||
      oldDelegate.metrics.width != metrics.width;
}

/// "Less → more" swatch strip. The heatmap and the ordinal bars share it so a
/// reader learns the ramp once.
class _RampLegend extends StatelessWidget {
  const _RampLegend({
    required this.palette,
    required this.steps,
    required this.maxValue,
  });

  final WellnessChartPalette palette;
  final int steps;
  final int maxValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = WellnessChartLabels.maybeOf(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final scale = palette.ramp(steps);
    // spaceBetween holds the peak against the right edge while both fit, and
    // drops it onto its own line on a narrow panel instead of overflowing.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 6,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(labels?.less ?? 'Less', style: style),
            const SizedBox(width: 6),
            for (final color in scale)
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Container(
                  width: 14,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            const SizedBox(width: 4),
            Text(labels?.more ?? 'More', style: style),
          ],
        ),
        if (maxValue > 0)
          Text(
            labels?.peakPerHour(wellnessCompactDuration(maxValue)) ??
                'Peak ${wellnessCompactDuration(maxValue)}/h',
            style: style,
          ),
      ],
    );
  }
}

List<String> _defaultDayLabels(BuildContext context) {
  final locale = Localizations.localeOf(context).toString();
  final format = DateFormat.E(locale);
  // 2024-01-01 is a Monday, so this walks Monday → Sunday in order.
  return List<String>.generate(
    7,
    (index) => format.format(DateTime(2024, 1, 1 + index)),
    growable: false,
  );
}

String _hourLabel(int hour) =>
    DateFormat.j().format(DateTime(2024, 1, 1, hour));

/// One ordered category: same hue, ramp step by position, length by magnitude.
@immutable
class WellnessOrdinalDatum {
  const WellnessOrdinalDatum({
    required this.label,
    required this.value,
    this.caption,
  });

  final String label;
  final int value;

  /// Optional secondary line (a share, a count) rendered under the label.
  final String? caption;
}

/// Ordered categories as horizontal bars — part-of-day, size tiers, funnel
/// stages. Ordinal, so it wears a one-hue ramp rather than categorical hues,
/// and the order is the caller's, never re-sorted by value.
class WellnessOrdinalBars extends StatelessWidget {
  const WellnessOrdinalBars({
    required this.data,
    super.key,
    this.selectedIndex,
    this.onSelected,
    this.labelWidth = 84,
    this.valueLabel = wellnessCompactDuration,
    this.surfaceColor,
    this.showLegend = false,
  });

  final List<WellnessOrdinalDatum> data;
  final int? selectedIndex;
  final ValueChanged<int?>? onSelected;
  final double labelWidth;
  final String Function(int value) valueLabel;
  final Color? surfaceColor;
  final bool showLegend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = WellnessChartPalette.of(context, surface: surfaceColor);
    final maxValue = data.fold<int>(0, (best, d) => math.max(best, d.value));
    final scale = palette.ramp(math.min(5, math.max(2, data.length)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < data.length; index++)
          Padding(
            padding: EdgeInsets.only(bottom: index == data.length - 1 ? 0 : 10),
            child: _OrdinalRow(
              datum: data[index],
              color: scale[math.min(index, scale.length - 1)],
              ratio: maxValue <= 0 ? 0 : data[index].value / maxValue,
              dimmed: selectedIndex != null && selectedIndex != index,
              selected: selectedIndex == index,
              palette: palette,
              labelWidth: labelWidth,
              valueText: valueLabel(data[index].value),
              onTap: onSelected == null
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      onSelected!.call(selectedIndex == index ? null : index);
                    },
            ),
          ),
        if (showLegend) ...[
          const SizedBox(height: 12),
          _RampLegend(
            palette: palette,
            steps: math.min(5, math.max(2, data.length)),
            maxValue: 0,
          ),
        ],
        // The values are printed beside every bar, so length is never the only
        // path to a number.
        if (data.isEmpty)
          Text(
            WellnessChartLabels.maybeOf(context)?.nothingYet ??
                'Nothing recorded yet.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _OrdinalRow extends StatelessWidget {
  const _OrdinalRow({
    required this.datum,
    required this.color,
    required this.ratio,
    required this.dimmed,
    required this.selected,
    required this.palette,
    required this.labelWidth,
    required this.valueText,
    required this.onTap,
  });

  final WellnessOrdinalDatum datum;
  final Color color;
  final double ratio;
  final bool dimmed;
  final bool selected;
  final WellnessChartPalette palette;
  final double labelWidth;
  final String valueText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: '${datum.label}, $valueText',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ExcludeSemantics(
          // 44px tall including the padding: the row is the hit target, not
          // the bar.
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: labelWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        datum.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: selected ? FontWeight.w800 : null,
                        ),
                      ),
                      if (datum.caption case final caption?)
                        Text(
                          caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 14,
                    child: CustomPaint(
                      painter: _TrackPainter(
                        ratio: ratio,
                        color: dimmed ? color.withValues(alpha: .42) : color,
                        palette: palette,
                        ringed: selected,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 56,
                  child: Text(
                    valueText,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.ratio,
    required this.color,
    required this.palette,
    this.ringed = false,
  });

  final double ratio;
  final Color color;
  final WellnessChartPalette palette;
  final bool ringed;

  @override
  void paint(Canvas canvas, Size size) {
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(4),
    );
    canvas.drawRRect(track, Paint()..color = palette.emptyCell);
    final width = size.width * ratio.clamp(0.0, 1.0);
    if (width <= 0) return;
    final fill = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, 0, math.max(width, 3), size.height),
      topLeft: const Radius.circular(2),
      bottomLeft: const Radius.circular(2),
      topRight: const Radius.circular(4),
      bottomRight: const Radius.circular(4),
    );
    canvas.drawRRect(fill, Paint()..color = color);
    if (!ringed) return;
    canvas.drawRRect(
      track.inflate(1.5),
      Paint()
        ..color = palette.labelInk.withValues(alpha: .55)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_TrackPainter oldDelegate) =>
      oldDelegate.ratio != ratio ||
      oldDelegate.color != color ||
      oldDelegate.ringed != ringed ||
      oldDelegate.palette != palette;
}

/// A single ratio out of a whole — completion rate, share of active days.
/// The number is always printed; the bar is the secondary encoding.
class WellnessMeter extends StatelessWidget {
  const WellnessMeter({
    required this.label,
    required this.valueLabel,
    required this.ratio,
    super.key,
    this.caption,
    this.color,
    this.surfaceColor,
  });

  final String label;
  final String valueLabel;

  /// 0..1.
  final double ratio;
  final String? caption;
  final Color? color;
  final Color? surfaceColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = WellnessChartPalette.of(context, surface: surfaceColor);
    return Semantics(
      label: '$label, $valueLabel${caption == null ? '' : '. $caption'}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  valueLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 10,
              child: CustomPaint(
                painter: _TrackPainter(
                  ratio: ratio,
                  color: color ?? palette.primaryMark,
                  palette: palette,
                ),
              ),
            ),
            if (caption case final caption?) ...[
              const SizedBox(height: 6),
              Text(
                caption,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One part of a split meter.
@immutable
class WellnessSplitPart {
  const WellnessSplitPart({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

/// Two or three parts of one whole as a single bar, with a legend that prints
/// each part's own value. 2px of surface separates the segments.
class WellnessSplitMeter extends StatelessWidget {
  const WellnessSplitMeter({
    required this.parts,
    super.key,
    this.valueLabel = wellnessCompactDuration,
    this.surfaceColor,
    this.height = 14,
  });

  final List<WellnessSplitPart> parts;
  final String Function(int value) valueLabel;
  final Color? surfaceColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = WellnessChartPalette.of(context, surface: surfaceColor);
    final total = parts.fold<int>(0, (sum, part) => sum + part.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: parts
              .map((part) => '${part.label} ${valueLabel(part.value)}')
              .join(', '),
          child: ExcludeSemantics(
            child: SizedBox(
              height: height,
              child: CustomPaint(
                painter: _SplitPainter(
                  parts: parts,
                  total: total,
                  palette: palette,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        for (final part in parts)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: part.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    part.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
                Text(
                  total <= 0
                      ? valueLabel(part.value)
                      : '${valueLabel(part.value)} · '
                          '${(part.value / total * 100).round()}%',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SplitPainter extends CustomPainter {
  _SplitPainter({
    required this.parts,
    required this.total,
    required this.palette,
  });

  final List<WellnessSplitPart> parts;
  final int total;
  final WellnessChartPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      radius,
    );
    canvas.drawRRect(track, Paint()..color = palette.emptyCell);
    if (total <= 0) return;
    canvas.save();
    canvas.clipRRect(track);
    var x = 0.0;
    for (final part in parts) {
      if (part.value <= 0) continue;
      final width = size.width * part.value / total;
      canvas.drawRect(
        Rect.fromLTWH(x, 0, math.max(width - 2, 1), size.height),
        Paint()..color = part.color,
      );
      x += width;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SplitPainter oldDelegate) =>
      oldDelegate.parts != parts ||
      oldDelegate.total != total ||
      oldDelegate.palette != palette;
}

/// Trend at a glance: a 2px line, a faint area wash, and a marked last point.
/// No axis — it lives beside a number that gives it scale.
class WellnessSparkline extends StatelessWidget {
  const WellnessSparkline({
    required this.values,
    super.key,
    this.height = 44,
    this.color,
    this.surfaceColor,
    this.semanticsLabel,
  });

  final List<int> values;
  final double height;
  final Color? color;
  final Color? surfaceColor;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final palette = WellnessChartPalette.of(context, surface: surfaceColor);
    return Semantics(
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          // A childless CustomPaint sizes to `Size.zero` under loose
          // constraints, so the width has to be claimed here — otherwise the
          // line collapses to nothing in any parent that does not stretch.
          width: double.infinity,
          height: height,
          child: CustomPaint(
            painter: _SparklinePainter(
              values: values,
              color: color ?? palette.primaryMark,
              palette: palette,
            ),
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.color,
    required this.palette,
  });

  final List<int> values;
  final Color color;
  final WellnessChartPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxValue = values.fold<int>(0, math.max);
    const inset = 5.0;
    final plotHeight = size.height - inset * 2;
    final step = (size.width - inset * 2) / (values.length - 1);
    Offset pointAt(int index) => Offset(
          inset + step * index,
          maxValue <= 0
              ? size.height - inset
              : size.height - inset - plotHeight * (values[index] / maxValue),
        );
    final line = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var index = 1; index < values.length; index++) {
      final point = pointAt(index);
      line.lineTo(point.dx, point.dy);
    }
    final area = Path.from(line)
      ..lineTo(pointAt(values.length - 1).dx, size.height)
      ..lineTo(pointAt(0).dx, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = color.withValues(alpha: .12));
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
    final last = pointAt(values.length - 1);
    // 2px of surface around the end dot so it stays a mark where the line
    // doubles back on itself.
    canvas.drawCircle(last, 6, Paint()..color = palette.surface);
    canvas.drawCircle(last, 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.color != color ||
      oldDelegate.palette != palette;
}

/// The words the charts draw, in the reader's language. Charts built outside
/// one fall back to English.
class WellnessChartLabels extends InheritedWidget {
  const WellnessChartLabels({
    required this.less,
    required this.more,
    required this.peakPerHour,
    required this.nothingYet,
    required super.child,
    super.key,
  });

  final String less;
  final String more;

  /// "Peak 1h/h", given the compact duration.
  final String Function(String duration) peakPerHour;
  final String nothingYet;

  static WellnessChartLabels? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WellnessChartLabels>();

  @override
  bool updateShouldNotify(WellnessChartLabels oldWidget) =>
      less != oldWidget.less ||
      more != oldWidget.more ||
      nothingYet != oldWidget.nothingYet;
}
