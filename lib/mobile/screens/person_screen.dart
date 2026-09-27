import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../api/endpoints.dart';
import '../../catalog/media_item.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../design/skeleton.dart';
import '../../functions/network.dart';
import '../../models/images.dart';
import '../../models/movie.dart';
import '../../models/person.dart';
import '../../models/tv.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../../screens/common/hero_photoview.dart';
import '../../video_providers/scraper_api.dart';
import '../../widgets/hosted_ads_banner.dart';
import '../widgets/details_parts.dart';
import '../widgets/media_art.dart';
import '../widgets/page_kit.dart';
import '../widgets/poster_card.dart';
import '../widgets/section_header.dart';

enum _Kind { movies, series }

/// A person's page: their portrait, name and what they're known for, when
/// and where they were born, their biography and links, then everything
/// they've been in as posters, a kind at a time, and their photos.
class PersonScreen extends StatefulWidget {
  const PersonScreen({
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

  /// What they were to the page that opened this one: a character, a job.
  final String? subtitle;
  final bool? isPersonAdult;

  @override
  State<PersonScreen> createState() => _PersonScreenState();
}

class _PersonScreenState extends State<PersonScreen> {
  late Future<PersonDetails> _details;
  late Future<ExternalLinks> _links;
  late Future<PersonImages> _images;
  late Future<List<Movie>> _movies;
  late Future<List<TV>> _series;
  final ScrollController _scroll = ScrollController();
  bool _started = false;
  bool _named = false;
  bool _bioOpen = false;
  _Kind _kind = _Kind.movies;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final named = _scroll.hasClients && _scroll.offset > 150;
      if (named != _named) setState(() => _named = named);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _load() {
    final settings = context.read<SettingsProvider>();
    final proxy = context.read<AppDependencyProvider>().tmdbProxy;
    final proxied = settings.enableProxy;
    final language = settings.appLanguage;
    final id = widget.personId;
    _details = fetchPersonDetails(
      Endpoints.getPersonDetails(id, language),
      proxied,
      proxy,
    )..ignore();
    _links = fetchSocialLinks(
      Endpoints.getExternalLinksForPerson(id, language),
      proxied,
      proxy,
    )..ignore();
    _images = fetchPersonImages(
      Endpoints.getPersonImages(id),
      proxied,
      proxy,
    )..ignore();
    _movies = fetchPersonMovies(
      Endpoints.getMovieCreditsForPerson(id, language),
      proxied,
      proxy,
    )..ignore();
    _series = fetchPersonTV(
      Endpoints.getTVCreditsForPerson(id, language),
      proxied,
      proxy,
    )..ignore();
  }

  void _retry() => setState(_load);

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      body: CustomScrollView(
        controller: _scroll,
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            backgroundColor: palette.page,
            surfaceTintColor: Colors.transparent,
            foregroundColor: palette.foreground,
            titleSpacing: 0,
            title: AnimatedOpacity(
              opacity: _named ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              child: Text(
                widget.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.sectionHeader.copyWith(
                  color: palette.foreground,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _header(context)),
          SliverToBoxAdapter(child: _biography(context)),
          SliverToBoxAdapter(child: _socialLinks(context)),
          SliverToBoxAdapter(
            child: RemoteHostedAdsBanner(
              placement: 'person_detail',
              variant: HostedBannerVariant.tall,
              loadAds: () => ScraperApi(
                context.read<AppDependencyProvider>().flixquestAPIURL,
              ).getAds(),
            ),
          ),
          ..._filmography(context),
          SliverToBoxAdapter(child: _photos(context)),
          SliverToBoxAdapter(
            child: SizedBox(
              height: AppSpace.xxxl + MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ],
      ),
    );
  }

  /// The portrait beside the name, the role that led here, and the facts.
  Widget _header(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    const portrait = 112.0;
    final url = tmdbImageUrl(context, widget.profilePath, size: 'w342/');
    final subtitle = widget.subtitle?.trim() ?? '';
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, AppSpace.xs, gutter, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Hero(
            tag: widget.heroId,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.card),
              child: SizedBox(
                width: portrait,
                height: portrait / PosterCard.aspectRatio,
                child: url == null
                    ? ColoredBox(
                        color: palette.raisedSurface,
                        child: Icon(
                          PhosphorIcons.user(),
                          size: 40,
                          color: palette.mutedText,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            ColoredBox(color: palette.raisedSurface),
                        errorWidget: (_, __, ___) => ColoredBox(
                          color: palette.raisedSurface,
                          child: Icon(
                            PhosphorIcons.user(),
                            size: 40,
                            color: palette.mutedText,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: AppSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.name,
                  style: AppType.scaled(context, AppType.pageTitle)
                      .copyWith(color: palette.foreground),
                ),
                if (subtitle.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body.copyWith(color: palette.secondaryText),
                  ),
                ],
                const SizedBox(height: AppSpace.sm),
                FutureBuilder<PersonDetails>(
                  future: _details,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const SkeletonPulse(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            SkeletonBlock.line(width: 90),
                            SizedBox(height: AppSpace.sm),
                            SkeletonBlock.line(width: 150),
                            SizedBox(height: AppSpace.sm),
                            SkeletonBlock.line(width: 120),
                          ],
                        ),
                      );
                    }
                    final person = snapshot.data;
                    if (person == null) return const SizedBox.shrink();
                    return _facts(context, person);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _facts(BuildContext context, PersonDetails person) {
    final palette = AppPalette.of(context);
    final locale = Localizations.localeOf(context).toString();
    final born = DateTime.tryParse(person.birthday ?? '');
    final died = DateTime.tryParse(person.deathday ?? '');
    final place = person.birthPlace?.trim() ?? '';
    final department = person.department?.trim() ?? '';
    final age = _age(born, died);
    Widget line(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(
            text,
            style: AppType.metadata.copyWith(
              fontSize: 13,
              height: 1.35,
              color: palette.mutedText,
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (department.isNotEmpty) line(department),
        if (born != null)
          line('${tr('born_on')} ${DateFormat.yMMMMd(locale).format(born)}'),
        if (age != null)
          line('${died != null ? tr('died_aged') : tr('age')} $age'),
        if (place.isNotEmpty) line('${tr('from')} $place'),
      ],
    );
  }

  static int? _age(DateTime? born, DateTime? died) {
    if (born == null) return null;
    final until = died ?? DateTime.now();
    var age = until.year - born.year;
    final hadBirthday = until.month > born.month ||
        (until.month == born.month && until.day >= born.day);
    if (!hadBirthday) age -= 1;
    return age < 0 ? null : age;
  }

  Widget _biography(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, AppSpace.xl, gutter, 0),
      child: FutureBuilder<PersonDetails>(
        future: _details,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SkeletonPulse(
              child: Column(
                children: <Widget>[
                  SkeletonBlock.line(height: 13),
                  SizedBox(height: AppSpace.sm),
                  SkeletonBlock.line(height: 13),
                  SizedBox(height: AppSpace.sm),
                  SkeletonBlock.line(height: 13),
                ],
              ),
            );
          }
          if (snapshot.hasError) {
            return DetailsMessage(
              message: tr('check_connection'),
              onRetry: _retry,
            );
          }
          final biography = snapshot.data?.biography?.trim() ?? '';
          if (biography.isEmpty) {
            return Text(
              tr('no_biography_person'),
              style: AppType.body.copyWith(color: palette.mutedText),
            );
          }
          return Semantics(
            button: true,
            onTapHint: _bioOpen ? tr('read_less') : tr('read_more'),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _bioOpen = !_bioOpen),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: AlignmentDirectional.topStart,
                child: Text(
                  biography,
                  maxLines: _bioOpen ? null : 5,
                  overflow: _bioOpen ? null : TextOverflow.ellipsis,
                  style: AppType.body.copyWith(color: palette.secondaryText),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _socialLinks(BuildContext context) {
    final gutter = AppSpace.gutter(context);
    return FutureBuilder<ExternalLinks>(
      future: _links,
      builder: (context, snapshot) {
        final links = snapshot.data;
        if (links == null || !SocialLinks.any(links)) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: EdgeInsets.fromLTRB(gutter, AppSpace.lg, gutter, 0),
          child: SocialLinks(links: links),
        );
      },
    );
  }

  /// Everything they've been in, a kind at a time, most popular first.
  List<Widget> _filmography(BuildContext context) {
    final gutter = AppSpace.gutter(context);
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= AppBreakpoints.tablet ? 5 : 3;
    const spacing = 10.0;
    final poster = (width - gutter * 2 - spacing * (columns - 1)) / columns;
    final hidden = widget.isPersonAdult == true &&
        !context.watch<SettingsProvider>().isAdult;
    return <Widget>[
      SliverPadding(
        padding: EdgeInsets.fromLTRB(gutter, AppSpace.xxl, gutter, AppSpace.md),
        sliver: SliverToBoxAdapter(
          child: SegmentSwitch<_Kind>(
            segments: <Segment<_Kind>>[
              Segment(
                _Kind.movies,
                tr('movies'),
                icon: PhosphorIcons.filmSlate(),
              ),
              Segment(
                _Kind.series,
                tr('tv_shows'),
                icon: PhosphorIcons.television(),
              ),
            ],
            selected: _kind,
            onChanged: (kind) => setState(() => _kind = kind),
          ),
        ),
      ),
      if (hidden)
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          sliver: SliverToBoxAdapter(
            child: DetailsMessage(message: tr('contains_nsfw')),
          ),
        )
      else
        SliverToBoxAdapter(
          child: FutureBuilder<List<MediaItem>>(
            key: ValueKey<_Kind>(_kind),
            future: _titles(_kind),
            builder: (context, snapshot) {
              Widget wrap(List<Widget> children) => Padding(
                    padding: EdgeInsets.symmetric(horizontal: gutter),
                    child: Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: children,
                    ),
                  );
              if (snapshot.connectionState != ConnectionState.done) {
                return SkeletonPulse(
                  child: wrap(<Widget>[
                    for (var i = 0; i < columns * 2; i++)
                      SkeletonBlock(
                        width: poster,
                        height: poster / PosterCard.aspectRatio,
                      ),
                  ]),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  child: DetailsMessage(
                    message: tr('check_connection'),
                    onRetry: _retry,
                  ),
                );
              }
              final items = snapshot.data ?? const <MediaItem>[];
              if (items.isEmpty) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  child: DetailsMessage(
                    message: tr(
                      _kind == _Kind.movies
                          ? 'no_movies_person'
                          : 'no_tv_person',
                    ),
                  ),
                );
              }
              return wrap(<Widget>[
                for (final item in items) PosterCard(item: item, width: poster),
              ]);
            },
          ),
        ),
    ];
  }

  final Map<_Kind, Future<List<MediaItem>>> _titleCache =
      <_Kind, Future<List<MediaItem>>>{};

  /// A kind's titles, each once, most popular first.
  Future<List<MediaItem>> _titles(_Kind kind) =>
      _titleCache.putIfAbsent(kind, () async {
        final seen = <int>{};
        if (kind == _Kind.movies) {
          final movies = List<Movie>.of(await _movies)
            ..sort((a, b) => (b.popularity ?? 0).compareTo(a.popularity ?? 0));
          return <MediaItem>[
            for (final movie in movies)
              if (movie.id != null && seen.add(movie.id!))
                MediaItem.fromMovie(movie),
          ];
        }
        final series = List<TV>.of(await _series)
          ..sort((a, b) => (b.popularity ?? 0).compareTo(a.popularity ?? 0));
        return <MediaItem>[
          for (final show in series)
            if (show.id != null && seen.add(show.id!))
              MediaItem.fromSeries(show),
        ];
      });

  Widget _photos(BuildContext context) => FutureBuilder<PersonImages>(
        future: _images,
        builder: (context, snapshot) {
          final paths = <String>[
            for (final profile in snapshot.data?.profile ?? const <Profiles>[])
              if (profile.filePath case final path?) path,
          ];
          if (paths.length < 2) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: AppSpace.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionHeader(title: tr('images')),
                ImageRow(
                  paths: paths,
                  aspectRatio: 2 / 3,
                  onOpen: (index) {
                    final url = tmdbImageUrl(
                      context,
                      paths[index],
                      listen: false,
                    );
                    if (url == null) return;
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => HeroPhotoView(
                          imageProvider: CachedNetworkImageProvider(url),
                          currentIndex: index,
                          heroId: url,
                          name: widget.name,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      );
}
