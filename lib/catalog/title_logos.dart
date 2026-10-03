import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:dio/dio.dart';

import '../core/error/failure_exception.dart';
import '../core/network/network_runtime.dart';
import '../data/repositories/tmdb_repository.dart';
import '../data/sources/tmdb_api.dart';

import '../api/endpoints.dart';
import 'media_item.dart';

/// Finds each title's logo artwork on TMDB and remembers it for the session,
/// so the spotlight can show the logo instead of the title's name.
///
/// Only the lookup is cached here; the images themselves go through the
/// usual image cache.
class TitleLogos {
  TitleLogos({
    required String language,
    required this.proxyEnabled,
    required this.proxyUrl,
    Dio? dio,
  })  : language = languageCode(language),
        _repository = dio == null ? NetworkRuntime.tmdb
            : TmdbRepository(TmdbApi(dio));

  /// ISO 639-1, the form TMDB tags images with.
  final String language;

  /// [language] as ISO 639-1: `pt-BR` is `pt`.
  static String languageCode(String language) =>
      language.split(RegExp('[-_]')).first.toLowerCase();
  final bool proxyEnabled;
  final String proxyUrl;
  final TmdbRepository _repository;
  final CancelToken _cancelToken = CancelToken();

  /// Bounds the cache on long sessions; a lookup is small, so this is about
  /// never growing without limit rather than about memory.
  static const _capacity = 400;

  final Map<String, String?> _known = <String, String?>{};
  final Map<String, Future<String?>> _pending = <String, Future<String?>>{};

  /// Whether [item]'s lookup has finished, with or without a logo.
  bool isKnown(MediaItem item) => _known.containsKey(_key(item));

  /// [item]'s logo path, once [isKnown].
  String? known(MediaItem item) => _known[_key(item)];

  /// [item]'s logo path, or null when it has none or the lookup failed.
  ///
  /// A failure is not remembered, so a later focus tries again.
  Future<String?> resolve(MediaItem item) {
    final key = _key(item);
    if (_known.containsKey(key)) return Future<String?>.value(_known[key]);
    if (item.id < 0) return Future<String?>.value();
    if (_pending[key] case final inFlight?) return inFlight;
    final pending = _fetch(item).then<String?>((path) {
      if (_known.length >= _capacity) _known.remove(_known.keys.first);
      _known[key] = path;
      return path;
    }, onError: (Object _) => null);
    // A block body: returning the removed future would make this wait on
    // itself.
    pending.whenComplete(() {
      _pending.remove(key);
    });
    return _pending[key] = pending;
  }

  void dispose() => _cancelToken.cancel('Title logos disposed');

  static String _key(MediaItem item) => '${item.kind.name}:${item.id}';

  Future<String?> _fetch(MediaItem item) async {
    final images = item.kind == MediaKind.movie
        ? Endpoints.getImages(item.id)
        : Endpoints.getTVImages(item.id);
    final url = '$images&include_image_language=$language,en,null';
    final result = await _repository.getJson(url,
      proxyEnabled: proxyEnabled, proxyUrl: proxyUrl,
      cancelToken: _cancelToken, timeout: const Duration(seconds: 12));
    final body = result.when(ok: (data) => data,
        err: (failure) => throw FailureException(failure));
    final logos = body['logos'];
    return pickTitleLogo(
      logos is List ? logos.whereType<Map<String, dynamic>>() : const [],
      language: language,
    );
  }
}

/// The logo to show from TMDB's `logos` list: the app's language first, then
/// English, then one without text, the best voted within each.
///
/// Leaves out SVGs, which the image cache cannot draw, and prefers wide
/// logos, since a tall one leaves the spotlight's title slot looking empty.
@visibleForTesting
String? pickTitleLogo(
  Iterable<Map<String, dynamic>> logos, {
  required String language,
}) {
  int tier(Object? tag) => switch (tag) {
        final String code when code == language => 0,
        'en' => 1,
        null => 2,
        _ => 3,
      };
  final candidates = logos
      .where((logo) =>
          logo['file_path'] is String &&
          !(logo['file_path'] as String).toLowerCase().endsWith('.svg') &&
          tier(logo['iso_639_1']) < 3)
      .toList();
  if (candidates.isEmpty) return null;
  num aspect(Map<String, dynamic> logo) => (logo['aspect_ratio'] as num?) ?? 2;
  num votes(Map<String, dynamic> logo) => (logo['vote_average'] as num?) ?? 0;
  // A stable sort, so TMDB's own order breaks the remaining ties.
  final ranked = candidates.indexed.toList()
    ..sort((a, b) {
      final byTier = tier(a.$2['iso_639_1']).compareTo(
        tier(b.$2['iso_639_1']),
      );
      if (byTier != 0) return byTier;
      final byShape = (aspect(a.$2) < 1 ? 1 : 0).compareTo(
        aspect(b.$2) < 1 ? 1 : 0,
      );
      if (byShape != 0) return byShape;
      final byVotes = votes(b.$2).compareTo(votes(a.$2));
      return byVotes != 0 ? byVotes : a.$1.compareTo(b.$1);
    });
  return ranked.first.$2['file_path'] as String;
}

/// Makes a [TitleLogos] available to the TV screens below it. Without one,
/// titles are shown as text.
class TitleLogoScope extends InheritedWidget {
  const TitleLogoScope({
    required this.logos,
    required super.child,
    super.key,
  });

  final TitleLogos logos;

  static TitleLogos? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TitleLogoScope>()?.logos;

  @override
  bool updateShouldNotify(TitleLogoScope oldWidget) =>
      !identical(logos, oldWidget.logos);
}
