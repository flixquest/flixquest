import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/playlist_provider.dart';
import '../playlists.dart';
import '../widgets/page_kit.dart';

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlaylistProvider>();
    return Scaffold(
        appBar: AppBar(title: Text(tr('playlists')), actions: [
          IconButton(
              icon: const Icon(Icons.add),
              tooltip: tr('playlist_new'),
              onPressed: () async {
                final id = await createPlaylist(context);
                if (id != null && context.mounted) {
                  await openPlaylist(context, id);
                }
              })
        ]),
        body: RefreshIndicator(
            onRefresh: provider.load,
            child: ListView(children: [
              for (final list in provider.lists)
                ListRow(
                    leading: PlaylistCover(list: list, width: 44),
                    label: list.name,
                    subtitle: playlistSummary(list),
                    onTap: () => openPlaylist(context, list.id)),
              if (provider.loaded && provider.lists.isEmpty)
                Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(tr('playlists_empty_title'))),
            ])));
  }
}
