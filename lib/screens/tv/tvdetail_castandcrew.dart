import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/endpoints.dart';
import '../../functions/network.dart';
import '../../mobile/screens/credits_screen.dart';
import '../../models/credits.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';

/// Everyone who has worked on a series, across all its seasons.
class TVDetailCastAndCrew extends StatefulWidget {
  const TVDetailCastAndCrew({
    required this.id,
    required this.passedFrom,
    this.title,
    super.key,
  });

  final int id;
  final String passedFrom;

  /// The series' name, over the page's title.
  final String? title;

  @override
  State<TVDetailCastAndCrew> createState() => _TVDetailCastAndCrewState();
}

class _TVDetailCastAndCrewState extends State<TVDetailCastAndCrew> {
  late Future<Credits> _credits;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final settings = context.read<SettingsProvider>();
    _credits = fetchCredits(
      Endpoints.getFullTVCreditsUrl(widget.id, settings.appLanguage),
      settings.enableProxy,
      context.read<AppDependencyProvider>().tmdbProxy,
    );
  }

  @override
  Widget build(BuildContext context) =>
      CreditsScreen(title: widget.title, credits: _credits);
}
