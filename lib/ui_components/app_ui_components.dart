import 'package:flutter/material.dart';

import '../constants/loading_colors.dart';

/// Shared responsive primitives for the FlixQuest UI.
abstract final class AppUI {
  static const double phonePadding = 20;
  static const double tabletPadding = 28;
  static const double contentMaxWidth = 1180;

  static double pagePadding(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= 700
        ? tabletPadding
        : phonePadding;
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
