import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../catalog/media_item.dart';
import '../../data/playlists/playlist.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../provider/playlist_provider.dart';
import '../playlists.dart';
import '../widgets/media_art.dart';
import '../widgets/page_kit.dart';
import '../widgets/poster_card.dart';
import '../widgets/poster_grid.dart';

/// How a list's titles are shown. Only [custom] is the list's own order;
/// the rest are views of it on this device.
enum PlaylistSort { custom, recentlyAdded, title, rating }

/// The titles in [sort] order.
List<PlaylistEntry> sortPlaylistEntries(
    List<PlaylistEntry> entries, PlaylistSort sort) {
  final sorted = List<PlaylistEntry>.of(entries);
  switch (sort) {
    case PlaylistSort.custom:
      break;
    case PlaylistSort.recentlyAdded:
      sorted.sort((a, b) => (b.addedAt ?? '').compareTo(a.addedAt ?? ''));
    case PlaylistSort.title:
      sorted.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    case PlaylistSort.rating:
      sorted.sort((a, b) => (b.voteAverage ?? 0).compareTo(a.voteAverage ?? 0));
  }
  return sorted;
}

/// One custom list: its posters in a grid, and a way to put them in order,
/// take some out, rename the list or delete it.
///
/// Editing is a draft: drags and removals show at once but only become edits
/// on Done, as one reorder and one removal per title, so Cancel leaves the
/// list exactly as it was.
class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({required this.playlistId, super.key});

  final String playlistId;

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  PlaylistSort _sort = PlaylistSort.custom;
  List<PlaylistEntry>? _draft;

  void _startEditing(Playlist list) {
    HapticFeedback.selectionClick();
    setState(() => _draft = List<PlaylistEntry>.of(list.entries));
  }

  Future<void> _finishEditing(Playlist list) async {
    final draft = _draft!;
    final playlists = context.read<PlaylistProvider>();
    setState(() => _draft = null);
    final kept = draft.map((entry) => entry.key).toSet();
    try {
      for (final entry in list.entries) {
        if (!kept.contains(entry.key)) {
          await playlists.remove(list.id, entry.toMediaItem());
        }
      }
      await playlists.reorder(list.id, kept.toList());
    } on PlaylistEditException catch (error) {
      if (mounted) showPlaylistSnack(context, playlistEditMessage(error.error));
    }
  }

  Future<void> _rename(Playlist list) async {
    final named = await showPlaylistNameSheet(
      context,
      title: tr('playlist_edit_details'),
      confirmLabel: tr('save'),
      name: list.name,
      description: list.description,
    );
    if (named == null || !mounted) return;
    try {
      await context
          .read<PlaylistProvider>()
          .rename(list.id, named.name, description: named.description);
    } on PlaylistEditException catch (error) {
      if (mounted) showPlaylistSnack(context, playlistEditMessage(error.error));
    }
  }

  Future<void> _delete(Playlist list) async {
    final confirmed = await showConfirmDialog(
      context,
      icon: PhosphorIcons.trash(),
      title: tr('playlist_delete_title', namedArgs: {'name': list.name}),
      message: tr('playlist_delete_message'),
      confirmLabel: tr('delete'),
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    await context.read<PlaylistProvider>().delete(list.id);
    navigator.pop();
    messenger?.showSnackBar(SnackBar(
      content: Text(tr('playlist_deleted', namedArgs: {'name': list.name})),
    ));
  }

  Future<void> _chooseSort() async {
    final chosen = await showAppSheet<PlaylistSort>(
      context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            KickerHeading(tr('playlist_sort_by'),
                padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 4)),
            for (final sort in PlaylistSort.values)
              ListRow(
                label: tr('playlist_sort_${sort.name}'),
                trailing: sort == _sort
                    ? Icon(PhosphorIcons.check(),
                        color: AppPalette.of(sheetContext).foreground)
                    : null,
                showsNext: false,
                onTap: () => Navigator.of(sheetContext).pop(sort),
              ),
            const SizedBox(height: AppSpace.sm),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) setState(() => _sort = chosen);
  }

  Future<void> _more(Playlist list) async {
    final action = await showAppSheet<String>(
      context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListRow(
              icon: PhosphorIcons.pencilSimple(),
              label: tr('playlist_edit_details'),
              showsNext: false,
              onTap: () => Navigator.of(sheetContext).pop('rename'),
            ),
            if (list.entries.isNotEmpty)
              ListRow(
                icon: PhosphorIcons.arrowsDownUp(),
                label: tr('playlist_edit_titles'),
                showsNext: false,
                onTap: () => Navigator.of(sheetContext).pop('edit'),
              ),
            ListRow(
              icon: PhosphorIcons.trash(),
              label: tr('playlist_delete'),
              destructive: true,
              showsNext: false,
              onTap: () => Navigator.of(sheetContext).pop('delete'),
            ),
            const SizedBox(height: AppSpace.sm),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'rename':
        await _rename(list);
      case 'edit':
        _startEditing(list);
      case 'delete':
        await _delete(list);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final provider = context.watch<PlaylistProvider>();
    final list = provider.byId(widget.playlistId);
    if (list == null) {
      return Scaffold(
        backgroundColor: palette.page,
        appBar: PageAppBar(title: tr('playlists')),
        body: provider.loaded
            ? EmptyState(
                icon: PhosphorIcons.listBullets(),
                title: tr('playlist_missing'),
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }
    final draft = _draft;
    return PopScope(
      canPop: draft == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _draft = null);
      },
      child: Scaffold(
        backgroundColor: palette.page,
        appBar: PageAppBar(
          title: draft == null ? list.name : tr('playlist_edit_titles'),
          contentWidth: 760,
          kicker: draft == null ? tr('playlist') : list.name,
          actions: draft == null
              ? <Widget>[
                  if (list.entries.length > 1)
                    IconButton(
                      tooltip: tr('playlist_sort_by'),
                      color: palette.mutedText,
                      onPressed: _chooseSort,
                      icon: Icon(PhosphorIcons.sortAscending()),
                    ),
                  const SizedBox.shrink(),
                  IconButton(
                    tooltip: tr('more_options'),
                    color: palette.mutedText,
                    onPressed: () => _more(list),
                    icon: Icon(PhosphorIcons.dotsThreeVertical()),
                  ),
                ]
              : <Widget>[
                  TextButton(
                    onPressed: () => setState(() => _draft = null),
                    child: Text(tr('cancel')),
                  ),
                  TextButton(
                    onPressed: () => _finishEditing(list),
                    child: Text(tr('done')),
                  ),
                ],
        ),
        body: SafeArea(
          bottom: false,
          child: draft != null
              ? _EditList(
                  entries: draft,
                  onChanged: (entries) => setState(() => _draft = entries),
                )
              : _Titles(
                  list: list,
                  sort: _sort,
                  onEdit: () => _startEditing(list),
                ),
        ),
      ),
    );
  }
}

class _Titles extends StatelessWidget {
  const _Titles({required this.list, required this.sort, required this.onEdit});

  final Playlist list;
  final PlaylistSort sort;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final description = list.description;
    final entries = sortPlaylistEntries(list.entries, sort);
    return CustomScrollView(
      slivers: <Widget>[
        SliverPadding(
          padding:
              EdgeInsets.fromLTRB(gutter, AppSpace.sm, gutter, AppSpace.md),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (description != null) ...<Widget>[
                  Text(
                    description,
                    style: AppType.body.copyWith(color: palette.secondaryText),
                  ),
                  const SizedBox(height: AppSpace.sm),
                ],
                Text(
                  sort == PlaylistSort.custom
                      ? playlistSummary(list)
                      : '${playlistSummary(list)} · ${tr('playlist_sort_${sort.name}')}',
                  style: AppType.metadata.copyWith(color: palette.mutedText),
                ),
              ],
            ),
          ),
        ),
        if (entries.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: PhosphorIcons.listPlus(),
              title: tr('playlist_empty_title'),
              message: tr('playlist_empty_message'),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              gutter,
              0,
              gutter,
              AppSpace.xxl + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverGrid.builder(
              gridDelegate: posterGridDelegate(context),
              itemCount: entries.length,
              itemBuilder: (context, index) => LayoutBuilder(
                builder: (context, constraints) => PosterCard(
                  item: entries[index].toMediaItem(),
                  width: constraints.maxWidth,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The draft while editing: a row per title with a handle to drag it and a
/// button to take it out.
class _EditList extends StatelessWidget {
  const _EditList({required this.entries, required this.onChanged});

  final List<PlaylistEntry> entries;
  final ValueChanged<List<PlaylistEntry>> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    if (entries.isEmpty) {
      return EmptyState(
        icon: PhosphorIcons.listBullets(),
        title: tr('playlist_empty_title'),
        message: tr('playlist_edit_all_removed'),
      );
    }
    return ReadableWidth(
      child: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        padding: EdgeInsets.only(
            bottom: AppSpace.xxl + MediaQuery.paddingOf(context).bottom),
        itemCount: entries.length,
        onReorder: (from, to) {
          HapticFeedback.selectionClick();
          final next = List<PlaylistEntry>.of(entries);
          final moved = next.removeAt(from);
          next.insert(to > from ? to - 1 : to, moved);
          onChanged(next);
        },
        itemBuilder: (context, index) {
          final entry = entries[index];
          final item = entry.toMediaItem();
          return Material(
            key: ValueKey<String>(entry.key),
            color: palette.page,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter, vertical: 6),
              child: Row(
                children: <Widget>[
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 12),
                      child: Icon(PhosphorIcons.dotsSixVertical(),
                          color: palette.mutedText,
                          semanticLabel: tr('playlist_drag')),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    child: SizedBox(
                      width: 40,
                      height: 60,
                      child: MediaArt(
                          item: item, path: item.posterPath, width: 40),
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.cardTitle.copyWith(
                              fontSize: 15, color: palette.foreground),
                        ),
                        Text(
                          <String>[
                            if (item.year case final year?) year,
                            tr(item.kind == MediaKind.movie
                                ? 'movie'
                                : 'series_one'),
                          ].join(' · '),
                          style: AppType.metadata
                              .copyWith(color: palette.mutedText),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: tr('remove'),
                    color: palette.mutedText,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onChanged(
                          List<PlaylistEntry>.of(entries)..removeAt(index));
                    },
                    icon: Icon(PhosphorIcons.minusCircle()),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
