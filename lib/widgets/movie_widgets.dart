// ignore_for_file: avoid_unnecessary_containers, use_build_context_synchronously
import 'dart:async';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flixquest/functions/function.dart';
import 'package:flixquest/services/globle_method.dart';
import '../models/movie_stream_metadata.dart';
import '/provider/app_dependency_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../screens/movie/movie_video_loader.dart';
import '../ui_components/app_ui_components.dart';
import '/screens/common/photoview.dart';
import '../provider/settings_provider.dart';
import '/constants/app_constants.dart';
import '/models/videos.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../functions/network.dart';
import '/constants/api_constants.dart';
import '/models/images.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'common_widgets.dart';

class MovieImagesDisplay extends StatefulWidget {
  final String? api, title, name;
  const MovieImagesDisplay({super.key, this.api, this.name, this.title});

  @override
  MovieImagesState createState() => MovieImagesState();
}

class MovieImagesState extends State<MovieImagesDisplay> {
  Images? movieImages;
  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchImages(widget.api!, isProxyEnabled, proxyUrl).then((value) {
      if (mounted) {
        setState(() {
          movieImages = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final imageQuality = Provider.of<SettingsProvider>(context).imageQuality;
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final isProxyEnabled = Provider.of<SettingsProvider>(context).enableProxy;
    final proxyUrl = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    return SizedBox(
      height: 260,
      width: double.infinity,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      const LeadingDot(),
                      Expanded(
                        child: Text(
                          widget.title!,
                          style:
                              kTextHeaderStyle, /*style: widget.themeData!.textTheme.bodyText1*/
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: SizedBox(
              width: double.infinity,
              height: 220,
              child: movieImages == null
                  ? detailImageShimmer(themeMode)
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: CarouselSlider(
                        options: CarouselOptions(
                          enableInfiniteScroll: false,
                          viewportFraction: 1,
                        ),
                        items: [
                          Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: Container(
                                  child: Container(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Stack(
                                          alignment:
                                              AlignmentDirectional.bottomStart,
                                          children: [
                                            SizedBox(
                                              height: 180,
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(AppUI.cardRadius),
                                                child: movieImages!
                                                        .poster!.isEmpty
                                                    ? Image.asset(
                                                        'assets/images/na_logo.png',
                                                        fit: BoxFit.cover,
                                                        height: double.infinity,
                                                        width: double.infinity)
                                                    : CachedNetworkImage(
                                                        cacheManager:
                                                            cacheProp(),
                                                        fadeOutDuration:
                                                            const Duration(
                                                                milliseconds:
                                                                    300),
                                                        fadeOutCurve:
                                                            Curves.easeOut,
                                                        fadeInDuration:
                                                            const Duration(
                                                                milliseconds:
                                                                    700),
                                                        fadeInCurve:
                                                            Curves.easeIn,
                                                        imageUrl: buildImageUrl(
                                                                TMDB_BASE_IMAGE_URL,
                                                                proxyUrl,
                                                                isProxyEnabled,
                                                                context) +
                                                            imageQuality +
                                                            movieImages!
                                                                .poster![0]
                                                                .posterPath!,
                                                        imageBuilder: (context,
                                                                imageProvider) =>
                                                            GestureDetector(
                                                          onTap: () {
                                                            Navigator.push(
                                                                context,
                                                                MaterialPageRoute(
                                                                    builder:
                                                                        ((context) {
                                                              return HeroPhotoView(
                                                                posters:
                                                                    movieImages!
                                                                        .poster!,
                                                                name:
                                                                    widget.name,
                                                                imageType:
                                                                    'poster',
                                                              );
                                                            })));
                                                          },
                                                          child: Hero(
                                                            tag: buildImageUrl(
                                                                    TMDB_BASE_IMAGE_URL,
                                                                    proxyUrl,
                                                                    isProxyEnabled,
                                                                    context) +
                                                                imageQuality +
                                                                movieImages!
                                                                    .poster![0]
                                                                    .posterPath!,
                                                            child: Container(
                                                              decoration:
                                                                  BoxDecoration(
                                                                image:
                                                                    DecorationImage(
                                                                  image:
                                                                      imageProvider,
                                                                  fit: BoxFit
                                                                      .cover,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        placeholder: (context,
                                                                url) =>
                                                            detailImageImageSimmer(
                                                                themeMode),
                                                        errorWidget: (context,
                                                                url, error) =>
                                                            Image.asset(
                                                                'assets/images/na_logo.png',
                                                                fit: BoxFit
                                                                    .cover,
                                                                height: double
                                                                    .infinity,
                                                                width: double
                                                                    .infinity),
                                                      ),
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: Container(
                                                color: Colors.black38,
                                                child: Text(movieImages!
                                                            .poster!.length ==
                                                        1
                                                    ? tr('poster_singular',
                                                        namedArgs: {
                                                            'poster':
                                                                movieImages!
                                                                    .poster!
                                                                    .length
                                                                    .toString()
                                                          })
                                                    : tr('poster_plural',
                                                        namedArgs: {
                                                            'poster':
                                                                movieImages!
                                                                    .poster!
                                                                    .length
                                                                    .toString()
                                                          })),
                                              ),
                                            )
                                          ]),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Stack(
                                        alignment:
                                            AlignmentDirectional.bottomStart,
                                        children: [
                                          SizedBox(
                                            height: 180,
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(AppUI.cardRadius),
                                              child: movieImages!
                                                      .backdrop!.isEmpty
                                                  ? Image.asset(
                                                      'assets/images/na_logo.png',
                                                      fit: BoxFit.cover,
                                                    )
                                                  : CachedNetworkImage(
                                                      cacheManager: cacheProp(),
                                                      fadeOutDuration:
                                                          const Duration(
                                                              milliseconds:
                                                                  300),
                                                      fadeOutCurve:
                                                          Curves.easeOut,
                                                      fadeInDuration:
                                                          const Duration(
                                                              milliseconds:
                                                                  700),
                                                      fadeInCurve:
                                                          Curves.easeIn,
                                                      imageUrl: buildImageUrl(
                                                              TMDB_BASE_IMAGE_URL,
                                                              proxyUrl,
                                                              isProxyEnabled,
                                                              context) +
                                                          imageQuality +
                                                          movieImages!
                                                              .backdrop![0]
                                                              .filePath!,
                                                      imageBuilder: (context,
                                                              imageProvider) =>
                                                          GestureDetector(
                                                        onTap: () {
                                                          Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                  builder:
                                                                      ((context) {
                                                            return HeroPhotoView(
                                                              backdrops:
                                                                  movieImages!
                                                                      .backdrop!,
                                                              name: widget.name,
                                                              imageType:
                                                                  'backdrop',
                                                            );
                                                          })));
                                                        },
                                                        child: Hero(
                                                          tag: buildImageUrl(
                                                                  TMDB_BASE_IMAGE_URL,
                                                                  proxyUrl,
                                                                  isProxyEnabled,
                                                                  context) +
                                                              imageQuality +
                                                              movieImages!
                                                                  .backdrop![0]
                                                                  .filePath!,
                                                          child: Container(
                                                            decoration:
                                                                BoxDecoration(
                                                              image:
                                                                  DecorationImage(
                                                                image:
                                                                    imageProvider,
                                                                fit: BoxFit
                                                                    .cover,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      placeholder: (context,
                                                              url) =>
                                                          detailImageImageSimmer(
                                                              themeMode),
                                                      errorWidget: (context,
                                                              url, error) =>
                                                          Image.asset(
                                                        'assets/images/na_logo.png',
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Container(
                                              color: Colors.black38,
                                              child: Text(movieImages!
                                                          .backdrop!.length ==
                                                      1
                                                  ? tr('backdrop_singular',
                                                      namedArgs: {
                                                          'backdrop':
                                                              movieImages!
                                                                  .backdrop!
                                                                  .length
                                                                  .toString()
                                                        })
                                                  : tr('backdrop_plural',
                                                      namedArgs: {
                                                          'backdrop':
                                                              movieImages!
                                                                  .backdrop!
                                                                  .length
                                                                  .toString()
                                                        })),
                                            ),
                                          )
                                        ]),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class MovieVideosDisplay extends StatefulWidget {
  final String? api, title;
  const MovieVideosDisplay({super.key, this.api, this.title});

  @override
  MovieVideosState createState() => MovieVideosState();
}

class MovieVideosState extends State<MovieVideosDisplay> {
  Videos? movieVideos;

  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchVideos(widget.api!, isProxyEnabled, proxyUrl).then((value) {
      if (mounted) {
        setState(() {
          movieVideos = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool playButtonVisibility = true;
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    return Column(
      children: [
        movieVideos == null
            ? Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          const LeadingDot(),
                          Expanded(
                            child: Text(
                              widget.title!,
                              style:
                                  kTextHeaderStyle, /* style: widget.themeData!.textTheme.bodyText1*/
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          const LeadingDot(),
                          Expanded(
                            child: Text(
                              widget.title!,
                              style:
                                  kTextHeaderStyle, /*style: widget.themeData!.textTheme.bodyText1*/
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
        Container(
          child: SizedBox(
            width: double.infinity,
            height: 230,
            child: movieVideos == null
                ? detailVideoShimmer(themeMode)
                : movieVideos!.result!.isEmpty
                    ? SizedBox(
                        width: double.infinity,
                        height: 80,
                        child: Center(
                          child: Text(tr('no_video_movie'),
                              textAlign: TextAlign.center),
                        ),
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: CarouselSlider.builder(
                          options: CarouselOptions(
                            disableCenter: true,
                            viewportFraction: 0.8,
                            enlargeCenterPage: false,
                            autoPlay: true,
                          ),
                          itemBuilder:
                              (BuildContext context, int index, pageViewIndex) {
                            return Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: GestureDetector(
                                onTap: () {
                                  launchUrl(
                                      Uri.parse(YOUTUBE_BASE_URL +
                                          movieVideos!
                                              .result![index].videoLink!),
                                      mode: LaunchMode.externalApplication);
                                },
                                child: SizedBox(
                                  height: 205,
                                  width: double.infinity,
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: 200,
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(AppUI.cardRadius),
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  CachedNetworkImage(
                                                    cacheManager: cacheProp(),
                                                    fadeOutDuration:
                                                        const Duration(
                                                            milliseconds: 300),
                                                    fadeOutCurve:
                                                        Curves.easeOut,
                                                    fadeInDuration:
                                                        const Duration(
                                                            milliseconds: 700),
                                                    fadeInCurve: Curves.easeIn,
                                                    imageUrl:
                                                        '$YOUTUBE_THUMBNAIL_URL${movieVideos!.result![index].videoLink!}/hqdefault.jpg',
                                                    imageBuilder: (context,
                                                            imageProvider) =>
                                                        Container(
                                                      decoration: BoxDecoration(
                                                        image: DecorationImage(
                                                          image: imageProvider,
                                                          fit: BoxFit.cover,
                                                        ),
                                                      ),
                                                    ),
                                                    placeholder: (context,
                                                            url) =>
                                                        detailVideoImageShimmer(
                                                            themeMode),
                                                    errorWidget:
                                                        (context, url, error) =>
                                                            Image.asset(
                                                      'assets/images/na_rect.png',
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                  Visibility(
                                                    visible:
                                                        playButtonVisibility,
                                                    child: SizedBox(
                                                      height: 90,
                                                      width: 90,
                                                      child: Icon(
                                                        PhosphorIcons.play(),
                                                        size: 90,
                                                      ),
                                                    ),
                                                  )
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          movieVideos!.result![index].name!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          itemCount: movieVideos!.result!.length,
                        ),
                      ),
          ),
        ),
      ],
    );
  }
}

class WatchNowButton extends StatefulWidget {
  const WatchNowButton({
    super.key,
    required this.posterPath,
    required this.movieId,
    this.movieName,
    this.movieImdbId,
    this.api,
    required this.releaseYear,
    required this.backdropPath,
    required this.releaseDate,
    this.adult,
  });
  final String? movieName;
  final int movieId;
  final int? movieImdbId;
  final bool? adult;
  final String? api;
  final int releaseYear;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate;

  @override
  WatchNowButtonState createState() => WatchNowButtonState();
}

class WatchNowButtonState extends State<WatchNowButton> {
  bool? isVisible = false;
  double? buttonWidth = 160;

  Color _borderColor = Colors.red; // Initial border color
  Timer? _timer;
  Random random = Random();

  @override
  void initState() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        // Generate random RGB values between 0 and 255
        int red = random.nextInt(256);
        int green = random.nextInt(256);
        int blue = random.nextInt(256);

        _borderColor = Color.fromRGBO(red, green, blue, 1.0);
      });
    });
    super.initState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
        duration: const Duration(seconds: 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            // Add an outer box shadow here
            BoxShadow(
              color: _borderColor,
              spreadRadius: 2.5,
              blurRadius: 4.25,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: GestureDetector(
          onTap: () async {
            await checkConnection().then((value) {
              value
                  ? Navigator.push(context,
                      MaterialPageRoute(builder: ((context) {
                      return MovieVideoLoader(
                        download: false,
                        metadata: MovieStreamMetadata(
                            backdropPath: widget.backdropPath,
                            elapsed: null,
                            isAdult: widget.adult,
                            movieId: widget.movieId,
                            movieName: widget.movieName,
                            posterPath: widget.posterPath,
                            releaseYear: widget.releaseYear,
                            releaseDate: widget.releaseDate),
                      );
                    })))
                  : GlobalMethods.showCustomScaffoldMessage(
                      SnackBar(
                        content: Text(
                          tr('check_connection'),
                          maxLines: 3,
                          style: kTextSmallBodyStyle,
                        ),
                        duration: const Duration(seconds: 3),
                      ),
                      context);
            });
          },
          child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Icon(
                  PhosphorIcons.playCircle(PhosphorIconsStyle.fill),
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                const SizedBox(width: 6),
                Text(tr('watch_now'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ))
              ])),
        ));
  }
}
