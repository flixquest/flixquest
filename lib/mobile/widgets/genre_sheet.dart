import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../catalog/media_item.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../models/genres.dart';

/// Home's Categories: the genres of the kinds on show, under a heading per
/// kind. Resolves to the genre picked, with its kind, or null.
Future<(MediaKind, Genres)?> showGenreSheet(
  BuildContext context, {
  required List<Genres> movieGenres,
  required List<Genres> seriesGenres,
}) {
  final palette = AppPalette.of(context);
  return showModalBottomSheet<(MediaKind, Genres)>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .7,
      minChildSize: .4,
      maxChildSize: .92,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + AppSpace.lg,
        ),
        children: <Widget>[
          if (movieGenres.isNotEmpty) ...<Widget>[
            _Heading(tr('movie_genres')),
            for (final genre in movieGenres)
              _GenreTile(kind: MediaKind.movie, genre: genre),
          ],
          if (seriesGenres.isNotEmpty) ...<Widget>[
            _Heading(tr('series_genres')),
            for (final genre in seriesGenres)
              _GenreTile(kind: MediaKind.series, genre: genre),
          ],
          if (movieGenres.isEmpty && seriesGenres.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpace.xxl),
              child: Text(
                tr('nothing_here_yet'),
                textAlign: TextAlign.center,
                style: AppType.body.copyWith(color: palette.mutedText),
              ),
            ),
        ],
      ),
    ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 6),
      child: Text(
        label.toUpperCase(),
        style: AppType.kicker.copyWith(color: palette.mutedText),
      ),
    );
  }
}

class _GenreTile extends StatelessWidget {
  const _GenreTile({required this.kind, required this.genre});

  final MediaKind kind;
  final Genres genre;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return InkWell(
      onTap: () => Navigator.of(context).pop((kind, genre)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Text(
          genre.genreName ?? '',
          style: AppType.body.copyWith(
            fontFamily: AppType.semiBold,
            fontSize: 16,
            color: palette.foreground,
          ),
        ),
      ),
    );
  }
}
