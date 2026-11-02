import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixquest/functions/player_subtitle_configuration.dart';
import 'package:flixquest/functions/subtitle_style.dart';

void main() {
  test('builds the configured subtitle appearance', () {
    final configuration = buildPlayerSubtitleConfiguration(
      backgroundColor: 'Color(0x80112233)',
      foregroundColor: 'Color(0xffabcdef)',
      fontSize: 24,
      textStyle: 'bold',
    );

    expect(configuration.backgroundColor, const Color(0x80112233));
    expect(configuration.fontColor, const Color(0xffabcdef));
    expect(configuration.fontSize, 24);
    expect(configuration.fontFamily, 'FigtreeSB');
    expect(configuration.outlineEnabled, isFalse);
  });

  test('uses safe defaults for invalid persisted values', () {
    final configuration = buildPlayerSubtitleConfiguration(
      backgroundColor: 'invalid',
      foregroundColor: '',
      fontSize: 17,
      textStyle: 'unknown',
    );

    expect(configuration.backgroundColor, Colors.black45);
    expect(configuration.fontColor, Colors.white);
    expect(configuration.fontFamily, 'Figtree');
  });

  test('reads colors persisted by current Flutter Color.toString', () {
    const selectedColor = Color(0xff443a49);

    expect(
      parseStoredSubtitleColor(
        selectedColor.toString(),
        fallback: Colors.white,
      ),
      selectedColor,
    );
  });

  test('serializes colors without depending on Color.toString', () {
    expect(serializeSubtitleColor(const Color(0x80443a49)), '0x80443a49');
  });

  test('clamps invalid persisted font sizes', () {
    final tooSmall = buildPlayerSubtitleConfiguration(
      backgroundColor: '0x73000000',
      foregroundColor: '0xffffffff',
      fontSize: -1,
      textStyle: 'regular',
    );
    final tooLarge = buildPlayerSubtitleConfiguration(
      backgroundColor: '0x73000000',
      foregroundColor: '0xffffffff',
      fontSize: 100,
      textStyle: 'regular',
    );

    expect(tooSmall.fontSize, minimumSubtitleFontSize);
    expect(tooLarge.fontSize, maximumSubtitleFontSize);
  });

  test('maps light subtitle text to the light app font', () {
    final configuration = buildPlayerSubtitleConfiguration(
      backgroundColor: Colors.black45.toString(),
      foregroundColor: Colors.white.toString(),
      fontSize: 17,
      textStyle: 'light',
    );

    expect(configuration.fontFamily, 'FigtreeLight');
  });

  test('builds subtitle appearance with custom outline configuration', () {
    final configuration = buildPlayerSubtitleConfiguration(
      backgroundColor: 'Color(0x80112233)',
      foregroundColor: 'Color(0xffabcdef)',
      fontSize: 20,
      textStyle: 'bold',
      outlineEnabled: true,
      outlineColor: '0xffffff00',
      outlineSize: 3.5,
    );

    expect(configuration.outlineEnabled, isTrue);
    expect(configuration.outlineColor, const Color(0xffffff00));
    expect(configuration.outlineSize, 3.5);
  });
}
