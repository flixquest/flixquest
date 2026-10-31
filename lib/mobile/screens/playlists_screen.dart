import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../provider/playlist_provider.dart';
import '../playlists.dart';
import '../widgets/page_kit.dart';
import '../widgets/pill_button.dart';
import 'playlist_import_screen.dart';

/// Every custom list, newest first, with new and import at the top.
class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  @override
  void initState() {
    super.initState();
    // Another device may have changed them since this one last looked.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PlaylistProvider>().autoSync();
    });
  }

  Future<void> _create() async {
    final id = await createPlaylist(context);
    if (id != null && mounted) await openPlaylist(context, id);
  }

  void _import() => Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const PlaylistImportScreen()));

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final provider = context.watch<PlaylistProvider>();
    final lists = provider.lists;
    return Scaffold(
      backgroundColor: palette.page,
      appBar: PageAppBar(
        title: tr('playlists'),
        contentWidth: 760,
        actions: <Widget>[
          IconButton(
            tooltip: tr('playlist_import'),
            color: palette.mutedText,
            onPressed: _import,
            icon: Icon(PhosphorIcons.downloadSimple()),
          ),
          IconButton(
            tooltip: tr('playlist_new'),
            color: palette.mutedText,
            onPressed: _create,
            icon: Icon(PhosphorIcons.plus()),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: lists.isEmpty
            ? (provider.loaded
                ? _Empty(onCreate: _create, onImport: _import)
                : const ListSkeleton(scrolls: true, leadingHeight: 66))
            : RefreshIndicator(
                onRefresh: provider.sync,
                child: ReadableWidth(
                  child: ListView.builder(
                    padding: EdgeInsets.only(
                      top: AppSpace.sm,
                      bottom:
                          AppSpace.xxl + MediaQuery.paddingOf(context).bottom,
                    ),
                    itemCount: lists.length,
                    itemBuilder: (context, index) {
                      final list = lists[index];
                      return ListRow(
                        leading: PlaylistCover(list: list, width: 44),
                        label: list.name,
                        subtitle: playlistSummary(list),
                        onTap: () => openPlaylist(context, list.id),
                      );
                    },
                  ),
                ),
              ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onCreate, required this.onImport});

  final VoidCallback onCreate;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(PhosphorIcons.listPlus(),
                  size: 40, color: palette.mutedText),
              const SizedBox(height: AppSpace.lg),
              Text(
                tr('playlists_empty_title'),
                textAlign: TextAlign.center,
                style: AppType.sectionHeader.copyWith(
                    fontFamily: AppType.bold, color: palette.foreground),
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                tr('playlists_empty_message'),
                textAlign: TextAlign.center,
                style: AppType.body.copyWith(color: palette.mutedText),
              ),
              const SizedBox(height: AppSpace.xl),
              PillButton(
                primary: true,
                icon: PhosphorIcons.plus(),
                label: tr('playlist_new'),
                onPressed: onCreate,
              ),
              const SizedBox(height: AppSpace.sm),
              PillButton(
                icon: PhosphorIcons.downloadSimple(),
                label: tr('playlist_import'),
                onPressed: onImport,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
