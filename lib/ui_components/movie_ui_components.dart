import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import '../functions/function.dart';
import '../models/movie.dart';
import '../provider/app_dependency_provider.dart';
import '../provider/settings_provider.dart';
import '../screens/movie/movie_detail.dart';
import '../widgets/common_widgets.dart';
import 'app_ui_components.dart';

class HorizontalScrollingMoviesList extends StatelessWidget {
  const HorizontalScrollingMoviesList({
    super.key,
    required ScrollController scrollController,
    required this.movieList,
    required this.imageQuality,
    required this.themeMode,
  }) : _scrollController = scrollController;

  final ScrollController _scrollController;
  final List<Movie>? movieList;
  final String imageQuality;
  final String themeMode;

  @override
  Widget build(BuildContext context) {
    final isProxyEnabled = Provider.of<SettingsProvider>(context).enableProxy;
    final proxyUrl = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      itemCount: movieList!.length,
      scrollDirection: Axis.horizontal,
      itemBuilder: (BuildContext context, int index) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => MovieDetailPage(
                          movie: movieList![index],
                          heroId: '${movieList![index].id}')));
            },
            child: SizedBox(
              width: 100,
              child: Column(
                children: <Widget>[
                  Expanded(
                    flex: 6,
                    child: Hero(
                      tag: '${movieList![index].id}',
                      child: Material(
                        type: MaterialType.transparency,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppUI.cardRadius),
                              child: movieList![index].posterPath == null
                                  ? Image.asset('assets/images/na_logo.png',
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity)
                                  : CachedNetworkImage(
                                      cacheManager: cacheProp(),
                                      fadeOutDuration:
                                          const Duration(milliseconds: 300),
                                      fadeOutCurve: Curves.easeOut,
                                      fadeInDuration:
                                          const Duration(milliseconds: 700),
                                      fadeInCurve: Curves.easeIn,
                                      imageUrl:
                                          movieList![index].posterPath == null
                                              ? ''
                                              : buildImageUrl(
                                                      TMDB_BASE_IMAGE_URL,
                                                      proxyUrl,
                                                      isProxyEnabled,
                                                      context) +
                                                  imageQuality +
                                                  movieList![index].posterPath!,
                                      imageBuilder: (context, imageProvider) =>
                                          Container(
                                        decoration: BoxDecoration(
                                          image: DecorationImage(
                                            image: imageProvider,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      placeholder: (context, url) =>
                                          scrollingImageShimmer(themeMode),
                                      errorWidget: (context, url, error) =>
                                          Image.asset(
                                              'assets/images/na_logo.png',
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity),
                                    ),
                            ),
                            Positioned(
                              top: 0,
                              left: 0,
                              child: Container(
                                margin: const EdgeInsets.all(3),
                                padding: EdgeInsets.symmetric(horizontal: 3),
                                alignment: Alignment.topLeft,
                                height: 25,
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: themeMode == 'dark' ||
                                            themeMode == 'amoled'
                                        ? Colors.black45
                                        : Colors.white60),
                                child: Row(
                                  children: [
                                    Icon(PhosphorIcons.star(PhosphorIconsStyle.fill),
                                    ),
                                    Text(movieList![index].voteAverage! % 1 == 0
                                        ? movieList![index]
                                            .voteAverage!
                                            .toInt()
                                            .toString()
                                        : movieList![index]
                                            .voteAverage!
                                            .toStringAsFixed(1))
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        movieList![index].title!,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class MovieListView extends StatelessWidget {
  const MovieListView({
    super.key,
    required ScrollController scrollController,
    required this.moviesList,
    required this.themeMode,
    required this.imageQuality,
  }) : _scrollController = scrollController;

  final ScrollController _scrollController;
  final List<Movie>? moviesList;
  final String themeMode;
  final String imageQuality;

  @override
  Widget build(BuildContext context) {
    final isProxyEnabled = context.watch<SettingsProvider>().enableProxy;
    final proxyUrl = context.watch<AppDependencyProvider>().tmdbProxy;

    return ListView.separated(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppUI.pagePadding(context),
        12,
        AppUI.pagePadding(context),
        24,
      ),
      itemCount: moviesList!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final movie = moviesList![index];
        return AppMediaListCard(
          title: movie.title ?? movie.originalTitle ?? '',
          date: movie.releaseDate,
          language: movie.originalLanguage,
          overview: movie.overview,
          rating: movie.voteAverage,
          voteCount: movie.voteCount,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MovieDetailPage(
                movie: movie,
                heroId: '${movie.id}',
              ),
            ),
          ),
          poster: Hero(
            tag: '${movie.id}',
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppUI.cardRadius),
                child: movie.posterPath == null
                    ? Image.asset(
                        'assets/images/na_logo.png',
                        fit: BoxFit.cover,
                      )
                    : CachedNetworkImage(
                        cacheManager: cacheProp(),
                        imageUrl: buildImageUrl(
                              TMDB_BASE_IMAGE_URL,
                              proxyUrl,
                              isProxyEnabled,
                              context,
                            ) +
                            imageQuality +
                            movie.posterPath!,
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
        );
      },
    );
  }
}

class MovieGridView extends StatelessWidget {
  const MovieGridView({
    super.key,
    required ScrollController scrollController,
    required this.moviesList,
    required this.imageQuality,
    required this.themeMode,
  }) : _scrollController = scrollController;

  final ScrollController _scrollController;
  final List<Movie>? moviesList;
  final String imageQuality;
  final String themeMode;

  @override
  Widget build(BuildContext context) {
    final isProxyEnabled = Provider.of<SettingsProvider>(context).enableProxy;
    final proxyUrl = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    return GridView.builder(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
            AppUI.pagePadding(context), 12, AppUI.pagePadding(context), 24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: AppUI.mediaGridColumns(context),
          childAspectRatio: AppUI.mediaGridChildAspectRatio(context),
          crossAxisSpacing: AppUI.mediaGridCrossAxisSpacing,
          mainAxisSpacing: 16,
        ),
        itemCount: moviesList!.length,
        itemBuilder: (BuildContext context, int index) {
          return GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) {
                return MovieDetailPage(
                    movie: moviesList![index],
                    heroId: '${moviesList![index].id}');
              }));
            },
            child: Padding(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: AppUI.posterAspectRatio,
                    child: Hero(
                      tag: '${moviesList![index].id}',
                      child: Material(
                        type: MaterialType.transparency,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppUI.cardRadius),
                              child: moviesList![index].posterPath == null
                                  ? Image.asset('assets/images/na_logo.png',
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity)
                                  : CachedNetworkImage(
                                      cacheManager: cacheProp(),
                                      fadeOutDuration:
                                          const Duration(milliseconds: 300),
                                      fadeOutCurve: Curves.easeOut,
                                      fadeInDuration:
                                          const Duration(milliseconds: 700),
                                      fadeInCurve: Curves.easeIn,
                                      imageUrl: buildImageUrl(
                                              TMDB_BASE_IMAGE_URL,
                                              proxyUrl,
                                              isProxyEnabled,
                                              context) +
                                          imageQuality +
                                          moviesList![index].posterPath!,
                                      imageBuilder: (context, imageProvider) =>
                                          Container(
                                        decoration: BoxDecoration(
                                          image: DecorationImage(
                                            image: imageProvider,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      placeholder: (context, url) =>
                                          scrollingImageShimmer(themeMode),
                                      errorWidget: (context, url, error) =>
                                          Image.asset(
                                              'assets/images/na_logo.png',
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity),
                                    ),
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: AppRatingBadge(
                                rating: moviesList![index].voteAverage,
                                compact: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppUI.mediaGridTitleGap),
                  SizedBox(
                      width: double.infinity,
                      height: AppUI.mediaGridTitleHeight,
                      child: Text(
                        moviesList![index].title!,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontFamily: 'FigtreeSB',
                            ),
                      )),
                ],
              ),
            ),
          );
        });
  }
}
