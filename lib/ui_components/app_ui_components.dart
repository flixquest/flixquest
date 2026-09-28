
import 'package:flutter/material.dart';

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
