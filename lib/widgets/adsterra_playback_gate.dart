import 'package:flutter/material.dart';

import '../services/adsterra_playback_ads_service.dart';

/// For player-to-player navigation: keep the loader unconstructed until the
/// interstitial finishes, while retaining the route that will hand off playback.
class AdsterraPlaybackGate extends StatefulWidget {
  const AdsterraPlaybackGate(
      {required this.builder, this.television = false, super.key});
  final WidgetBuilder builder;
  final bool television;

  @override
  State<AdsterraPlaybackGate> createState() => _AdsterraPlaybackGateState();
}

class _AdsterraPlaybackGateState extends State<AdsterraPlaybackGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final proceed = await AdsterraPlaybackAdsService.instance
          .beforeLoader(context, television: widget.television);
      if (!mounted) return;
      if (proceed) {
        setState(() => _ready = true);
      } else {
        final route = ModalRoute.of(context);
        if (route?.isActive == true) Navigator.of(context).removeRoute(route!);
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      _ready ? widget.builder(context) : const ColoredBox(color: Colors.black);
}
