import 'package:flutter/material.dart';

import '../mobile/screens/person_screen.dart';

/// The single detail surface shared by every person entry point — cast, crew,
/// guest star and search results. They differ only in the data they hand in;
/// the page itself is [PersonScreen].
class PersonDetailView extends StatelessWidget {
  const PersonDetailView({
    required this.personId,
    required this.name,
    required this.heroId,
    this.profilePath,
    this.subtitle,
    this.isPersonAdult,
    super.key,
  });

  final int personId;
  final String name;
  final String heroId;
  final String? profilePath;
  final String? subtitle;
  final bool? isPersonAdult;

  @override
  Widget build(BuildContext context) => PersonScreen(
        personId: personId,
        name: name,
        heroId: heroId,
        profilePath: profilePath,
        subtitle: subtitle,
        isPersonAdult: isPersonAdult,
      );
}
