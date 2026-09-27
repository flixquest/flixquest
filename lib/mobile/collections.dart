import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../catalog/catalog_controller.dart';
import '../catalog/media_item.dart';
import '../models/genres.dart';
import '../provider/app_dependency_provider.dart';
import '../provider/settings_provider.dart';
import 'screens/collection_screen.dart';

/// Opens [genre]'s titles of [kind] in a grid, reporting the ad placement
/// the old genre pages did.
Future<void> openGenreCollection(
  BuildContext context,
  MediaKind kind,
  Genres genre,
) {
  final movie = kind == MediaKind.movie;
  final collection = const CatalogController().genreCollection(
    kind: kind,
    genre: genre,
    settings: context.read<SettingsProvider>(),
    dependencies: context.read<AppDependencyProvider>(),
  );
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => CollectionScreen(
        collection: MediaCollection(
          id: collection.id,
          title: collection.title,
          kicker: tr(movie ? 'movie_genres' : 'series_genres').toUpperCase(),
          adPlacement: movie ? 'genre_movies' : 'genre_tv',
          loadPage: collection.loadPage,
        ),
      ),
    ),
  );
}
