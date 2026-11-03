// ignore: implementation_imports
import 'package:better_player_plus/src/subtitles/better_player_subtitles_configuration.dart';
import 'package:flutter/material.dart';

import 'subtitle_style.dart';

/// Builds a Better Player subtitle appearance from the persisted app settings.
BetterPlayerSubtitlesConfiguration buildPlayerSubtitleConfiguration({
  required String backgroundColor,
  required String foregroundColor,
  required int fontSize,
  required String textStyle,
  bool outlineEnabled = false,
  String outlineColor = '0xff000000',
  double outlineSize = 2.0,
}) {
  return BetterPlayerSubtitlesConfiguration(
    backgroundColor: parseStoredSubtitleColor(
      backgroundColor,
      fallback: Colors.black45,
    ),
    fontColor: parseStoredSubtitleColor(
      foregroundColor,
      fallback: Colors.white,
    ),
    fontFamily: subtitleFontFamily(textStyle),
    outlineEnabled: outlineEnabled,
    outlineColor: parseStoredSubtitleColor(
      outlineColor,
      fallback: Colors.black,
    ),
    outlineSize: outlineSize,
    fontSize: normalizeSubtitleFontSize(fontSize).toDouble(),
  );
}
