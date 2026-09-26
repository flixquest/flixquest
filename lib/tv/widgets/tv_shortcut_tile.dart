import 'package:flutter/material.dart';

import '../app/tv_design.dart';

/// A browse-page tile that leads somewhere rather than to a title: a streaming
/// service's catalog or a genre.
class TvBrowseShortcut {
  const TvBrowseShortcut({
    required this.id,
    required this.title,
    required this.description,
    required this.onActivate,
    this.facts = const <String>[],
    this.logoAsset,
  });

  final String id;
  final String title;

  /// The spotlight's synopsis while the tile has focus.
  final String description;

  /// The spotlight's facts line while the tile has focus.
  final List<String> facts;

  /// A service's logo; without one the tile shows [title].
  final String? logoAsset;
  final VoidCallback onActivate;
}

/// A 16:9 tile for a [TvBrowseShortcut]: a service's logo on a dark plate, or
/// a genre's name on a tinted one.
class TvShortcutTile extends StatelessWidget {
  const TvShortcutTile({
    required this.shortcut,
    required this.width,
    this.tint = 0,
    this.dimmed = false,
    super.key,
  });

  static const aspectRatio = 16 / 9;

  /// Muted two-stop washes for genre tiles, so a row of names still reads as
  /// distinct tiles without competing with the artwork rows around it.
  static const _washes = <List<Color>>[
    <Color>[Color(0xff3a1f16), Color(0xff15100e)],
    <Color>[Color(0xff1b2a3a), Color(0xff0e1217)],
    <Color>[Color(0xff2d1d38), Color(0xff110d15)],
    <Color>[Color(0xff1d3328), Color(0xff0d1511)],
    <Color>[Color(0xff3a2d14), Color(0xff15120c)],
    <Color>[Color(0xff351722), Color(0xff140c10)],
  ];

  final TvBrowseShortcut shortcut;
  final double width;

  /// Picks the genre tile's wash, typically the tile's index in its row.
  final int tint;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final logo = shortcut.logoAsset;
    final wash = _washes[tint % _washes.length];
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(TvDesign.cardRadius),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: logo != null
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[Color(0xff1e1f22), Color(0xff111214)],
                        )
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: wash,
                        ),
                ),
              ),
              if (logo != null)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: width * 0.2,
                    vertical: width * 0.12,
                  ),
                  child: Image.asset(
                    logo,
                    fit: BoxFit.contain,
                    cacheWidth: (width * MediaQuery.devicePixelRatioOf(context))
                        .round(),
                    errorBuilder: (_, __, ___) => _TileTitle(shortcut.title),
                  ),
                )
              else
                _TileTitle(shortcut.title),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                color: dimmed ? const Color(0x8c000000) : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileTitle extends StatelessWidget {
  const _TileTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: TvDesign.foreground,
            fontFamily: 'FigtreeBold',
            fontSize: 18,
            height: 1.1,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}
