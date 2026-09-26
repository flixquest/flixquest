import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:readmore/readmore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/endpoints.dart';
import '../constants/app_constants.dart';
import '../functions/function.dart';
import '../provider/app_dependency_provider.dart';
import '../ui_components/app_ui_components.dart';
import '../video_providers/scraper_api.dart';
import '../widgets/hosted_ads_banner.dart';
import '/constants/api_constants.dart';
import '/functions/network.dart';
import '/models/images.dart';
import '/models/movie.dart';
import '/models/person.dart';
import '/models/tv.dart';
import '/provider/settings_provider.dart';
import '/screens/common/hero_photoview.dart';
import '/screens/movie/movie_detail.dart';
import '/screens/tv/tv_detail.dart';

/// The single detail surface shared by every person entry point — cast, crew,
/// created-by, guest star and search results.
///
/// Every one of those screens used to carry its own near-identical copy of the
/// header and tab scaffolding; they now differ only in the data they hand in.
class PersonDetailView extends StatefulWidget {
  const PersonDetailView({
    required this.personId,
    required this.name,
    required this.heroId,
    this.profilePath,
    this.subtitle,
    this.isPersonAdult,
    super.key,
  });

  final int personId;
  final String name;
  final String heroId;
  final String? profilePath;
  final String? subtitle;
  final bool? isPersonAdult;

  @override
  State<PersonDetailView> createState() => _PersonDetailViewState();
}

class _PersonDetailViewState extends State<PersonDetailView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  late Future<PersonDetails> _details;
  late Future<ExternalLinks> _socialLinks;
  late Future<PersonImages> _images;
  late Future<List<Movie>> _movies;
  late Future<List<TV>> _tvShows;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(_onTabChanged);
    _loadPageData();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) setState(() {});
  }

  void _loadPageData() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final dependencies =
        Provider.of<AppDependencyProvider>(context, listen: false);
    final proxy = settings.enableProxy;
    final proxyUrl = dependencies.tmdbProxy;
    final lang = settings.appLanguage;

    _details = fetchPersonDetails(
        Endpoints.getPersonDetails(widget.personId, lang), proxy, proxyUrl);
    _socialLinks = fetchSocialLinks(
        Endpoints.getExternalLinksForPerson(widget.personId, lang),
        proxy,
        proxyUrl);
    _images = fetchPersonImages(
        Endpoints.getPersonImages(widget.personId), proxy, proxyUrl);
    _movies = fetchPersonMovies(
        Endpoints.getMovieCreditsForPerson(widget.personId, lang),
        proxy,
        proxyUrl);
    _tvShows = fetchPersonTV(
        Endpoints.getTVCreditsForPerson(widget.personId, lang),
        proxy,
        proxyUrl);
  }

  @override
  Widget build(BuildContext context) {
    final heroHeight =
        (MediaQuery.sizeOf(context).height * .34).clamp(260.0, 340.0);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: heroHeight,
            toolbarHeight: 64,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            titleSpacing: 4,
            leadingWidth: 68,
            leading: Padding(
              padding: const EdgeInsetsDirectional.only(start: 12),
              child: _PersonHeroButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: PhosphorIcons.caretLeft(),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            title: AnimatedBuilder(
              animation: _scrollController,
              builder: (context, _) {
                final collapseAt = heroHeight -
                    kToolbarHeight -
                    MediaQuery.paddingOf(context).top -
                    12;
                final visible = _scrollController.hasClients &&
                    _scrollController.offset >= collapseAt;
                return AnimatedOpacity(
                  opacity: visible ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: Text(
                    widget.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontFamily: 'FigtreeSB',
                        ),
                  ),
                );
              },
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              stretchModes: const [StretchMode.zoomBackground],
              background: _PersonHero(
                name: widget.name,
                subtitle: widget.subtitle,
                profilePath: widget.profilePath,
                heroId: widget.heroId,
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _PersonTabHeaderDelegate(
              controller: _tabController,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              dividerColor: colors.outlineVariant,
            ),
          ),
          SliverToBoxAdapter(
            child: AppResponsiveContent(
              padding: EdgeInsets.fromLTRB(
                AppUI.pagePadding(context),
                20,
                AppUI.pagePadding(context),
                48 + MediaQuery.paddingOf(context).bottom,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: KeyedSubtree(
                  key: ValueKey(_tabController.index),
                  child: _buildSelectedTab(),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: RemoteHostedAdsBanner(
              placement: 'person_detail',
              variant: HostedBannerVariant.tall,
              loadAds: () => ScraperApi(
                context.read<AppDependencyProvider>().flixquestAPIURL,
              ).getAds(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedTab() {
    switch (_tabController.index) {
      case 1:
        return PersonMovieListWidget(
          movies: _movies,
          isPersonAdult: widget.isPersonAdult,
          includeAdult: Provider.of<SettingsProvider>(context).isAdult,
          onRetry: () => setState(_loadPageData),
        );
      case 2:
        return PersonTVListWidget(
          tvShows: _tvShows,
          isPersonAdult: widget.isPersonAdult,
          includeAdult: Provider.of<SettingsProvider>(context).isAdult,
          onRetry: () => setState(_loadPageData),
        );
      default:
        return _PersonAboutTab(
          personName: widget.name,
          details: _details,
          socialLinks: _socialLinks,
          images: _images,
          onRetry: () => setState(_loadPageData),
        );
    }
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

/// The person artwork header: the profile photo doubles as a blurred backdrop
/// so short, portrait-only artwork still fills the hero area.
class _PersonHero extends StatelessWidget {
  const _PersonHero({
    required this.name,
    required this.heroId,
    this.subtitle,
    this.profilePath,
  });

  final String name;
  final String heroId;
  final String? subtitle;
  final String? profilePath;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final dependencies = Provider.of<AppDependencyProvider>(context);
    final colors = Theme.of(context).colorScheme;
    final imageUrl = profilePath == null
        ? null
        : buildImageUrl(
              TMDB_BASE_IMAGE_URL,
              dependencies.tmdbProxy,
              settings.enableProxy,
              context,
            ) +
            settings.imageQuality +
            profilePath!;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageUrl == null)
          ColoredBox(color: colors.primary.withValues(alpha: .12))
        else
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
            child: CachedNetworkImage(
              cacheManager: cacheProp(),
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              placeholder: (_, __) => const AppShimmerBlock(radius: 0),
              errorWidget: (_, __, ___) =>
                  ColoredBox(color: colors.primary.withValues(alpha: .12)),
            ),
          ),
        const AppDetailHeroGradient(),
        Positioned.fill(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppUI.pagePadding(context),
                64,
                AppUI.pagePadding(context),
                18,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Hero(
                    tag: heroId,
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                        width: 108,
                        height: 108,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .82),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .3),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: imageUrl == null
                              ? Image.asset('assets/images/na_rect.png',
                                  fit: BoxFit.cover)
                              : CachedNetworkImage(
                                  cacheManager: cacheProp(),
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) =>
                                      const AppShimmerBlock(radius: 60),
                                  errorWidget: (_, __, ___) => Image.asset(
                                    'assets/images/na_rect.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 12),
                      ],
                    ),
                  ),
                  if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .38),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        child: Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PersonHeroButton extends StatelessWidget {
  const _PersonHeroButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox.square(
        dimension: 42,
        child: Material(
          color: Colors.black.withValues(alpha: .38),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            color: Colors.white,
            padding: EdgeInsets.zero,
            icon: Icon(icon, size: 21),
          ),
        ),
      ),
    );
  }
}

class _PersonTabHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _PersonTabHeaderDelegate({
    required this.controller,
    required this.backgroundColor,
    required this.dividerColor,
  });

  final TabController controller;
  final Color backgroundColor;
  final Color dividerColor;

  @override
  double get minExtent => 60;

  @override
  double get maxExtent => 60;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: backgroundColor,
      elevation: overlapsContent ? 1 : 0,
      shadowColor: Colors.black.withValues(alpha: .12),
      child: AppResponsiveContent(
        padding: EdgeInsets.symmetric(horizontal: AppUI.pagePadding(context)),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => Row(
            children: [
              _PersonTabButton(
                label: tr('about'),
                selected: controller.index == 0,
                onTap: () => controller.animateTo(0),
              ),
              _PersonTabButton(
                label: tr('movies'),
                selected: controller.index == 1,
                onTap: () => controller.animateTo(1),
              ),
              _PersonTabButton(
                label: tr('tv_shows'),
                selected: controller.index == 2,
                onTap: () => controller.animateTo(2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PersonTabHeaderDelegate oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.dividerColor != dividerColor;
  }
}

class _PersonTabButton extends StatelessWidget {
  const _PersonTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = selected ? colors.primary : colors.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 7, 4, 5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: color,
                      height: 1.05,
                      fontFamily: selected ? 'FigtreeSB' : null,
                    ),
              ),
              const SizedBox(height: 9),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: selected ? 34 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonAboutTab extends StatelessWidget {
  const _PersonAboutTab({
    required this.personName,
    required this.details,
    required this.socialLinks,
    required this.images,
    required this.onRetry,
  });

  final String personName;
  final Future<PersonDetails> details;
  final Future<ExternalLinks> socialLinks;
  final Future<PersonImages> images;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PersonAboutWidget(details: details, onRetry: onRetry),
        const SizedBox(height: 28),
        PersonDataTable(details: details),
        const SizedBox(height: 28),
        PersonImagesDisplay(
          images: images,
          title: tr('images'),
          personName: personName,
          onRetry: onRetry,
        ),
        const SizedBox(height: 28),
        PersonSectionHeading(title: tr('social_media_links')),
        const SizedBox(height: 12),
        PersonSocialLinks(links: socialLinks, onRetry: onRetry),
      ],
    );
  }
}

/// The biography block.
class PersonAboutWidget extends StatelessWidget {
  const PersonAboutWidget({
    required this.details,
    required this.onRetry,
    super.key,
  });

  final Future<PersonDetails> details;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PersonSectionHeading(title: tr('biography')),
        const SizedBox(height: 12),
        FutureBuilder<PersonDetails>(
          future: details,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return PersonInlineError(onRetry: onRetry);
            }
            if (!snapshot.hasData) {
              return const _PersonTextShimmer(lines: 4);
            }
            final biography = snapshot.data?.biography?.trim() ?? '';
            return ReadMoreText(
              biography.isEmpty ? tr('no_biography_person') : biography,
              trimLines: 5,
              trimMode: TrimMode.Line,
              trimCollapsedText: tr('read_more'),
              trimExpandedText: tr('read_less'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.5,
                  ),
              colorClickableText: colors.primary,
              lessStyle: TextStyle(
                fontFamily: 'FigtreeSB',
                color: colors.primary,
              ),
              moreStyle: TextStyle(
                fontFamily: 'FigtreeSB',
                color: colors.primary,
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Birth / death / origin facts, presented with the same tiles the movie and
/// TV info grids use.
class PersonDataTable extends StatelessWidget {
  const PersonDataTable({required this.details, super.key});

  final Future<PersonDetails> details;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PersonDetails>(
      future: details,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _PersonTileGridShimmer();
        }
        final person = snapshot.data!;
        final born = person.birthday;
        final died = person.deathday;
        final rows = <(IconData, String, String)>[
          (
            died != null ? PhosphorIcons.flowerLotus() : PhosphorIcons.cake(),
            died != null && born != null ? tr('died_aged') : tr('age'),
            _age(born, died),
          ),
          (PhosphorIcons.calendarBlank(), tr('born_on'), _birthDate(born)),
          (
            PhosphorIcons.mapPin(),
            tr('from'),
            person.birthPlace?.trim().isNotEmpty == true
                ? person.birthPlace!
                : tr('not_available'),
          ),
        ];
        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 820 ? 3 : 2;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: rows
                  .map((row) => SizedBox(
                        width: width,
                        child: PersonInfoTile(
                          icon: row.$1,
                          label: row.$2,
                          value: row.$3,
                        ),
                      ))
                  .toList(),
            );
          },
        );
      },
    );
  }

  String _age(String? birthday, String? deathday) {
    if (birthday == null) return tr('not_available');
    final born = DateTime.tryParse(birthday);
    if (born == null) return tr('not_available');
    final until = deathday == null
        ? DateTime.now()
        : DateTime.tryParse(deathday) ?? DateTime.now();
    var age = until.year - born.year;
    final hadBirthday = until.month > born.month ||
        (until.month == born.month && until.day >= born.day);
    if (!hadBirthday) age -= 1;
    return age < 0 ? tr('not_available') : '$age';
  }

  String _birthDate(String? birthday) {
    if (birthday == null) return tr('not_available');
    final born = DateTime.tryParse(birthday);
    if (born == null) return tr('not_available');
    return '${born.day} ${DateFormat.MMMM().format(born)}, ${born.year}';
  }
}

/// Outlined link buttons, matching the movie and TV detail social rows.
class PersonSocialLinks extends StatelessWidget {
  const PersonSocialLinks({
    required this.links,
    required this.onRetry,
    super.key,
  });

  final Future<ExternalLinks> links;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ExternalLinks>(
      future: links,
      builder: (context, snapshot) {
        if (snapshot.hasError) return PersonInlineError(onRetry: onRetry);
        if (!snapshot.hasData) {
          return const _PersonChipRowShimmer();
        }
        final data = snapshot.data!;
        final items = <(IconData, String, String)>[
          if (data.facebookUsername != null)
            (
              PhosphorIcons.facebookLogo(),
              'Facebook',
              '$FACEBOOK_BASE_URL${data.facebookUsername}'
            ),
          if (data.instagramUsername != null)
            (
              PhosphorIcons.instagramLogo(),
              'Instagram',
              '$INSTAGRAM_BASE_URL${data.instagramUsername}'
            ),
          if (data.twitterUsername != null)
            (
              PhosphorIcons.twitterLogo(),
              'X',
              '$TWITTER_BASE_URL${data.twitterUsername}'
            ),
          if (data.imdbId != null)
            (PhosphorIcons.filmSlate(), 'IMDb', '$IMDB_BASE_URL${data.imdbId}'),
        ];
        if (items.isEmpty) {
          return PersonCompactEmpty(
            icon: PhosphorIcons.linkBreak(),
            message: tr('no_social_link_person'),
          );
        }
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map(
                (item) => OutlinedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(item.$3),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: Icon(item.$1, size: 17),
                  label: Text(item.$2),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

/// A horizontal rail of profile photos that opens the full-screen viewer.
class PersonImagesDisplay extends StatelessWidget {
  const PersonImagesDisplay({
    required this.images,
    required this.title,
    required this.personName,
    required this.onRetry,
    super.key,
  });

  final Future<PersonImages> images;
  final String title;
  final String personName;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final dependencies = Provider.of<AppDependencyProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PersonSectionHeading(title: title),
        const SizedBox(height: 12),
        FutureBuilder<PersonImages>(
          future: images,
          builder: (context, snapshot) {
            if (snapshot.hasError) return PersonInlineError(onRetry: onRetry);
            if (!snapshot.hasData) {
              return const SizedBox(height: 170, child: _PersonImageShimmer());
            }
            final profiles = snapshot.data?.profile ?? const <Profiles>[];
            if (profiles.isEmpty) {
              return PersonCompactEmpty(
                icon: PhosphorIcons.imageBroken(),
                message: tr('no_images_person'),
              );
            }
            return SizedBox(
              height: 170,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: profiles.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final path = profiles[index].filePath;
                  if (path == null) return const SizedBox.shrink();
                  final url = buildImageUrl(
                        TMDB_BASE_IMAGE_URL,
                        dependencies.tmdbProxy,
                        settings.enableProxy,
                        context,
                      ) +
                      settings.imageQuality +
                      path;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(AppUI.cardRadius),
                    child: SizedBox(
                      width: 113,
                      child: CachedNetworkImage(
                        cacheManager: cacheProp(),
                        imageUrl: url,
                        fit: BoxFit.cover,
                        imageBuilder: (context, imageProvider) => InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HeroPhotoView(
                                imageProvider: imageProvider,
                                currentIndex: index,
                                heroId: url,
                                name: personName,
                              ),
                            ),
                          ),
                          child: Ink.image(
                              image: imageProvider, fit: BoxFit.cover),
                        ),
                        placeholder: (_, __) => const AppShimmerBlock(),
                        errorWidget: (_, __, ___) => Image.asset(
                          'assets/images/na_rect.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

/// The person's filmography grid, sharing the app-wide poster grid metrics.
class PersonMovieListWidget extends StatelessWidget {
  const PersonMovieListWidget({
    required this.movies,
    required this.includeAdult,
    required this.onRetry,
    this.isPersonAdult,
    super.key,
  });

  final Future<List<Movie>> movies;
  final bool? isPersonAdult;
  final bool? includeAdult;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isPersonAdult == true && includeAdult == false) {
      return PersonCompactEmpty(
        icon: PhosphorIcons.eyeSlash(),
        message: tr('contains_nsfw'),
      );
    }
    return FutureBuilder<List<Movie>>(
      future: movies,
      builder: (context, snapshot) {
        if (snapshot.hasError) return PersonInlineError(onRetry: onRetry);
        if (!snapshot.hasData) return const _PersonPosterGridShimmer();
        final unique = _dedupe(snapshot.data!, (movie) => movie.id);
        if (unique.isEmpty) {
          return PersonCompactEmpty(
            icon: PhosphorIcons.filmStrip(),
            message: tr('no_movies_person'),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PersonSectionHeading(
              title: tr('person_movie_count',
                  namedArgs: {'count': '${unique.length}'}),
            ),
            const SizedBox(height: 12),
            _PersonPosterGrid(
              itemCount: unique.length,
              posterPath: (index) => unique[index].posterPath,
              title: (index) => unique[index].title ?? '',
              rating: (index) => unique[index].voteAverage,
              // Namespaced so a person id and a credited movie id sharing the
              // same number can never register the same hero tag twice.
              heroTag: (index) => 'person_movie_${unique[index].id}',
              onTap: (index) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MovieDetailPage(
                    movie: unique[index],
                    heroId: 'person_movie_${unique[index].id}',
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class PersonTVListWidget extends StatelessWidget {
  const PersonTVListWidget({
    required this.tvShows,
    required this.includeAdult,
    required this.onRetry,
    this.isPersonAdult,
    super.key,
  });

  final Future<List<TV>> tvShows;
  final bool? isPersonAdult;
  final bool? includeAdult;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isPersonAdult == true && includeAdult == false) {
      return PersonCompactEmpty(
        icon: PhosphorIcons.eyeSlash(),
        message: tr('contains_nsfw'),
      );
    }
    return FutureBuilder<List<TV>>(
      future: tvShows,
      builder: (context, snapshot) {
        if (snapshot.hasError) return PersonInlineError(onRetry: onRetry);
        if (!snapshot.hasData) return const _PersonPosterGridShimmer();
        final unique = _dedupe(snapshot.data!, (tv) => tv.id);
        if (unique.isEmpty) {
          return PersonCompactEmpty(
            icon: PhosphorIcons.television(),
            message: tr('no_tv_person'),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PersonSectionHeading(
              title: tr('person_tv_count',
                  namedArgs: {'count': '${unique.length}'}),
            ),
            const SizedBox(height: 12),
            _PersonPosterGrid(
              itemCount: unique.length,
              posterPath: (index) => unique[index].posterPath,
              title: (index) =>
                  unique[index].name ?? unique[index].originalName ?? '',
              rating: (index) => unique[index].voteAverage,
              heroTag: (index) => 'person_tv_${unique[index].id}',
              onTap: (index) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TVDetailPage(
                    tvSeries: unique[index],
                    heroId: 'person_tv_${unique[index].id}',
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

List<T> _dedupe<T>(List<T> items, int? Function(T) id) {
  final seen = <int>{};
  final result = <T>[];
  for (final item in items) {
    final key = id(item);
    if (key == null || seen.add(key)) result.add(item);
  }
  return result;
}

class _PersonPosterGrid extends StatelessWidget {
  const _PersonPosterGrid({
    required this.itemCount,
    required this.posterPath,
    required this.title,
    required this.rating,
    required this.heroTag,
    required this.onTap,
  });

  final int itemCount;
  final String? Function(int) posterPath;
  final String Function(int) title;
  final num? Function(int) rating;
  final String Function(int) heroTag;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final dependencies = Provider.of<AppDependencyProvider>(context);
    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: AppUI.mediaGridColumns(context),
        childAspectRatio: AppUI.mediaGridChildAspectRatio(context),
        crossAxisSpacing: AppUI.mediaGridCrossAxisSpacing,
        mainAxisSpacing: 16,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        final path = posterPath(index);
        return GestureDetector(
          onTap: () => onTap(index),
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: AppUI.posterAspectRatio,
                child: Hero(
                  tag: heroTag(index),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(AppUI.cardRadius),
                            child: path == null
                                ? Image.asset('assets/images/na_logo.png',
                                    fit: BoxFit.cover)
                                : CachedNetworkImage(
                                    cacheManager: cacheProp(),
                                    imageUrl: buildImageUrl(
                                          TMDB_BASE_IMAGE_URL,
                                          dependencies.tmdbProxy,
                                          settings.enableProxy,
                                          context,
                                        ) +
                                        settings.imageQuality +
                                        path,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) =>
                                        const AppShimmerBlock(),
                                    errorWidget: (_, __, ___) => Image.asset(
                                      'assets/images/na_logo.png',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                          ),
                        ),
                        PositionedDirectional(
                          top: 8,
                          start: 8,
                          child: AppRatingBadge(
                              rating: rating(index), compact: true),
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
                  title(index),
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
      },
    );
  }
}

class PersonSectionHeading extends StatelessWidget {
  const PersonSectionHeading({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleLarge,
    );
  }
}

class PersonInfoTile extends StatelessWidget {
  const PersonInfoTile({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 94),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colors.primary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'FigtreeSB',
                ),
          ),
        ],
      ),
    );
  }
}

class PersonCompactEmpty extends StatelessWidget {
  const PersonCompactEmpty({
    required this.icon,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: colors.primary),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class PersonInlineError extends StatelessWidget {
  const PersonInlineError({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(PhosphorIcons.cloudSlash(), color: colors.error),
          const SizedBox(width: 12),
          Expanded(child: Text(tr('check_connection'))),
          TextButton(onPressed: onRetry, child: Text(tr('retry'))),
        ],
      ),
    );
  }
}

class _PersonTextShimmer extends StatelessWidget {
  const _PersonTextShimmer({required this.lines});

  final int lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < lines; i++) ...[
          if (i != 0) const SizedBox(height: 9),
          SizedBox(
            height: 13,
            child: FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: i == lines - 1 ? .55 : 1,
              child: const AppShimmerBlock(radius: 6),
            ),
          ),
        ],
      ],
    );
  }
}

class _PersonChipRowShimmer extends StatelessWidget {
  const _PersonChipRowShimmer();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        3,
        (index) => Padding(
          padding: EdgeInsetsDirectional.only(end: index == 2 ? 0 : 10),
          child: const SizedBox(
            width: 108,
            height: 44,
            child: AppShimmerBlock(),
          ),
        ),
      ),
    );
  }
}

class _PersonImageShimmer extends StatelessWidget {
  const _PersonImageShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (_, __) => const SizedBox(
        width: 113,
        child: AppShimmerBlock(),
      ),
    );
  }
}

class _PersonTileGridShimmer extends StatelessWidget {
  const _PersonTileGridShimmer();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 820 ? 3 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(
            3,
            (_) => SizedBox(
              width: width,
              height: 94,
              child: const AppShimmerBlock(radius: 7),
            ),
          ),
        );
      },
    );
  }
}

class _PersonPosterGridShimmer extends StatelessWidget {
  const _PersonPosterGridShimmer();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: AppUI.mediaGridColumns(context),
        childAspectRatio: AppUI.mediaGridChildAspectRatio(context),
        crossAxisSpacing: AppUI.mediaGridCrossAxisSpacing,
        mainAxisSpacing: 16,
      ),
      itemCount: AppUI.mediaGridColumns(context) * 3,
      itemBuilder: (_, __) => Column(
        children: [
          const AspectRatio(
            aspectRatio: AppUI.posterAspectRatio,
            child: AppShimmerBlock(),
          ),
          const SizedBox(height: AppUI.mediaGridTitleGap),
          const SizedBox(
            height: AppUI.mediaGridTitleHeight,
            child: FractionallySizedBox(
              widthFactor: .8,
              heightFactor: .4,
              child: AppShimmerBlock(radius: 6),
            ),
          ),
        ],
      ),
    );
  }
}
