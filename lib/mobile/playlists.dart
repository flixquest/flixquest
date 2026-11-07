import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../catalog/media_item.dart';
import '../data/playlists/playlist.dart';
import '../design/app_palette.dart';
import '../design/app_tokens.dart';
import '../provider/playlist_provider.dart';
import 'my_list.dart';
import 'screens/playlist_screen.dart';
import 'widgets/media_art.dart';
import 'widgets/page_kit.dart';
import 'widgets/pill_button.dart';

/// What to tell someone when a list edit could not be made.
String playlistEditMessage(PlaylistEditError error) => switch (error) {
      PlaylistEditError.emptyName => tr('playlist_name_required'),
      PlaylistEditError.tooManyLists => tr('playlist_too_many_lists',
          namedArgs: {'count': '${PlaylistLimits.lists}'}),
      PlaylistEditError.listFull => tr('playlist_list_full',
          namedArgs: {'count': '${PlaylistLimits.items}'}),
      PlaylistEditError.missing => tr('playlist_missing'),
      PlaylistEditError.signInRequired => tr('playlist_share_sign_in'),
    };

/// "12 titles", or "Imported from TMDB · 12 titles".
String playlistSummary(Playlist list) {
  final count = plural('playlist_title_count', list.entries.length,
      namedArgs: {'count': '${list.entries.length}'});
  final summary = switch (list.record.sourceProvider) {
    'tmdb' => '${tr('playlist_from_tmdb')} · $count',
    'imdb' => '${tr('playlist_from_imdb')} · $count',
    _ => count,
  };
  return list.isPublic ? '$summary · ${tr('playlist_public')}' : summary;
}

void showPlaylistSnack(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 2),
    ));
}

Future<void> openPlaylist(BuildContext context, String id) =>
    Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => PlaylistScreen(playlistId: id),
    ));

/// A list's picture: its first four posters in a square-cornered mosaic, or
/// the first alone when it has fewer, at the poster's 2:3.
class PlaylistCover extends StatelessWidget {
  const PlaylistCover({required this.list, required this.width, super.key});

  final Playlist list;
  final double width;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final items = list.items.where((item) => item.posterPath != null).toList();
    final height = width * 3 / 2;
    Widget art(MediaItem item, double size) =>
        MediaArt(item: item, path: item.posterPath, width: size);
    final Widget child;
    if (items.isEmpty) {
      child = ColoredBox(
        color: palette.idleFill,
        child: Center(
          child: Icon(PhosphorIcons.listBullets(),
              size: width * .32, color: palette.mutedText),
        ),
      );
    } else if (items.length < 4) {
      child = art(items.first, width);
    } else {
      child = Column(
        children: <Widget>[
          for (final row in <List<MediaItem>>[
            items.sublist(0, 2),
            items.sublist(2, 4),
          ])
            Expanded(
              child: Row(
                children: <Widget>[
                  for (final item in row)
                    Expanded(
                        child: SizedBox.expand(child: art(item, width / 2))),
                ],
              ),
            ),
        ],
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: SizedBox(width: width, height: height, child: child),
    );
  }
}

/// Asks for a list's name (and an optional note). Null when dismissed.
Future<({String name, String? description})?> showPlaylistNameSheet(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? name,
  String? description,
}) =>
    showAppSheet<({String name, String? description})>(
      context,
      builder: (_) => _NameSheet(
        title: title,
        confirmLabel: confirmLabel,
        name: name,
        description: description,
      ),
    );

class _NameSheet extends StatefulWidget {
  const _NameSheet({
    required this.title,
    required this.confirmLabel,
    this.name,
    this.description,
  });

  final String title;
  final String confirmLabel;
  final String? name;
  final String? description;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final _name = TextEditingController(text: widget.name);
  late final _description = TextEditingController(text: widget.description);
  late bool _showDescription = widget.description?.isNotEmpty ?? false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty) return;
    Navigator.of(context).pop((
      name: _name.text.trim(),
      description:
          _description.text.trim().isEmpty ? null : _description.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                widget.title,
                style: AppType.sectionHeader.copyWith(
                  fontFamily: AppType.bold,
                  color: palette.foreground,
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              TextField(
                controller: _name,
                autofocus: true,
                maxLength: PlaylistLimits.name,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(labelText: tr('playlist_name')),
              ),
              if (_showDescription)
                TextField(
                  controller: _description,
                  maxLength: PlaylistLimits.description,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration:
                      InputDecoration(labelText: tr('playlist_description')),
                )
              else
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showDescription = true),
                    icon: Icon(PhosphorIcons.plus(), size: 16),
                    label: Text(tr('playlist_add_description')),
                  ),
                ),
              const SizedBox(height: AppSpace.lg),
              ListenableBuilder(
                listenable: _name,
                builder: (context, _) => PillButton(
                  primary: true,
                  label: widget.confirmLabel,
                  onPressed: _name.text.trim().isEmpty ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Makes a list, with [first] in it when given; returns its id, or null
/// when the sheet was dismissed or the list could not be made.
Future<String?> createPlaylist(BuildContext context, {MediaItem? first}) async {
  final playlists = context.read<PlaylistProvider>();
  final named = await showPlaylistNameSheet(
    context,
    title: tr('playlist_new'),
    confirmLabel: tr('playlist_create'),
  );
  if (named == null || !context.mounted) return null;
  try {
    final id = await playlists.create(named.name,
        description: named.description, first: first);
    if (context.mounted && first != null) {
      showPlaylistSnack(
          context, tr('playlist_added_to', namedArgs: {'name': named.name}));
    }
    return id;
  } on PlaylistEditException catch (error) {
    if (context.mounted) {
      showPlaylistSnack(context, playlistEditMessage(error.error));
    }
    return null;
  }
}

/// "Save to a list": My List and every custom list, each a tap to add or
/// take out [item], with a new list at the bottom.
Future<void> showSaveToListSheet(BuildContext context, MediaItem item) {
  HapticFeedback.selectionClick();
  return showAppSheet<void>(
    context,
    builder: (sheetContext) => _SaveSheet(item: item, host: context),
  );
}

class _SaveSheet extends StatelessWidget {
  const _SaveSheet({required this.item, required this.host});

  final MediaItem item;

  /// The page under the sheet, which outlives it for the snack bars.
  final BuildContext host;

  Future<void> _toggle(BuildContext context, Playlist list) async {
    HapticFeedback.selectionClick();
    try {
      final added =
          await context.read<PlaylistProvider>().toggle(list.id, item);
      if (host.mounted) {
        showPlaylistSnack(
          host,
          tr(added ? 'playlist_added_to' : 'playlist_removed_from',
              namedArgs: {'name': list.name}),
        );
      }
    } on PlaylistEditException catch (error) {
      if (host.mounted) {
        showPlaylistSnack(host, playlistEditMessage(error.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final lists = context.watch<PlaylistProvider>().lists;
    final inMyList = MyList.contains(context, item);
    Widget check(bool on) => Icon(
          on
              ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
              : PhosphorIcons.circle(),
          size: 24,
          color: on ? palette.foreground : palette.mutedText,
        );
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    tr('playlist_save_to'),
                    style: AppType.sectionHeader.copyWith(
                      fontFamily: AppType.bold,
                      color: palette.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.metadata.copyWith(color: palette.mutedText),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  ListRow(
                    icon: PhosphorIcons.bookmarkSimple(),
                    label: tr('my_list'),
                    trailing: check(inMyList),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      MyList.toggle(host, item);
                    },
                  ),
                  for (final list in lists)
                    ListRow(
                      leading: PlaylistCover(list: list, width: 30),
                      label: list.name,
                      subtitle: playlistSummary(list),
                      trailing: check(list.contains(item)),
                      onTap: () => _toggle(context, list),
                    ),
                ],
              ),
            ),
            ListRow(
              icon: PhosphorIcons.plus(),
              label: tr('playlist_new'),
              showsNext: false,
              onTap: () async {
                Navigator.of(context).pop();
                await createPlaylist(host, first: item);
              },
            ),
            const SizedBox(height: AppSpace.sm),
          ],
        ),
      ),
    );
  }
}
