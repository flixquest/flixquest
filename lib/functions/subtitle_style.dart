import 'package:flutter/material.dart';

const int minimumSubtitleFontSize = 5;
const int maximumSubtitleFontSize = 30;
const int defaultSubtitleFontSize = 17;

const int minimumSubtitleOutlineSize = 1;
const int maximumSubtitleOutlineSize = 6;
const int defaultSubtitleOutlineSize = 2;

/// Converts all subtitle color formats written by supported Flutter versions.
///
/// Flutter used to return `Color(0xff112233)` from [Color.toString], while
/// newer releases return named floating-point components. Persisting that
/// debug representation caused an unchecked `int.parse` to fail on rebuild.
Color parseStoredSubtitleColor(String value, {required Color fallback}) {
  final storedValue = value.trim();
  final hexMatch = RegExp(
    r'^(?:Color\()?0x([0-9a-fA-F]{8})\)?$',
  ).firstMatch(storedValue);
  if (hexMatch != null) {
    final argb = int.tryParse(hexMatch.group(1)!, radix: 16);
    if (argb != null) return Color(argb);
  }

  final hashMatch = RegExp(
    r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$',
  ).firstMatch(storedValue);
  if (hashMatch != null) {
    final hex = hashMatch.group(1)!;
    final argb = int.tryParse(hex.length == 6 ? 'ff$hex' : hex, radix: 16);
    if (argb != null) return Color(argb);
  }

  final componentMatch = RegExp(
    r'^Color\(alpha:\s*([^,]+),\s*red:\s*([^,]+),\s*green:\s*([^,]+),\s*blue:\s*([^,]+),\s*colorSpace:\s*[^)]+\)$',
  ).firstMatch(storedValue);
  if (componentMatch != null) {
    final components = List<double?>.generate(
      4,
      (index) => double.tryParse(componentMatch.group(index + 1)!.trim()),
    );
    if (components.every((component) => component?.isFinite == true)) {
      int channel(double component) =>
          (component.clamp(0.0, 1.0) * 255).round();
      return Color.fromARGB(
        channel(components[0]!),
        channel(components[1]!),
        channel(components[2]!),
        channel(components[3]!),
      );
    }
  }

  return fallback;
}

/// A stable, version-independent representation for SharedPreferences.
String serializeSubtitleColor(Color color) =>
    '0x${color.toARGB32().toRadixString(16).padLeft(8, '0')}';

int normalizeSubtitleFontSize(int value) => value.clamp(
      minimumSubtitleFontSize,
      maximumSubtitleFontSize,
    );

int normalizeSubtitleOutlineSize(int value) => value.clamp(
      minimumSubtitleOutlineSize,
      maximumSubtitleOutlineSize,
    );

String normalizeSubtitleTextStyle(String value) =>
    const {'light', 'regular', 'bold'}.contains(value) ? value : 'regular';

String subtitleFontFamily(String textStyle) {
  return switch (normalizeSubtitleTextStyle(textStyle)) {
    'bold' => 'FigtreeSB',
    'light' => 'FigtreeLight',
    _ => 'Figtree',
  };
}
