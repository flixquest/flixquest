import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../provider/app_dependency_provider.dart';
import '../services/start_io_ads_service.dart';
import '../tv/widgets/tv_pill_button.dart';
import 'hosted_ads_banner.dart';

/// Formats a pass length the way the rest of the app writes durations.
String adFreePassLength(Duration duration) =>
    duration.inMinutes % 60 == 0 && duration.inHours > 0
        ? tr('ad_free_pass_hours', namedArgs: {'n': '${duration.inHours}'})
        : tr('ad_free_pass_minutes', namedArgs: {'n': '${duration.inMinutes}'});

/// Offers an opt-in rewarded video that switches playback interstitials off
/// for a while, and says so once the pass is active.
///
/// Renders nothing until a rewarded video is loaded, so pressing it always
/// plays something, and nothing when either format is switched off.
class AdFreePassButton extends StatefulWidget {
  const AdFreePassButton({super.key});

  @override
  State<AdFreePassButton> createState() => _AdFreePassButtonState();
}

class _AdFreePassButtonState extends State<AdFreePassButton> {
  bool _busy = false;

  StartIoAdsService get _ads => StartIoAdsService.instance;

  Future<void> _watch() async {
    if (_busy) return;
    setState(() => _busy = true);
    await _ads.watchForAdFreePass();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds when Remote Config switches the formats on or off.
    context.watch<AppDependencyProvider?>();
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        _ads.adFreeUntil,
        _ads.adFreePassReady,
      ]),
      builder: (context, _) {
        final until = _ads.adFreeUntil.value;
        if (until != null) return _ActivePass(until: until);
        if (!_busy && !_ads.canOfferAdFreePass) {
          return const SizedBox.shrink();
        }
        final label = _busy
            ? tr('ad_free_pass_loading')
            : tr(
                'ad_free_pass_offer',
                namedArgs: {
                  'duration': adFreePassLength(_ads.config.adFreePassDuration),
                },
              );
        final icon = PhosphorIcons.playCircle();
        if (_ads.isTelevision) {
          return TvPillButton(
            label: label,
            icon: icon,
            enabled: !_busy,
            onActivate: _watch,
            scrollAlignment: null,
          );
        }
        return TextButton.icon(
          onPressed: _busy ? null : _watch,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, size: 18),
          label: Text(label, textAlign: TextAlign.center),
        );
      },
    );
  }
}

class _ActivePass extends StatelessWidget {
  const _ActivePass({required this.until});

  final DateTime until;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface.withValues(
          alpha: .7,
        );
    final time = DateFormat.jm(context.locale.toString()).format(until);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(PhosphorIcons.sealCheck(), size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            tr('ad_free_pass_active', namedArgs: {'time': time}),
            style: TextStyle(color: color, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

/// The stream loader's body: the provider progress plus a medium rectangle
/// and the ad-free pass. The viewer is waiting anyway, so the rectangle
/// earns a viewable impression on every play without delaying it.
///
/// Wide screens (TV, landscape tablets) place the ad beside the progress;
/// phones stack it underneath.
class StreamLoadingAds extends StatelessWidget {
  const StreamLoadingAds({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 720 && size.width > size.height;
    const extras = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        StartIoAdSlot(placement: 'stream_loading'),
        SizedBox(height: 12),
        AdFreePassButton(),
      ],
    );
    if (wide) {
      // Kept clear of TV overscan at the screen's edges.
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Flexible(child: child),
            const SizedBox(width: 40),
            extras,
          ],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        child,
        const SizedBox(height: 20),
        extras,
      ],
    );
  }
}
