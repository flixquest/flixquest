import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';

/// A row's title, with "See all ›" at the end when there is more to see.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.onSeeAll,
    this.kicker,
    super.key,
  });

  final String title;

  /// A small label over the title, such as which kind a genre row is.
  final String? kicker;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final onSeeAll = this.onSeeAll;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        gutter,
        0,
        onSeeAll == null ? gutter : gutter - 8,
        AppSpace.headerGap,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Semantics(
              header: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (kicker case final kicker?)
                    Text(
                      kicker.toUpperCase(),
                      style: AppType.kicker.copyWith(
                        color: palette.mutedText,
                        fontSize: 10,
                      ),
                    ),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.sectionHeader.copyWith(
                      color: palette.foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onSeeAll != null)
            InkWell(
              onTap: onSeeAll,
              borderRadius: BorderRadius.circular(AppRadii.button),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      tr('see_all'),
                      style: AppType.metadata.copyWith(
                        color: palette.mutedText,
                        fontFamily: AppType.semiBold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Directionality.of(context) == TextDirection.rtl
                          ? PhosphorIcons.caretLeft()
                          : PhosphorIcons.caretRight(),
                      size: 14,
                      color: palette.mutedText,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
