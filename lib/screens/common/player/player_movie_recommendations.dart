import 'dart:async';

import 'package:flixquest/widgets/adsterra_playback_gate.dart';
import 'package:flixquest/widgets/playback_action.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../constants/app_constants.dart';
import '../../../models/movie_stream_metadata.dart';
import '../../../ui_components/app_ui_components.dart';
import '../../movie/movie_video_loader.dart';
import 'player_sheet_ui.dart';

class PlayerMovieRecommendations {
  Future<void> loadRecommendedMovie({
    required BuildContext context,
    required int movieId,
    required MovieStreamMetadata movieMetadata,
    required FutureOr<void> Function() onSaveProgress,
    required Function() closePlayer,
    bool useTvPlayer = false,
    bool Function()? onReady,
  }) async {
    try {
      // Save progress and analytics for current movie before switching
      await onSaveProgress();

      // Find the movie in recommendations to get all its details
      final recommendedMovie = movieMetadata.recommendations
          ?.firstWhere((movie) => movie.movieId == movieId);

      if (recommendedMovie == null) {
        throw Exception('Movie not found in recommendations');
      }

      // Create new movie metadata from the recommendation
      final newMetadata = MovieStreamMetadata(
        movieId: recommendedMovie.movieId,
        movieName: recommendedMovie.title,
        posterPath: recommendedMovie.posterPath,
        backdropPath: recommendedMovie.backdropPath,
        releaseDate: recommendedMovie.releaseDate,
        releaseYear: recommendedMovie.releaseDate != null
            ? DateTime.tryParse(recommendedMovie.releaseDate!)?.year
            : null,
        isAdult: false, // This info is not in recommendations
        elapsed: 0, // New movie, no elapsed time
      );

      // Pop current player, then push new video loader
      // This prevents player stacking while maintaining navigation history
      if (context.mounted) {
        if (onReady?.call() == false) return;
        closePlayer();
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AdsterraPlaybackGate.buildLoader(context,
                television: useTvPlayer,
                builder: (context) => MovieVideoLoader(
                      download: false,
                      useTvPlayer: useTvPlayer,
                      metadata: newMetadata,
                    )),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to load movie: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                tr('failed_load_movie', namedArgs: {'error': e.toString()})),
          ),
        );
      }
    }
  }

  Future<void> showMovieRecommendationsBottomSheet({
    required BuildContext context,
    required List<Color> colors,
    required MovieStreamMetadata movieMetadata,
    required FutureOr<void> Function() onSaveProgress,
    required Function() closePlayer,
    bool useTvPlayer = false,
  }) {
    final recommendations = movieMetadata.recommendations;
    debugPrint(
      '[PlayerContentMenu] recommendations sheet requested '
      'contextMounted=${context.mounted} '
      'recommendations=${recommendations?.length ?? 0}',
    );
    if (recommendations == null || recommendations.isEmpty) {
      debugPrint('[PlayerContentMenu] recommendations sheet skipped: no items');
      return Future.value();
    }
    final playerContext = context;

    debugPrint('[PlayerContentMenu] pushing recommendations modal');
    return showPlayerSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) {
        debugPrint(
          '[PlayerContentMenu] recommendations modal builder '
          'sheetContext=${identityHashCode(sheetContext)}',
        );
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) {},
          child: DraggableScrollableSheet(
            initialChildSize: .8,
            minChildSize: .55,
            maxChildSize: .95,
            expand: false,
            snap: true,
            snapSizes: const [.55, .8, .95],
            builder: (context, scrollController) => PlayerSheetScaffold(
              title: tr('recommended_movies'),
              actions: [
                IconButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: Icon(PhosphorIcons.x()),
                ),
              ],
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: recommendations.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final movie = recommendations[index];
                  return PlayerChoiceCard(
                    title: movie.title,
                    subtitle: _movieSubtitle(movie),
                    description: movie.overview,
                    thumbnail: _RecommendationThumbnail(
                      path: movie.backdropPath ?? movie.posterPath,
                      width: 112,
                      height: 68,
                    ),
                    onTap: () => loadRecommendedMovie(
                      context: playerContext,
                      movieId: movie.movieId,
                      movieMetadata: movieMetadata,
                      onSaveProgress: onSaveProgress,
                      closePlayer: closePlayer,
                      useTvPlayer: useTvPlayer,
                      onReady: () {
                        if (!sheetContext.mounted) return false;
                        final route = ModalRoute.of(sheetContext);
                        if (route?.isActive != true) return false;
                        Navigator.of(sheetContext).removeRoute(route!);
                        return true;
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void showRecommendedMovieCountdown({
    required BuildContext context,
    required List<Color> colors,
    required MovieStreamMetadata movieMetadata,
    required FutureOr<void> Function() onSaveProgress,
    required Function() closePlayer,
    bool useTvPlayer = false,
  }) {
    final playerContext = context;
    final recommendations = movieMetadata.recommendations;
    debugPrint(
      '[MovieRecommendationsDebug][COUNTDOWN_ENTER] '
      'contextMounted=${context.mounted} movieId=${movieMetadata.movieId} '
      'recommendations=${recommendations?.length ?? 0} '
      'ids=${recommendations?.map((movie) => movie.movieId).join(',') ?? 'none'}',
    );
    if (recommendations == null || recommendations.isEmpty) {
      debugPrint(
        '[MovieRecommendationsDebug][COUNTDOWN_SKIPPED] '
        'reason=no_recommendations',
      );
      return;
    }
    var selectedIndex = 0;

    final dialog = showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        debugPrint(
          '[MovieRecommendationsDebug][COUNTDOWN_BUILDER] '
          'dialogMounted=${dialogContext.mounted} '
          'dialogContext=${identityHashCode(dialogContext)}',
        );
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final selected = recommendations[selectedIndex];
            final panel = playerSheetTheme(context)
                    .extension<BetterPlayerPanelColors>() ??
                BetterPlayerPanelColors.dark;
            return PlayerTheme(
              child: Dialog(
                insetPadding: const EdgeInsets.all(20),
                clipBehavior: Clip.antiAlias,
                backgroundColor: panel.panel,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: panel.raised,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                PhosphorIcons.sparkle(),
                                color: panel.secondary,
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Text(
                                tr('recommended_movies'),
                                style: TextStyle(
                                  color: panel.foreground,
                                  fontFamily: 'FigtreeBold',
                                  fontSize: 19,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: Icon(PhosphorIcons.x()),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        PlayerChoiceCard(
                          title: selected.title,
                          subtitle: _movieSubtitle(selected),
                          description: selected.overview,
                          selected: true,
                          thumbnail: _RecommendationThumbnail(
                            path: selected.backdropPath ?? selected.posterPath,
                            width: 128,
                            height: 76,
                          ),
                          trailing: Icon(
                            PhosphorIcons.playCircle(
                              PhosphorIconsStyle.fill,
                            ),
                            color: panel.foreground,
                          ),
                          onTap: null,
                        ),
                        if (recommendations.length > 1) ...[
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 122,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: recommendations.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 6),
                              itemBuilder: (context, index) {
                                final movie = recommendations[index];
                                final isSelected = index == selectedIndex;
                                return Material(
                                  color: isSelected
                                      ? panel.selectedFill
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: () => setDialogState(
                                      () => selectedIndex = index,
                                    ),
                                    child: SizedBox(
                                      width: 210,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Row(
                                          children: [
                                            _RecommendationThumbnail(
                                              path: movie.backdropPath ??
                                                  movie.posterPath,
                                              width: 96,
                                              height: 58,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                movie.title,
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: isSelected
                                                      ? panel.foreground
                                                      : panel.secondary,
                                                  fontFamily: 'FigtreeSB',
                                                  fontSize: 14,
                                                  height: 1.25,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: Text(tr('cancel')),
                            ),
                            const SizedBox(width: 8),
                            PlaybackAction(
                              onStart: () => loadRecommendedMovie(
                                context: playerContext,
                                movieId: selected.movieId,
                                movieMetadata: movieMetadata,
                                onSaveProgress: onSaveProgress,
                                closePlayer: closePlayer,
                                useTvPlayer: useTvPlayer,
                                onReady: () {
                                  if (!dialogContext.mounted) return false;
                                  final route = ModalRoute.of(dialogContext);
                                  if (route?.isActive != true) return false;
                                  Navigator.of(dialogContext)
                                      .removeRoute(route!);
                                  return true;
                                },
                              ),
                              builder: (context, busy, start) =>
                                  FilledButton.icon(
                                onPressed: busy ? null : start,
                                icon: busy
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : Icon(PhosphorIcons.play()),
                                label: Text(tr('play_now')),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    dialog.then(
      (_) => debugPrint(
        '[MovieRecommendationsDebug][COUNTDOWN_CLOSED] '
        'movieId=${movieMetadata.movieId}',
      ),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint(
          '[MovieRecommendationsDebug][COUNTDOWN_ERROR] '
          'type=${error.runtimeType} error=$error',
        );
        debugPrintStack(
          label: '[MovieRecommendationsDebug][COUNTDOWN_STACK]',
          stackTrace: stackTrace,
        );
      },
    );
  }

  String _movieSubtitle(MovieRecommendation movie) {
    final values = <String>[];
    if (movie.releaseDate?.isNotEmpty == true) {
      values.add(movie.releaseDate!.split('-').first);
    }
    if (movie.voteAverage != null && movie.voteAverage! > 0) {
      values.add('★ ${movie.voteAverage!.toStringAsFixed(1)}');
    }
    return values.join('  •  ');
  }
}

class _RecommendationThumbnail extends StatelessWidget {
  const _RecommendationThumbnail({
    required this.path,
    required this.width,
    required this.height,
  });

  final String? path;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return PlayerThumbnail(
      width: width,
      height: height,
      child: path == null
          ? Icon(PhosphorIcons.filmStrip())
          : CachedNetworkImage(
              cacheManager: cacheProp(),
              imageUrl: 'https://image.tmdb.org/t/p/w300$path',
              fit: BoxFit.cover,
              placeholder: (_, __) => const AppCachedImagePlaceholder(),
              errorWidget: (_, __, ___) => Icon(PhosphorIcons.filmStrip()),
            ),
    );
  }
}
