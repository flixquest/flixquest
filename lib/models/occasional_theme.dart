import 'dart:convert';

import 'package:flutter/material.dart';

enum OccasionalEffectType {
  none,
  snow,
  confetti,
  fireworks,
  petals,
  candyEggs,
  adeyFlowers,
  hearts,
  stars,
  bats,
  sparkles,
}

@immutable
class OccasionalEffect {
  const OccasionalEffect({
    this.enabled = false,
    this.type = OccasionalEffectType.none,
    this.density = 28,
    this.speed = 1,
    this.opacity = .65,
    this.colors = const <Color>[],
  });

  final bool enabled;
  final OccasionalEffectType type;
  final int density;
  final double speed;
  final double opacity;
  final List<Color> colors;

  factory OccasionalEffect.fromJson(
    Object? value, {
    required OccasionalEffectType presetType,
  }) {
    if (value is! Map<String, dynamic>) {
      return OccasionalEffect(type: presetType);
    }
    final typeName = (value['type'] ?? '').toString().trim().toLowerCase();
    final parsedType = OccasionalEffectType.values.firstWhere(
      (candidate) =>
          candidate.name.toLowerCase() == typeName ||
          jsonName(candidate) == typeName,
      orElse: () => presetType,
    );
    // Older catalogs used `petals` for these built-in occasions. Preserve
    // those payloads while upgrading them to their richer combined effects.
    final type = parsedType == OccasionalEffectType.petals &&
            (presetType == OccasionalEffectType.adeyFlowers ||
                presetType == OccasionalEffectType.candyEggs)
        ? presetType
        : parsedType;
    final rawColors = value['colors'];
    final colors = rawColors is List
        ? rawColors
            .map(OccasionalTheme.parseColor)
            .whereType<Color>()
            .take(8)
            .toList(growable: false)
        : const <Color>[];
    return OccasionalEffect(
      enabled: OccasionalTheme.parseBool(value['enabled']),
      type: type,
      density:
          OccasionalTheme.parseInt(value['density'], fallback: 28).clamp(4, 80),
      speed:
          OccasionalTheme.parseDouble(value['speed'], fallback: 1).clamp(.2, 3),
      opacity: OccasionalTheme.parseDouble(value['opacity'], fallback: .65)
          .clamp(.1, 1),
      colors: colors,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'enabled': enabled,
        'type': jsonName(type),
        'density': density,
        'speed': speed,
        'opacity': opacity,
        if (colors.isNotEmpty)
          'colors': colors.map(OccasionalTheme.colorHex).toList(),
      };

  static String jsonName(OccasionalEffectType type) => switch (type) {
        OccasionalEffectType.candyEggs => 'candy_eggs',
        OccasionalEffectType.adeyFlowers => 'adey_flowers',
        _ => type.name,
      };
}

/// One remotely managed, time-bounded visual theme.
@immutable
class OccasionalTheme {
  const OccasionalTheme({
    required this.id,
    required this.displayName,
    required this.enabled,
    required this.userSelectable,
    required this.priority,
    required this.primaryColor,
    required this.secondaryColor,
    required this.tertiaryColor,
    required this.effect,
    this.isValidConfiguration = true,
    this.description = '',
    this.logoUrl = '',
    this.lightBackgroundColor,
    this.darkBackgroundColor,
    this.startsAt,
    this.endsAt,
  });

  const OccasionalTheme.disabled()
      : id = '',
        displayName = '',
        description = '',
        enabled = false,
        userSelectable = false,
        priority = 0,
        primaryColor = const Color(0xFFF97316),
        secondaryColor = const Color(0xFFF59E0B),
        tertiaryColor = const Color(0xFFEF4444),
        logoUrl = '',
        lightBackgroundColor = null,
        darkBackgroundColor = null,
        startsAt = null,
        endsAt = null,
        isValidConfiguration = false,
        effect = const OccasionalEffect();

  final String id;
  final String displayName;
  final String description;
  final bool enabled;
  final bool userSelectable;
  final int priority;
  final Color primaryColor;
  final Color secondaryColor;
  final Color tertiaryColor;
  final String logoUrl;
  final Color? lightBackgroundColor;
  final Color? darkBackgroundColor;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final OccasionalEffect effect;
  final bool isValidConfiguration;

  bool isActiveAt(DateTime now) {
    if (!enabled || id.isEmpty) return false;
    final instant = now.toUtc();
    if (startsAt != null && instant.isBefore(startsAt!.toUtc())) return false;
    if (endsAt != null && instant.isAfter(endsAt!.toUtc())) return false;
    return true;
  }

  bool get isActive => isActiveAt(DateTime.now());

  Color? backgroundFor(Brightness brightness) => brightness == Brightness.dark
      ? darkBackgroundColor
      : lightBackgroundColor;

  factory OccasionalTheme.fromJson(Map<String, dynamic> json) {
    final id = stringValue(json, const ['id', 'name']).toLowerCase();
    final preset = _presetFor(id);
    final palette = valueFor(json, const ['colors', 'palette']);
    final palettePrimary = palette is List && palette.isNotEmpty
        ? parseColor(palette.first)
        : null;
    final paletteSecondary =
        palette is List && palette.length >= 2 ? parseColor(palette[1]) : null;
    final primaryOverride =
        parseColor(valueFor(json, const ['primary_color', 'primaryColor'])) ??
            palettePrimary;
    final secondaryOverride = parseColor(
          valueFor(json, const ['secondary_color', 'secondaryColor']),
        ) ??
        paletteSecondary;
    final customPaletteIsValid = primaryOverride != null &&
        secondaryOverride != null &&
        primaryOverride.toARGB32() != secondaryOverride.toARGB32();
    final startsAtValue =
        valueFor(json, const ['starts_at', 'start_at', 'startsAt']);
    final endsAtValue = valueFor(json, const ['ends_at', 'end_at', 'endsAt']);
    final startsAt = parseDate(startsAtValue);
    final endsAt = parseDate(endsAtValue);
    final invalidDate = (hasValue(startsAtValue) && startsAt == null) ||
        (hasValue(endsAtValue) && endsAt == null);
    final invalidWindow =
        startsAt != null && endsAt != null && endsAt.isBefore(startsAt);
    final rawName = stringValue(
      json,
      const ['display_name', 'displayName', 'title'],
    );
    final requestedEnabled = parseBool(json['enabled']);
    final isValidConfiguration = id.isNotEmpty &&
        !invalidDate &&
        !invalidWindow &&
        (!requestedEnabled || preset.isBuiltIn || customPaletteIsValid);
    final primary = primaryOverride ?? preset.primary;
    final secondary = secondaryOverride ?? preset.secondary;
    final tertiaryOverride = parseColor(
      valueFor(json, const ['tertiary_color', 'tertiaryColor']),
    );
    final lightBackgroundOverride = parseColor(valueFor(json, const [
      'light_background_color',
      'lightBackgroundColor',
    ]));
    final darkBackgroundOverride = parseColor(valueFor(json, const [
      'dark_background_color',
      'darkBackgroundColor',
    ]));

    return OccasionalTheme(
      id: id,
      displayName: rawName.isEmpty
          ? (preset.displayName.isEmpty ? _titleFromId(id) : preset.displayName)
          : rawName,
      description: stringValue(json, const ['description', 'subtitle']),
      enabled: requestedEnabled && isValidConfiguration,
      userSelectable: json.containsKey('user_selectable')
          ? parseBool(json['user_selectable'])
          : true,
      priority: parseInt(json['priority']).clamp(-1000, 1000),
      primaryColor: primary,
      secondaryColor: secondary,
      tertiaryColor: tertiaryOverride ??
          (preset.isBuiltIn
              ? preset.tertiary
              : _derivedTertiary(primary, secondary)),
      logoUrl: stringValue(json, const ['logo_url', 'logoUrl']),
      lightBackgroundColor: lightBackgroundOverride ??
          preset.lightBackground ??
          (customPaletteIsValid
              ? _derivedBackground(primary, secondary, Brightness.light)
              : null),
      darkBackgroundColor: darkBackgroundOverride ??
          preset.darkBackground ??
          (customPaletteIsValid
              ? _derivedBackground(primary, secondary, Brightness.dark)
              : null),
      startsAt: startsAt,
      endsAt: endsAt,
      isValidConfiguration: isValidConfiguration,
      effect: OccasionalEffect.fromJson(
        json['effect'],
        presetType: preset.effectType,
      ),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'display_name': displayName,
        if (description.isNotEmpty) 'description': description,
        'enabled': enabled,
        'user_selectable': userSelectable,
        'priority': priority,
        'primary_color': colorHex(primaryColor),
        'secondary_color': colorHex(secondaryColor),
        'tertiary_color': colorHex(tertiaryColor),
        'logo_url': logoUrl,
        if (lightBackgroundColor != null)
          'light_background_color': colorHex(lightBackgroundColor!),
        if (darkBackgroundColor != null)
          'dark_background_color': colorHex(darkBackgroundColor!),
        if (startsAt != null) 'starts_at': startsAt!.toUtc().toIso8601String(),
        if (endsAt != null) 'ends_at': endsAt!.toUtc().toIso8601String(),
        'effect': effect.toJson(),
      };

  static Object? valueFor(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      if (json.containsKey(key)) return json[key];
    }
    return null;
  }

  static String stringValue(Map<String, dynamic> json, List<String> keys) =>
      (valueFor(json, keys) ?? '').toString().trim();

  static bool parseBool(Object? value) => switch (value) {
        true => true,
        String value => value.toLowerCase() == 'true' || value == '1',
        num value => value != 0,
        _ => false,
      };

  static int parseInt(Object? value, {int fallback = 0}) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

  static double parseDouble(Object? value, {double fallback = 0}) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;

  static DateTime? parseDate(Object? value) {
    final raw = value?.toString().trim() ?? '';
    return raw.isEmpty ? null : DateTime.tryParse(raw)?.toUtc();
  }

  static bool hasValue(Object? value) =>
      value != null && value.toString().trim().isNotEmpty;

  static Color? parseColor(Object? value) {
    if (value is int) return Color(value);
    var raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    raw = raw.replaceFirst('#', '').replaceFirst('0x', '');
    if (raw.length == 6) raw = 'FF$raw';
    if (raw.length != 8) return null;
    final parsed = int.tryParse(raw, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  static String colorHex(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

  static String canonicalId(String id) => switch (id.trim().toLowerCase()) {
        'xmas' => 'christmas',
        'ethiopian-new-year' || 'enkutatash' => 'ethiopian_new_year',
        'new-year' => 'new_year',
        'valentines_day' || 'valentine' => 'valentines',
        'eid_al_fitr' || 'eid_al_adha' => 'eid',
        final value => value,
      };

  static Color _derivedTertiary(Color primary, Color secondary) =>
      Color.alphaBlend(secondary.withValues(alpha: .45), primary);

  static Color _derivedBackground(
    Color primary,
    Color secondary,
    Brightness brightness,
  ) {
    final blended = Color.lerp(primary, secondary, .35) ?? primary;
    final base =
        brightness == Brightness.dark ? const Color(0xFF101014) : Colors.white;
    return Color.alphaBlend(
      blended.withValues(alpha: brightness == Brightness.dark ? .16 : .07),
      base,
    );
  }

  static String _titleFromId(String id) => id
      .split(RegExp('[_-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  static _OccasionalThemePreset _presetFor(String id) => switch (id) {
        'christmas' || 'xmas' => const _OccasionalThemePreset(
            isBuiltIn: true,
            displayName: 'Christmas',
            primary: Color(0xFFC62828),
            secondary: Color(0xFF2E7D32),
            tertiary: Color(0xFFD4AF37),
            lightBackground: Color(0xFFFFFBF5),
            darkBackground: Color(0xFF0C1710),
            effectType: OccasionalEffectType.snow,
          ),
        'ethiopian_new_year' ||
        'ethiopian-new-year' ||
        'enkutatash' =>
          const _OccasionalThemePreset(
            isBuiltIn: true,
            displayName: 'Ethiopian New Year',
            primary: Color(0xFFF9A825),
            secondary: Color(0xFF2E7D32),
            tertiary: Color(0xFFC62828),
            lightBackground: Color(0xFFFFFDF2),
            darkBackground: Color(0xFF141508),
            effectType: OccasionalEffectType.adeyFlowers,
          ),
        'new_year' || 'new-year' => const _OccasionalThemePreset(
            isBuiltIn: true,
            displayName: 'New Year',
            primary: Color(0xFFD4AF37),
            secondary: Color(0xFF3949AB),
            tertiary: Color(0xFFE040FB),
            lightBackground: Color(0xFFFFFDF5),
            darkBackground: Color(0xFF10101B),
            effectType: OccasionalEffectType.fireworks,
          ),
        'halloween' => const _OccasionalThemePreset(
            isBuiltIn: true,
            displayName: 'Halloween',
            primary: Color(0xFFFF6D00),
            secondary: Color(0xFF6A1B9A),
            tertiary: Color(0xFF212121),
            lightBackground: Color(0xFFFFF8F0),
            darkBackground: Color(0xFF140B18),
            effectType: OccasionalEffectType.bats,
          ),
        'valentines' ||
        'valentines_day' ||
        'valentine' =>
          const _OccasionalThemePreset(
            isBuiltIn: true,
            displayName: "Valentine's Day",
            primary: Color(0xFFD81B60),
            secondary: Color(0xFFAD1457),
            tertiary: Color(0xFFF48FB1),
            lightBackground: Color(0xFFFFF7FA),
            darkBackground: Color(0xFF1B0B12),
            effectType: OccasionalEffectType.hearts,
          ),
        'easter' => const _OccasionalThemePreset(
            isBuiltIn: true,
            displayName: 'Easter',
            primary: Color(0xFF7E57C2),
            secondary: Color(0xFF26A69A),
            tertiary: Color(0xFFFFCA28),
            lightBackground: Color(0xFFFFFBFF),
            darkBackground: Color(0xFF15101C),
            effectType: OccasionalEffectType.candyEggs,
          ),
        'eid' || 'eid_al_fitr' || 'eid_al_adha' => const _OccasionalThemePreset(
            isBuiltIn: true,
            displayName: 'Eid',
            primary: Color(0xFF00897B),
            secondary: Color(0xFFD4AF37),
            tertiary: Color(0xFF5E35B1),
            lightBackground: Color(0xFFF5FFFC),
            darkBackground: Color(0xFF081714),
            effectType: OccasionalEffectType.stars,
          ),
        'diwali' => const _OccasionalThemePreset(
            isBuiltIn: true,
            displayName: 'Diwali',
            primary: Color(0xFFFF8F00),
            secondary: Color(0xFFD81B60),
            tertiary: Color(0xFF7B1FA2),
            lightBackground: Color(0xFFFFFBF2),
            darkBackground: Color(0xFF1A0D16),
            effectType: OccasionalEffectType.sparkles,
          ),
        _ => const _OccasionalThemePreset(
            displayName: '',
            primary: Color(0xFFF97316),
            secondary: Color(0xFFF59E0B),
            tertiary: Color(0xFFEF4444),
            effectType: OccasionalEffectType.confetti,
          ),
      };
}

@immutable
class OccasionalThemeCatalog {
  const OccasionalThemeCatalog({
    required this.enabled,
    required this.allowUserSelection,
    required this.effectsEnabled,
    required this.allowUserEffectsToggle,
    required this.themes,
    this.defaultThemeId = '',
    this.activeThemeId = '',
    this.resolvedAt,
    this.schemaVersion = 2,
  });

  const OccasionalThemeCatalog.disabled()
      : enabled = false,
        allowUserSelection = false,
        effectsEnabled = false,
        allowUserEffectsToggle = false,
        defaultThemeId = '',
        activeThemeId = '',
        resolvedAt = null,
        schemaVersion = 2,
        themes = const <OccasionalTheme>[];

  final bool enabled;
  final bool allowUserSelection;
  final bool effectsEnabled;
  final bool allowUserEffectsToggle;
  final String defaultThemeId;
  final String activeThemeId;
  final DateTime? resolvedAt;
  final int schemaVersion;
  final List<OccasionalTheme> themes;

  factory OccasionalThemeCatalog.fromJsonString(String value) {
    return tryFromJsonString(value) ?? const OccasionalThemeCatalog.disabled();
  }

  /// Parses a Remote Config payload. A null result means callers should keep
  /// their last known-good catalog rather than replacing it.
  static OccasionalThemeCatalog? tryFromJsonString(String value) {
    if (value.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) return null;
      return _tryFromJson(decoded);
    } on FormatException {
      return null;
    }
  }

  factory OccasionalThemeCatalog.fromJson(Map<String, dynamic> json) {
    return _tryFromJson(json) ?? const OccasionalThemeCatalog.disabled();
  }

  static OccasionalThemeCatalog? _tryFromJson(Map<String, dynamic> json) {
    final rawThemes = json['themes'];
    if (rawThemes is! List) {
      // Backward-compatible migration for the original single-theme schema.
      final legacy = OccasionalTheme.fromJson(json);
      if (!legacy.isValidConfiguration) {
        return OccasionalTheme.parseBool(json['enabled'])
            ? null
            : const OccasionalThemeCatalog.disabled();
      }
      return OccasionalThemeCatalog(
        enabled: legacy.enabled,
        allowUserSelection: false,
        effectsEnabled: true,
        allowUserEffectsToggle: false,
        themes: legacy.id.isEmpty ? const [] : <OccasionalTheme>[legacy],
        schemaVersion: 1,
      );
    }

    final byId = <String, OccasionalTheme>{};
    for (final item in rawThemes.take(24)) {
      if (item is! Map) continue;
      final normalized = <String, dynamic>{};
      for (final entry in item.entries) {
        if (entry.key is String) {
          normalized[entry.key as String] = entry.value;
        }
      }
      final theme = OccasionalTheme.fromJson(normalized);
      if (theme.isValidConfiguration) byId[theme.id] = theme;
    }
    final enabled = OccasionalTheme.parseBool(json['enabled']);
    if (enabled && byId.isEmpty) return null;
    return OccasionalThemeCatalog(
      enabled: enabled,
      allowUserSelection:
          OccasionalTheme.parseBool(json['allow_user_selection']),
      effectsEnabled: json.containsKey('effects_enabled')
          ? OccasionalTheme.parseBool(json['effects_enabled'])
          : true,
      allowUserEffectsToggle:
          OccasionalTheme.parseBool(json['allow_user_effects_toggle']),
      defaultThemeId:
          (json['default_theme_id'] ?? '').toString().trim().toLowerCase(),
      activeThemeId:
          (json['active_theme_id'] ?? '').toString().trim().toLowerCase(),
      resolvedAt: OccasionalTheme.parseDate(json['resolved_at']),
      schemaVersion: OccasionalTheme.parseInt(
        json['schema_version'],
        fallback: 2,
      ),
      themes: List<OccasionalTheme>.unmodifiable(byId.values),
    );
  }

  List<OccasionalTheme> activeThemesAt(DateTime now) {
    if (!enabled) return const <OccasionalTheme>[];
    final active = themes.where((theme) => theme.isActiveAt(now)).toList();
    active.sort((a, b) {
      final priority = b.priority.compareTo(a.priority);
      return priority != 0 ? priority : a.id.compareTo(b.id);
    });
    return List<OccasionalTheme>.unmodifiable(active);
  }

  List<OccasionalTheme> get activeThemes => activeThemesAt(DateTime.now());

  OccasionalTheme? resolve({
    required String selectedThemeId,
    DateTime? now,
  }) {
    final instant = (now ?? DateTime.now()).toUtc();
    final active = activeThemesAt(instant);
    if (active.isEmpty) return null;
    if (allowUserSelection && selectedThemeId != 'automatic') {
      for (final theme in active) {
        if (theme.userSelectable &&
            OccasionalTheme.canonicalId(theme.id) ==
                OccasionalTheme.canonicalId(selectedThemeId)) {
          return theme;
        }
      }
    }
    // A server choice applies to its snapshot window. After any local start
    // or end boundary, resolve again so an offline app keeps changing seasons.
    final crossedBoundary = resolvedAt != null && themes.any((theme) =>
        (theme.startsAt != null && theme.startsAt!.isAfter(resolvedAt!) &&
            !instant.isBefore(theme.startsAt!)) ||
        (theme.endsAt != null && !theme.endsAt!.isBefore(resolvedAt!) &&
            instant.isAfter(theme.endsAt!)));
    if (activeThemeId.isNotEmpty && !crossedBoundary) {
      for (final theme in active) {
        if (OccasionalTheme.canonicalId(theme.id) ==
            OccasionalTheme.canonicalId(activeThemeId)) {
          return theme;
        }
      }
    }
    if (defaultThemeId.isNotEmpty) {
      for (final theme in active) {
        if (OccasionalTheme.canonicalId(theme.id) ==
            OccasionalTheme.canonicalId(defaultThemeId)) {
          return theme;
        }
      }
    }
    return active.first;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schema_version': schemaVersion,
        'enabled': enabled,
        'allow_user_selection': allowUserSelection,
        'effects_enabled': effectsEnabled,
        'allow_user_effects_toggle': allowUserEffectsToggle,
        'default_theme_id': defaultThemeId,
        if (activeThemeId.isNotEmpty) 'active_theme_id': activeThemeId,
        if (resolvedAt != null) 'resolved_at': resolvedAt!.toUtc().toIso8601String(),
        'themes': themes.map((theme) => theme.toJson()).toList(),
      };

  String toJsonString() => jsonEncode(toJson());
}

class _OccasionalThemePreset {
  const _OccasionalThemePreset({
    this.isBuiltIn = false,
    required this.displayName,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.effectType,
    this.lightBackground,
    this.darkBackground,
  });

  final bool isBuiltIn;
  final String displayName;
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color? lightBackground;
  final Color? darkBackground;
  final OccasionalEffectType effectType;
}
