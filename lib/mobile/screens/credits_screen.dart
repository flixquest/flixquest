import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../models/credits.dart';
import '../../screens/person/cast_detail.dart';
import '../../screens/person/crew_detail.dart';
import '../../screens/person/guest_star_detail.dart';
import '../widgets/media_art.dart';
import '../widgets/page_kit.dart';

enum _Group { cast, guests, crew }

/// Everyone in a title's, season's or episode's credits: the cast, an
/// episode's guest stars, and the crew by department, each a face, a name
/// and what they did. A person opens their page.
class CreditsScreen extends StatefulWidget {
  const CreditsScreen({
    required this.credits,
    this.title,
    this.kicker,
    super.key,
  });

  /// What the credits are for: the title, the season or the episode.
  final String? title;

  /// What [title] belongs to: a season's or an episode's series.
  final String? kicker;
  final Future<Credits> credits;

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  late Future<Credits> _credits = widget.credits;
  _Group? _group;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      appBar: PageAppBar(
        kicker: switch ((widget.kicker, widget.title)) {
          (final String kicker, final String title) => '$kicker · $title',
          (final String kicker, null) => kicker,
          (null, final String title) => title,
          (null, null) => null,
        },
        title: tr('cast_and_crew'),
      ),
      body: FutureBuilder<Credits>(
        future: _credits,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const ListSkeleton(
              rows: 10,
              leadingWidth: 48,
              leadingHeight: 48,
              circle: true,
              scrolls: true,
            );
          }
          if (snapshot.hasError) {
            return EmptyState.error(
              message: tr('check_connection'),
              onRetry: () => setState(() => _credits = widget.credits),
            );
          }
          return _body(context, snapshot.data ?? Credits());
        },
      ),
    );
  }

  Widget _body(BuildContext context, Credits credits) {
    final cast = credits.cast ?? const <Cast>[];
    final guests = credits.episodeGuestStars ?? const <TVEpisodeGuestStars>[];
    final crew = credits.crew ?? const <Crew>[];
    final groups = <_Group, String>{
      if (cast.isNotEmpty) _Group.cast: tr('cast'),
      if (guests.isNotEmpty) _Group.guests: tr('guest_stars'),
      if (crew.isNotEmpty) _Group.crew: tr('crew'),
    };
    if (groups.isEmpty) {
      return EmptyState(
        icon: PhosphorIcons.usersThree(),
        title: tr('nothing_here_yet'),
      );
    }
    final group = groups.containsKey(_group) ? _group! : groups.keys.first;
    final gutter = AppSpace.gutter(context);
    return CustomScrollView(
      slivers: <Widget>[
        if (groups.length > 1)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(gutter, AppSpace.xs, gutter, 0),
            sliver: SliverToBoxAdapter(
              child: SegmentSwitch<_Group>(
                segments: <Segment<_Group>>[
                  for (final entry in groups.entries)
                    Segment(entry.key, entry.value),
                ],
                selected: group,
                onChanged: (value) => setState(() => _group = value),
              ),
            ),
          ),
        ...switch (group) {
          _Group.cast => _castRows(context, cast),
          _Group.guests => _guestRows(context, guests),
          _Group.crew => _crewRows(context, crew),
        },
        SliverToBoxAdapter(
          child: SizedBox(
            height: AppSpace.xxl + MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );
  }

  List<Widget> _castRows(BuildContext context, List<Cast> cast) {
    final people = List<Cast>.of(cast)
      ..sort((a, b) => (a.order ?? 1 << 20).compareTo(b.order ?? 1 << 20));
    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.only(top: AppSpace.sm),
        sliver: SliverList.builder(
          itemCount: people.length,
          itemBuilder: (context, index) {
            final person = people[index];
            final role =
                person.character ?? person.roles?.firstOrNull?.character;
            final episodes = person.roles?.fold<int>(
              0,
              (sum, role) => sum + (role.episodeCount ?? 0),
            );
            return PersonRow(
              name: person.name ?? '',
              role: <String>[
                if ((role ?? '').trim().isNotEmpty) role!.trim(),
                if (episodes != null && episodes > 0)
                  tr(
                    'episodes_count',
                    namedArgs: <String, String>{'count': '$episodes'},
                  ),
              ].join(' · '),
              profilePath: person.profilePath,
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => CastDetailPage(
                    cast: person,
                    heroId: 'credits_cast_${person.id}_$index',
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _guestRows(
    BuildContext context,
    List<TVEpisodeGuestStars> guests,
  ) =>
      <Widget>[
        SliverPadding(
          padding: const EdgeInsets.only(top: AppSpace.sm),
          sliver: SliverList.builder(
            itemCount: guests.length,
            itemBuilder: (context, index) {
              final person = guests[index];
              return PersonRow(
                name: person.name ?? '',
                role: person.character ?? '',
                profilePath: person.profilePath,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => GuestStarDetailPage(
                      cast: person,
                      heroId: 'credits_guest_${person.id}_$index',
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ];

  /// The crew under their departments, each person once per department
  /// with every job they did in it.
  List<Widget> _crewRows(BuildContext context, List<Crew> crew) {
    final departments = <String, Map<int?, (Crew, List<String>)>>{};
    for (final person in crew) {
      final department = (person.department ?? '').trim();
      final people = departments.putIfAbsent(
        department,
        () => <int?, (Crew, List<String>)>{},
      );
      final key = person.id ?? person.name.hashCode;
      final entry = people.putIfAbsent(key, () => (person, <String>[]));
      final job = (person.job ?? '').trim();
      if (job.isNotEmpty && !entry.$2.contains(job)) entry.$2.add(job);
    }
    final gutter = AppSpace.gutter(context);
    return <Widget>[
      for (final department in departments.entries) ...<Widget>[
        SliverToBoxAdapter(
          child: KickerHeading(
            department.key.isEmpty ? tr('crew') : department.key,
            padding: EdgeInsetsDirectional.fromSTEB(
              gutter,
              AppSpace.xl,
              gutter,
              AppSpace.xs,
            ),
          ),
        ),
        SliverList.list(
          children: <Widget>[
            for (final (person, jobs) in department.value.values)
              PersonRow(
                name: person.name ?? '',
                role: jobs.join(', '),
                profilePath: person.profilePath,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => CrewDetailPage(
                      crew: person,
                      heroId: 'credits_crew_${person.id}_${department.key}',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    ];
  }
}

/// A person in a list: their face, their name, and what they did.
class PersonRow extends StatelessWidget {
  const PersonRow({
    required this.name,
    required this.role,
    required this.profilePath,
    required this.onTap,
    super.key,
  });

  final String name;
  final String role;
  final String? profilePath;
  final VoidCallback onTap;

  static const _face = 48.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final url = tmdbImageUrl(context, profilePath, size: 'w185/');
    final placeholder = Icon(
      PhosphorIcons.user(),
      color: palette.mutedText,
      size: 22,
    );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: gutter, vertical: 8),
        child: Row(
          children: <Widget>[
            ClipOval(
              child: Container(
                width: _face,
                height: _face,
                color: palette.raisedSurface,
                alignment: Alignment.center,
                child: url == null
                    ? placeholder
                    : CachedNetworkImage(
                        imageUrl: url,
                        width: _face,
                        height: _face,
                        fit: BoxFit.cover,
                        memCacheWidth:
                            (_face * MediaQuery.devicePixelRatioOf(context))
                                .round(),
                        errorWidget: (_, __, ___) => placeholder,
                      ),
              ),
            ),
            const SizedBox(width: AppSpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.cardTitle.copyWith(
                      fontSize: 15,
                      height: 1.3,
                      color: palette.foreground,
                    ),
                  ),
                  if (role.isNotEmpty)
                    Text(
                      role,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.metadata.copyWith(
                        fontSize: 13,
                        height: 1.35,
                        color: palette.mutedText,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
