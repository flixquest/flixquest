import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/tv_design.dart';

/// The landing collage, cut into its posters and laid out again as a tilted
/// wall that fills a 16:9 screen, drifting slowly.
///
/// The collage is portrait (a 7 × 8 grid), so a plain `BoxFit.cover` on a TV
/// shows only two rows of oversized posters. Re-tiling keeps posters at a
/// browsable size and hides the watermark in the collage's last row.
class TvPosterWall extends StatefulWidget {
  const TvPosterWall({super.key});

  @override
  State<TvPosterWall> createState() => _TvPosterWallState();
}

class _TvPosterWallState extends State<TvPosterWall>
    with SingleTickerProviderStateMixin {
  static const _columns = 7;
  static const _rows = 8;
  // The last two cells of the bottom row carry the collage site's watermark.
  static const _cells = _columns * _rows - 2;
  static const _cellAspect = (3400 / _columns) / (6000 / _rows);
  static const _tilt = -0.12;
  static const _postersAcross = 10;

  // Decoded near display size: the 3400 × 6000 original is ~80 MB in memory.
  static const ImageProvider _collage = ResizeImage(
    AssetImage('assets/images/grid_final.jpg'),
    width: 1400,
  );

  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  );
  late final ImageStreamListener _listener = ImageStreamListener(
    (_, __) {
      if (mounted && !_ready) setState(() => _ready = true);
    },
    onError: (_, __) {},
  );
  ImageStream? _stream;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stream = _collage.resolve(createLocalImageConfiguration(context));
    if (stream.key != _stream?.key) {
      _stream?.removeListener(_listener);
      _stream = stream..addListener(_listener);
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _drift.stop();
    } else if (!_drift.isAnimating) {
      _drift.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            final tileWidth = size.width / _postersAcross;
            final tileHeight = tileWidth / _cellAspect;
            final gap = tileWidth * 0.06;
            final drift = tileHeight * 0.5;

            // The tilted wall must still cover every corner of the screen,
            // at both ends of the drift.
            final cos = math.cos(_tilt.abs());
            final sin = math.sin(_tilt.abs());
            final neededWidth = size.width * cos + size.height * sin;
            final neededHeight =
                size.width * sin + size.height * cos + drift * 2;
            final columns = (neededWidth / (tileWidth + gap)).ceil() + 1;
            final rows = (neededHeight / (tileHeight + gap)).ceil() + 1;

            final wall = RepaintBoundary(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (var row = 0; row < rows; row++)
                    Padding(
                      padding: EdgeInsets.all(gap / 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          for (var column = 0; column < columns; column++)
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: gap / 2,
                              ),
                              child: _poster(
                                // A stride of 23 rows keeps each poster's
                                // repeats at least seven tiles apart.
                                (column + row * 23) % _cells,
                                tileWidth,
                                tileHeight,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            );

            return AnimatedOpacity(
              opacity: _ready ? 1 : 0,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              child: OverflowBox(
                minWidth: 0,
                maxWidth: double.infinity,
                minHeight: 0,
                maxHeight: double.infinity,
                child: Transform.rotate(
                  angle: _tilt,
                  child: AnimatedBuilder(
                    animation: _drift,
                    child: wall,
                    builder: (context, child) {
                      final t = Curves.easeInOut.transform(_drift.value);
                      return Transform.translate(
                        offset: Offset(0, (t - 0.5) * 2 * drift),
                        child: child,
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _poster(int cell, double width, double height) {
    final column = cell % _columns;
    final row = cell ~/ _columns;
    return ClipRRect(
      borderRadius: BorderRadius.circular(TvDesign.cardRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: OverflowBox(
          alignment: Alignment(
            column * 2 / (_columns - 1) - 1,
            row * 2 / (_rows - 1) - 1,
          ),
          minWidth: width * _columns,
          maxWidth: width * _columns,
          minHeight: height * _rows,
          maxHeight: height * _rows,
          child: const Image(
            image: _collage,
            fit: BoxFit.fill,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}
