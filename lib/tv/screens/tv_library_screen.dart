import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../data/playlists/playlist.dart';
import '../../provider/playlist_provider.dart';
import '../../provider/recently_watched_provider.dart';
import '../app/tv_design.dart';
import '../app/tv_shell_layout.dart';
import '../controllers/tv_catalog_controller.dart';
import '../focus/tv_screen_focus_controller.dart';
import '../models/tv_media_item.dart';
import '../widgets/tv_browse_skeleton.dart';
import '../widgets/tv_browse_view.dart';
import '../widgets/tv_continue_watching_menu.dart';
import '../widgets/tv_dialog.dart';
import '../widgets/tv_playlist_picker.dart';
import '../widgets/tv_shortcut_tile.dart';
import '../widgets/tv_state_panel.dart';
import 'tv_playlist_name_screen.dart';

/// My List as a browse page: saved movies and series, then what is being
/// watched, with the spotlight and backdrop following focus.
///
/// Rows stop at [rowLimit] titles, so a long list does not mount hundreds of
/// cards; past that, a See all tile opens the rest as a grid.
class TvLibraryScreen extends StatefulWidget {
  const TvLibraryScreen({
    required this.metrics,
    required this.onOpenMedia,
    this.onContinueWatching,
    this.onOpenCollection,
    this.revision = 0,
    this.focusController,
    this.controller = const TvCatalogController(),
    super.key,
  });

  final TvShellMetrics metrics;
  final ValueChanged<TvMediaItem> onOpenMedia;
  final FutureOr<void> Function(TvMediaItem item)? onContinueWatching;
  final ValueChanged<TvCollection>? onOpenCollection;

  /// Bumped when a bookmark may have changed; the list reloads in place so
  /// the card the user came back to can take focus again.
  final int revision;
  final TvScreenFocusController? focusController;
  final TvCatalogController controller;

  static const rowLimit = 30;

  @override
  State<TvLibraryScreen> createState() => _TvLibraryScreenState();
}

class _TvLibraryScreenState extends State<TvLibraryScreen> {
  late Future<List<TvMediaItem>> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.controller.loadLibrary();
  }

  @override
  void didUpdateWidget(TvLibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) {
      _items = widget.controller.loadLibrary();
    }
  }

  void _refresh() {
    setState(() => _items = widget.controller.loadLibrary());
  }

  Future<void> _removeFromContinueWatching(TvMediaItem item) async {
    final removal = TvContinueWatchingRemoval.forItem(item);
    if (removal == null) return;
    final confirmed = await confirmRemoveFromContinueWatching(
      context: context,
      item: item,
    );
    if (!confirmed || !mounted) return;
    await removal.apply(context.read<RecentProvider>());
  }

  TvCollection _collection(TvMediaKind kind, List<TvMediaItem> items) {
    const page = 24;
    return TvCollection(
      id: 'library-${kind == TvMediaKind.movie ? 'movies' : 'series'}',
      title: tr(kind == TvMediaKind.movie ? 'movies' : 'series'),
      kicker: tr('tv_my_list'),
      loadPage: (number) async {
        final start = (number - 1) * page;
        if (start >= items.length) return const <TvMediaItem>[];
        return items.sublist(start, (start + page).clamp(0, items.length));
      },
    );
  }

  TvCollection _listCollection(Playlist list) {
    const page = 24;
    final items = list.items;
    return TvCollection(
      id: 'playlist-${list.id}',
      title: list.name,
      kicker: tr('playlist'),
      loadPage: (number) async {
        final start = (number - 1) * page;
        if (start >= items.length) return const <TvMediaItem>[];
        return items.sublist(start, (start + page).clamp(0, items.length));
      },
    );
  }

  Future<void> _removeFromList(Playlist list, TvMediaItem item) async {
    final confirmed = await showTvDialog<bool>(
      context: context,
      title: tr('tv_playlist_remove_title'),
      content: Text(tr('tv_playlist_remove_body',
          namedArgs: {'title': item.title, 'name': list.name})),
      actions: <TvDialogAction>[
        TvDialogAction(
          label: tr('remove'),
          isPrimary: true,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        TvDialogAction(
          label: tr('cancel'),
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    await context.read<PlaylistProvider>().remove(list.id, item);
  }

  /// Hold OK on a list's tile: rename it or delete it.
  Future<void> _manageList(Playlist list) async {
    final playlists = context.read<PlaylistProvider>();
    final action = await showTvDialog<String>(
      context: context,
      title: list.name,
      content: Text(playlistSummaryForTv(list)),
      actions: <TvDialogAction>[
        TvDialogAction(
          label: tr('tv_playlist_rename'),
          onPressed: () => Navigator.of(context).pop('rename'),
        ),
        TvDialogAction(
          label: tr('playlist_delete'),
          onPressed: () => Navigator.of(context).pop('delete'),
        ),
        TvDialogAction(
          label: tr('cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
    if (!mounted) return;
    if (action == 'rename') {
      final name = await TvPlaylistNameScreen.open(
        context,
        title: tr('tv_playlist_rename'),
        actionLabel: tr('save'),
        initialName: list.name,
      );
      if (name != null) {
        await playlists.rename(list.id, name, description: list.description);
      }
    } else if (action == 'delete') {
      final confirmed = await showTvDialog<bool>(
        context: context,
        title: tr('playlist_delete_title', namedArgs: {'name': list.name}),
        content: Text(tr('playlist_delete_message')),
        actions: <TvDialogAction>[
          TvDialogAction(
            label: tr('delete'),
            isPrimary: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          TvDialogAction(
            label: tr('cancel'),
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      );
      if (confirmed == true) await playlists.delete(list.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final insets = TvShellInsets.of(context);
    final lists =
        context.watch<PlaylistProvider?>()?.lists ?? const <Playlist>[];
    final recent = context.watch<RecentProvider?>();
    final continueWatching = <TvMediaItem>[
      ...?recent?.movies.map(TvMediaItem.fromRecentMovie),
      ...?recent?.episodes.map(TvMediaItem.fromRecentEpisode),
    ].where((item) => item.id >= 0).take(16).toList(growable: false);

    return FutureBuilder<List<TvMediaItem>>(
      future: _items,
      builder: (context, snapshot) {
        // A reload keeps the previous list on screen (FutureBuilder carries
        // its data over), so the rows and their focus survive.
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData) {
          return TvBrowseSkeleton(metrics: widget.metrics);
        }
        if (snapshot.hasError && !snapshot.hasData) {
          return Padding(
            padding: insets,
            child: TvStatePanel.error(onRetry: _refresh),
          );
        }
        final saved = snapshot.data ?? const <TvMediaItem>[];
        if (saved.isEmpty && continueWatching.isEmpty && lists.isEmpty) {
          return Padding(
            padding: insets,
            child: TvStatePanel(
              title: tr('tv_your_list_is_empty'),
              message: tr(
                  'tv_add_a_movie_or_series_to_my_list_from_its_page_and_it_will_wait_for_you_here'),
              icon: PhosphorIcons.bookmarkSimple(),
              actionLabel: tr('refresh'),
              onAction: _refresh,
            ),
          );
        }
        final movies = saved
            .where((item) => item.kind == TvMediaKind.movie)
            .toList(growable: false);
        final series = saved
            .where((item) => item.kind == TvMediaKind.series)
            .toList(growable: false);
        final overflow = <(TvMediaKind, List<TvMediaItem>)>[
          if (movies.length > TvLibraryScreen.rowLimit)
            (TvMediaKind.movie, movies),
          if (series.length > TvLibraryScreen.rowLimit)
            (TvMediaKind.series, series),
        ];

        return TvBrowseView(
          featured: saved.firstOrNull ??
              continueWatching.firstOrNull ??
              lists.expand((list) => list.items).firstOrNull ??
              TvMediaItem(
                kind: TvMediaKind.movie,
                id: -1,
                title: tr('playlists'),
                overview: '',
                posterPath: null,
                backdropPath: null,
                rating: null,
                releaseDate: null,
              ),
          metrics: widget.metrics,
          onOpenMedia: widget.onOpenMedia,
          focusController: widget.focusController,
          focusMemoryScope: 'tv-library-row',
          showBillboard: false,
          rows: <TvBrowseRow>[
            TvMediaRow(
              title: tr('tv_movies_in_my_list'),
              scopeId: 'library-movies',
              items: movies.take(TvLibraryScreen.rowLimit).toList(),
            ),
            TvMediaRow(
              title: tr('tv_series_in_my_list'),
              scopeId: 'library-series',
              items: series.take(TvLibraryScreen.rowLimit).toList(),
            ),
            TvMediaRow(
              title: tr('tv_continue_watching'),
              scopeId: 'library-continue-watching',
              items: continueWatching,
              onItemActivated: widget.onContinueWatching,
              onItemMenu: _removeFromContinueWatching,
              itemMenuHint: tr('tv_hold_ok_to_remove'),
              showBadges: false,
            ),
            for (final list in lists)
              TvMediaRow(
                title: list.name,
                scopeId: 'library-list-${list.id}',
                items: list.items.take(TvLibraryScreen.rowLimit).toList(),
                onItemMenu: (item) => _removeFromList(list, item),
                itemMenuHint: tr('tv_hold_ok_to_remove'),
                seeAll: list.entries.length > TvLibraryScreen.rowLimit &&
                        widget.onOpenCollection != null
                    ? TvRowSeeAll(
                        onActivate: () =>
                            widget.onOpenCollection!(_listCollection(list)),
                      )
                    : null,
              ),
            if (widget.onOpenCollection case final open?)
              TvShortcutRow(
                title: tr('see_all'),
                scopeId: 'library-all',
                shortcuts: <TvBrowseShortcut>[
                  for (final (kind, items) in overflow)
                    TvBrowseShortcut(
                      id: 'all-${kind == TvMediaKind.movie ? 'Movies' : 'Series'}',
                      title: tr('tv_library_all', namedArgs: {
                        'kind':
                            tr(kind == TvMediaKind.movie ? 'movies' : 'series'),
                        'count': '${items.length}'
                      }),
                      icon: PhosphorIcons.squaresFour(),
                      facts: <String>[
                        plural('tv_title_count', items.length, name: 'count')
                      ],
                      description: tr('tv_library_description', namedArgs: {
                        'kind':
                            tr(kind == TvMediaKind.movie ? 'movies' : 'series')
                      }),
                      onActivate: () => open(_collection(kind, items)),
                    ),
                ],
              ),
            TvShortcutRow(
              title: tr('playlists'),
              scopeId: 'library-lists',
              menuHint: tr('tv_playlist_hold_to_manage'),
              onShortcutMenu: (shortcut) {
                for (final list in lists) {
                  if (shortcut.id == 'list-${list.id}') _manageList(list);
                }
              },
              shortcuts: <TvBrowseShortcut>[
                TvBrowseShortcut(
                  id: 'new-list',
                  title: tr('playlist_new'),
                  icon: PhosphorIcons.plus(),
                  description: tr('tv_playlist_new_description'),
                  onActivate: () => tvCreatePlaylist(context),
                ),
                for (final list in lists)
                  TvBrowseShortcut(
                    id: 'list-${list.id}',
                    title: list.name,
                    icon: PhosphorIcons.listBullets(),
                    facts: <String>[playlistSummaryForTv(list)],
                    description:
                        list.description ?? tr('tv_playlist_hold_to_manage'),
                    onActivate: () {
                      if (widget.onOpenCollection case final open?) {
                        open(_listCollection(list));
                      }
                    },
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// "12 titles", the line a TV tile shows under a list's name.
String playlistSummaryForTv(Playlist list) =>
    plural('playlist_title_count', list.entries.length,
        namedArgs: {'count': '${list.entries.length}'});
