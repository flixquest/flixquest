import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../provider/app_dependency_provider.dart';
import '../screens/common/live_tv_screen.dart';
import 'daddylive_service.dart';

import 'deep_link_dispatcher.dart';
import 'deep_link_routes.dart';
import 'live_channel_focus.dart';
import 'media_link.dart';
import 'device_presentation_service.dart';
import 'home_widget_navigation_service.dart';

/// Opens the TMDB, IMDb and flix.quest addresses the platform hands over.
///
/// Two things send them. A browser or another app can hand over a URL directly, and anything with a
/// share sheet can hand over the text it was showing with the URL somewhere inside it. Both arrive
/// here as text, because that is all they have in common, and both are read by [MediaLink].
///
/// Nothing is opened from the link itself. A link names a record and the route fetches it, so a film
/// reached from a shared IMDb page is the same screen, with the same rating and synopsis behind it, as
/// one reached from the app's own lists.
class MediaLinkNavigationService {
  const MediaLinkNavigationService._();

  static const MethodChannel _channel =
      MethodChannel('dev.beamlak.flixquest/media_links');

  static Future<void> initialize() async {
    _channel.setMethodCallHandler(_onCall);
    // A link can be the reason the app is starting, in which case it arrived before there was any
    // Dart to hand it to and has been waiting on the platform side.
    try {
      final waiting = await _channel.invokeListMethod<String>('drainLinks');
      for (final link in waiting ?? const <String>[]) {
        await _handlePlatformLink(link);
      }
    } on MissingPluginException {
      // A platform without the bridge simply never delivers links.
    }
  }

  static Future<void> _onCall(MethodCall call) async {
    if (call.method != 'onLink') return;
    final link = call.arguments;
    if (link is String) await _handlePlatformLink(link);
  }

  static Future<void> _handlePlatformLink(String value) async {
    final uri = Uri.tryParse(value);
    if (uri?.scheme == 'flixquest') {
      await HomeWidgetNavigationService.handle(uri!);
      return;
    }
    handle(value);
  }

  /// Opens whatever [value] points at, or says that it points at nothing this app can open.
  ///
  /// Visible for the sake of tests and of anywhere in the app that has a link in hand — pasted, say —
  /// and wants it treated exactly as one arriving from outside.
  static void handle(String value) {
    final target = MediaLink.parse(value);
    if (target == null) {
      _reportUnreadable(value);
      return;
    }
    DeepLinkDispatcher.submit(
      key: value,
      open: (navigator) => target is LiveChannelLink
          ? _openChannel(navigator, target)
          : navigator.push(_route(target)),
    );
  }

  /// A live channel is shown in the Live TV channel list, scrolled to and focused, and left for the
  /// person to play. It is refused while live TV is switched off remotely, as the tab is.
  ///
  /// On a television the list is the Live TV destination of the home shell, so the link only asks for
  /// the channel and drops any screen open over the shell; the shell and that destination do the rest.
  static void _openChannel(NavigatorState navigator, LiveChannelLink target) {
    final dependencies = navigator.context.read<AppDependencyProvider?>();
    if (!(dependencies?.displayLiveTV ?? false)) {
      ScaffoldMessenger.maybeOf(navigator.context)?.showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 4),
          content: Text(
            liveTvUnavailableMessage,
            style: TextStyle(fontFamily: 'Figtree'),
          ),
        ),
      );
      return;
    }
    if (DevicePresentationService.instance.isTelevision) {
      navigator.popUntil((route) => route.isFirst);
      LiveChannelFocus.request(target.channelId);
      return;
    }
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => ChannelList(initialChannelId: target.channelId),
      ),
    );
  }

  static Route<void> _route(MediaLinkTarget target) => switch (target) {
        TmdbMovieLink() => DeepLinkRoutes.movie(
            id: target.id,
            title: target.title,
          ),
        TmdbTvLink() => DeepLinkRoutes.tv(id: target.id, name: target.name),
        TmdbSeasonLink() => DeepLinkRoutes.season(
            seriesId: target.seriesId,
            seasonNumber: target.seasonNumber,
            seriesName: target.seriesName,
          ),
        TmdbEpisodeLink() => DeepLinkRoutes.episode(
            seriesId: target.seriesId,
            seasonNumber: target.seasonNumber,
            episodeNumber: target.episodeNumber,
            seriesName: target.seriesName,
          ),
        TmdbPersonLink() => DeepLinkRoutes.person(
            id: target.id,
            name: target.name,
          ),
        TmdbCollectionLink() => DeepLinkRoutes.collection(
            id: target.id,
            name: target.name,
          ),
        ImdbTitleLink() => DeepLinkRoutes.imdbTitle(
            imdbId: target.imdbId,
            seasonNumber: target.seasonNumber,
          ),
        ImdbNameLink() => DeepLinkRoutes.imdbName(imdbId: target.imdbId),
        LiveChannelLink() =>
          throw StateError('Live channels open via _openChannel'),
      };

  /// Text handed over with no address in it that this app knows.
  ///
  /// Anything at all can be shared into the app, so this is the common case rather than an odd one,
  /// and it deserves an answer: a share that appears to do nothing looks like the app failing.
  static void _reportUnreadable(String value) {
    DeepLinkDispatcher.submit(
      key: 'unreadable:$value',
      open: (navigator) {
        ScaffoldMessenger.maybeOf(navigator.context)?.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            content: Text(
              tr('link_unreadable'),
              style: const TextStyle(fontFamily: 'Figtree'),
            ),
          ),
        );
      },
    );
  }
}
