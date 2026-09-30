import 'package:flutter/material.dart';

import '../app/tv_design.dart';
import '../app/tv_shell_layout.dart';
import 'tv_media_card.dart';

/// A browse page's shape while its rows load: the billboard's text and the
/// first rows as quiet blocks, in the places [TvBrowseView] will put them, so
/// the page settles into place instead of jumping from a spinner.
///
/// The blocks breathe slowly between two surface greys; one colour animates
/// for all of them, with no shader or offscreen layer.
class TvBrowseSkeleton extends StatefulWidget {
  const TvBrowseSkeleton({required this.metrics, super.key});

  final TvShellMetrics metrics;

  @override
  State<TvBrowseSkeleton> createState() => _TvBrowseSkeletonState();
}

class _TvBrowseSkeletonState extends State<TvBrowseSkeleton>
    with SingleTickerProviderStateMixin {
  // Matches TvBrowseView's layout.
  static const _billboardRowsTop = 0.7;
  static const _cardSpacing = 18.0;
  static const _itemFocusPadding = 4.0;
  static const _leading = TvDesign.focusOutset + _itemFocusPadding;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  late final Animation<double> _breath =
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    final metrics = widget.metrics;
    final compact = metrics.compact;
    final insets = TvShellInsets.of(context);
    final cardWidth = metrics.mediaCardWidth;
    final cardHeight = cardWidth / TvMediaCard.artworkAspectRatio;

    return Semantics(
      label: 'Loading',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final innerHeight = constraints.maxHeight - insets.vertical;
          final rowsTop = insets.top + innerHeight * _billboardRowsTop;
          final spotlightWidth =
              ((constraints.maxWidth - insets.horizontal) * 0.46)
                  .clamp(0.0, compact ? 430.0 : 580.0);

          return AnimatedBuilder(
            animation: _breath,
            builder: (context, _) {
              // Between the panel colour and the one a step above, so the
              // pulse is as quiet on a light page as on a dark one.
              final color = Color.lerp(
                palette.surface,
                palette.raisedSurface,
                _breath.value,
              )!;
              Widget block(double width, double height) => Container(
                    width: width,
                    height: height,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(TvDesign.cardRadius),
                    ),
                  );

              return ClipRect(
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      left: insets.left + _leading,
                      bottom:
                          constraints.maxHeight - rowsTop + (compact ? 10 : 16),
                      width: spotlightWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          block(120, 12),
                          const SizedBox(height: 12),
                          block(spotlightWidth * 0.72, compact ? 34 : 46),
                          const SizedBox(height: 12),
                          block(spotlightWidth * 0.4, 14),
                          SizedBox(height: compact ? 10 : 14),
                          for (final fraction in const <double>[1, 0.92, 0.6])
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: block(spotlightWidth * fraction, 13),
                            ),
                          SizedBox(height: compact ? 8 : 12),
                          block(128, 40),
                        ],
                      ),
                    ),
                    Positioned(
                      left: insets.left + _leading,
                      top: rowsTop,
                      right: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          for (var row = 0; row < 2; row++) ...<Widget>[
                            block(row == 0 ? 180 : 140, 20),
                            // The row title's gap, and the focus padding and
                            // track padding above the cards.
                            const SizedBox(height: 5 + 8 + _itemFocusPadding),
                            SizedBox(
                              height: cardHeight,
                              child: OverflowBox(
                                alignment: Alignment.topLeft,
                                maxWidth: double.infinity,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    for (var card = 0; card < 9; card++)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: _cardSpacing +
                                              _itemFocusPadding * 2,
                                        ),
                                        child: block(cardWidth, cardHeight),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(
                              height:
                                  (compact ? 16 : 24) + 8 + _itemFocusPadding,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
