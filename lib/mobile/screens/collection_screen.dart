import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../catalog/catalog_controller.dart';
import '../../catalog/media_item.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../provider/app_dependency_provider.dart';
import '../../video_providers/scraper_api.dart';
import '../../widgets/hosted_ads_banner.dart';
import '../widgets/filter_chips.dart';
import '../widgets/pill_button.dart';
import '../widgets/poster_card.dart';
import '../widgets/media_rows.dart';

/// A genre's or a service's titles in a grid, a page at a time as the viewer
/// scrolls.
///
/// Given a movie and a series collection, it shows one at a time under a
/// Movies | Series switch, so the two kinds never share a grid; each keeps
/// its own place.
class CollectionScreen extends StatefulWidget {
  CollectionScreen({required MediaCollection collection, super.key})
      : tabs = <(String, MediaCollection)>[('', collection)];

  /// One collection per kind, each under its label.
  const CollectionScreen.tabbed({required this.tabs, super.key})
      : assert(tabs.length > 0);

  final List<(String, MediaCollection)> tabs;

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  int _tab = 0;
  final Set<int> _opened = <int>{0};

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final first = widget.tabs.first.$2;
    final logo = first.logoAsset;
    final tabbed = widget.tabs.length > 1;
    return Scaffold(
      backgroundColor: palette.page,
      appBar: AppBar(
        backgroundColor: palette.page,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              first.kicker,
              style: AppType.kicker.copyWith(color: palette.mutedText),
            ),
            Text(
              first.title,
              style: AppType.sectionHeader.copyWith(
                fontFamily: AppType.bold,
                color: palette.foreground,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          if (logo != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 16),
              child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppPalette.logoPlate,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Image.asset(logo, fit: BoxFit.contain),
              ),
            ),
        ],
        bottom: !tabbed
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(FilterChips.height + 12),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FilterChips(
                    chips: <FilterChipSpec>[
                      for (var i = 0; i < widget.tabs.length; i++)
                        FilterChipSpec(
                          label: widget.tabs[i].$1,
                          selected: i == _tab,
                          onTap: () => setState(() {
                            _tab = i;
                            _opened.add(i);
                          }),
                        ),
                    ],
                  ),
                ),
              ),
      ),
      body: IndexedStack(
        index: _tab,
        children: <Widget>[
          for (var i = 0; i < widget.tabs.length; i++)
            _opened.contains(i)
                ? _CollectionGrid(
                    key: ValueKey<String>(widget.tabs[i].$2.id),
                    collection: widget.tabs[i].$2,
                    gutter: gutter,
                  )
                : const SizedBox.shrink(),
        ],
      ),
    );
  }
}

/// One collection's grid, paging in as it scrolls.
class _CollectionGrid extends StatefulWidget {
  const _CollectionGrid({
    required this.collection,
    required this.gutter,
    super.key,
  });

  final MediaCollection collection;
  final double gutter;

  @override
  State<_CollectionGrid> createState() => _CollectionGridState();
}

class _CollectionGridState extends State<_CollectionGrid> {
  final List<MediaItem> _items = <MediaItem>[];
  final Set<String> _seen = <String>{};
  int _nextPage = 1;
  bool _loading = false;
  bool _ended = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _ended) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final page = await widget.collection.loadPage(_nextPage);
      if (!mounted) return;
      setState(() {
        _nextPage++;
        if (page.isEmpty) _ended = true;
        _items.addAll(page.where((item) => _seen.add(item.stableId)));
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.extentAfter < 800) _loadMore();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = widget.gutter;
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= AppBreakpoints.wide
        ? 6
        : width >= AppBreakpoints.tablet
            ? 5
            : 3;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: CustomScrollView(
        slivers: <Widget>[
          if (widget.collection.adPlacement case final placement?)
            SliverToBoxAdapter(
              child: RemoteHostedAdsBanner(
                placement: placement,
                loadAds: () => ScraperApi(
                  context.read<AppDependencyProvider>().flixquestAPIURL,
                ).getAds(),
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(gutter, AppSpace.sm, gutter, 0),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: PosterCard.aspectRatio,
              ),
              itemCount: _items.length,
              itemBuilder: (context, index) => LayoutBuilder(
                builder: (context, constraints) => PosterCard(
                  item: _items[index],
                  width: constraints.maxWidth,
                  badge: recencyBadge(_items[index]),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                gutter,
                AppSpace.xxl,
                gutter,
                AppSpace.xxl + MediaQuery.paddingOf(context).bottom,
              ),
              child: Center(
                child: _failed
                    ? PillButton(label: tr('retry'), onPressed: _loadMore)
                    : _loading
                        ? SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: palette.mutedText,
                            ),
                          )
                        : _items.isEmpty
                            ? Text(
                                tr('nothing_here_yet'),
                                style: AppType.body.copyWith(
                                  color: palette.mutedText,
                                ),
                              )
                            : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
