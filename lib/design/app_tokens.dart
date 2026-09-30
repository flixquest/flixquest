import 'package:flutter/widgets.dart';

/// Spacing, radii and type for the handheld UI. Colours are roles in
/// [AppPalette]; the accent is the theme's `primary`, kept to the places the
/// redesign guide allows (docs/mobile_redesign_guide.md, section 3.2).
abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  /// The page's side margin: 16 on phones, 24 from tablet width.
  static double gutter(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet ? 24 : 16;

  /// Between one row of titles and the next.
  static const rowGap = 24.0;

  /// Between a section header and its row.
  static const headerGap = 8.0;
}

abstract final class AppRadii {
  static const card = 6.0;
  static const button = 6.0;
  static const hero = 10.0;
  static const chip = 18.0;
  static const sheet = 16.0;
}

abstract final class AppBreakpoints {
  static const tablet = 700.0;
  static const wide = 1000.0;
}

/// The type scale for phones; tablets use [scaled].
abstract final class AppType {
  static const bold = 'FigtreeBold';
  static const semiBold = 'FigtreeSB';
  static const regular = 'Figtree';

  static const heroTitle = TextStyle(
    fontFamily: bold,
    fontSize: 30,
    height: 34 / 30,
    letterSpacing: -0.6,
  );
  static const pageTitle = TextStyle(
    fontFamily: bold,
    fontSize: 28,
    height: 32 / 28,
    letterSpacing: -0.5,
  );
  static const sectionHeader = TextStyle(
    fontFamily: semiBold,
    fontSize: 18,
    height: 24 / 18,
    letterSpacing: -0.1,
  );
  static const cardTitle = TextStyle(
    fontFamily: semiBold,
    fontSize: 14,
    height: 18 / 14,
  );
  static const metadata = TextStyle(
    fontFamily: regular,
    fontSize: 12,
    height: 16 / 12,
  );
  static const kicker = TextStyle(
    fontFamily: semiBold,
    fontSize: 11,
    letterSpacing: 1.4,
  );
  static const body = TextStyle(
    fontFamily: regular,
    fontSize: 14,
    height: 20 / 14,
  );
  static const button = TextStyle(fontFamily: semiBold, fontSize: 15);

  /// [style] for [context]: 10% larger from tablet width.
  static TextStyle scaled(BuildContext context, TextStyle style) =>
      MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet
          ? style.copyWith(fontSize: (style.fontSize ?? 14) * 1.1)
          : style;
}
