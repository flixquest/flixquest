import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:flutter/material.dart';

import '../constants/loading_colors.dart';
import '../design/skeleton.dart';

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
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: .5),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: .8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    index.toString().padLeft(2, '0'),
                    style: TextStyle(
                      color: colors.onSurface,
                      fontFamily: 'FigtreeSB',
                      fontSize: 14,
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
                      style: TextStyle(
                        color: colors.onSurface,
                        fontFamily: 'FigtreeSB',
                        fontSize: 15,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12.5,
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
                    : colors.onSurface,
              ),
            ],
          ),
        ),
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

class AppMediaGridShimmer extends StatelessWidget {
  const AppMediaGridShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final loadingColors = AppLoadingColors.of(context);
    final base = loadingColors.shimmerBase;
    return SkeletonTint(
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

/// A self-contained pulsing placeholder that can fill any constrained space.
class AppShimmerBlock extends StatelessWidget {
  const AppShimmerBlock({this.radius = AppUI.cardRadius, super.key});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return SkeletonTint(
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
