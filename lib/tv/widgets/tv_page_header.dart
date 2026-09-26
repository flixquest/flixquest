import 'package:flutter/material.dart';

import '../app/tv_design.dart';

/// A page's kicker and title, for the TV screens that are not browse pages
/// (Settings, Profile, Insights).
///
/// The kicker keeps the accent, like the browse pages' "FEATURED" lines; it
/// is the brand's mark on the page, not a signal for focus.
class TvPageHeader extends StatelessWidget {
  const TvPageHeader({
    required this.kicker,
    required this.title,
    required this.compact,
    this.trailing,
    super.key,
  });

  final String kicker;
  final String title;
  final bool compact;

  /// Sits at the title's end, such as a range picker.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                kicker,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontFamily: 'FigtreeSB',
                  fontSize: compact ? 11 : 12,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: TvDesign.foreground,
                  fontFamily: 'FigtreeBold',
                  fontSize: compact ? 30 : 38,
                  height: 1,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }
}

/// A small uppercase label over a group of rows.
class TvSectionLabel extends StatelessWidget {
  const TvSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: TvDesign.mutedText,
          fontFamily: 'FigtreeSB',
          fontSize: 12,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
