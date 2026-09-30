import 'dart:convert';

/// TMDB genre ids however they were stored: a list (TMDB, and the cloud
/// from this version on), "28,12" (the local bookmark tables) or "[28,12]".
/// Anything else, including nothing, is null, so rows saved before genres
/// were kept still read.
List<int>? parseGenreIds(Object? raw) {
  Object? value = raw;
  if (value is String) {
    final text = value.trim();
    if (text.isEmpty) return null;
    if (text.startsWith('[')) {
      try {
        value = jsonDecode(text);
      } on FormatException {
        return null;
      }
    } else {
      value = text.split(',');
    }
  }
  if (value is! List) return null;
  final ids = value
      .map((id) => id is int ? id : int.tryParse('$id'.trim()))
      .whereType<int>()
      .toList(growable: false);
  return ids.isEmpty ? null : ids;
}

/// [ids] for a SQLite column: "28,12", or null for none.
String? encodeGenreIds(List<int>? ids) =>
    ids == null || ids.isEmpty ? null : ids.join(',');
