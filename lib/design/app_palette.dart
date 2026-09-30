import 'package:flutter/material.dart';

/// The app's colours as roles, taken from the theme so Dark, AMOLED and Light
/// (and the seasonal and ambient themes that replace the page colour) come out
/// right on the phone and the TV alike.
///
/// Every colour is a role, not a shade: in Light the text is dark, and the
/// focus pill that is white on a dark page turns near-black. The accent stays
/// out of it; it is the theme's own `primary`.
///
/// Anything drawn over artwork or video (poster badges, logo plates, the
/// player) keeps its own fixed colours, since the picture under it is the
/// same in every theme.
@immutable
class AppPalette {
  const AppPalette._({
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

  factory AppPalette.fromTheme(ThemeData theme) {
    final dark = theme.colorScheme.brightness == Brightness.dark;
    final page = theme.scaffoldBackgroundColor;
    final ink = dark ? const Color(0xfff7f7f7) : const Color(0xff141516);
    Color lift(double alpha) =>
        Color.alphaBlend(ink.withValues(alpha: alpha), page);
    return AppPalette._(
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

  static final Expando<AppPalette> _cache = Expando<AppPalette>('AppPalette');

  /// The palette for the theme in effect at [context], built once per theme.
  static AppPalette of(BuildContext context) {
    final theme = Theme.of(context);
    return _cache[theme] ??= AppPalette.fromTheme(theme);
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

  /// The plate streaming-service logos sit on, in every theme: they're app
  /// icons, several of them black squares, drawn for a light ground.
  static const logoPlate = Color(0xFFF2F2F3);
}
