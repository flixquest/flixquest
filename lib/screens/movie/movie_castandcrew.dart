import 'package:flutter/material.dart';

import '../../mobile/screens/credits_screen.dart';
import '../../models/credits.dart';

/// Everyone in a movie's credits.
class MovieCastAndCrew extends StatefulWidget {
  const MovieCastAndCrew({required this.credits, this.title, super.key});

  final Credits credits;

  /// The movie's name, over the page's title.
  final String? title;

  @override
  State<MovieCastAndCrew> createState() => _MovieCastAndCrewState();
}

class _MovieCastAndCrewState extends State<MovieCastAndCrew> {
  late final Future<Credits> _credits = Future<Credits>.value(widget.credits);

  @override
  Widget build(BuildContext context) =>
      CreditsScreen(title: widget.title, credits: _credits);
}
