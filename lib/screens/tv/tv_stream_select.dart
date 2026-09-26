import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../ui_components/app_ui_components.dart';

class TVStreamSelect extends StatelessWidget {
  const TVStreamSelect({
    required this.tvSeriesName,
    required this.tvSeriesId,
    required this.episodeName,
    this.tvSeriesImdbId,
    required this.episodeNumber,
    required this.seasonNumber,
    super.key,
  });

  final String tvSeriesName;
  final int tvSeriesId;
  final String? tvSeriesImdbId;
  final int seasonNumber;
  final String episodeName;
  final int episodeNumber;

  String get _episodeCode => 'S${seasonNumber.toString().padLeft(2, '0')} · '
      'E${episodeNumber.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final sources = <String>[
      'Stream one (multiple player options)',
      if (tvSeriesImdbId != null) 'Stream two (multiple player options)',
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
        title: Text('$tvSeriesName · $_episodeCode'),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              episodeName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$tvSeriesName · $_episodeCode',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
              return AppStreamSourceTile(
                index: index,
                title: sources[index - 1],
                subtitle: 'TMDB $tvSeriesId · $_episodeCode',
              );
            },
          ),
        ),
      ),
    );
  }
}
