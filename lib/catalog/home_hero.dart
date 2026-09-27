import 'continue_watching.dart';
import 'home_feed_controller.dart';
import 'media_item.dart';

/// The title at the top of Home, and whether it is there to be resumed.
class HomeHero {
  const HomeHero({required this.item, this.continuing = false});

  final MediaItem item;

  /// Picked from Continue Watching rather than from the charts.
  final bool continuing;
}

/// How recently a title must have been played to take the hero from the
/// charts.
const heroContinueWindow = Duration(days: 3);

/// Home's heroes for [filter], in the order the hero turns through them:
/// FlixQuest's spotlight, trending alternating with random picks.
///
/// Under All, a title the viewer is in the middle of leads, if it has artwork
/// and was played in the last [heroContinueWindow]. With no spotlight, the
/// day's #1 stands alone.
///
/// Home chooses once per filter and keeps the set for the session, so the
/// hero doesn't reshuffle under the viewer as rows refresh.
List<HomeHero> chooseHomeHeroes({
  required HomeFilter filter,
  required HomeFeed feed,
  required List<MediaItem> continueWatching,
  DateTime? now,
}) {
  HomeHero? continuing;
  if (filter == HomeFilter.all && continueWatching.isNotEmpty) {
    final latest = continueWatching.first;
    final played = lastWatchedItem(latest);
    final backdrop = latest.backdropPath;
    if (played != null &&
        backdrop != null &&
        backdrop.isNotEmpty &&
        (now ?? DateTime.now()).difference(played) <= heroContinueWindow) {
      continuing = HomeHero(item: latest, continuing: true);
    }
  }
  final charts = feed.spotlight.isNotEmpty
      ? feed.spotlight
      : <MediaItem>[if (feed.hero case final top?) top];
  return <HomeHero>[
    if (continuing != null) continuing,
    for (final item in charts)
      if (continuing == null || titleKey(item) != titleKey(continuing.item))
        HomeHero(item: item),
  ].take(HomeFeedController.spotlightLength).toList(growable: false);
}
