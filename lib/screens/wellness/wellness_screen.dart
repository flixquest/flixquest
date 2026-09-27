import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../design/skeleton.dart';
import '../../mobile/widgets/filter_chips.dart';
import '../../mobile/widgets/page_kit.dart';
import '../../mobile/widgets/pill_button.dart';
import '../../models/wellness.dart';
import '../../models/wellness_insights.dart';
import '../../models/wellness_recap.dart';
import '../../models/wellness_time_series.dart';
import '../../provider/wellness_provider.dart';
import '../../services/wellness_sync_service.dart';
import '../../ui_components/app_ui_components.dart';
import '../../widgets/wellness_charts.dart';

class WellnessScreen extends StatefulWidget {
  const WellnessScreen({super.key});

  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> {
  final GlobalKey _timeSectionKey = GlobalKey();
  final GlobalKey _titlesSectionKey = GlobalKey();
  final GlobalKey _tasteSectionKey = GlobalKey();
  final GlobalKey _patternsSectionKey = GlobalKey();
  bool _sharing = false;

  @override
  Widget build(BuildContext context) {
    final wellness = context.watch<WellnessProvider>();
    final insights = wellness.insights;
    final hasRecapHistory = hasRecapWorthyHistory(wellness.sessions);
    final palette = AppPalette.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      appBar: PageAppBar(
        title: 'Viewing Insights',
        actions: [
          IconButton(
            tooltip: 'Viewing Insights options',
            onPressed: () => _showInsightsActions(wellness),
            icon: Icon(PhosphorIcons.dotsThreeVertical()),
          ),
        ],
      ),
      body: SkeletonSwitcher(
        loading: wellness.loading,
        skeleton: const _InsightsSkeleton(),
        child: RefreshIndicator(
              color: palette.foreground,
              backgroundColor: palette.raisedSurface,
              onRefresh: wellness.canSync ? wellness.syncNow : wellness.reload,
              child: AppResponsiveContent(
                maxWidth: 920,
                padding: EdgeInsets.zero,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    AppUI.pagePadding(context),
                    12,
                    AppUI.pagePadding(context),
                    40,
                  ),
                  children: [
                    if (wellness.shouldOfferGuestMerge)
                      _GuestMergeCard(provider: wellness),
                    _InsightsToolbar(
                      provider: wellness,
                    ),
                    const SizedBox(height: 18),
                    if (insights.isEmpty) ...[
                      // A finished recap lives outside the selected range, so
                      // the shelf has to stay reachable even when the range on
                      // screen is empty.
                      if (hasRecapHistory) ...[
                        _RecapShelf(
                          sessions: wellness.sessions,
                          onSelected: (period) => _openShareRecap(
                            wellness,
                            initialPeriod: period,
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      _WellnessEmptyState(
                        hasHistory: hasRecapHistory,
                      ),
                    ] else ...[
                      _HeroCard(
                        insights: insights,
                        previous: wellness.previousInsights,
                        range: wellness.range,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _trackingSince(wellness.sessions),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ),
                          PillButton(
                            busy: _sharing,
                            onPressed: () => _openShareRecap(wellness),
                            icon: PhosphorIcons.shareNetwork(),
                            label: 'Share recap',
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _RecapShelf(
                        sessions: wellness.sessions,
                        onSelected: (period) => _openShareRecap(
                          wellness,
                          initialPeriod: period,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _StatGrid(insights: insights),
                      const SizedBox(height: 20),
                      _SectionNavigator(
                        onSelected: (section) =>
                            _jumpToSection(switch (section) {
                          _InsightsSection.time => _timeSectionKey,
                          _InsightsSection.titles => _titlesSectionKey,
                          _InsightsSection.taste => _tasteSectionKey,
                          _InsightsSection.patterns => _patternsSectionKey,
                        }),
                      ),
                      const SizedBox(height: 34),
                      _SectionHeader(
                        key: _timeSectionKey,
                        icon: PhosphorIcons.clockCounterClockwise(),
                        eyebrow: 'TIME',
                        title: 'Your viewing rhythm',
                        description:
                            'Active playback only—pauses and buffering are excluded.',
                      ),
                      const SizedBox(height: 14),
                      _TimelinePanel(
                        key: const Key('wellness-timeline-panel'),
                        insights: insights,
                        range: wellness.range,
                      ),
                      const SizedBox(height: 14),
                      _ConsistencyPanel(insights: insights),
                      const SizedBox(height: 14),
                      _MediaBreakdown(insights: insights),
                      const SizedBox(height: 34),
                      _SectionHeader(
                        key: _titlesSectionKey,
                        icon: PhosphorIcons.filmSlate(),
                        eyebrow: 'TITLES',
                        title: 'What held your attention',
                        description:
                            'Completed titles, returning favorites, and recent sessions.',
                      ),
                      const SizedBox(height: 14),
                      _CompletionPanel(insights: insights),
                      const SizedBox(height: 14),
                      _RankedPanel(
                        title: 'Most watched',
                        values: insights.topTitles.take(5).toList(),
                        emptyMessage:
                            'More viewing will reveal your top titles.',
                      ),
                      const SizedBox(height: 14),
                      if (insights.topSeriesEpisodes.isNotEmpty) ...[
                        _RankedPanel(
                          title: 'Series you kept going',
                          values: insights.topSeriesEpisodes.take(5).toList(),
                          emptyMessage:
                              'Episode counts appear once you watch a series.',
                          valueLabel: _episodeCount,
                        ),
                        const SizedBox(height: 14),
                      ],
                      _HistoryPanel(
                          sessions: insights.sessions.take(8).toList()),
                      const SizedBox(height: 34),
                      _SectionHeader(
                        key: _tasteSectionKey,
                        icon: PhosphorIcons.palette(),
                        eyebrow: 'TASTE',
                        title: 'The shape of your taste',
                        description:
                            'Built from the metadata available when you watched.',
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 680;
                          final width = wide
                              ? (constraints.maxWidth - 14) / 2
                              : constraints.maxWidth;
                          final panels = <Widget>[
                            _RankedPanel(
                              title: 'Genres',
                              values: insights.topGenres.take(5).toList(),
                              emptyMessage:
                                  'Genre insights will appear as title metadata is collected.',
                            ),
                            _RankedPanel(
                              title: 'Languages',
                              values: insights.topLanguages.take(5).toList(),
                              emptyMessage:
                                  'Language insights will appear with enriched titles.',
                            ),
                            _RankedPanel(
                              title: 'Countries',
                              values: insights.topCountries.take(5).toList(),
                              emptyMessage:
                                  'Country insights will appear with enriched titles.',
                            ),
                            _RankedPanel(
                              title: 'Release decades',
                              values: insights.topDecades.take(5).toList(),
                              emptyMessage:
                                  'Release-era insights will appear after more viewing.',
                            ),
                            _RankedPanel(
                              title: 'Stream providers',
                              values: insights.topProviders.take(5).toList(),
                              emptyMessage:
                                  'Provider insights will appear after streaming sessions.',
                            ),
                          ];
                          return Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            children: [
                              for (final panel in panels)
                                SizedBox(width: width, child: panel),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 34),
                      _SectionHeader(
                        key: _patternsSectionKey,
                        icon: PhosphorIcons.calendarDots(),
                        eyebrow: 'PATTERNS',
                        title: 'When stories fit your day',
                        description:
                            'A private view of your own routine—not a score or a warning.',
                      ),
                      const SizedBox(height: 14),
                      _RhythmPanel(
                        key: const Key('wellness-rhythm-panel'),
                        insights: insights,
                      ),
                      const SizedBox(height: 14),
                      _DayPartsPanel(insights: insights),
                      const SizedBox(height: 14),
                      _InsightStrip(insights: insights),
                      const SizedBox(height: 26),
                      _PrivacyNote(canSync: wellness.canSync),
                    ],
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Future<void> _jumpToSection(GlobalKey key) async {
    var sectionContext = key.currentContext;
    if (sectionContext == null) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      sectionContext = key.currentContext;
    }
    if (sectionContext == null || !sectionContext.mounted) return;
    Scrollable.ensureVisible(
      sectionContext,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: .08,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
  }

  Future<void> _handleAction(
    WellnessProvider wellness,
    _WellnessAction action,
  ) async {
    switch (action) {
      case _WellnessAction.export:
        final json = await wellness.exportJson();
        final csv = await wellness.exportCsv();
        final directory = await getTemporaryDirectory();
        final jsonFile =
            File('${directory.path}/flixquest-viewing-insights.json');
        final csvFile =
            File('${directory.path}/flixquest-viewing-insights.csv');
        await jsonFile.writeAsString(json);
        await csvFile.writeAsString(csv);
        await Share.shareXFiles(
          <XFile>[
            XFile(jsonFile.path, mimeType: 'application/json'),
            XFile(csvFile.path, mimeType: 'text/csv'),
          ],
          text: 'My private FlixQuest Viewing Insights archive',
        );
      case _WellnessAction.clear:
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Clear viewing history?'),
            content: Text(
              wellness.canSync
                  ? 'This removes your viewing sessions from this device and every synced device. This cannot be undone.'
                  : 'This removes the viewing sessions stored on this device. This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Clear history'),
              ),
            ],
          ),
        );
        if (confirmed == true) await wellness.clearHistory();
    }
  }

  Future<void> _showInsightsActions(WellnessProvider wellness) async {
    final action = await showModalBottomSheet<_WellnessAction>(
      context: context,
      useSafeArea: true,
      showDragHandle: false,
      builder: (context) => const _InsightsActionsSheet(),
    );
    if (action != null && mounted) await _handleAction(wellness, action);
  }

  Future<void> _openShareRecap(
    WellnessProvider provider, {
    WellnessRecapPeriod? initialPeriod,
  }) async {
    setState(() => _sharing = true);
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _ShareRecapSheet(
          sessions: provider.sessions,
          initialPeriod: initialPeriod ??
              WellnessRecapPeriod.bestForRange(
                provider.sessions,
                provider.range,
                DateTime.now(),
              ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }
}

enum _WellnessAction { export, clear }

class _InsightsActionsSheet extends StatelessWidget {
  const _InsightsActionsSheet();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppPalette.of(context).idleFill,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  PhosphorIcons.slidersHorizontal(),
                  color: AppPalette.of(context).foreground,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your insights data',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      'Export a copy or manage your history.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: Icon(PhosphorIcons.x()),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _InsightsActionTile(
            icon: PhosphorIcons.export(),
            title: 'Export my data',
            description: 'Download your sessions as JSON and CSV.',
            onTap: () => Navigator.pop(context, _WellnessAction.export),
          ),
          const SizedBox(height: 10),
          _InsightsActionTile(
            icon: PhosphorIcons.trash(),
            title: 'Clear viewing history',
            description: 'Remove all locally stored and synced sessions.',
            destructive: true,
            onTap: () => Navigator.pop(context, _WellnessAction.clear),
          ),
        ],
      ),
    );
  }
}

class _InsightsActionTile extends StatelessWidget {
  const _InsightsActionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent =
        destructive ? colors.error : AppPalette.of(context).foreground;
    return Material(
      color: destructive
          ? colors.errorContainer.withValues(alpha: .32)
          : _insightSurface(context),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accent, size: 21),
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
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                PhosphorIcons.caretRight(),
                color: destructive ? colors.error : colors.onSurfaceVariant,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _RecapStyle { light, dark, lightsOut }

class _ShareRecapSheet extends StatefulWidget {
  const _ShareRecapSheet({
    required this.sessions,
    required this.initialPeriod,
  });

  final List<WellnessViewingSession> sessions;
  final WellnessRecapPeriod initialPeriod;

  @override
  State<_ShareRecapSheet> createState() => _ShareRecapSheetState();
}

class _ShareRecapSheetState extends State<_ShareRecapSheet> {
  final GlobalKey _recapKey = GlobalKey();
  late _RecapStyle _style;
  late WellnessRecapPeriod _period;
  bool _includeTopTitle = true;
  bool _sharing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!mounted || _styleInitialized) return;
    final theme = Theme.of(context);
    _style = theme.brightness == Brightness.light
        ? _RecapStyle.light
        : _isLightsOut(context)
            ? _RecapStyle.lightsOut
            : _RecapStyle.dark;
    _period = widget.initialPeriod;
    _styleInitialized = true;
  }

  bool _styleInitialized = false;

  WellnessInsights get _insights => WellnessInsights.fromSessions(
        widget.sessions,
        period: _period.wellnessPeriod,
      );

  String get _caption {
    final insights = _insights;
    final title = _includeTopTitle && insights.topTitles.isNotEmpty
        ? ' My most-watched title was ${insights.topTitles.first.label}.'
        : '';
    return '${_period.captionLabel} on FlixQuest: '
        '${_duration(insights.totalWatchedMs)} of stories across '
        '${insights.activeDays} active ${insights.activeDays == 1 ? 'day' : 'days'}.$title';
  }

  Future<void> _copyCaption() async {
    await Clipboard.setData(ClipboardData(text: _caption));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Caption copied')),
    );
  }

  Future<void> _shareImage() async {
    setState(() => _sharing = true);
    try {
      await precacheImage(
        const AssetImage('assets/images/logo.png'),
        context,
      );
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _recapKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('Recap preview is not ready');
      final image = await boundary.toImage(pixelRatio: 3.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw StateError('Could not render recap image');
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/flixquest-${_period.id}-recap.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        <XFile>[XFile(file.path, mimeType: 'image/png')],
        subject: '${_period.label} FlixQuest recap',
        text: _caption,
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not create the recap. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final insights = _insights;
    final periods = WellnessRecapPeriod.available(
      widget.sessions,
      DateTime.now(),
    );
    if (!periods.any((period) => period.id == _period.id)) {
      periods.insert(0, _period);
    }
    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .9,
        minChildSize: .65,
        maxChildSize: .96,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share your viewing story',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pick a moment, choose a look, then make it yours.',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(PhosphorIcons.x()),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'RECAP PERIOD',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontFamily: 'FigtreeSB',
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: periods.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final period = periods[index];
                  final selected = period.id == _period.id;
                  return ChoicePill(
                    spec: FilterChipSpec(
                      label: period.label,
                      selected: selected,
                      onTap: () => setState(() => _period = period),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'FLIXQUEST THEMES',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontFamily: 'FigtreeSB',
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _RecapStyleChip(
                    label: 'Light',
                    colors: const [Color(0xFFFAF9FC), Color(0xFFF57C00)],
                    selected: _style == _RecapStyle.light,
                    onTap: () => setState(() => _style = _RecapStyle.light),
                  ),
                  const SizedBox(width: 8),
                  _RecapStyleChip(
                    label: 'Dark',
                    colors: const [Color(0xFF181A1D), Color(0xFFF57C00)],
                    selected: _style == _RecapStyle.dark,
                    onTap: () => setState(() => _style = _RecapStyle.dark),
                  ),
                  const SizedBox(width: 8),
                  _RecapStyleChip(
                    label: 'Lights out',
                    colors: const [Color(0xFF000000), Color(0xFFF57C00)],
                    selected: _style == _RecapStyle.lightsOut,
                    onTap: () => setState(() => _style = _RecapStyle.lightsOut),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: RepaintBoundary(
                  key: _recapKey,
                  child: AspectRatio(
                    aspectRatio: 4 / 5,
                    child: FittedBox(
                      fit: BoxFit.fill,
                      child: SizedBox(
                        width: 380,
                        height: 475,
                        child: _ShareRecapCard(
                          insights: insights,
                          period: _period,
                          style: _style,
                          includeTopTitle: _includeTopTitle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (insights.isEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'There isn’t enough viewing activity in ${_period.label.toLowerCase()} to make a recap yet.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: _insightSurface(context),
                borderRadius: BorderRadius.circular(9),
              ),
              child: SwitchListTile.adaptive(
                value: _includeTopTitle,
                onChanged: (value) => setState(() => _includeTopTitle = value),
                secondary: Icon(PhosphorIcons.eye()),
                title: const Text('Include my top title'),
                subtitle: const Text('Turn this off for a more private recap.'),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: PillButton(
                    height: 48,
                    onPressed: insights.isEmpty ? null : _copyCaption,
                    icon: PhosphorIcons.copy(),
                    label: 'Copy caption',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PillButton(
                    primary: true,
                    height: 48,
                    busy: _sharing,
                    onPressed: insights.isEmpty ? null : _shareImage,
                    icon: PhosphorIcons.shareNetwork(),
                    label: _sharing ? 'Creating…' : 'Share image',
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

class _RecapStyleChip extends StatelessWidget {
  const _RecapStyleChip({
    required this.label,
    required this.colors,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final List<Color> colors;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Material(
      color: selected ? palette.focusFill : palette.idleFill,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 7, 13, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: colors),
                  border: Border.all(color: Colors.white.withValues(alpha: .3)),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? palette.onFocus : palette.foreground,
                  fontFamily: 'FigtreeSB',
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                Icon(
                  PhosphorIcons.checkCircle(),
                  size: 17,
                  color: palette.onFocus,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareRecapCard extends StatelessWidget {
  const _ShareRecapCard({
    required this.insights,
    required this.period,
    required this.style,
    required this.includeTopTitle,
  });

  final WellnessInsights insights;
  final WellnessRecapPeriod period;
  final _RecapStyle style;
  final bool includeTopTitle;

  @override
  Widget build(BuildContext context) {
    const appAccent = Color(0xFFF57C00);
    final palette = switch (style) {
      _RecapStyle.light => (
          const Color(0xFFFAF9FC),
          const Color(0xFFF1EDF6),
          const Color(0xFFEAE3F2),
          appAccent,
          const Color(0xFF211D26),
        ),
      _RecapStyle.dark => (
          const Color(0xFF272A2E),
          const Color(0xFF181A1D),
          const Color(0xFF101113),
          appAccent,
          Colors.white,
        ),
      _RecapStyle.lightsOut => (
          Colors.black,
          const Color(0xFF080808),
          const Color(0xFF131313),
          appAccent,
          Colors.white,
        ),
    };
    final foreground = palette.$5;
    final bars = _recapBarData(insights, period);
    final maxBar =
        bars.fold<int>(0, (max, item) => item.value > max ? item.value : max);
    final topTitle = insights.topTitles.firstOrNull?.label;
    final topGenre = insights.topGenres.firstOrNull?.label;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.$1, palette.$2, palette.$3],
          stops: const [0, .55, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -70,
            top: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: foreground.withValues(alpha: .09),
                  width: 44,
                ),
              ),
            ),
          ),
          Positioned(
            left: -40,
            bottom: 80,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.$4.withValues(alpha: .08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 34,
                        height: 34,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'FLIXQUEST',
                      style: TextStyle(
                        color: foreground,
                        fontFamily: 'FigtreeSB',
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.15,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: foreground.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: foreground.withValues(alpha: .13),
                        ),
                      ),
                      child: Text(
                        period.label.toUpperCase(),
                        style: TextStyle(
                          color: foreground,
                          fontFamily: 'FigtreeSB',
                          fontWeight: FontWeight.w700,
                          letterSpacing: .8,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                Text(
                  'MY VIEWING\nSTORY',
                  style: TextStyle(
                    color: foreground.withValues(alpha: .7),
                    fontFamily: 'FigtreeSB',
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.2,
                    height: 1.12,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _duration(insights.totalWatchedMs),
                  style: TextStyle(
                    color: foreground,
                    fontFamily: 'FigtreeBlack',
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                    height: .98,
                    fontSize: 45,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'of active playback',
                  style: TextStyle(
                    color: foreground.withValues(alpha: .76),
                    fontFamily: 'Figtree',
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                if (includeTopTitle && topTitle != null) ...[
                  Text(
                    'MOST WATCHED',
                    style: TextStyle(
                      color: palette.$4,
                      fontFamily: 'FigtreeSB',
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.25,
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    topTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontFamily: 'FigtreeSB',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (topGenre != null)
                    Text(
                      'Top genre • $topGenre',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground.withValues(alpha: .62),
                        fontFamily: 'Figtree',
                        fontSize: 10,
                      ),
                    ),
                  const SizedBox(height: 14),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: _RecapMetric(
                        value: '${insights.completedTitles}',
                        label: 'completed',
                        foreground: foreground,
                      ),
                    ),
                    Expanded(
                      child: _RecapMetric(
                        value: '${insights.activeDays}',
                        label: 'active days',
                        foreground: foreground,
                      ),
                    ),
                    Expanded(
                      child: _RecapMetric(
                        value: '${insights.sessionCount}',
                        label: 'sessions',
                        foreground: foreground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                SizedBox(
                  height: 42,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final bar in bars)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: FractionallySizedBox(
                                      heightFactor: maxBar == 0
                                          ? .08
                                          : .12 + .88 * (bar.value / maxBar),
                                      widthFactor: 1,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color:
                                              maxBar > 0 && bar.value == maxBar
                                                  ? palette.$4
                                                  : foreground.withValues(
                                                      alpha: .26,
                                                    ),
                                          borderRadius:
                                              const BorderRadius.vertical(
                                            top: Radius.circular(4),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  bar.label,
                                  style: TextStyle(
                                    color: foreground.withValues(alpha: .58),
                                    fontFamily: 'Figtree',
                                    fontSize: 7,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(PhosphorIcons.lockKey(),
                        color: foreground.withValues(alpha: .52), size: 10),
                    const SizedBox(width: 4),
                    Text(
                      'Active playback only • Pauses excluded',
                      style: TextStyle(
                        color: foreground.withValues(alpha: .52),
                        fontFamily: 'Figtree',
                        fontSize: 8,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat.yMMMd().format(DateTime.now()),
                      style: TextStyle(
                        color: foreground.withValues(alpha: .52),
                        fontFamily: 'Figtree',
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecapMetric extends StatelessWidget {
  const _RecapMetric({
    required this.value,
    required this.label,
    required this.foreground,
  });

  final String value;
  final String label;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: foreground,
            fontFamily: 'FigtreeSB',
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: foreground.withValues(alpha: .6),
            fontFamily: 'Figtree',
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

class WellnessPreviewCard extends StatelessWidget {
  const WellnessPreviewCard({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WellnessProvider>();
    final now = DateTime.now();
    final insights = WellnessInsights.fromSessions(
      provider.sessions,
      period: WellnessPeriod.forRange(WellnessRange.week, now),
    );
    final featured = WellnessRecapPeriod.featured(provider.sessions, now);
    final recapReady = featured.hasReadyRecap(provider.sessions, now);
    final colors = Theme.of(context).colorScheme;
    final palette = AppPalette.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('wellness-profile-card'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: palette.idleFill,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                  ),
                  child: Icon(
                    recapReady
                        ? PhosphorIcons.confetti()
                        : PhosphorIcons.chartDonut(),
                    color: palette.foreground,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Viewing Insights',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (recapReady)
                            Container(
                              padding: const EdgeInsetsDirectional.only(
                                start: 8,
                              ),
                              child: Text(
                                'RECAP READY',
                                style: TextStyle(
                                  color: colors.primary,
                                  fontFamily: 'FigtreeSB',
                                  fontSize: 10,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        recapReady
                            ? '${featured.label} recap is ready to revisit'
                            : insights.isEmpty
                                ? 'Your private viewing insights start here'
                                : '${_duration(insights.totalWatchedMs)} this week • ${insights.completedTitles} completed',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Directionality.of(context) == ui.TextDirection.rtl
                      ? PhosphorIcons.caretLeft()
                      : PhosphorIcons.caretRight(),
                  size: 17,
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

class _InsightsToolbar extends StatelessWidget {
  const _InsightsToolbar({required this.provider});

  final WellnessProvider provider;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = provider.syncService.status.value;
    final syncing = status == WellnessSyncStatus.syncing;
    final statusLabel = !provider.canSync
        ? 'On this device'
        : syncing
            ? 'Syncing…'
            : status == WellnessSyncStatus.error
                ? 'Sync paused'
                : provider.syncService.lastSynced.value == null
                    ? 'Ready to sync'
                    : 'Synced ${_relativeTime(provider.syncService.lastSynced.value!)}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _insightSurface(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppPalette.of(context).idleFill,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                child: Icon(
                  provider.canSync
                      ? PhosphorIcons.cloudCheck()
                      : PhosphorIcons.deviceMobile(),
                  size: 18,
                  color: AppPalette.of(context).foreground,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your private viewing story',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      statusLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: status == WellnessSyncStatus.error
                                ? colors.error
                                : colors.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (provider.canSync)
                PillButton(
                  busy: syncing,
                  onPressed: provider.syncNow,
                  icon: PhosphorIcons.arrowsClockwise(),
                  label: 'Sync',
                ),
            ],
          ),
          const SizedBox(height: 14),
          _RangePicker(
            selected: provider.range,
            onSelected: provider.setRange,
          ),
        ],
      ),
    );
  }
}

class _RangePicker extends StatelessWidget {
  const _RangePicker({required this.selected, required this.onSelected});

  final WellnessRange selected;
  final ValueChanged<WellnessRange> onSelected;

  @override
  Widget build(BuildContext context) {
    final labels = <WellnessRange, String>{
      WellnessRange.week: 'Week',
      WellnessRange.month: 'Month',
      WellnessRange.year: 'Year',
      WellnessRange.allTime: 'All time',
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final range in WellnessRange.values)
          ChoicePill(
            spec: FilterChipSpec(
              label: labels[range]!,
              selected: selected == range,
              onTap: () => onSelected(range),
            ),
          ),
      ],
    );
  }
}

enum _InsightsSection { time, titles, taste, patterns }

class _SectionNavigator extends StatelessWidget {
  const _SectionNavigator({required this.onSelected});

  final ValueChanged<_InsightsSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = <(_InsightsSection, IconData, String)>[
      (_InsightsSection.time, PhosphorIcons.clock(), 'Time'),
      (_InsightsSection.titles, PhosphorIcons.filmSlate(), 'Titles'),
      (_InsightsSection.taste, PhosphorIcons.palette(), 'Taste'),
      (_InsightsSection.patterns, PhosphorIcons.calendarDots(), 'Patterns'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          ChoicePill(
            spec: FilterChipSpec(
              icon: item.$2,
              label: item.$3,
              onTap: () => onSelected(item.$1),
            ),
          ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.insights,
    required this.previous,
    required this.range,
  });

  final WellnessInsights insights;
  final WellnessInsights previous;
  final WellnessRange range;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    // A raised panel, not a coloured one: the accent is kept for progress.
    final rawGradient = <Color>[
      palette.raisedSurface,
      Color.lerp(palette.raisedSurface, palette.surface, .5)!,
      palette.surface,
    ];
    final foreground = _bestGradientForeground(rawGradient);
    final gradient = rawGradient
        .map((color) => _ensureTextContrast(color, foreground))
        .toList(growable: false);
    final foregroundIsLight = foreground.computeLuminance() > .5;
    final translucentSurface = foregroundIsLight
        ? Colors.white.withValues(alpha: .12)
        : Colors.white.withValues(alpha: .28);
    final difference = insights.totalWatchedMs - previous.totalWatchedMs;
    final today = DateTime.now();
    final trailStart = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 13));
    final trail = List<int>.generate(
      14,
      (index) =>
          insights.dailyWatchedMs[trailStart.add(Duration(days: index))] ?? 0,
      growable: false,
    );
    // The sparkline's own ring is cut to its surface, so the plate underneath
    // has to be an opaque color rather than a wash over the gradient.
    final trailSurface = Color.alphaBlend(translucentSurface, rawGradient[1]);
    final comparison = range == WellnessRange.allTime
        ? 'Across ${insights.activeDays} viewing days'
        : previous.totalWatchedMs == 0
            ? 'Your story is taking shape'
            : '${_duration(difference.abs())} ${difference >= 0 ? 'more' : 'less'} than the previous ${_rangeName(range)}';
    return Container(
      key: const Key('wellness-hero-card'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(AppRadii.hero),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -42,
            top: -62,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  width: 38,
                  color: foreground.withValues(alpha: .08),
                ),
              ),
            ),
          ),
          Positioned(
            right: 80,
            bottom: -74,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: foreground.withValues(alpha: .055),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 600;
                final headline = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: translucentSurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: foreground.withValues(alpha: .14),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                PhosphorIcons.sparkle(),
                                color: foreground,
                                size: 15,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'YOUR VIEWING STORY',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: foreground,
                                      letterSpacing: 1.05,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      _duration(insights.totalWatchedMs),
                      style:
                          Theme.of(context).textTheme.displayMedium?.copyWith(
                                color: foreground,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.8,
                              ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'active playback this ${_rangeName(range)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: foreground.withValues(alpha: .82),
                          ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Icon(
                          previous.totalWatchedMs == 0
                              ? PhosphorIcons.sparkle()
                              : difference >= 0
                                  ? PhosphorIcons.trendUp()
                                  : PhosphorIcons.trendDown(),
                          color: foreground.withValues(alpha: .8),
                          size: 18,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            comparison,
                            style: TextStyle(
                              color: foreground.withValues(alpha: .8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (trail.any((value) => value > 0)) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                        decoration: BoxDecoration(
                          color: trailSurface,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: foreground.withValues(alpha: .12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            WellnessSparkline(
                              key: const Key('wellness-hero-sparkline'),
                              values: trail,
                              height: 38,
                              color: foreground,
                              surfaceColor: trailSurface,
                              semanticsLabel:
                                  'Watch time for each of the last 14 days, '
                                  'ending today at ${_duration(trail.last)}.',
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'LAST 14 DAYS',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: foreground.withValues(alpha: .72),
                                    letterSpacing: 1.0,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
                final supporting = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeroMetric(
                      value: '${insights.completedTitles}',
                      label: 'completed',
                      foreground: foreground,
                      surface: translucentSurface,
                    ),
                    _HeroMetric(
                      value: '${insights.activeDays}',
                      label: 'active days',
                      foreground: foreground,
                      surface: translucentSurface,
                    ),
                    _HeroMetric(
                      value: '${insights.sessionCount}',
                      label: 'sessions',
                      foreground: foreground,
                      surface: translucentSurface,
                    ),
                  ],
                );
                if (!wide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      headline,
                      const SizedBox(height: 22),
                      supporting,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: headline),
                    const SizedBox(width: 24),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 250),
                      child: supporting,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.value,
    required this.label,
    required this.foreground,
    required this.surface,
  });

  final String value;
  final String label;
  final Color foreground;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground.withValues(alpha: .74),
                ),
          ),
        ],
      ),
    );
  }
}

class _RecapShelf extends StatelessWidget {
  const _RecapShelf({required this.sessions, required this.onSelected});

  final List<WellnessViewingSession> sessions;
  final ValueChanged<WellnessRecapPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final colors = Theme.of(context).colorScheme;
    final featured = WellnessRecapPeriod.featured(sessions, now);
    final featuredInsights = featured.insightsFrom(sessions);
    final quickPeriods = WellnessRecapPeriod.available(sessions, now)
        .where((period) => period.id != featured.id)
        .where((period) => !period.insightsFrom(sessions).isEmpty)
        .take(3)
        .toList(growable: false);
    final ready = featured.hasReadyRecap(sessions, now);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _insightSurface(context),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            end: -28,
            top: -38,
            child: Icon(
              PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
              size: 150,
              color: AppPalette.of(context).foreground.withValues(alpha: .04),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      ready ? 'RECAP READY' : 'YOUR RECAPS',
                      style: TextStyle(
                        color: ready ? colors.primary : colors.onSurfaceVariant,
                        fontFamily: 'FigtreeSB',
                        fontSize: 11,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      ready
                          ? PhosphorIcons.confetti()
                          : PhosphorIcons.calendarDots(),
                      color: colors.onSurfaceVariant,
                      size: 22,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  ready
                      ? '${featured.label} recap is ready'
                      : '${featured.label} recap is taking shape',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 5),
                Text(
                  featuredInsights.isEmpty
                      ? 'Your next viewing session will start filling in this story.'
                      : '${_duration(featuredInsights.totalWatchedMs)} watched · ${featuredInsights.completedTitles} completed · ${featuredInsights.activeDays} active ${featuredInsights.activeDays == 1 ? 'day' : 'days'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                PillButton(
                  primary: true,
                  onPressed: featuredInsights.isEmpty
                      ? null
                      : () => onSelected(featured),
                  icon: ready
                      ? PhosphorIcons.sparkle()
                      : PhosphorIcons.arrowUpRight(),
                  label: ready ? 'See my recap' : 'Preview recap',
                ),
                if (quickPeriods.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var index = 0;
                            index < quickPeriods.length;
                            index++) ...[
                          if (index > 0) const SizedBox(width: 8),
                          _QuickRecapButton(
                            period: quickPeriods[index],
                            insights:
                                quickPeriods[index].insightsFrom(sessions),
                            onTap: () => onSelected(quickPeriods[index]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickRecapButton extends StatelessWidget {
  const _QuickRecapButton({
    required this.period,
    required this.insights,
    required this.onTap,
  });

  final WellnessRecapPeriod period;
  final WellnessInsights insights;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: _insightSurface(context, raised: true),
      borderRadius: BorderRadius.circular(9),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIcons.playCircle(), size: 17, color: colors.onSurface),
              const SizedBox(width: 7),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    period.label,
                    style: const TextStyle(
                      fontFamily: 'FigtreeSB',
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _duration(insights.totalWatchedMs),
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontFamily: 'Figtree',
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.insights});

  final WellnessInsights insights;

  @override
  Widget build(BuildContext context) {
    final stats = <(IconData, String, String)>[
      (PhosphorIcons.filmSlate(), '${insights.completedMovies}', 'movies'),
      (PhosphorIcons.television(), '${insights.completedEpisodes}', 'episodes'),
      (PhosphorIcons.stack(), '${insights.uniqueSeries}', 'series'),
      (PhosphorIcons.playCircle(), '${insights.sessionCount}', 'sessions'),
      (PhosphorIcons.calendarDots(), '${insights.activeDays}', 'active days'),
      (
        PhosphorIcons.arrowCounterClockwise(),
        '${insights.rewatches}',
        'rewatches'
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 3 : 2;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        final colors = Theme.of(context).colorScheme;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var index = 0; index < stats.length; index++)
              SizedBox(
                width: width,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 102),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _insightSurface(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppPalette.of(context).idleFill,
                          borderRadius: BorderRadius.circular(AppRadii.card),
                        ),
                        child: Icon(
                          stats[index].$1,
                          size: 20,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stats[index].$2,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              stats[index].$3,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ],
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
  }
}

class _MediaBreakdown extends StatefulWidget {
  const _MediaBreakdown({required this.insights});

  final WellnessInsights insights;

  @override
  State<_MediaBreakdown> createState() => _MediaBreakdownState();
}

class _MediaBreakdownState extends State<_MediaBreakdown> {
  int? _selected;

  @override
  void didUpdateWidget(_MediaBreakdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.insights != widget.insights) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = _insightSurface(context);
    final palette = WellnessChartPalette.of(context, surface: surface);
    final insights = widget.insights;
    // Fixed order, fixed slots: movies always wear slot 1, so a period with no
    // live TV never repaints episodes.
    final entries = <(String, int, Color)>[
      ('Movies', insights.movieMs, palette.categorical[0]),
      ('Episodes', insights.episodeMs, palette.categorical[1]),
      ('Live TV', insights.liveMs, palette.categorical[2]),
    ];
    final total = entries.fold<int>(0, (sum, entry) => sum + entry.$2);
    final selected = _selected;
    final centerLabel =
        selected == null ? _duration(total) : _duration(entries[selected].$2);
    final centerCaption = selected == null
        ? 'total playback'
        : '${entries[selected].$1} · ${_share(entries[selected].$2, total)}';

    void select(int? index) => setState(() => _selected = index);

    final chart = WellnessDonutChart(
      key: const Key('wellness-media-donut'),
      slices: [
        for (final entry in entries)
          WellnessDonutSlice(
            label: entry.$1,
            value: entry.$2,
            color: entry.$3,
          ),
      ],
      centerLabel: centerLabel,
      centerCaption: centerCaption,
      selectedIndex: selected,
      onSelected: select,
      surfaceColor: surface,
    );
    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < entries.length; index++)
          _MediaLegendRow(
            label: entries[index].$1,
            valueLabel: _duration(entries[index].$2),
            shareLabel: _share(entries[index].$2, total),
            color: entries[index].$3,
            selected: selected == index,
            dimmed: selected != null && selected != index,
            onTap: () => select(selected == index ? null : index),
          ),
      ],
    );

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Playback mix',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text(
                'Tap a slice',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth > 520
                ? Row(
                    children: [
                      chart,
                      const SizedBox(width: 26),
                      Expanded(child: legend),
                    ],
                  )
                : Column(
                    children: [
                      chart,
                      const SizedBox(height: 16),
                      legend,
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Legend row that doubles as the donut's control surface — the whole row is
/// the hit target, and it carries the value so the ring is never the only way
/// to read one.
class _MediaLegendRow extends StatelessWidget {
  const _MediaLegendRow({
    required this.label,
    required this.valueLabel,
    required this.shareLabel,
    required this.color,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  final String label;
  final String valueLabel;
  final String shareLabel;
  final Color color;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $valueLabel, $shareLabel',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
            child: Row(
              children: [
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: dimmed ? color.withValues(alpha: .42) : color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w800 : null,
                    ),
                  ),
                ),
                Text(
                  valueLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFeatures: const [ui.FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 42,
                  child: Text(
                    shareLabel,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFeatures: const [ui.FontFeature.tabularFigures()],
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

class _RankedPanel extends StatelessWidget {
  const _RankedPanel({
    required this.title,
    required this.values,
    required this.emptyMessage,
    this.valueLabel = _duration,
  });

  final String title;
  final List<WellnessRankedValue> values;
  final String emptyMessage;

  /// Ranked values are not always durations — episode counts use their own
  /// formatter.
  final String Function(int value) valueLabel;

  @override
  Widget build(BuildContext context) {
    final max = values.isEmpty ? 1 : values.first.value;
    final palette = WellnessChartPalette.of(
      context,
      surface: _insightSurface(context),
    );
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          if (values.isEmpty)
            Text(
              emptyMessage,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (var index = 0; index < values.length; index++) ...[
              Row(
                children: [
                  Container(
                    width: 25,
                    height: 25,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: index == 0
                          ? AppPalette.of(context).idleFillStrong
                          : AppPalette.of(context).idleFill,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      values[index].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    valueLabel(values[index].value),
                    style: const TextStyle(
                      fontFeatures: [ui.FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: max == 0 ? 0 : values[index].value / max,
                minHeight: 5,
                borderRadius: BorderRadius.circular(99),
                color: palette.primaryMark,
                backgroundColor: palette.emptyCell,
              ),
              if (index != values.length - 1) const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({required this.sessions});

  final List<WellnessViewingSession> sessions;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<WellnessProvider>();
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Viewing history',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Text(
              '${sessions.length} recent',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontFamily: 'Figtree',
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < sessions.length; index++) ...[
          Material(
            color: _insightSurface(context, raised: index == 0),
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
              child: _HistoryRow(
                session: sessions[index],
                onDelete: () => provider.deleteSession(sessions[index].id),
              ),
            ),
          ),
          if (index != sessions.length - 1) const SizedBox(height: 9),
        ],
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.session, required this.onDelete});

  final WellnessViewingSession session;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final icon = switch (session.mediaType) {
      WellnessMediaType.movie => PhosphorIcons.filmSlate(),
      WellnessMediaType.episode => PhosphorIcons.television(),
      WellnessMediaType.live => PhosphorIcons.broadcast(),
    };
    final localStart = session.startedAtUtc
        .add(Duration(minutes: session.timezoneOffsetMinutes));
    final hasProgress =
        session.mediaType != WellnessMediaType.live && session.durationMs > 0;
    final statusColor =
        session.completed ? colors.onSurface : colors.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 58,
          decoration: BoxDecoration(
            color: AppPalette.of(context).idleFill,
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          child: Icon(icon, size: 21, color: colors.onSurface),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontFamily: 'FigtreeSB',
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (session.subtitle?.isNotEmpty == true) ...[
                const SizedBox(height: 2),
                Text(
                  session.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 5,
                children: [
                  _HistoryMeta(
                    icon: PhosphorIcons.calendarBlank(),
                    label: DateFormat.MMMd().add_jm().format(localStart),
                  ),
                  _HistoryMeta(
                    icon: PhosphorIcons.clock(),
                    label: _duration(session.watchedMs),
                  ),
                  _HistoryMeta(
                    icon: session.completed
                        ? PhosphorIcons.checkCircle()
                        : PhosphorIcons.playCircle(),
                    label: session.viewingStatus,
                    color: statusColor,
                  ),
                ],
              ),
              if (hasProgress) ...[
                const SizedBox(height: 11),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: session.progress,
                    minHeight: 3,
                    backgroundColor: colors.onSurface.withValues(alpha: .07),
                  ),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          tooltip: 'Remove from insights',
          visualDensity: VisualDensity.compact,
          onPressed: () => _confirmDelete(context),
          icon: Icon(
            PhosphorIcons.trash(),
            size: 18,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this activity?'),
        content: Text(
          '${session.title} will no longer be included in your viewing insights.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (remove == true) onDelete();
  }
}

class _HistoryMeta extends StatelessWidget {
  const _HistoryMeta({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: foreground),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: foreground,
            fontFamily: color == null ? 'Figtree' : 'FigtreeSB',
            fontSize: 11,
            fontWeight: color == null ? FontWeight.w500 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _InsightStrip extends StatelessWidget {
  const _InsightStrip({required this.insights});

  final WellnessInsights insights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final peak = insights.peakHourOfWeek;
    final busiest = insights.busiestDay;
    final total = insights.totalWatchedMs;
    final streak = insights.currentStreakDays();
    final observations = <(IconData, String)>[
      if (streak > 1)
        (
          PhosphorIcons.flame(),
          'You have watched something $streak days running — your longest run '
              'is ${insights.longestStreakDays} days.',
        ),
      if (peak != null)
        (
          PhosphorIcons.clock(),
          'Your most reliable window is ${_weekdayName(peak.$1)} at '
              '${_hourRange(peak.$2)}, ${_duration(peak.$3)} in total.',
        ),
      if (busiest != null)
        (
          PhosphorIcons.calendarStar(),
          'Your heaviest day was ${DateFormat.MMMEd().format(busiest.$1)} at '
              '${_duration(busiest.$2)}.',
        ),
      if (insights.averageSessionMs > 0)
        (
          PhosphorIcons.hourglass(),
          'A typical sitting runs ${_duration(insights.averageSessionMs)}, and '
              'a typical active day ${_duration(insights.medianActiveDayMs)}.',
        ),
      if (total > 0 && insights.lateNightMs > 0)
        (
          PhosphorIcons.moon(),
          '${_share(insights.lateNightMs, total)} of your viewing happens '
              'after 10pm.',
        ),
      if (insights.titlesStarted > 0)
        (
          PhosphorIcons.checkCircle(),
          'You finish ${_percent(insights.completionRate)} of what you start '
              '(${insights.completedTitles} of ${insights.titlesStarted}).',
        ),
      if (insights.longestSessionMs > 0)
        (
          PhosphorIcons.filmSlate(),
          'Your longest single session was '
              '${_duration(insights.longestSessionMs)}.',
        ),
      if (insights.topTitles.isNotEmpty)
        (
          PhosphorIcons.crown(),
          '${insights.topTitles.first.label} held the most viewing time.',
        ),
    ];
    if (observations.isEmpty) {
      return _Panel(
        child: Text(
          'Watch a few things and this is where the patterns show up.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What stands out', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          for (final observation in observations)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      observation.$1,
                      size: 17,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      observation.$2,
                      style: theme.textTheme.bodySmall,
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

/// The time-series panel: bar chart, a callout for the tapped bucket, and a
/// table of every value behind a toggle so no number lives only in the chart.
class _TimelinePanel extends StatefulWidget {
  const _TimelinePanel({
    required this.insights,
    required this.range,
    super.key,
  });

  final WellnessInsights insights;
  final WellnessRange range;

  @override
  State<_TimelinePanel> createState() => _TimelinePanelState();
}

class _TimelinePanelState extends State<_TimelinePanel> {
  int? _selected;
  bool _showTable = false;

  @override
  void didUpdateWidget(_TimelinePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different range means different buckets; a stale index would point at
    // the wrong span.
    if (oldWidget.range != widget.range ||
        oldWidget.insights != widget.insights) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = _insightSurface(context);
    final series = WellnessTimeSeries.forRange(widget.insights, widget.range);
    final selected = _selected != null && _selected! < series.buckets.length
        ? _selected
        : null;
    final busiest = series.indexOfBusiest();
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Watch time', style: theme.textTheme.titleMedium),
                    Text(
                      'by ${series.unitLabel} · ${_rangeName(widget.range)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _duration(widget.insights.totalWatchedMs),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [ui.FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          WellnessBarChart(
            key: const Key('wellness-time-chart'),
            data: [
              for (final bucket in series.buckets)
                WellnessBarDatum(
                  label: bucket.label,
                  fullLabel: bucket.fullLabel,
                  value: bucket.totalMs,
                ),
            ],
            selectedIndex: selected,
            onSelected: (index) => setState(() => _selected = index),
            averageMs: series.averageMs,
            surfaceColor: surface,
            semanticsLabel: 'Watch time by ${series.unitLabel}. Total '
                '${_duration(series.totalMs)} across ${series.activeBuckets} '
                'active ${series.unitLabel}s.',
          ),
          const SizedBox(height: 14),
          if (selected == null)
            _TimelineSummary(series: series, busiest: busiest)
          else
            _BucketCallout(
              bucket: series.buckets[selected],
              periodTotalMs: series.totalMs,
              sessions: widget.insights.sessions,
              unitLabel: series.unitLabel,
              onClose: () => setState(() => _selected = null),
            ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _showTable = !_showTable),
              icon: Icon(
                _showTable ? PhosphorIcons.caretUp() : PhosphorIcons.table(),
                size: 16,
              ),
              label: Text(_showTable ? 'Hide values' : 'All values'),
            ),
          ),
          if (_showTable)
            _ValuesTable(
              series: series,
              selectedIndex: selected,
              onSelected: (index) => setState(() => _selected = index),
            ),
        ],
      ),
    );
  }
}

/// What the chart says before anything is tapped: the average line it draws,
/// and where the peak sits.
class _TimelineSummary extends StatelessWidget {
  const _TimelineSummary({required this.series, required this.busiest});

  final WellnessTimeSeries series;
  final int busiest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    if (series.isEmpty) {
      return Text('Nothing recorded in this range yet.', style: style);
    }
    final peak = series.buckets[busiest];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          PhosphorIcons.handTap(),
          size: 15,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Tap any bar for that ${series.unitLabel}. Busiest was '
            '${peak.fullLabel} at ${_duration(peak.totalMs)}; the level line '
            'marks your ${_duration(series.averageMs.round())} average across '
            '${series.activeBuckets} active ${series.unitLabel}'
            '${series.activeBuckets == 1 ? '' : 's'}.',
            style: style,
          ),
        ),
      ],
    );
  }
}

/// The tapped bucket, spelled out: total, share, media split, and what was on.
class _BucketCallout extends StatelessWidget {
  const _BucketCallout({
    required this.bucket,
    required this.periodTotalMs,
    required this.sessions,
    required this.unitLabel,
    required this.onClose,
  });

  final WellnessTimeBucket bucket;
  final int periodTotalMs;
  final List<WellnessViewingSession> sessions;
  final String unitLabel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = _insightSurface(context, raised: true);
    final palette = WellnessChartPalette.of(context, surface: surface);
    final inside = bucket.sessionsFrom(sessions);
    final split = bucket.split;
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bucket.fullLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        bucket.isEmpty
                            ? 'No viewing recorded'
                            : _duration(bucket.totalMs),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (!bucket.isEmpty)
                        Text(
                          '${_share(bucket.totalMs, periodTotalMs)} of the '
                          'range · ${inside.length} '
                          'session${inside.length == 1 ? '' : 's'}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Clear selection',
                  visualDensity: VisualDensity.compact,
                  onPressed: onClose,
                  icon: Icon(PhosphorIcons.x(), size: 16),
                ),
              ],
            ),
            if (split != null && !split.isEmpty) ...[
              const SizedBox(height: 12),
              WellnessSplitMeter(
                parts: [
                  WellnessSplitPart(
                    label: 'Movies',
                    value: split.movieMs,
                    color: palette.categorical[0],
                  ),
                  WellnessSplitPart(
                    label: 'Episodes',
                    value: split.episodeMs,
                    color: palette.categorical[1],
                  ),
                  WellnessSplitPart(
                    label: 'Live TV',
                    value: split.liveMs,
                    color: palette.categorical[2],
                  ),
                ],
                valueLabel: _duration,
                surfaceColor: surface,
              ),
            ],
            if (inside.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final session in inside.take(3))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(
                        switch (session.mediaType) {
                          WellnessMediaType.movie => PhosphorIcons.filmSlate(),
                          WellnessMediaType.episode =>
                            PhosphorIcons.television(),
                          WellnessMediaType.live => PhosphorIcons.broadcast(),
                        },
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          session.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        _duration(session.watchedMs),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              if (inside.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '+${inside.length - 3} more this $unitLabel',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Every bucket as text. The chart is the fast read; this is the exact one,
/// and it is what a screen reader or a print-out gets.
class _ValuesTable extends StatelessWidget {
  const _ValuesTable({
    required this.series,
    required this.selectedIndex,
    required this.onSelected,
  });

  final WellnessTimeSeries series;
  final int? selectedIndex;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = series.totalMs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  series.unitLabel.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Text(
                'TIME',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 46,
                child: Text(
                  'SHARE',
                  textAlign: TextAlign.right,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (var index = 0; index < series.buckets.length; index++)
          InkWell(
            onTap: () => onSelected(selectedIndex == index ? null : index),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      series.buckets[index].fullLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight:
                            selectedIndex == index ? FontWeight.w800 : null,
                      ),
                    ),
                  ),
                  Text(
                    series.buckets[index].isEmpty
                        ? '—'
                        : _duration(series.buckets[index].totalMs),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFeatures: const [ui.FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 46,
                    child: Text(
                      series.buckets[index].isEmpty
                          ? ''
                          : _share(series.buckets[index].totalMs, total),
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontFeatures: const [ui.FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Streaks, active-day share, and the shape of the last two weeks.
class _ConsistencyPanel extends StatelessWidget {
  const _ConsistencyPanel({required this.insights});

  final WellnessInsights insights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = _insightSurface(context);
    final current = insights.currentStreakDays();
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 13));
    final recent = List<int>.generate(
      14,
      (index) => insights.dailyWatchedMs[start.add(Duration(days: index))] ?? 0,
      growable: false,
    );
    final recentActive = recent.where((value) => value > 0).length;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Consistency', style: theme.textTheme.titleMedium),
                    Text(
                      current == 0
                          ? 'No active streak right now'
                          : '$current day${current == 1 ? '' : 's'} in a row',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${insights.longestStreakDays}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'longest streak',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          WellnessSparkline(
            values: recent,
            surfaceColor: surface,
            semanticsLabel: 'Daily watch time for the last 14 days. '
                '$recentActive of 14 days had viewing.',
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Last 14 days · $recentActive active',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                'Peak ${_duration(recent.fold<int>(0, math.max))}/day',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          WellnessMeter(
            label: 'Days with viewing',
            valueLabel: _percent(insights.activeDayShare),
            ratio: insights.activeDayShare,
            // periodDays stops at the last recorded day, so "tracked so far"
            // is what the share actually measures.
            caption: '${insights.activeDays} of ${insights.periodDays} days '
                'tracked so far · typical active day '
                '${_duration(insights.medianActiveDayMs)}',
            surfaceColor: surface,
          ),
        ],
      ),
    );
  }
}

/// Week × hour grid with a tappable cell callout.
class _RhythmPanel extends StatefulWidget {
  const _RhythmPanel({required this.insights, super.key});

  final WellnessInsights insights;

  @override
  State<_RhythmPanel> createState() => _RhythmPanelState();
}

class _RhythmPanelState extends State<_RhythmPanel> {
  (int day, int hour)? _selected;

  @override
  void didUpdateWidget(_RhythmPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.insights != widget.insights) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = _insightSurface(context);
    final grid = widget.insights.hourOfWeekMs;
    final peak = widget.insights.peakHourOfWeek;
    final selected = _selected;
    final selectedMs = selected == null
        ? 0
        : (selected.$1 < grid.length && selected.$2 < grid[selected.$1].length
            ? grid[selected.$1][selected.$2]
            : 0);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Weekly rhythm', style: theme.textTheme.titleMedium),
                    Text(
                      'Every hour you watched, summed across this range',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Tap a cell',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          WellnessHeatmap(
            key: const Key('wellness-pattern-heatmap'),
            values: grid,
            selectedCell: selected,
            onSelected: (cell) => setState(() => _selected = cell),
            surfaceColor: surface,
          ),
          const SizedBox(height: 12),
          if (selected != null)
            Text(
              '${_weekdayName(selected.$1)} at ${_hourRange(selected.$2)} — '
              '${selectedMs == 0 ? 'nothing watched' : _duration(selectedMs)}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            )
          else if (peak != null)
            Text(
              'Your steadiest window is ${_weekdayName(peak.$1)} at '
              '${_hourRange(peak.$2)} — ${_duration(peak.$3)} in total.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Text(
              'Watch a little more and your weekly shape will appear here.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// Parts of the day as an ordinal ramp, plus weekday/weekend and late-night
/// shares.
class _DayPartsPanel extends StatefulWidget {
  const _DayPartsPanel({required this.insights});

  final WellnessInsights insights;

  @override
  State<_DayPartsPanel> createState() => _DayPartsPanelState();
}

class _DayPartsPanelState extends State<_DayPartsPanel> {
  int? _selected;

  static const _labels = ['Morning', 'Afternoon', 'Evening', 'Late night'];
  static const _windows = ['5a–12p', '12–5p', '5–10p', '10p–5a'];

  @override
  void didUpdateWidget(_DayPartsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.insights != widget.insights) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = _insightSurface(context);
    final palette = WellnessChartPalette.of(context, surface: surface);
    final parts = widget.insights.partOfDayMs;
    final total = parts.fold<int>(0, (sum, value) => sum + value);
    final selected = _selected;
    final weekday = widget.insights.weekdayWatchedMs;
    final weekend = widget.insights.weekendWatchedMs;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How your day splits', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          WellnessOrdinalBars(
            key: const Key('wellness-day-parts'),
            data: [
              for (var index = 0; index < parts.length; index++)
                WellnessOrdinalDatum(
                  label: _labels[index],
                  caption: _windows[index],
                  value: parts[index],
                ),
            ],
            selectedIndex: selected,
            onSelected: (index) => setState(() => _selected = index),
            surfaceColor: surface,
          ),
          const SizedBox(height: 10),
          Text(
            selected == null
                ? 'Ordered from morning to late night — darker means later in '
                    'the day, longer means more time.'
                : '${_labels[selected]} (${_windows[selected]}): '
                    '${_duration(parts[selected])}, '
                    '${_share(parts[selected], total)} of your viewing.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: selected == null
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onSurface,
              fontWeight: selected == null ? null : FontWeight.w700,
            ),
          ),
          const Divider(height: 30),
          Text(
            'Weekdays vs weekend',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          WellnessSplitMeter(
            parts: [
              WellnessSplitPart(
                label: 'Mon–Fri',
                value: weekday,
                color: palette.categorical[0],
              ),
              WellnessSplitPart(
                label: 'Sat–Sun',
                value: weekend,
                color: palette.categorical[1],
              ),
            ],
            valueLabel: _duration,
            surfaceColor: surface,
          ),
          const SizedBox(height: 14),
          WellnessMeter(
            label: 'After 10pm',
            valueLabel: _percent(
              total == 0 ? 0 : widget.insights.lateNightMs / total,
            ),
            ratio: total == 0 ? 0 : widget.insights.lateNightMs / total,
            caption: '${_duration(widget.insights.lateNightMs)} of viewing '
                'landed between 10pm and 5am.',
            surfaceColor: surface,
          ),
        ],
      ),
    );
  }
}

/// Started, finished, sampled — follow-through rather than volume.
class _CompletionPanel extends StatelessWidget {
  const _CompletionPanel({required this.insights});

  final WellnessInsights insights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = _insightSurface(context);
    final stats = <(String, String)>[
      ('${insights.titlesStarted}', 'started'),
      ('${insights.completedTitles}', 'finished'),
      ('${insights.sampledTitles}', 'sampled'),
      ('${insights.rewatches}', 'rewatched'),
    ];
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Follow-through', style: theme.textTheme.titleMedium),
          const SizedBox(height: 14),
          WellnessMeter(
            label: 'Titles finished',
            valueLabel: _percent(insights.completionRate),
            ratio: insights.completionRate,
            caption: '${insights.completedTitles} of '
                '${insights.titlesStarted} titles you started · average '
                'session ${_duration(insights.averageSessionMs)}',
            surfaceColor: surface,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final stat in stats)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stat.$1,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        stat.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (insights.sampledTitles > 0) ...[
            const SizedBox(height: 12),
            Text(
              'Sampled means under two minutes and under 5% watched — dropped '
              'early, not counted against you.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GuestMergeCard extends StatelessWidget {
  const _GuestMergeCard({required this.provider});

  final WellnessProvider provider;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add this device’s guest history?',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            const Text(
              'Guest viewing may belong to someone else. It will stay separate unless you choose to merge it.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: provider.mergeGuestHistory,
                  child: const Text('Merge with my account'),
                ),
                TextButton(
                  onPressed: provider.dismissGuestMerge,
                  child: const Text('Keep separate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.canSync});

  final bool canSync;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.secondaryContainer.withValues(alpha: .32),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              PhosphorIcons.lockKey(),
              size: 17,
              color: colors.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Private by design',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  canSync
                      ? 'Stored in SQLite on this device and synced to your FlixQuest account. This history is not sent to product analytics.'
                      : 'Stored only in SQLite on this device. Sign in when you want to sync it across devices.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WellnessEmptyState extends StatelessWidget {
  const _WellnessEmptyState({required this.hasHistory});

  final bool hasHistory;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: _insightSurface(context),
        borderRadius: BorderRadius.circular(AppRadii.hero),
      ),
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: AppPalette.of(context).idleFill,
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasHistory
                  ? PhosphorIcons.calendarBlank()
                  : PhosphorIcons.chartDonut(),
              size: 38,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          Text(
              hasHistory
                  ? 'Nothing watched in this period'
                  : 'Your viewing story starts here',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            hasHistory
                ? 'Try another time range to revisit your earlier viewing activity.'
                : 'Watch for at least 30 seconds and FlixQuest will begin building private insights about your time, titles, taste, and patterns.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: const [
              _EmptyFeature(icon: Icons.schedule_rounded, label: 'Time'),
              _EmptyFeature(icon: Icons.movie_outlined, label: 'Titles'),
              _EmptyFeature(icon: Icons.palette_outlined, label: 'Taste'),
              _EmptyFeature(icon: Icons.grid_view_rounded, label: 'Patterns'),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyFeature extends StatelessWidget {
  const _EmptyFeature({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    super.key,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppPalette.of(context).idleFill,
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          child: Icon(icon, color: colors.onSurface, size: 22),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: AppType.kicker.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _insightSurface(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

bool _isLightsOut(BuildContext context) =>
    Theme.of(context).scaffoldBackgroundColor.computeLuminance() < .003;

Color _insightSurface(BuildContext context, {bool raised = false}) {
  final palette = AppPalette.of(context);
  return raised ? palette.raisedSurface : palette.surface;
}

Color _bestGradientForeground(List<Color> colors) {
  const darkInk = Color(0xFF111315);
  var darkScore = double.infinity;
  var lightScore = double.infinity;
  for (final color in colors) {
    final darkContrast = _contrastRatio(color, darkInk);
    final lightContrast = _contrastRatio(color, Colors.white);
    if (darkContrast < darkScore) darkScore = darkContrast;
    if (lightContrast < lightScore) lightScore = lightContrast;
  }
  return darkScore >= lightScore ? darkInk : Colors.white;
}

Color _ensureTextContrast(Color background, Color foreground) {
  var adjusted = background;
  final target =
      foreground.computeLuminance() > .5 ? Colors.black : Colors.white;
  for (var step = 0;
      step < 20 && _contrastRatio(adjusted, foreground) < 7;
      step++) {
    adjusted = Color.lerp(adjusted, target, .08)!;
  }
  return adjusted;
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter =
      firstLuminance > secondLuminance ? firstLuminance : secondLuminance;
  final darker =
      firstLuminance > secondLuminance ? secondLuminance : firstLuminance;
  return (lighter + .05) / (darker + .05);
}

String _duration(int milliseconds) {
  final duration = Duration(milliseconds: milliseconds.abs());
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

String _share(int value, int total) =>
    total <= 0 ? '0%' : '${(value / total * 100).round()}%';

String _percent(double ratio) => '${(ratio.clamp(0.0, 1.0) * 100).round()}%';

String _episodeCount(int value) => '$value ep${value == 1 ? '' : 's'}';

String _weekdayName(int mondayFirstIndex) =>
    DateFormat.EEEE().format(DateTime(2024, 1, 1 + mondayFirstIndex));

/// "9 PM" reads as an instant; the cell is an hour, so name the hour.
String _hourRange(int hour) {
  final start = DateFormat.j().format(DateTime(2024, 1, 1, hour));
  final end = DateFormat.j().format(DateTime(2024, 1, 1, (hour + 1) % 24));
  return '$start–$end';
}

String _trackingSince(List<WellnessViewingSession> sessions) {
  if (sessions.isEmpty) return 'Tracking begins with your next viewing session';
  final oldest = sessions.reduce(
    (current, session) =>
        session.startedAtUtc.isBefore(current.startedAtUtc) ? session : current,
  );
  final local =
      oldest.startedAtUtc.add(Duration(minutes: oldest.timezoneOffsetMinutes));
  return 'Tracking since ${DateFormat.yMMMd().format(local)}';
}

String _relativeTime(DateTime value) {
  final difference = DateTime.now().difference(value);
  if (difference.inMinutes < 1) return 'just now';
  if (difference.inHours < 1) return '${difference.inMinutes}m ago';
  if (difference.inDays < 1) return '${difference.inHours}h ago';
  return DateFormat.MMMd().format(value);
}

String _rangeName(WellnessRange range) => switch (range) {
      WellnessRange.week => 'week',
      WellnessRange.month => 'month',
      WellnessRange.year => 'year',
      WellnessRange.allTime => 'all time',
    };

/// The recap card's bars come from the same bucketing as the live chart, so a
/// shared recap can never disagree with the screen it was shared from.
List<WellnessBarDatum> _recapBarData(
  WellnessInsights insights,
  WellnessRecapPeriod period,
) =>
    WellnessTimeSeries.forRecap(insights, period)
        .buckets
        .map((bucket) => WellnessBarDatum(
              label: bucket.label,
              value: bucket.totalMs,
              fullLabel: bucket.fullLabel,
            ))
        .toList(growable: false);

/// Viewing Insights' shape while the history loads: the sync bar, the
/// story card and the grid of counts.
class _InsightsSkeleton extends StatelessWidget {
  const _InsightsSkeleton();

  @override
  Widget build(BuildContext context) {
    final gutter = AppUI.pagePadding(context);
    return SkeletonPulse(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBlock(height: 116),
            const SizedBox(height: 18),
            const SkeletonBlock(height: 300, radius: AppRadii.hero),
            const SizedBox(height: 18),
            const SkeletonBlock(height: 170),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < 4; i++)
                      SkeletonBlock(width: width, height: 102),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
