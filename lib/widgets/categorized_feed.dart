import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/endpoints.dart';
import '../constants/api_constants.dart';
import '../functions/network.dart';
import '../functions/function.dart';
import '../models/genres.dart';
import '../provider/app_dependency_provider.dart';
import '../provider/settings_provider.dart';
import '../screens/movie/genremovies.dart';
import '../screens/movie/movie_detail.dart';
import '../screens/tv/genre_tv.dart';
import '../screens/tv/tv_detail.dart';
import '../ui_components/app_ui_components.dart';
import 'common_widgets.dart';

class CategorizedFeedItem {
  final int id;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final double voteAverage;
  final String? releaseYear;
  final VoidCallback onTap;
  final bool isAdult;
  final String heroId;

  CategorizedFeedItem({
    required this.id,
    required this.title,
    this.posterPath,
    this.backdropPath,
    required this.voteAverage,
    this.releaseYear,
    required this.onTap,
    required this.isAdult,
    required this.heroId,
  });
}

enum CategorizedLayoutType {
  heroBackdrop,
  mediumBackdrops,
  doublePoster,
  singleBackdrop,
  singlePoster,
}

class RandomCategorizedFeed extends StatefulWidget {
  final bool isTv;

  const RandomCategorizedFeed({super.key, required this.isTv});

  @override
  State<RandomCategorizedFeed> createState() => _RandomCategorizedFeedState();
}

class _RandomCategorizedFeedState extends State<RandomCategorizedFeed> {
  List<Genres>? _genres;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRandomGenres();
  }

  Future<void> _fetchRandomGenres() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final dependencies =
        Provider.of<AppDependencyProvider>(context, listen: false);

    final url = widget.isTv
        ? Endpoints.tvGenresUrl(settings.appLanguage)
        : Endpoints.movieGenresUrl(settings.appLanguage);

    try {
      final allGenres = await fetchGenre(
        url,
        settings.enableProxy,
        dependencies.tmdbProxy,
      );

      if (allGenres.isNotEmpty) {
        allGenres.shuffle(Random());
        setState(() {
          _genres = allGenres.take(5).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Column(
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                SizedBox(
                    width: 150, height: 24, child: AppShimmerBlock(radius: 6)),
                SizedBox(
                    width: 60, height: 16, child: AppShimmerBlock(radius: 4)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: AppUI.horizontalCardWidth(context) * 1.5 + 46,
            child: const AppMediaRowShimmer(),
          ),
        ],
      );
    }
    if (_genres == null || _genres!.isEmpty) {
      return const SizedBox.shrink();
    }

    final layouts = [
      CategorizedLayoutType.heroBackdrop,
      CategorizedLayoutType.mediumBackdrops,
      CategorizedLayoutType.doublePoster,
      CategorizedLayoutType.singleBackdrop,
      CategorizedLayoutType.singlePoster,
    ];
    layouts.shuffle(Random());

    return Column(
      children: List.generate(_genres!.length, (index) {
        final genre = _genres![index];
        final layout = layouts[index % layouts.length];
        return _CategorySection(
          genre: genre,
          isTv: widget.isTv,
          layout: layout,
        );
      }),
    );
  }
}

class _CategorySection extends StatefulWidget {
  final Genres genre;
  final bool isTv;
  final CategorizedLayoutType layout;

  const _CategorySection({
    required this.genre,
    required this.isTv,
    required this.layout,
  });

  @override
  State<_CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<_CategorySection>
    with AutomaticKeepAliveClientMixin {
  List<CategorizedFeedItem>? _items;
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final dependencies =
        Provider.of<AppDependencyProvider>(context, listen: false);

    final url = widget.isTv
        ? Endpoints.getTVShowsForGenre(
            widget.genre.genreID!, 1, settings.appLanguage)
        : Endpoints.getMoviesForGenre(
            widget.genre.genreID!, 1, settings.appLanguage);

    try {
      if (widget.isTv) {
        final tvs =
            await fetchTV(url, settings.enableProxy, dependencies.tmdbProxy);
        if (mounted) {
          setState(() {
            _items = tvs.map((tv) {
              final year =
                  DateTime.tryParse(tv.firstAirDate ?? '')?.year.toString();
              return CategorizedFeedItem(
                id: tv.id ?? 0,
                title: tv.name ?? tr('not_available'),
                posterPath: tv.posterPath,
                backdropPath: tv.backdropPath,
                voteAverage: (tv.voteAverage ?? 0.0).toDouble(),
                releaseYear: year,
                isAdult: tv.adult ?? false,
                heroId: 'cat_feed_${tv.id}_${widget.genre.genreID}',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TVDetailPage(
                        tvSeries: tv,
                        heroId: 'cat_feed_${tv.id}_${widget.genre.genreID}',
                      ),
                    ),
                  );
                },
              );
            }).toList();
            _isLoading = false;
          });
        }
      } else {
        final movies = await fetchMovies(
            url, settings.enableProxy, dependencies.tmdbProxy);
        if (mounted) {
          setState(() {
            _items = movies.map((movie) {
              final year =
                  DateTime.tryParse(movie.releaseDate ?? '')?.year.toString();
              return CategorizedFeedItem(
                id: movie.id ?? 0,
                title: movie.title ?? tr('not_available'),
                posterPath: movie.posterPath,
                backdropPath: movie.backdropPath,
                voteAverage: (movie.voteAverage ?? 0.0).toDouble(),
                releaseYear: year,
                isAdult: movie.adult ?? false,
                heroId: 'cat_feed_${movie.id}_${widget.genre.genreID}',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MovieDetailPage(
                        movie: movie,
                        heroId: 'cat_feed_${movie.id}_${widget.genre.genreID}',
                      ),
                    ),
                  );
                },
              );
            }).toList();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return _buildShimmer(context);
    }
    if (_items == null || _items!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.genre.genreName ?? '',
                  style: const TextStyle(
                    fontFamily: 'FigtreeSB',
                    fontSize: 21,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => widget.isTv
                          ? TVGenre(genres: widget.genre)
                          : GenreMovies(genres: widget.genre),
                    ),
                  );
                },
                child: Text(
                  tr('view_all'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 13,
                    fontFamily: 'FigtreeSB',
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildLayoutContent(context),
      ],
    );
  }

  Widget _buildShimmer(BuildContext context) {
    final cardWidth = AppUI.horizontalCardWidth(context);
    final cardHeight = cardWidth * 1.5 + 46;

    Widget content;
    switch (widget.layout) {
      case CategorizedLayoutType.heroBackdrop:
        content = Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: SizedBox(
                width: double.infinity,
                height: MediaQuery.of(context).size.width * 0.56,
                child: const AppShimmerBlock(radius: AppUI.cardRadius),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: cardHeight,
              child: const AppMediaRowShimmer(),
            ),
          ],
        );
        break;
      case CategorizedLayoutType.mediumBackdrops:
        content = Column(
          children: [
            SizedBox(
              height: 140,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 3,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, __) => const SizedBox(
                  width: 240,
                  height: 140,
                  child: AppShimmerBlock(radius: AppUI.cardRadius),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: cardHeight,
              child: const AppMediaRowShimmer(),
            ),
          ],
        );
        break;
      case CategorizedLayoutType.doublePoster:
        content = SizedBox(
          height: cardHeight * 2 + 16,
          child: Column(
            children: [
              SizedBox(height: cardHeight, child: const AppMediaRowShimmer()),
              const SizedBox(height: 16),
              SizedBox(height: cardHeight, child: const AppMediaRowShimmer()),
            ],
          ),
        );
        break;
      case CategorizedLayoutType.singleBackdrop:
        content = SizedBox(
          height: 140,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => const SizedBox(
              width: 240,
              height: 140,
              child: AppShimmerBlock(radius: AppUI.cardRadius),
            ),
          ),
        );
        break;
      case CategorizedLayoutType.singlePoster:
        content = SizedBox(
          height: cardHeight,
          child: const AppMediaRowShimmer(),
        );
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              SizedBox(
                width: 150,
                height: 24,
                child: AppShimmerBlock(radius: 6),
              ),
              SizedBox(
                width: 60,
                height: 16,
                child: AppShimmerBlock(radius: 4),
              ),
            ],
          ),
        ),
        content,
      ],
    );
  }

  Widget _buildLayoutContent(BuildContext context) {
    switch (widget.layout) {
      case CategorizedLayoutType.heroBackdrop:
        return _HeroBackdropLayout(items: _items!);
      case CategorizedLayoutType.mediumBackdrops:
        return _MediumBackdropsLayout(items: _items!);
      case CategorizedLayoutType.doublePoster:
        return _DoublePosterLayout(items: _items!);
      case CategorizedLayoutType.singleBackdrop:
        return _SingleBackdropLayout(items: _items!);
      case CategorizedLayoutType.singlePoster:
        return _SinglePosterLayout(items: _items!);
    }
  }
}

// -----------------------------------------------------------------------------
// LAYOUT IMPLEMENTATIONS
// -----------------------------------------------------------------------------

class _CategorizedPosterCard extends StatelessWidget {
  final CategorizedFeedItem item;
  const _CategorizedPosterCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final dependencies = Provider.of<AppDependencyProvider>(context);
    final cardWidth = AppUI.horizontalCardWidth(context);

    return GestureDetector(
      onTap: item.onTap,
      child: SizedBox(
        width: cardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: cardWidth * 1.5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppUI.cardRadius),
                child: Hero(
                  tag: item.heroId,
                  child: item.posterPath == null
                      ? Image.asset('assets/images/na_logo.png',
                          fit: BoxFit.cover)
                      : CachedNetworkImage(
                          imageUrl: buildImageUrl(
                                TMDB_BASE_IMAGE_URL,
                                dependencies.tmdbProxy,
                                settings.enableProxy,
                                context,
                              ) +
                              settings.imageQuality +
                              item.posterPath!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              scrollingImageShimmer(settings.appTheme),
                          errorWidget: (_, __, ___) => Image.asset(
                              'assets/images/na_logo.png',
                              fit: BoxFit.cover),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'FigtreeSB',
                  ),
            ),
            if (item.releaseYear != null)
              Text(
                item.releaseYear!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategorizedBackdropCard extends StatelessWidget {
  final CategorizedFeedItem item;
  final double width;
  final double height;
  const _CategorizedBackdropCard({
    required this.item,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final dependencies = Provider.of<AppDependencyProvider>(context);

    return GestureDetector(
      onTap: item.onTap,
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppUI.cardRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: item.heroId,
                child: item.backdropPath == null
                    ? Image.asset('assets/images/na_logo.png',
                        fit: BoxFit.cover)
                    : CachedNetworkImage(
                        imageUrl: '${buildImageUrl(
                          TMDB_BASE_IMAGE_URL,
                          dependencies.tmdbProxy,
                          settings.enableProxy,
                          context,
                        )}w780${item.backdropPath!}',
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            scrollingImageShimmer(settings.appTheme),
                        errorWidget: (_, __, ___) => Image.asset(
                            'assets/images/na_logo.png',
                            fit: BoxFit.cover),
                      ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'FigtreeSB',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (item.releaseYear != null) ...[
                          Text(
                            item.releaseYear!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(PhosphorIcons.star(PhosphorIconsStyle.fill),
                                  color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                item.voteAverage.toStringAsFixed(1),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroBackdropLayout extends StatelessWidget {
  final List<CategorizedFeedItem> items;
  const _HeroBackdropLayout({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final heroItem = items.first;
    final remainingItems = items.skip(1).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: _CategorizedBackdropCard(
            item: heroItem,
            width: double.infinity,
            height: MediaQuery.of(context).size.width * 0.56, // roughly 16:9
          ),
        ),
        const SizedBox(height: 16),
        _SinglePosterLayout(items: remainingItems),
      ],
    );
  }
}

class _MediumBackdropsLayout extends StatelessWidget {
  final List<CategorizedFeedItem> items;
  const _MediumBackdropsLayout({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    // Use first 2 or 3 items as backdrops
    final backdropCount = items.length >= 3 ? 3 : items.length;
    final backdropItems = items.take(backdropCount).toList();
    final remainingItems = items.skip(backdropCount).toList();

    return Column(
      children: [
        SizedBox(
          height: 140,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: backdropItems.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return _CategorizedBackdropCard(
                item: backdropItems[index],
                width: 240,
                height: 140,
              );
            },
          ),
        ),
        if (remainingItems.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SinglePosterLayout(items: remainingItems),
        ]
      ],
    );
  }
}

class _DoublePosterLayout extends StatelessWidget {
  final List<CategorizedFeedItem> items;
  const _DoublePosterLayout({required this.items});

  @override
  Widget build(BuildContext context) {
    final cardWidth = AppUI.horizontalCardWidth(context);
    final cardHeight = cardWidth * 1.5 + 46; // Poster + text

    return SizedBox(
      height: cardHeight * 2 + 16, // Two rows + spacing
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: (items.length / 2).ceil(),
        itemBuilder: (context, index) {
          final firstIndex = index * 2;
          final secondIndex = firstIndex + 1;

          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Column(
              children: [
                if (firstIndex < items.length)
                  _CategorizedPosterCard(
                      item: firstIndex < items.length
                          ? items[firstIndex]
                          : items.first),
                const SizedBox(height: 16),
                if (secondIndex < items.length)
                  _CategorizedPosterCard(
                      item: secondIndex < items.length
                          ? items[secondIndex]
                          : items.first),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SingleBackdropLayout extends StatelessWidget {
  final List<CategorizedFeedItem> items;
  const _SingleBackdropLayout({required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return _CategorizedBackdropCard(
            item: items[index],
            width: 240,
            height: 140,
          );
        },
      ),
    );
  }
}

class _SinglePosterLayout extends StatelessWidget {
  final List<CategorizedFeedItem> items;
  const _SinglePosterLayout({required this.items});

  @override
  Widget build(BuildContext context) {
    final cardWidth = AppUI.horizontalCardWidth(context);
    final cardHeight =
        cardWidth * 1.5 + 46; // Roughly poster height + text height

    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return _CategorizedPosterCard(item: items[index]);
        },
      ),
    );
  }
}
