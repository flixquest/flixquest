import 'package:flutter/material.dart';

class TvShellMetrics {
  const TvShellMetrics({
    required this.compact,
    required this.safeInset,
    required this.railWidth,
    required this.railGap,
    required this.contentPadding,
    required this.navItemHeight,
    required this.navItemGap,
    required this.mediaCardWidth,
  });

  factory TvShellMetrics.fromConstraints(BoxConstraints constraints) {
    final compact = constraints.maxHeight < 700 || constraints.maxWidth < 1200;
    final safeInset = compact ? 16.0 : 26.0;
    final railWidth = compact ? 56.0 : 68.0;
    final railGap = compact ? 8.0 : 14.0;
    final contentWidth =
        constraints.maxWidth - (safeInset * 2) - railWidth - railGap;
    final mediaCardWidth = (contentWidth / 7.2).clamp(106.0, 210.0);

    return TvShellMetrics(
      compact: compact,
      safeInset: safeInset,
      railWidth: railWidth,
      railGap: railGap,
      contentPadding: compact ? 14 : 22,
      navItemHeight: compact ? 42 : 48,
      navItemGap: compact ? 2 : 5,
      mediaCardWidth: mediaCardWidth,
    );
  }

  final bool compact;
  final double safeInset;
  final double railWidth;
  final double railGap;
  final double contentPadding;
  final double navItemHeight;
  final double navItemGap;
  final double mediaCardWidth;

  /// The rail's width while it has focus and shows its labels.
  double get expandedRailWidth => compact ? 200 : 244;
}

abstract final class TvDesign {
  /// The phone app's charcoal palette, deepened slightly for a ten-foot screen.
  /// Keeping these colors neutral lets the user's mobile accent color remain the
  /// only saturated UI color on television as well.
  static const pageBackground = Color(0xff050606);
  static const surface = Color(0xff111212);
  static const raisedSurface = Color(0xff1b1c1c);
  static const mutedText = Color(0xffa7a8a8);
  static const foreground = Color(0xfff7f7f7);
  static const hairline = Color(0x1fffffff);
  static const focusOutset = 12.0;
  static const cardRadius = 5.0;

  static Color surfaceFor(BuildContext context, {double emphasis = 0}) {
    final theme = Theme.of(context);
    final base = theme.brightness == Brightness.dark
        ? surface
        : theme.colorScheme.surface;
    // A neutral lift: the accent is kept for the brand, not for surfaces.
    return Color.alphaBlend(
      Colors.white.withValues(alpha: 0.012 + emphasis),
      base,
    );
  }
}
