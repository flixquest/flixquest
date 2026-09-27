import 'package:flutter/material.dart';

import '../../catalog/media_item.dart';
import '../../mobile/screens/title_details_screen.dart';
import '../../models/movie.dart';

/// A movie's page. Links, bookmarks, people and collections open movies by
/// this name; the page itself is the phone's [TitleDetailsScreen].
class MovieDetailPage extends StatelessWidget {
  const MovieDetailPage({
    super.key,
    required this.movie,
    required this.heroId,
  });

  final Movie movie;

  /// Kept for the callers that pass one; the page has no shared element.
  final String heroId;

  @override
  Widget build(BuildContext context) =>
      TitleDetailsScreen(item: MediaItem.fromMovie(movie));
}
