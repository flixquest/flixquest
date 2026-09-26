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

/// The TV's colours, taken from the app theme so Dark, AMOLED and Light (and
/// the seasonal themes that replace the page colour) look on the TV the way
/// they do on the phone.
///
/// Every colour is a role, not a shade: in Light the text is dark, and the
/// focus pill that is white on a dark page turns near-black. The accent stays
/// out of it; it is the theme's own `primary`.
///
/// Anything drawn over artwork or video (poster badges, logo plates, the
/// player) keeps its own fixed colours, since the picture under it is the
/// same in every theme.
@immutable
class TvPalette {
  const TvPalette._({
    required this.dark,
    required this.page,
    required this.surface,
    required this.raisedSurface,
    required this.foreground,
    required this.secondaryText,
    required this.mutedText,
    required this.hairline,
    required this.focusFill,
    required this.onFocus,
    required this.onFocusMuted,
    required this.idleFill,
    required this.idleFillStrong,
    required this.idleFillFaint,
    required this.dim,
  });

  factory TvPalette.fromTheme(ThemeData theme) {
    final dark = theme.colorScheme.brightness == Brightness.dark;
    final page = theme.scaffoldBackgroundColor;
    final ink = dark ? const Color(0xfff7f7f7) : const Color(0xff141516);
    Color lift(double alpha) =>
        Color.alphaBlend(ink.withValues(alpha: alpha), page);
    return TvPalette._(
      dark: dark,
      page: page,
      surface: lift(dark ? 0.045 : 0.035),
      raisedSurface: lift(dark ? 0.085 : 0.07),
      foreground: ink,
      secondaryText: dark ? const Color(0xffd6d7d7) : const Color(0xff2f3134),
      mutedText: dark ? const Color(0xffa7a8a8) : const Color(0xff5c5f63),
      hairline: ink.withValues(alpha: 0.12),
      focusFill: ink.withValues(alpha: 0.95),
      onFocus: dark ? Colors.black : Colors.white,
      onFocusMuted: dark ? Colors.black54 : Colors.white70,
      idleFill: ink.withValues(alpha: 0.14),
      idleFillStrong: ink.withValues(alpha: 0.25),
      idleFillFaint: ink.withValues(alpha: 0.08),
      dim: page.withValues(alpha: 0.55),
    );
  }

  static final Expando<TvPalette> _cache = Expando<TvPalette>('TvPalette');

  /// The palette for the theme in effect at [context], built once per theme.
  static TvPalette of(BuildContext context) {
    final theme = Theme.of(context);
    return _cache[theme] ??= TvPalette.fromTheme(theme);
  }

  final bool dark;

  /// The screen behind everything, and the colour artwork fades into.
  final Color page;

  /// Panels and tiles.
  final Color surface;

  /// Placeholders and chips, a step above [surface].
  final Color raisedSurface;

  /// Titles, labels and icons.
  final Color foreground;

  /// Supporting copy that sits over artwork, such as a spotlight synopsis.
  final Color secondaryText;
  final Color mutedText;
  final Color hairline;

  /// A focused control's fill: white on a dark page, near-black on a light
  /// one, and [onFocus] for what is on it.
  final Color focusFill;
  final Color onFocus;
  final Color onFocusMuted;

  /// A control's resting fill; [idleFillStrong] marks a screen's main action.
  final Color idleFill;
  final Color idleFillStrong;
  final Color idleFillFaint;

  /// Laid over artwork that steps back, such as the rows below the one being
  /// browsed.
  final Color dim;

  /// [page] at [alpha], for scrims that fade artwork into the page.
  Color scrim(double alpha) => page.withValues(alpha: alpha);
}
