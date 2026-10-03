/// Tolerant reads at API boundaries; domain objects retain strong types.
class JsonReader {
  const JsonReader(this.json);

  final Map<String, dynamic> json;

  Object? firstOf(List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null) return value;
    }
    return null;
  }

  static int? asInt(Object? value) {
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.truncateToDouble()) {
      return value.toInt();
    }
    return value is String ? int.tryParse(value.trim()) : null;
  }

  static double? asDouble(Object? value) {
    final number = value is num
        ? value.toDouble()
        : value is String
            ? double.tryParse(value.trim())
            : null;
    return number != null && number.isFinite ? number : null;
  }

  static bool? asBool(Object? value) {
    if (value is bool) return value;
    if (value == 1) return true;
    if (value == 0) return false;
    if (value is String) {
      switch (value.trim().toLowerCase()) {
        case 'true':
        case '1':
          return true;
        case 'false':
        case '0':
          return false;
      }
    }
    return null;
  }

  static String? asString(Object? value) => value is String
      ? value
      : value is num || value is bool
          ? '$value'
          : null;

  static List<dynamic>? asList(Object? value) =>
      value is List ? List<dynamic>.from(value) : null;

  static Map<String, dynamic>? asMap(Object? value) {
    if (value is! Map || value.keys.any((key) => key is! String)) return null;
    return Map<String, dynamic>.from(value);
  }
}
