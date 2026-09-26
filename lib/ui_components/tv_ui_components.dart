import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import '../functions/function.dart';
import '../models/tv.dart';
import '../provider/app_dependency_provider.dart';
import '../provider/settings_provider.dart';
import '../screens/tv/tv_detail.dart';
import '../widgets/common_widgets.dart';
import 'app_ui_components.dart';

class HorizontalScrollingTVList extends StatelessWidget {
  const HorizontalScrollingTVList({
    super.key,
    required ScrollController scrollController,
    required this.tvList,
    required this.imageQuality,
    required this.themeMode,
  }) : _scrollController = scrollController;

  final ScrollController _scrollController;
  final List<TV>? tvList;
  final String imageQuality;
  final String themeMode;

  @override
  Widget build(BuildContext context) {
    final isProxyEnabled = Provider.of<SettingsProvider>(context).enableProxy;
    final proxyUrl = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      itemCount: tvList!.length,
      scrollDirection: Axis.horizontal,
      itemBuilder: (BuildContext context, int index) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => TVDetailPage(
                          tvSeries: tvList![index],
                          heroId: '${tvList![index].id}')));
            },
            child: SizedBox(
              width: 100,
              child: Column(
                children: <Widget>[
                  Expanded(
                    flex: 6,
                    child: Hero(
                      tag: '${tvList![index].id}',
                      child: Material(
                        type: MaterialType.transparency,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppUI.cardRadius),
                              child: tvList![index].posterPath == null
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
                                          tvList![index].posterPath == null
                                              ? ''
                                              : buildImageUrl(
                                                      TMDB_BASE_IMAGE_URL,
                                                      proxyUrl,
                                                      isProxyEnabled,
                                                      context) +
                                                  imageQuality +
                                                  tvList![index].posterPath!,
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
                                alignment: Alignment.topLeft,
                                padding: EdgeInsets.symmetric(horizontal: 3),
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
                                    Text(tvList![index].voteAverage! % 1 == 0
                                        ? tvList![index]
                                            .voteAverage!
                                            .toInt()
                                            .toString()
                                        : tvList![index]
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
                        tvList![index].name!,
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

class TVListView extends StatelessWidget {
  const TVListView({
    super.key,
    required ScrollController scrollController,
    required this.tvList,
    required this.themeMode,
    required this.imageQuality,
  }) : _scrollController = scrollController;

  final ScrollController _scrollController;
  final List<TV>? tvList;
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
      itemCount: tvList!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final show = tvList![index];
        return AppMediaListCard(
          title: show.name ?? show.originalName ?? '',
          date: show.firstAirDate,
          language: show.originalLanguage,
          overview: show.overview,
          rating: show.voteAverage,
          voteCount: show.voteCount,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TVDetailPage(
                tvSeries: show,
                heroId: '${show.id}',
              ),
            ),
          ),
          poster: Hero(
            tag: '${show.id}',
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppUI.cardRadius),
                child: show.posterPath == null
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
                            show.posterPath!,
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

class TVGridView extends StatelessWidget {
  const TVGridView({
    super.key,
    required this.tvList,
    required this.imageQuality,
    required this.themeMode,
    required this.scrollController,
  });

  final List<TV>? tvList;
  final String imageQuality;
  final String themeMode;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final isProxyEnabled = Provider.of<SettingsProvider>(context).enableProxy;
    final proxyUrl = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    return GridView.builder(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(
            AppUI.pagePadding(context), 12, AppUI.pagePadding(context), 24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: AppUI.mediaGridColumns(context),
          childAspectRatio: AppUI.mediaGridChildAspectRatio(context),
          crossAxisSpacing: AppUI.mediaGridCrossAxisSpacing,
          mainAxisSpacing: 16,
        ),
        itemCount: tvList!.length,
        itemBuilder: (BuildContext context, int index) {
          return GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) {
                return TVDetailPage(
                    tvSeries: tvList![index], heroId: '${tvList![index].id}');
              }));
            },
            child: Padding(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: AppUI.posterAspectRatio,
                    child: Hero(
                      tag: '${tvList![index].id}',
                      child: Material(
                        type: MaterialType.transparency,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppUI.cardRadius),
                              child: tvList![index].posterPath == null
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
                                          tvList![index].posterPath!,
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
                                rating: tvList![index].voteAverage,
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
                        tvList![index].name!,
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
