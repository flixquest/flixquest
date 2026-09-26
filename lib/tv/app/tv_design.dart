import 'package:flutter/material.dart';

import '../../design/app_palette.dart';

export '../../design/app_palette.dart';

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
  static const focusOutset = 12.0;
  static const cardRadius = 5.0;

  /// A panel colour a shade off the page; [emphasis] lifts it further.
  static Color surfaceFor(BuildContext context, {double emphasis = 0}) {
    final palette = TvPalette.of(context);
    return Color.alphaBlend(
      palette.foreground.withValues(alpha: emphasis),
      palette.surface,
    );
  }
}

/// The TV's name for the shared palette in lib/design/.
typedef TvPalette = AppPalette;
