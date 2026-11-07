import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../design/skeleton.dart';
import '../../mobile/widgets/filter_chips.dart';
import '../../mobile/widgets/media_art.dart' show ArtSize, tmdbImageUrl;
import '../../mobile/widgets/page_kit.dart';
import '../../mobile/widgets/pill_button.dart';
import '../../mobile/widgets/settings_kit.dart' show SheetTitle;
import '../../models/wellness.dart';
import '../../models/wellness_insights.dart';
import '../../models/wellness_recap.dart';
import '../../models/wellness_recap_story.dart';
import '../../models/wellness_time_series.dart';
import '../../provider/wellness_provider.dart';
import '../../ui_components/app_ui_components.dart';
import '../../widgets/wellness_charts.dart';
import 'widgets/insights_dashboard.dart';
import 'widgets/share_recap_card.dart';

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
  final GlobalKey _playbackSectionKey = GlobalKey();
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
        title: tr('ins_title'),
        contentWidth: 920,
        actions: [
          IconButton(
            tooltip: tr('ins_options'),
            onPressed: () => _showInsightsActions(wellness),
            icon: Icon(PhosphorIcons.dotsThreeVertical()),
          ),
        ],
      ),
      body: WellnessChartLabels(
        less: tr('ins_less'),
        more: tr('ins_more'),
        peakPerHour: (duration) =>
            tr('ins_peak_hour', namedArgs: {'time': duration}),
        nothingYet: tr('ins_nothing_yet'),
        child: SkeletonSwitcher(
          loading: wellness.loading,
          skeleton: const _InsightsSkeleton(),
          child: RefreshIndicator(
            color: palette.foreground,
            backgroundColor: palette.raisedSurface,
            onRefresh: wellness.reload,
            child: AppResponsiveContent(
              maxWidth: 920,
              padding: EdgeInsets.zero,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  AppUI.pagePadding(context),
                  12,
                  AppUI.pagePadding(context),
                  40,
                ),
                // Keep report anchors mounted so a snapshot or section chip
                // can jump directly to a section outside the viewport.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                      LayoutBuilder(builder: (context, constraints) {
                        final tracking = Text(
                          _trackingSince(wellness.sessions),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        );
                        final share = PillButton(
                          busy: _sharing,
                          onPressed: () => _openShareRecap(wellness),
                          icon: PhosphorIcons.shareNetwork(),
                          label: tr('ins_share_recap'),
                        );
                        if (constraints.maxWidth < 520) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              tracking,
                              const SizedBox(height: 10),
                              share
                            ],
                          );
                        }
                        return Row(children: [
                          Expanded(child: tracking),
                          const SizedBox(width: 12),
                          share,
                        ]);
                      }),
                      const SizedBox(height: 18),
                      InsightsSnapshot(
                        insights: insights,
                        onTitles: () => _jumpToSection(_titlesSectionKey),
                        onTaste: () => _jumpToSection(_tasteSectionKey),
                        onPatterns: () => _jumpToSection(_patternsSectionKey),
                      ),
                      const SizedBox(height: 18),
                      _StatGrid(insights: insights),
                      const SizedBox(height: 18),
                      _RecapShelf(
                        sessions: wellness.sessions,
                        onSelected: (period) => _openShareRecap(
                          wellness,
                          initialPeriod: period,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _SectionNavigator(
                        onSelected: (section) =>
                            _jumpToSection(switch (section) {
                          _InsightsSection.time => _timeSectionKey,
                          _InsightsSection.titles => _titlesSectionKey,
                          _InsightsSection.taste => _tasteSectionKey,
                          _InsightsSection.patterns => _patternsSectionKey,
                          _InsightsSection.playback => _playbackSectionKey,
                        }),
                      ),
                      const SizedBox(height: 34),
                      _SectionHeader(
                        key: _timeSectionKey,
                        icon: PhosphorIcons.clockCounterClockwise(),
                        eyebrow: tr('ins_time').toUpperCase(),
                        title: tr('ins_time_title'),
                        description: tr('ins_time_desc'),
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
                        eyebrow: tr('ins_titles').toUpperCase(),
                        title: tr('ins_titles_title'),
                        description: tr('ins_titles_desc'),
                      ),
                      const SizedBox(height: 14),
                      InsightsDiscoveryPanel(insights: insights),
                      const SizedBox(height: 14),
                      _CompletionPanel(insights: insights),
                      const SizedBox(height: 14),
                      InsightsRankedPanel(
                        title: tr('ins_most_watched'),
                        values: insights.topTitles,
                        emptyMessage: tr('ins_most_watched_empty'),
                      ),
                      const SizedBox(height: 14),
                      if (insights.topSeriesEpisodes.isNotEmpty) ...[
                        InsightsRankedPanel(
                          title: tr('ins_series_kept'),
                          values: insights.topSeriesEpisodes,
                          emptyMessage: tr('ins_series_kept_empty'),
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
                        eyebrow: tr('ins_taste').toUpperCase(),
                        title: tr('ins_taste_title'),
                        description: tr('ins_taste_desc'),
                      ),
                      const SizedBox(height: 14),
                      InsightsTasteBreadth(insights: insights),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 680;
                          final width = wide
                              ? (constraints.maxWidth - 14) / 2
                              : constraints.maxWidth;
                          final panels = <Widget>[
                            InsightsRankedPanel(
                              title: tr('genres'),
                              values: insights.topGenres,
                              emptyMessage: tr('ins_genres_empty'),
                            ),
                            InsightsRankedPanel(
                              title: tr('ins_languages'),
                              values: insights.topLanguages,
                              emptyMessage: tr('ins_languages_empty'),
                            ),
                            InsightsRankedPanel(
                              title: tr('ins_countries'),
                              values: insights.topCountries,
                              emptyMessage: tr('ins_countries_empty'),
                            ),
                            InsightsRankedPanel(
                              title: tr('ins_decades'),
                              values: insights.topDecades,
                              emptyMessage: tr('ins_decades_empty'),
                            ),
                            InsightsRankedPanel(
                              title: tr('ins_providers'),
                              values: insights.topProviders,
                              emptyMessage: tr('ins_providers_empty'),
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
                        eyebrow: tr('ins_patterns').toUpperCase(),
                        title: tr('ins_patterns_title'),
                        description: tr('ins_patterns_desc'),
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
                      const SizedBox(height: 34),
                      _SectionHeader(
                        key: _playbackSectionKey,
                        icon: PhosphorIcons.devices(),
                        eyebrow: tr('ins_playback').toUpperCase(),
                        title: tr('ins_playback_title'),
                        description: tr('ins_playback_desc'),
                      ),
                      const SizedBox(height: 14),
                      InsightsPlaybackPanel(insights: insights),
                      const SizedBox(height: 26),
                      const _PrivacyNote(canSync: false),
                    ],
                  ],
                ),
              ),
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
          text: tr('ins_export_text'),
        );
      case _WellnessAction.clear:
        if (!mounted) return;
        final confirmed = await showConfirmDialog(
          context,
          icon: PhosphorIcons.trash(),
          title: tr('ins_clear_q'),
          message: tr('ins_clear_local'),
          confirmLabel: tr('ins_clear_history'),
          destructive: true,
        );
        if (confirmed == true) await wellness.clearHistory();
    }
  }

  Future<void> _showInsightsActions(WellnessProvider wellness) async {
    final action = await showAppSheet<_WellnessAction>(
      context,
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
        constraints: appSheetConstraints(context),
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
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + AppSpace.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SheetTitle(tr('ins_data_title')),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              gutter,
              0,
              gutter,
              AppSpace.sm,
            ),
            child: Text(
              tr('ins_data_desc'),
              style: AppType.body.copyWith(color: palette.mutedText),
            ),
          ),
          ListRow(
            icon: PhosphorIcons.export(),
            label: tr('ins_export'),
            subtitle: tr('ins_export_desc'),
            onTap: () => Navigator.pop(context, _WellnessAction.export),
          ),
          ListRow(
            icon: PhosphorIcons.trash(),
            label: tr('ins_clear_title'),
            subtitle: tr('ins_clear_desc'),
            destructive: true,
            onTap: () => Navigator.pop(context, _WellnessAction.clear),
          ),
        ],
      ),
    );
  }
}

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
  late ShareRecapStyle _style;
  late WellnessRecapPeriod _period;
  ShareRecapFormat _format = ShareRecapFormat.post;
  bool _includeTitles = true;
  bool _includeHabits = true;
  bool _sharing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!mounted || _styleInitialized) return;
    final theme = Theme.of(context);
    _style = theme.brightness == Brightness.light
        ? ShareRecapStyle.light
        : _isLightsOut(context)
            ? ShareRecapStyle.lightsOut
            : ShareRecapStyle.dark;
    _period = widget.initialPeriod;
    _styleInitialized = true;
  }

  bool _styleInitialized = false;

  WellnessRecapStory? _cachedStory;

  /// Rebuilt only when the period changes: the sheet rebuilds on every toggle
  /// and this walks the whole history.
  WellnessRecapStory get _story {
    final cached = _cachedStory;
    if (cached != null && cached.period.id == _period.id) return cached;
    final story = WellnessRecapStory.of(
      WellnessInsights.fromSessions(
        widget.sessions,
        period: _period.wellnessPeriod,
      ),
      _period,
    );
    _cachedStory = story;
    return story;
  }

  String get _caption {
    final story = _story;
    final insights = story.insights;
    final title = _includeTitles && insights.topTitles.isNotEmpty
        ? tr('ins_caption_top',
            namedArgs: {'title': insights.topTitles.first.label})
        : '';
    final profile = _includeHabits ? story.profile : null;
    final type = profile == null
        ? ''
        : tr('ins_caption_type',
            namedArgs: {'type': shareRecapTypeName(profile.type)});
    return '${tr('ins_caption', namedArgs: {
          'period': _recapCaptionLabel(_period),
          'time': _duration(insights.totalWatchedMs),
          'days': plural('ins_active_days', insights.activeDays),
        })}$title$type flix.quest';
  }

  /// Session artwork is a TMDB path, except that downloads record whatever
  /// they were saved with: a full URL or a file on this device.
  ImageProvider? _artFor(String path, ShareRecapArtKind kind) {
    if (path.startsWith('http')) return CachedNetworkImageProvider(path);
    if (path.lastIndexOf('/') > 0) return FileImage(File(path));
    final url = tmdbImageUrl(
      context,
      path,
      size: kind == ShareRecapArtKind.poster ? 'w500/' : ArtSize.still,
      listen: false,
    );
    return url == null ? null : CachedNetworkImageProvider(url);
  }

  /// Waits for the artwork the card draws. One that fails is left to the
  /// card's fallback, and a slow network can't hold the export forever.
  Future<void> _loadArtwork() async {
    final artwork = ShareRecapCard.artworkOf(
      story: _story,
      format: _format,
      includeTitles: _includeTitles,
      artFor: _artFor,
    );
    await Future.wait<void>([
      for (final image in artwork)
        precacheImage(image, context, onError: (_, __) {}),
    ]).timeout(const Duration(seconds: 8), onTimeout: () => const []);
  }

  Future<void> _copyCaption() async {
    await Clipboard.setData(ClipboardData(text: _caption));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('ins_caption_copied'))),
    );
  }

  Future<void> _shareImage() async {
    setState(() => _sharing = true);
    try {
      await precacheImage(
        const AssetImage('assets/images/logo.png'),
        context,
      );
      await _loadArtwork();
      if (!mounted) return;
      // One frame for the images to swap in, one for it to reach the layer
      // the boundary captures.
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _recapKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('Recap preview is not ready');
      final image = await boundary.toImage(
        pixelRatio: _format.pixelRatioFor(boundary.size.width),
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw StateError('Could not render recap image');
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/flixquest-${_period.id}-${_format.name}-recap.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        <XFile>[XFile(file.path, mimeType: 'image/png')],
        subject: tr('ins_recap_subject',
            namedArgs: {'period': _recapPeriodLabel(_period)}),
        text: _caption,
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('ins_recap_failed')),
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontFamily: 'FigtreeSB',
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final story = _story;
    final isEmpty = story.insights.isEmpty;
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
        initialChildSize: .92,
        minChildSize: .65,
        maxChildSize: .96,
        builder: (context, scrollController) => Column(
          children: [
            Expanded(
              // Not a ListView: the preview has to stay built and painted to
              // be captured, however far the options below it are scrolled.
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('ins_share_story'),
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tr('ins_share_story_desc'),
                                style:
                                    TextStyle(color: colors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: tr('close'),
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(PhosphorIcons.x()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          // Small enough to keep the period and format choices
                          // on screen beneath it.
                          maxWidth:
                              _format == ShareRecapFormat.post ? 280 : 240,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: RepaintBoundary(
                            key: _recapKey,
                            child: AspectRatio(
                              aspectRatio: _format.aspectRatio,
                              child: ShareRecapCard(
                                story: story,
                                format: _format,
                                style: _style,
                                includeTitles: _includeTitles,
                                includeHabits: _includeHabits,
                                artFor: _artFor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (isEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        tr('ins_not_enough', namedArgs: {
                          'period': _recapPeriodLabel(_period).toLowerCase()
                        }),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                      ),
                    ],
                    _sectionLabel(tr('ins_recap_period')),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: periods.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final period = periods[index];
                          return ChoicePill(
                            spec: FilterChipSpec(
                              label: _recapPeriodLabel(period),
                              selected: period.id == _period.id,
                              onTap: () => setState(() => _period = period),
                            ),
                          );
                        },
                      ),
                    ),
                    _sectionLabel(tr('ins_format')),
                    Row(
                      children: [
                        for (final format in ShareRecapFormat.values) ...[
                          ChoicePill(
                            spec: FilterChipSpec(
                              label: format == ShareRecapFormat.post
                                  ? tr('ins_format_post')
                                  : tr('ins_format_story'),
                              selected: format == _format,
                              onTap: () => setState(() => _format = format),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                    _sectionLabel(tr('ins_themes')),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _RecapStyleChip(
                            label: tr('ins_theme_light'),
                            colors: const [
                              Color(0xFFFAF9FC),
                              Color(0xFFF57C00)
                            ],
                            selected: _style == ShareRecapStyle.light,
                            onTap: () =>
                                setState(() => _style = ShareRecapStyle.light),
                          ),
                          const SizedBox(width: 8),
                          _RecapStyleChip(
                            label: tr('ins_theme_dark'),
                            colors: const [
                              Color(0xFF181A1D),
                              Color(0xFFF57C00)
                            ],
                            selected: _style == ShareRecapStyle.dark,
                            onTap: () =>
                                setState(() => _style = ShareRecapStyle.dark),
                          ),
                          const SizedBox(width: 8),
                          _RecapStyleChip(
                            label: tr('ins_theme_lights_out'),
                            colors: const [
                              Color(0xFF000000),
                              Color(0xFFF57C00)
                            ],
                            selected: _style == ShareRecapStyle.lightsOut,
                            onTap: () => setState(
                                () => _style = ShareRecapStyle.lightsOut),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: _insightSurface(context),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile.adaptive(
                            value: _includeTitles,
                            onChanged: (value) =>
                                setState(() => _includeTitles = value),
                            secondary: Icon(PhosphorIcons.filmStrip()),
                            title: Text(tr('ins_include_top')),
                            subtitle: Text(tr('ins_include_top_desc')),
                          ),
                          SwitchListTile.adaptive(
                            value: _includeHabits,
                            onChanged: (value) =>
                                setState(() => _includeHabits = value),
                            secondary: Icon(PhosphorIcons.eye()),
                            title: Text(tr('ins_include_habits')),
                            subtitle: Text(tr('ins_include_habits_desc')),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Pinned, so sharing never means scrolling past every option.
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                10,
                20,
                MediaQuery.paddingOf(context).bottom + 14,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: PillButton(
                      height: 48,
                      onPressed: isEmpty ? null : _copyCaption,
                      icon: PhosphorIcons.copy(),
                      label: tr('ins_copy_caption'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PillButton(
                      primary: true,
                      height: 48,
                      busy: _sharing,
                      onPressed: isEmpty ? null : _shareImage,
                      icon: PhosphorIcons.shareNetwork(),
                      label:
                          _sharing ? tr('ins_creating') : tr('ins_share_image'),
                    ),
                  ),
                ],
              ),
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
                              tr('viewing_insights'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (recapReady)
                            Container(
                              padding: const EdgeInsetsDirectional.only(
                                start: 8,
                              ),
                              child: Text(
                                tr('ins_recap_ready').toUpperCase(),
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
                            ? tr('ins_recap_ready_revisit', namedArgs: {
                                'period': _recapPeriodLabel(featured)
                              })
                            : insights.isEmpty
                                ? tr('ins_start_here')
                                : tr('ins_this_week_summary', namedArgs: {
                                    'time': _duration(insights.totalWatchedMs),
                                    'n': '${insights.completedTitles}',
                                  }),
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
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('on_this_device')),
        const SizedBox(height: 14),
        _RangePicker(selected: provider.range, onSelected: provider.setRange),
      ]);
}

class _RangePicker extends StatelessWidget {
  const _RangePicker({required this.selected, required this.onSelected});

  final WellnessRange selected;
  final ValueChanged<WellnessRange> onSelected;

  @override
  Widget build(BuildContext context) {
    final labels = <WellnessRange, String>{
      WellnessRange.week: tr('ins_week'),
      WellnessRange.month: tr('ins_month'),
      WellnessRange.year: tr('ins_year'),
      WellnessRange.allTime: tr('ins_all_time'),
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

enum _InsightsSection { time, titles, taste, patterns, playback }

class _SectionNavigator extends StatelessWidget {
  const _SectionNavigator({required this.onSelected});

  final ValueChanged<_InsightsSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = <(_InsightsSection, IconData, String)>[
      (_InsightsSection.time, PhosphorIcons.clock(), tr('ins_time')),
      (_InsightsSection.titles, PhosphorIcons.filmSlate(), tr('ins_titles')),
      (_InsightsSection.taste, PhosphorIcons.palette(), tr('ins_taste')),
      (
        _InsightsSection.patterns,
        PhosphorIcons.calendarDots(),
        tr('ins_patterns')
      ),
      (_InsightsSection.playback, PhosphorIcons.devices(), tr('ins_playback')),
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
        ? tr('ins_across_days', namedArgs: {'n': '${insights.activeDays}'})
        : previous.totalWatchedMs == 0
            ? tr('ins_taking_shape')
            : difference >= 0
                ? tr('ins_more_than', namedArgs: {
                    'time': _duration(difference.abs()),
                    'range': _rangeName(range),
                  })
                : tr('ins_less_than', namedArgs: {
                    'time': _duration(difference.abs()),
                    'range': _rangeName(range),
                  });
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: translucentSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: foreground.withValues(alpha: .14)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(PhosphorIcons.sparkle(),
                              color: foreground, size: 15),
                          const SizedBox(width: 6),
                          Flexible(
                              child: Text(
                            tr('ins_your_story').toUpperCase(),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: foreground,
                                  letterSpacing: 1.05,
                                  fontWeight: FontWeight.w700,
                                ),
                          )),
                        ],
                      ),
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
                      tr('ins_playback_this',
                          namedArgs: {'range': _rangeName(range)}),
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
                              semanticsLabel: tr(
                                'ins_trail_semantics',
                                namedArgs: {'time': _duration(trail.last)},
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              tr('ins_last_14').toUpperCase(),
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
                      label: tr('ins_completed'),
                      foreground: foreground,
                      surface: translucentSurface,
                    ),
                    _HeroMetric(
                      value: '${insights.activeDays}',
                      label: tr('ins_active_days_label'),
                      foreground: foreground,
                      surface: translucentSurface,
                    ),
                    _HeroMetric(
                      value: '${insights.sessionCount}',
                      label: tr('ins_sessions'),
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
                      (ready ? tr('ins_recap_ready') : tr('ins_your_recaps'))
                          .toUpperCase(),
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
                      ? tr('ins_recap_is_ready',
                          namedArgs: {'period': _recapPeriodLabel(featured)})
                      : tr('ins_recap_shaping',
                          namedArgs: {'period': _recapPeriodLabel(featured)}),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 5),
                Text(
                  featuredInsights.isEmpty
                      ? tr('ins_next_session')
                      : tr('ins_shelf_summary', namedArgs: {
                          'time': _duration(featuredInsights.totalWatchedMs),
                          'completed': '${featuredInsights.completedTitles}',
                          'days': plural(
                              'ins_active_days', featuredInsights.activeDays),
                        }),
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
                  label: ready ? tr('ins_see_recap') : tr('ins_preview_recap'),
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
              Icon(PhosphorIcons.playCircle(),
                  size: 17, color: colors.onSurface),
              const SizedBox(width: 7),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _recapPeriodLabel(period),
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
      (
        PhosphorIcons.filmSlate(),
        '${insights.completedMovies}',
        tr('ins_stat_movies')
      ),
      (
        PhosphorIcons.television(),
        '${insights.completedEpisodes}',
        tr('ins_stat_episodes')
      ),
      (
        PhosphorIcons.stack(),
        '${insights.uniqueSeries}',
        tr('ins_stat_series')
      ),
      (
        PhosphorIcons.arrowCounterClockwise(),
        '${insights.rewatches}',
        tr('ins_stat_rewatches')
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 4 : 2;
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
      (tr('movies'), insights.movieMs, palette.categorical[0]),
      (tr('episodes'), insights.episodeMs, palette.categorical[1]),
      (tr('live_tv'), insights.liveMs, palette.categorical[2]),
    ];
    final total = entries.fold<int>(0, (sum, entry) => sum + entry.$2);
    final selected = _selected;
    final centerLabel =
        selected == null ? _duration(total) : _duration(entries[selected].$2);
    final centerCaption = selected == null
        ? tr('ins_total_playback')
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
                  tr('ins_playback_mix'),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text(
                tr('ins_tap_slice'),
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
                tr('ins_history'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Text(
              tr('ins_recent_count', namedArgs: {'n': '${sessions.length}'}),
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
                    label: switch (session.viewingStatus) {
                      'completed' => tr('ins_completed'),
                      'sampled' => tr('ins_sampled'),
                      _ => tr('ins_in_progress'),
                    },
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
          tooltip: tr('ins_remove_tooltip'),
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
    final remove = await showConfirmDialog(
      context,
      title: tr('ins_remove_q'),
      message: tr('ins_remove_body', namedArgs: {'title': session.title}),
      cancelLabel: tr('ins_keep'),
      confirmLabel: tr('remove'),
      destructive: true,
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
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: foreground,
              fontFamily: color == null ? 'Figtree' : 'FigtreeSB',
              fontSize: 11,
              fontWeight: color == null ? FontWeight.w500 : FontWeight.w600,
            ),
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
          tr('ins_obs_streak', namedArgs: {
            'n': '$streak',
            'longest': '${insights.longestStreakDays}',
          }),
        ),
      if (peak != null)
        (
          PhosphorIcons.clock(),
          tr('ins_obs_window', namedArgs: {
            'day': _weekdayName(peak.$1),
            'hours': _hourRange(peak.$2),
            'time': _duration(peak.$3),
          }),
        ),
      if (busiest != null)
        (
          PhosphorIcons.calendarStar(),
          tr('ins_obs_heaviest', namedArgs: {
            'date': DateFormat.MMMEd().format(busiest.$1),
            'time': _duration(busiest.$2),
          }),
        ),
      if (insights.averageSessionMs > 0)
        (
          PhosphorIcons.hourglass(),
          tr('ins_obs_typical', namedArgs: {
            'session': _duration(insights.averageSessionMs),
            'day': _duration(insights.medianActiveDayMs),
          }),
        ),
      if (insights.hasNetworkUsage && insights.networkBytes > 0)
        (
          PhosphorIcons.cellSignalHigh(),
          tr('ins_obs_data', namedArgs: {
            'size': _dataSize(insights.networkBytes),
            'rate': _dataSize(insights.networkBytesPerHour),
          }),
        ),
      if (total > 0 && insights.lateNightMs > 0)
        (
          PhosphorIcons.moon(),
          tr('ins_obs_late',
              namedArgs: {'share': _share(insights.lateNightMs, total)}),
        ),
      if (insights.titlesStarted > 0)
        (
          PhosphorIcons.checkCircle(),
          tr('ins_obs_finish', namedArgs: {
            'share': _percent(insights.completionRate),
            'done': '${insights.completedTitles}',
            'started': '${insights.titlesStarted}',
          }),
        ),
      if (insights.longestSessionMs > 0)
        (
          PhosphorIcons.filmSlate(),
          tr('ins_obs_longest',
              namedArgs: {'time': _duration(insights.longestSessionMs)}),
        ),
      if (insights.topTitles.isNotEmpty)
        (
          PhosphorIcons.crown(),
          tr('ins_obs_top',
              namedArgs: {'title': insights.topTitles.first.label}),
        ),
    ];
    if (observations.isEmpty) {
      return _Panel(
        child: Text(
          tr('ins_obs_empty'),
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
          Text(tr('ins_stands_out'), style: theme.textTheme.titleMedium),
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
                    Text(tr('ins_watch_time'),
                        style: theme.textTheme.titleMedium),
                    Text(
                      tr('ins_by_unit', namedArgs: {
                        'unit': _unitName(series.unitLabel),
                        'range': _rangeName(widget.range),
                      }),
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
            semanticsLabel: tr('ins_timeline_semantics', namedArgs: {
              'unit': _unitName(series.unitLabel),
              'time': _duration(series.totalMs),
              'n': '${series.activeBuckets}',
              'units': _unitNames(series.unitLabel),
            }),
          ),
          const SizedBox(height: 14),
          if (selected == null)
            _TimelineSummary(series: series, busiest: busiest)
          else
            _BucketCallout(
              bucket: series.buckets[selected],
              periodTotalMs: series.totalMs,
              sessions: widget.insights.sessions,
              unitLabel: _unitName(series.unitLabel),
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
              label: Text(
                  _showTable ? tr('ins_hide_values') : tr('ins_all_values')),
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
      return Text(tr('ins_nothing_range'), style: style);
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
            tr('ins_timeline_summary', namedArgs: {
              'unit': _unitName(series.unitLabel),
              'label': peak.fullLabel,
              'time': _duration(peak.totalMs),
              'average': _duration(series.averageMs.round()),
              'n': '${series.activeBuckets}',
              'units': _unitNames(series.unitLabel),
            }),
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
                            ? tr('ins_no_viewing')
                            : _duration(bucket.totalMs),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (!bucket.isEmpty)
                        Text(
                          tr('ins_bucket_share', namedArgs: {
                            'share': _share(bucket.totalMs, periodTotalMs),
                            'sessions':
                                plural('ins_session_count', inside.length),
                          }),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: tr('ins_clear_selection'),
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
                    label: tr('movies'),
                    value: split.movieMs,
                    color: palette.categorical[0],
                  ),
                  WellnessSplitPart(
                    label: tr('episodes'),
                    value: split.episodeMs,
                    color: palette.categorical[1],
                  ),
                  WellnessSplitPart(
                    label: tr('live_tv'),
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
                    tr('ins_more_this', namedArgs: {
                      'n': '${inside.length - 3}',
                      'unit': unitLabel,
                    }),
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
                tr('ins_col_time').toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 46,
                child: Text(
                  tr('ins_col_share').toUpperCase(),
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
                    Text(tr('ins_consistency'),
                        style: theme.textTheme.titleMedium),
                    Text(
                      current == 0
                          ? tr('ins_no_streak')
                          : plural('ins_streak_row', current),
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
                    tr('ins_longest_streak'),
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
            semanticsLabel:
                tr('ins_daily_semantics', namedArgs: {'n': '$recentActive'}),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  tr('ins_last_14_active', namedArgs: {'n': '$recentActive'}),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                tr('ins_peak_day', namedArgs: {
                  'time': _duration(recent.fold<int>(0, math.max)),
                }),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          WellnessMeter(
            label: tr('ins_days_with_viewing'),
            valueLabel: _percent(insights.activeDayShare),
            ratio: insights.activeDayShare,
            // periodDays stops at the last recorded day, so "tracked so far"
            // is what the share actually measures.
            caption: tr('ins_days_caption', namedArgs: {
              'active': '${insights.activeDays}',
              'total': '${insights.periodDays}',
              'time': _duration(insights.medianActiveDayMs),
            }),
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
                    Text(tr('ins_weekly_rhythm'),
                        style: theme.textTheme.titleMedium),
                    Text(
                      tr('ins_rhythm_desc'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                tr('ins_tap_cell'),
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
              tr('ins_cell_selected', namedArgs: {
                'day': _weekdayName(selected.$1),
                'hours': _hourRange(selected.$2),
                'value': selectedMs == 0
                    ? tr('ins_nothing_watched')
                    : _duration(selectedMs),
              }),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            )
          else if (peak != null)
            Text(
              tr('ins_steadiest', namedArgs: {
                'day': _weekdayName(peak.$1),
                'hours': _hourRange(peak.$2),
                'time': _duration(peak.$3),
              }),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Text(
              tr('ins_rhythm_empty'),
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

  static const _windows = ['5a–12p', '12–5p', '5–10p', '10p–5a'];

  List<String> get _labels => [
        tr('ins_morning'),
        tr('ins_afternoon'),
        tr('ins_evening'),
        tr('ins_late_night'),
      ];

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
          Text(tr('ins_day_split'), style: theme.textTheme.titleMedium),
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
                ? tr('ins_dayparts_hint')
                : tr('ins_daypart_selected', namedArgs: {
                    'part': _labels[selected],
                    'window': _windows[selected],
                    'time': _duration(parts[selected]),
                    'share': _share(parts[selected], total),
                  }),
            style: theme.textTheme.bodySmall?.copyWith(
              color: selected == null
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onSurface,
              fontWeight: selected == null ? null : FontWeight.w700,
            ),
          ),
          const Divider(height: 30),
          Text(
            tr('ins_weekdays_weekend'),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          WellnessSplitMeter(
            parts: [
              WellnessSplitPart(
                label: tr('ins_mon_fri'),
                value: weekday,
                color: palette.categorical[0],
              ),
              WellnessSplitPart(
                label: tr('ins_sat_sun'),
                value: weekend,
                color: palette.categorical[1],
              ),
            ],
            valueLabel: _duration,
            surfaceColor: surface,
          ),
          const SizedBox(height: 14),
          WellnessMeter(
            label: tr('ins_after_10'),
            valueLabel: _percent(
              total == 0 ? 0 : widget.insights.lateNightMs / total,
            ),
            ratio: total == 0 ? 0 : widget.insights.lateNightMs / total,
            caption: tr('ins_late_caption', namedArgs: {
              'time': _duration(widget.insights.lateNightMs),
            }),
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
      ('${insights.titlesStarted}', tr('ins_started')),
      ('${insights.completedTitles}', tr('ins_finished')),
      ('${insights.sampledTitles}', tr('ins_sampled')),
      ('${insights.rewatches}', tr('ins_rewatched')),
    ];
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('ins_follow_through'), style: theme.textTheme.titleMedium),
          const SizedBox(height: 14),
          WellnessMeter(
            label: tr('ins_titles_finished'),
            valueLabel: _percent(insights.completionRate),
            ratio: insights.completionRate,
            caption: tr('ins_completion_caption', namedArgs: {
              'done': '${insights.completedTitles}',
              'started': '${insights.titlesStarted}',
              'time': _duration(insights.averageSessionMs),
            }),
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
              tr('ins_sampled_note'),
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

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.canSync});

  final bool canSync;

  @override
  Widget build(BuildContext context) {
    // A quiet note in the page's own tones; Material's tonal containers
    // would tint it with the accent.
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: _insightSurface(context),
        borderRadius: BorderRadius.circular(AppRadii.hero),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: palette.idleFill,
              shape: BoxShape.circle,
            ),
            child: Icon(
              PhosphorIcons.lockKey(),
              size: 17,
              color: palette.foreground,
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('ins_private'),
                  style: AppType.cardTitle.copyWith(color: palette.foreground),
                ),
                const SizedBox(height: 3),
                Text(
                  canSync ? tr('ins_private_synced') : tr('ins_private_local'),
                  style: AppType.metadata.copyWith(
                    fontSize: 13,
                    height: 1.4,
                    color: palette.mutedText,
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
          Text(hasHistory ? tr('ins_empty_period') : tr('ins_empty_start'),
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            hasHistory
                ? tr('ins_empty_period_desc')
                : tr('ins_empty_start_desc'),
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
            children: [
              _EmptyFeature(
                  icon: Icons.schedule_rounded, label: tr('ins_time')),
              _EmptyFeature(
                  icon: Icons.movie_outlined, label: tr('ins_titles')),
              _EmptyFeature(
                  icon: Icons.palette_outlined, label: tr('ins_taste')),
              _EmptyFeature(
                  icon: Icons.grid_view_rounded, label: tr('ins_patterns')),
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

String _duration(int milliseconds) => formatWatchedTime(milliseconds);

String _share(int value, int total) =>
    total <= 0 ? '0%' : '${(value / total * 100).round()}%';

String _percent(double ratio) => '${(ratio.clamp(0.0, 1.0) * 100).round()}%';

String _episodeCount(int value) => plural('ins_episode_count', value);

String _dataSize(int bytes) {
  const units = <String>['KB', 'MB', 'GB', 'TB'];
  if (bytes < 1024) return '$bytes B';
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value < 10 ? 1 : 0)} ${units[unit]}';
}

String _weekdayName(int mondayFirstIndex) =>
    DateFormat.EEEE().format(DateTime(2024, 1, 1 + mondayFirstIndex));

/// "9 PM" reads as an instant; the cell is an hour, so name the hour.
String _hourRange(int hour) {
  final start = DateFormat.j().format(DateTime(2024, 1, 1, hour));
  final end = DateFormat.j().format(DateTime(2024, 1, 1, (hour + 1) % 24));
  return '$start–$end';
}

String _trackingSince(List<WellnessViewingSession> sessions) {
  if (sessions.isEmpty) return tr('ins_tracking_begins');
  final oldest = sessions.reduce(
    (current, session) =>
        session.startedAtUtc.isBefore(current.startedAtUtc) ? session : current,
  );
  final local =
      oldest.startedAtUtc.add(Duration(minutes: oldest.timezoneOffsetMinutes));
  return tr('ins_tracking_since',
      namedArgs: {'date': DateFormat.yMMMd().format(local)});
}

String _unitName(String unit) => switch (unit) {
      'day' => tr('ins_unit_day'),
      'week' => tr('ins_unit_week'),
      'month' => tr('ins_unit_month'),
      'year' => tr('ins_unit_year'),
      _ => tr('ins_unit_block'),
    };

String _unitNames(String unit) => switch (unit) {
      'day' => tr('ins_unit_days'),
      'week' => tr('ins_unit_weeks'),
      'month' => tr('ins_unit_months'),
      'year' => tr('ins_unit_years'),
      _ => tr('ins_unit_blocks'),
    };

String _recapPeriodLabel(WellnessRecapPeriod period) => switch (period.kind) {
      WellnessRecapPeriodKind.day => tr('today'),
      WellnessRecapPeriodKind.week => tr('this_week'),
      WellnessRecapPeriodKind.month ||
      WellnessRecapPeriodKind.year =>
        period.label,
    };

String _recapCaptionLabel(WellnessRecapPeriod period) => switch (period.kind) {
      WellnessRecapPeriodKind.day => tr('ins_caption_today'),
      WellnessRecapPeriodKind.week => tr('ins_caption_week'),
      WellnessRecapPeriodKind.month ||
      WellnessRecapPeriodKind.year =>
        tr('ins_caption_named', namedArgs: {'period': period.label}),
    };

String _rangeName(WellnessRange range) => switch (range) {
      WellnessRange.week => tr('ins_range_week'),
      WellnessRange.month => tr('ins_range_month'),
      WellnessRange.year => tr('ins_range_year'),
      WellnessRange.allTime => tr('ins_range_all'),
    };

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
