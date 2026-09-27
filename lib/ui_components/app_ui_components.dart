import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../constants/loading_colors.dart';

/// Shared responsive and visual primitives for the refreshed FlixQuest UI.
abstract final class AppUI {
  static const double phonePadding = 20;
  static const double tabletPadding = 28;
  static const double contentMaxWidth = 1180;
  // The same restrained corners are used by posters and their placeholders.
  static const double cardRadius = 5;
  static const double mediaGridCrossAxisSpacing = 12;
  static const double mediaGridTitleGap = 9;
  static const double mediaGridTitleHeight = 36;
  static const double posterAspectRatio = 2 / 3;

  static double pagePadding(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= 700
        ? tabletPadding
        : phonePadding;
  }

  static int mediaGridColumns(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1200) return 6;
    if (width >= 900) return 5;
    if (width >= 650) return 4;
    return 3;
  }

  /// Sizes a grid tile around a true 2:3 poster plus its title area.
  static double mediaGridChildAspectRatio(BuildContext context) {
    final columns = mediaGridColumns(context);
    final gridWidth = MediaQuery.sizeOf(context).width -
        (pagePadding(context) * 2) -
        (mediaGridCrossAxisSpacing * (columns - 1));
    final itemWidth = gridWidth / columns;
    final itemHeight = (itemWidth / posterAspectRatio) +
        mediaGridTitleGap +
        mediaGridTitleHeight;
    return itemWidth / itemHeight;
  }

  static double horizontalCardWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 900) return 118;
    if (width >= 650) return 108;
    return ((width - (pagePadding(context) * 2) - 30) / 4).clamp(72.0, 100.0);
  }
}

/// The shared tonal transition between detail-page artwork and its content.
///
/// Keep the stops here so movie, TV, season, and episode pages always blend in
/// exactly the same way. The small intermediate steps avoid a visible dark
/// band while retaining enough contrast for artwork and carousel indicators.
class AppDetailHeroGradient extends StatelessWidget {
  const AppDetailHeroGradient({super.key});

  static const List<double> stops = <double>[0, .38, .67, .84, 1];
  static const List<Color> colors = <Color>[
    Color(0x30000000),
    Color(0x08000000),
    Color(0x12000000),
    Color(0x68000000),
    Color(0xD9000000),
  ];

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: stops,
            colors: colors,
          ),
        ),
      ),
    );
  }
}

/// A user-draggable, auto-advancing media pager for detail-page artwork.
class AppSwipeCarousel extends StatefulWidget {
  const AppSwipeCarousel({
    required this.itemCount,
    required this.itemBuilder,
    this.interval = const Duration(seconds: 6),
    this.indicatorBottom = 16,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Duration interval;
  final double indicatorBottom;

  @override
  State<AppSwipeCarousel> createState() => _AppSwipeCarouselState();
}

class _AppSwipeCarouselState extends State<AppSwipeCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant AppSwipeCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.itemCount) _index = 0;
    if (oldWidget.itemCount != widget.itemCount ||
        oldWidget.interval != widget.interval) {
      _restartTimer();
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    if (widget.itemCount <= 1) return;
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.animateToPage(
        (_index + 1) % widget.itemCount,
        duration: const Duration(milliseconds: 620),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount <= 0) return const SizedBox.shrink();
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.itemCount,
          pageSnapping: true,
          allowImplicitScrolling: true,
          physics: const PageScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          onPageChanged: (index) {
            setState(() => _index = index);
            _restartTimer();
          },
          itemBuilder: widget.itemBuilder,
        ),
        if (widget.itemCount > 1)
          PositionedDirectional(
            end: 16,
            bottom: widget.indicatorBottom,
            child: IgnorePointer(
              child: Row(
                children: List.generate(
                  widget.itemCount,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: index == _index ? 18 : 5,
                    height: 5,
                    margin: const EdgeInsetsDirectional.only(start: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: index == _index ? .95 : .45,
                      ),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }
}

/// One entry in an [AppSegmentedTabs] control.
class AppSegmentedTab {
  const AppSegmentedTab({required this.label, this.icon});

  final String label;
  final IconData? icon;
}

/// The segmented control used wherever a screen splits its body
/// into a small, fixed set of tabs (bookmarks, cast & crew, …).
class AppSegmentedTabs extends StatelessWidget {
  const AppSegmentedTabs({
    required this.controller,
    required this.tabs,
    super.key,
  });

  final TabController controller;
  final List<AppSegmentedTab> tabs;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: colors.onPrimary,
        unselectedLabelColor: colors.onSurfaceVariant,
        labelStyle: const TextStyle(
            fontFamily: 'FigtreeSB', fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: const TextStyle(
            fontFamily: 'FigtreeSB', fontWeight: FontWeight.w500, fontSize: 13),
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        tabs: [
          for (final tab in tabs)
            Tab(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (tab.icon != null) ...[
                    Icon(tab.icon, size: 17),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      tab.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

/// A person row — cast, crew, guest star — rendered as a tappable card.
class AppPersonTile extends StatelessWidget {
  const AppPersonTile({
    required this.avatar,
    required this.name,
    required this.onTap,
    this.subtitle,
    this.detail,
    super.key,
  });

  final Widget avatar;
  final String name;
  final VoidCallback onTap;
  final String? subtitle;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 62,
                child: ClipOval(child: avatar),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                      ),
                    ],
                    if (detail != null && detail!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        detail!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant
                                  .withValues(alpha: .85),
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                PhosphorIcons.caretRight(),
                size: 16,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loading state for a list of [AppPersonTile]s.
class AppPersonListShimmer extends StatelessWidget {
  const AppPersonListShimmer({this.itemCount = 8, super.key});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        AppUI.pagePadding(context),
        12,
        AppUI.pagePadding(context),
        24,
      ),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const SizedBox.square(
                dimension: 62,
                child: AppShimmerBlock(radius: 31),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      height: 15,
                      width: 160,
                      child: AppShimmerBlock(radius: 6),
                    ),
                    const SizedBox(height: 9),
                    const SizedBox(
                      height: 12,
                      width: 100,
                      child: AppShimmerBlock(radius: 6),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppResponsiveContent extends StatelessWidget {
  const AppResponsiveContent({
    required this.child,
    this.padding,
    this.maxWidth = AppUI.contentMaxWidth,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ??
              EdgeInsets.symmetric(horizontal: AppUI.pagePadding(context)),
          child: child,
        ),
      ),
    );
  }
}

/// A responsive, card-based row for single-choice settings and utilities.
class AppSelectionTile extends StatelessWidget {
  const AppSelectionTile({
    required this.title,
    required this.selected,
    required this.onTap,
    this.leading,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: selected
          ? colors.primaryContainer.withValues(alpha: .55)
          : colors.surfaceContainerHighest.withValues(alpha: .45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(
          color: selected
              ? colors.primary.withValues(alpha: .7)
              : colors.outline.withValues(alpha: .16),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              if (leading != null) ...[
                SizedBox.square(dimension: 36, child: Center(child: leading)),
                const SizedBox(width: 13),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontFamily: 'FigtreeSB',
                          ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              trailing ??
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 25,
                    height: 25,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? colors.primary : Colors.transparent,
                      border: Border.all(
                        color: selected ? colors.primary : colors.outline,
                        width: 1.5,
                      ),
                    ),
                    child: selected
                        ? Icon(
                            PhosphorIcons.check(),
                            size: 15,
                            color: colors.onPrimary,
                          )
                        : null,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A subtle bottom progress treatment used by paginated media screens.
class AppLoadingFooter extends StatelessWidget {
  const AppLoadingFooter({required this.visible, super.key});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      child: visible
          ? SafeArea(
              top: false,
              minimum: EdgeInsets.fromLTRB(
                AppUI.pagePadding(context),
                6,
                AppUI.pagePadding(context),
                10,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: const LinearProgressIndicator(minHeight: 4),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

/// A numbered source card used by legacy/manual stream-selection surfaces.
class AppStreamSourceTile extends StatelessWidget {
  const AppStreamSourceTile({
    required this.index,
    required this.title,
    this.subtitle,
    this.onTap,
    super.key,
  });

  final int index;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(color: colors.outline.withValues(alpha: .14)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    index.toString().padLeft(2, '0'),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.primary,
                          fontFamily: 'FigtreeSB',
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontFamily: 'FigtreeSB',
                          ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                PhosphorIcons.playCircle(),
                color: onTap == null
                    ? colors.onSurfaceVariant.withValues(alpha: .45)
                    : colors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppFormSurface extends StatelessWidget {
  const AppFormSurface({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
    this.danger = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = danger ? colors.error : colors.primary;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: AppResponsiveContent(
        maxWidth: 560,
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 32, color: accent),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.45,
                    ),
              ),
            ],
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppFilterPill extends StatelessWidget {
  const AppFilterPill({
    required this.label,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? colors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.primary, width: 1.4),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Text(
            label,
            maxLines: 1,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? colors.onPrimary : colors.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

class AppFilterRail extends StatelessWidget {
  const AppFilterRail({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class AppRatingBadge extends StatelessWidget {
  const AppRatingBadge({required this.rating, this.compact = false, super.key});

  final num? rating;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final value = rating == null
        ? '—'
        : rating! % 1 == 0
            ? rating!.toInt().toString()
            : rating!.toStringAsFixed(1);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 9,
          vertical: compact ? 4 : 5,
        ),
        child: Text(
          value,
          style: TextStyle(
            color: colors.onPrimary,
            fontFamily: 'FigtreeSB',
            fontSize: compact ? 11 : 12,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class AppHeroShimmer extends StatelessWidget {
  const AppHeroShimmer({required this.height, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    final loadingColors = AppLoadingColors.of(context);
    final base = loadingColors.shimmerBase;
    final highlight = loadingColors.shimmerHighlight;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: base),
          Positioned(
            left: AppUI.phonePadding,
            right: AppUI.phonePadding,
            bottom: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBlock(width: 210, height: 30, color: base),
                const SizedBox(height: 10),
                _ShimmerBlock(width: 150, height: 14, color: base),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _ShimmerBlock(width: 112, height: 44, color: base),
                    const SizedBox(width: 12),
                    _ShimmerBlock(width: 112, height: 44, color: base),
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

class AppMediaRowShimmer extends StatelessWidget {
  const AppMediaRowShimmer({this.itemWidth, super.key});

  final double? itemWidth;

  @override
  Widget build(BuildContext context) {
    final loadingColors = AppLoadingColors.of(context);
    final base = loadingColors.shimmerBase;
    final highlight = loadingColors.shimmerHighlight;
    final cardWidth = itemWidth ?? AppUI.horizontalCardWidth(context);
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppUI.pagePadding(context)),
        itemCount: 8,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, __) => SizedBox(
          width: cardWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AspectRatio(
                aspectRatio: 2 / 3,
                child: _ShimmerBlock(
                  width: cardWidth,
                  height: double.infinity,
                  color: base,
                  radius: AppUI.cardRadius,
                ),
              ),
              const SizedBox(height: 10),
              _ShimmerBlock(width: cardWidth * .82, height: 13, color: base),
              const SizedBox(height: 6),
              _ShimmerBlock(width: cardWidth * .55, height: 11, color: base),
            ],
          ),
        ),
      ),
    );
  }
}

class AppMediaGridShimmer extends StatelessWidget {
  const AppMediaGridShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final loadingColors = AppLoadingColors.of(context);
    final base = loadingColors.shimmerBase;
    final highlight = loadingColors.shimmerHighlight;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: GridView.builder(
        padding: EdgeInsets.fromLTRB(
            AppUI.pagePadding(context), 12, AppUI.pagePadding(context), 24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: AppUI.mediaGridColumns(context),
          childAspectRatio: AppUI.mediaGridChildAspectRatio(context),
          crossAxisSpacing: AppUI.mediaGridCrossAxisSpacing,
          mainAxisSpacing: 16,
        ),
        itemCount: AppUI.mediaGridColumns(context) * 4,
        itemBuilder: (_, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AspectRatio(
              aspectRatio: AppUI.posterAspectRatio,
              child: _ShimmerBlock(
                width: double.infinity,
                height: double.infinity,
                color: base,
                radius: AppUI.cardRadius,
              ),
            ),
            const SizedBox(height: AppUI.mediaGridTitleGap),
            SizedBox(
              height: AppUI.mediaGridTitleHeight,
              child: Column(
                children: [
                  FractionallySizedBox(
                    widthFactor: .84,
                    child: _ShimmerBlock(
                      width: double.infinity,
                      height: 13,
                      color: base,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _ShimmerBlock(width: 54, height: 11, color: base),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppMediaListCard extends StatelessWidget {
  const AppMediaListCard({
    required this.poster,
    required this.title,
    required this.onTap,
    this.date,
    this.language,
    this.overview,
    this.rating,
    this.voteCount,
    super.key,
  });

  final Widget poster;
  final String title;
  final VoidCallback onTap;
  final String? date;
  final String? language;
  final String? overview;
  final num? rating;
  final int? voteCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final posterWidth = wide ? 112.0 : 96.0;
    final posterHeight = posterWidth * 1.5;
    final year =
        date != null && date!.length >= 4 ? date!.substring(0, 4) : null;
    final summary = overview?.trim() ?? '';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: SizedBox(
            height: posterHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                    width: posterWidth, height: posterHeight, child: poster),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    height: 1.15,
                                  ),
                        ),
                        if (year != null ||
                            (language?.isNotEmpty ?? false)) ...[
                          const SizedBox(height: 7),
                          Wrap(
                            spacing: 7,
                            runSpacing: 5,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (year != null)
                                Text(year,
                                    style: TextStyle(
                                        color: colors.onSurfaceVariant)),
                              if (year != null &&
                                  (language?.isNotEmpty ?? false))
                                Text('•',
                                    style: TextStyle(color: colors.outline)),
                              if (language?.isNotEmpty ?? false)
                                Text(
                                  language!.toUpperCase(),
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .5,
                                  ),
                                ),
                            ],
                          ),
                        ],
                        if (summary.isNotEmpty) ...[
                          const SizedBox(height: 9),
                          Expanded(
                            child: Text(
                              summary,
                              maxLines: wide ? 4 : 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                            ),
                          ),
                        ] else
                          const Spacer(),
                        Row(
                          children: [
                            AppRatingBadge(rating: rating, compact: true),
                            if (voteCount != null) ...[
                              const SizedBox(width: 10),
                              Icon(PhosphorIcons.users(),
                                  size: 15, color: colors.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(
                                _compactCount(voteCount!),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                              ),
                            ],
                            const Spacer(),
                            Icon(PhosphorIcons.caretRight(),
                                color: colors.onSurfaceVariant),
                          ],
                        ),
                      ],
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

  String _compactCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
    }
    return value.toString();
  }
}

class AppMediaListShimmer extends StatelessWidget {
  const AppMediaListShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final loadingColors = AppLoadingColors.of(context);
    final base = loadingColors.shimmerBase;
    final highlight = loadingColors.shimmerHighlight;
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final posterWidth = wide ? 112.0 : 96.0;
    final posterHeight = posterWidth * 1.5;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(
          AppUI.pagePadding(context),
          12,
          AppUI.pagePadding(context),
          24,
        ),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox(
              height: posterHeight,
              child: Row(
                children: [
                  _ShimmerBlock(
                      width: posterWidth,
                      height: posterHeight,
                      color: base,
                      radius: 12),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        _ShimmerBlock(width: 190, height: 17, color: base),
                        const SizedBox(height: 9),
                        _ShimmerBlock(width: 88, height: 11, color: base),
                        const SizedBox(height: 13),
                        _ShimmerBlock(
                            width: double.infinity, height: 10, color: base),
                        const SizedBox(height: 7),
                        _ShimmerBlock(
                            width: double.infinity, height: 10, color: base),
                        const SizedBox(height: 7),
                        _ShimmerBlock(width: 140, height: 10, color: base),
                        const Spacer(),
                        _ShimmerBlock(
                            width: 54, height: 24, color: base, radius: 7),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.title,
    required this.message,
    this.icon,
    this.action,
    super.key,
  });

  final String title;
  final String message;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final effectiveIcon = icon ?? PhosphorIcons.filmStrip();
    return AppResponsiveContent(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .09),
                  shape: BoxShape.circle,
                ),
                child: Icon(effectiveIcon, size: 52, color: colors.primary),
              ),
              const SizedBox(height: 28),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colors.primary,
                      fontFamily: 'FigtreeSB',
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.45,
                    ),
              ),
              if (action != null) ...[const SizedBox(height: 22), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class AppInfoPill extends StatelessWidget {
  const AppInfoPill({
    required this.icon,
    required this.value,
    required this.label,
    super.key,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colors.primary),
          const SizedBox(width: 7),
          Text(value, style: const TextStyle(fontFamily: 'FigtreeSB')),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: colors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// A self-contained shimmer placeholder that can fill any constrained space.
class AppShimmerBlock extends StatelessWidget {
  const AppShimmerBlock({this.radius = AppUI.cardRadius, super.key});

  final double radius;

  @override
  Widget build(BuildContext context) {
    final loadingColors = AppLoadingColors.of(context);
    return Shimmer.fromColors(
      baseColor: loadingColors.shimmerBase,
      highlightColor: loadingColors.shimmerHighlight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// A neutral placeholder for cached network images that do not need shimmer.
class AppCachedImagePlaceholder extends StatelessWidget {
  const AppCachedImagePlaceholder({this.child, super.key});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppLoadingColors.of(context).cachedImagePlaceholder,
      child: child,
    );
  }
}

class _ShimmerBlock extends StatelessWidget {
  const _ShimmerBlock({
    required this.width,
    required this.height,
    required this.color,
    this.radius = 8,
  });

  final double width;
  final double height;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
