import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../ui_components/app_ui_components.dart';

class MovieStreamSelect extends StatelessWidget {
  const MovieStreamSelect({
    required this.movieName,
    required this.movieId,
    this.movieImdbId,
    super.key,
  });

  final String movieName;
  final int movieId;
  final dynamic movieImdbId;

  @override
  Widget build(BuildContext context) {
    final sources = <String>[
      'Stream one (multiple player options)',
      if (movieImdbId != null) 'Stream two (multiple player options)',
      'Stream three (multiple player options)',
      'Stream four (multiple player options)',
      'Stream five (multiple player options)',
      'Stream six (multiple player options)',
      'Stream seven (multiple player options)',
      'Stream eight (multiple player options)',
      'Stream nine (multiple player options)',
      'Stream ten (multiple player options)',
      'Stream eleven (360p)',
      'Stream twelve (multiple player options)',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('watch_movie', namedArgs: {'movie': movieName})),
        leading: IconButton(
          icon: Icon(PhosphorIcons.caretLeft()),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: .08),
              Colors.transparent,
            ],
          ),
        ),
        child: AppResponsiveContent(
          maxWidth: 760,
          padding: EdgeInsets.fromLTRB(
            AppUI.pagePadding(context),
            18,
            AppUI.pagePadding(context),
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            itemCount: sources.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          PhosphorIcons.broadcast(),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          movieName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return AppStreamSourceTile(
                index: index,
                title: sources[index - 1],
                subtitle: 'TMDB $movieId',
              );
            },
          ),
        ),
      ),
    );
  }
}
