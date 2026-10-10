import 'package:flutter/material.dart';

import '../services/adsterra_playback_ads_service.dart';

/// For player-to-player navigation: keep the loader unconstructed until the
/// interstitial finishes, while retaining the route that will hand off playback.
class AdsterraPlaybackGate extends StatefulWidget {
  const AdsterraPlaybackGate(
      {required this.builder, this.television = false, super.key});
  final WidgetBuilder builder;
  final bool television;

  /// Disabled interstitials build the loader directly, without creating a gate.
  static Widget buildLoader(BuildContext context,
      {required WidgetBuilder builder, bool television = false}) {
    if (!AdsterraPlaybackAdsService.instance
        .needsBeforeLoader(context, television: television)) {
      return builder(context);
    }
    return AdsterraPlaybackGate(builder: builder, television: television);
  }

  @override
  State<AdsterraPlaybackGate> createState() => _AdsterraPlaybackGateState();
}

class _AdsterraPlaybackGateState extends State<AdsterraPlaybackGate> {
  bool _ready = false;
  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checked) return;
    _checked = true;
    if (!AdsterraPlaybackAdsService.instance
        .needsBeforeLoader(context, television: widget.television)) {
      _ready = true;
      return;
    }
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
