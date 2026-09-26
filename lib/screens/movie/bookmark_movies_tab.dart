import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/api_constants.dart';
import '../../constants/app_constants.dart';
import '../../functions/function.dart';
import '../../models/movie.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../../ui_components/app_ui_components.dart';
import '../../provider/bookmark_provider.dart';
import '../../widgets/common_widgets.dart';
import 'movie_detail.dart';

class MovieBookmark extends StatefulWidget {
  const MovieBookmark({required this.movieList, super.key});

  final List<Movie>? movieList;

  @override
  State<MovieBookmark> createState() => _MovieBookmarkState();
}

class _MovieBookmarkState extends State<MovieBookmark> {
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final proxy = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    final items = widget.movieList;
    if (items == null) return moviesAndTVShowGridShimmer(settings.appTheme);
    if (items.isEmpty) {
      return AppEmptyState(
        title: tr('bookmarks'),
        message: tr('no_movies_bookmarked'),
        icon: PhosphorIcons.bookmarkSimple(),
      );
    }
    return settings.defaultView == 'list'
        ? _buildList(context, items, settings, proxy)
        : _buildGrid(context, items, settings, proxy);
  }

  Widget _buildGrid(BuildContext context, List<Movie> items,
      SettingsProvider settings, String proxy) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
          AppUI.pagePadding(context), 18, AppUI.pagePadding(context), 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: AppUI.mediaGridColumns(context),
        childAspectRatio: AppUI.mediaGridChildAspectRatio(context),
        crossAxisSpacing: AppUI.mediaGridCrossAxisSpacing,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length,
      itemBuilder: (_, index) => _MovieGridCard(
        movie: items[index],
        imageUrl: _imageUrl(context, items[index], settings, proxy),
        onOpen: () => _open(items[index]),
        onRemove: () => _remove(items, index),
        themeMode: settings.appTheme,
      ),
    );
  }

  Widget _buildList(BuildContext context, List<Movie> items,
      SettingsProvider settings, String proxy) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
          AppUI.pagePadding(context), 16, AppUI.pagePadding(context), 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final movie = items[index];
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: () => _open(movie),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppUI.cardRadius),
                    child: CachedNetworkImage(
                      cacheManager: cacheProp(),
                      imageUrl: _imageUrl(context, movie, settings, proxy),
                      width: 92,
                      height: 132,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          scrollingImageShimmer(settings.appTheme),
                      errorWidget: (_, __, ___) => Image.asset(
                        'assets/images/na_logo.png',
                        width: 92,
                        height: 132,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(movie.title ?? tr('not_available'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 10),
                        Row(children: [
                          AppRatingBadge(
                              rating: movie.voteAverage, compact: true),
                          const SizedBox(width: 10),
                          Text(_year(movie.releaseDate)),
                        ]),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: tr('delete'),
                    onPressed: () => _remove(items, index),
                    icon: Icon(PhosphorIcons.bookmarkSimple()),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _imageUrl(BuildContext context, Movie movie, SettingsProvider settings,
      String proxy) {
    if (movie.posterPath == null) return '';
    return buildImageUrl(
            TMDB_BASE_IMAGE_URL, proxy, settings.enableProxy, context) +
        settings.imageQuality +
        movie.posterPath!;
  }

  String _year(String? value) =>
      value != null && value.length >= 4 ? value.substring(0, 4) : '—';

  void _open(Movie movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MovieDetailPage(movie: movie, heroId: '${movie.id}'),
      ),
    );
  }

  Future<void> _remove(List<Movie> items, int index) async {
    final id = items[index].id;
    if (id != null) {
      await Provider.of<BookmarkProvider>(context, listen: false).removeMovie(id);
    }
  }
}

class _MovieGridCard extends StatelessWidget {
  const _MovieGridCard({
    required this.movie,
    required this.imageUrl,
    required this.onOpen,
    required this.onRemove,
    required this.themeMode,
  });

  final Movie movie;
  final String imageUrl;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  final String themeMode;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppUI.cardRadius),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: AppUI.posterAspectRatio,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Hero(
                    tag: '${movie.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppUI.cardRadius),
                      child: CachedNetworkImage(
                        cacheManager: cacheProp(),
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            scrollingImageShimmer(themeMode),
                        errorWidget: (_, __, ___) => Image.asset(
                          'assets/images/na_logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AppRatingBadge(rating: movie.voteAverage, compact: true),
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: IconButton.filledTonal(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          tooltip: tr('delete'),
                          onPressed: onRemove,
                          icon: Icon(PhosphorIcons.x(), size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppUI.mediaGridTitleGap),
          SizedBox(
            width: double.infinity,
            height: AppUI.mediaGridTitleHeight,
            child: Text(
              movie.title ?? tr('not_available'),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontFamily: 'FigtreeSB',
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
