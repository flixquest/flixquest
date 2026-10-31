import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../data/ads/ads_policy.dart';
import '../design/app_palette.dart';
import '../design/app_tokens.dart';
import '../mobile/widgets/pill_button.dart';
import '../provider/app_dependency_provider.dart';
import '../provider/settings_provider.dart';
import '../services/ad_block_detector.dart';
import '../services/ad_block_check_cache.dart';
import '../services/ad_delivery.dart';
import '../services/ad_redirect_resolver.dart';
import '../services/device_presentation_service.dart';
import '../tv/widgets/tv_dialog.dart';
import 'plus/plus_visuals.dart';

/// Another check over the live ad hosts, alongside DNS.
typedef AdBlockProbe = Future<bool> Function(BuildContext context, AdHosts ads);

/// Browsing stays open to everyone; Play and Download ask viewers whose ad
/// blocker hides FlixQuest's ads to turn it off first. Every loader calls
/// [allowPlayback] before it looks for sources, so all entry points share it.
/// Only the ads this device shows count, so a phone-only placement never
/// stops a TV, and nothing is checked while no ad is live. A popup counts as
/// blocked only when every network in its fallback chain is.
///
/// No check requests anything from an ad network: the device's DNS answers
/// for the live hosts, and what happened to the popups the viewer was shown
/// anyway ([observeDelivery]), are the evidence. A network that answered with
/// no ad is not a blocker.
class AdBlockGate {
  AdBlockGate({
    AdBlockDetector? detector,
    List<AdBlockProbe> additionalChecks = const [],
    AdBlockCheckCache? cache,
    AdRedirectResolver? redirects,
    DateTime Function()? now,
  })  : _detector = detector ?? AdBlockDetector(),
        _cache = cache ?? AdBlockCheckCache(),
        _redirects = redirects ?? AdRedirectResolver(),
        _additionalChecks = additionalChecks,
        _now = now ?? DateTime.now {
    // Plus has no ads to protect: a block found before payment must not
    // linger, and players re-read the gate when it lifts.
    AdsPolicy.addListener(_cache.invalidate);
  }

  static final instance = AdBlockGate();

  final AdBlockDetector _detector;
  final AdBlockCheckCache _cache;
  final AdRedirectResolver _redirects;
  final List<AdBlockProbe> _additionalChecks;
  final DateTime Function() _now;

  /// How long a popup's outcome stands for its host.
  static const observationTtl = Duration(minutes: 30);
  final _observed = <String, ({AdDelivery delivery, DateTime at})>{};

  /// Records what a real popup's request to [host], its network's own
  /// delivery host, showed. A changed outcome starts a new check.
  void observeDelivery(String host, AdDelivery delivery) {
    final previous = _observedAt(host);
    _observed[host] = (delivery: delivery, at: _now());
    if (previous != delivery) _cache.invalidate();
  }

  AdDelivery? _observedAt(String host) {
    final seen = _observed[host];
    return seen != null && _now().difference(seen.at) < observationTtl
        ? seen.delivery
        : null;
  }

  /// [forgetPopups] also drops popup outcomes: after the viewer turned a
  /// blocker off, or on another network.
  void invalidate({bool forgetPopups = false}) {
    if (forgetPopups) _observed.clear();
    _cache.invalidate();
  }

  void addListener(VoidCallback listener) => _cache.addListener(listener);
  void removeListener(VoidCallback listener) => _cache.removeListener(listener);
  bool blocksPlayback(AppDependencyProvider provider) =>
      !AdsPolicy.adFree &&
      provider.adBlockGateEnabled &&
      _cache.isBlocked(_key(provider, _sources(provider)));

  AdSources _sources(AppDependencyProvider provider,
          {bool television = false}) =>
      AdBlockDetector.adSources(provider,
          television:
              television || DevicePresentationService.instance.isTelevision);

  Object _key(AppDependencyProvider provider, AdSources sources) {
    String sorted(Iterable<Uri?> urls) =>
        (urls.map((url) => '$url').toList()..sort()).join(',');
    return (
      provider,
      provider.adBlockGateEnabled,
      sorted(sources.required),
      (sources.alternatives.map(sorted).toList()..sort()).join(';'),
    );
  }

  Future<bool> _scan(BuildContext context, AdSources sources) async {
    final resolved = await _redirects.resolve(sources);
    // A popup that reached its network settles that ad, and its chain.
    bool reached(String host) => _observedAt(host) == AdDelivery.reached;
    final ads = AdHosts(
      required: {
        for (final host in resolved.required)
          if (!reached(host)) host,
      },
      alternatives: [
        for (final chain in resolved.alternatives)
          if (!chain.any(reached)) chain,
      ],
    );
    if (ads.all.isEmpty || !context.mounted) return false;
    return _detector.isBlocking(ads.required,
        alternatives: ads.alternatives,
        observedBlocked: {
          for (final host in ads.all)
            if (_observedAt(host) == AdDelivery.blocked) host,
        },
        additionalChecks: [
          for (final check in _additionalChecks) () => check(context, ads),
        ]);
  }

  Future<void> warmUp(BuildContext context) async {
    final provider = context.read<AppDependencyProvider?>();
    if (provider == null ||
        !provider.adBlockGateEnabled ||
        AdsPolicy.adFreeAt(context)) {
      invalidate();
      return;
    }
    final sources = _sources(provider);
    await _cache.warm(_key(provider, sources), () => _scan(context, sources));
  }

  /// False when the viewer backs out; the loader then closes.
  Future<bool> allowPlayback(BuildContext context,
      {bool download = false, bool television = false}) async {
    final provider = context.read<AppDependencyProvider?>();
    if (provider == null ||
        !provider.adBlockGateEnabled ||
        AdsPolicy.adFreeAt(context)) {
      invalidate();
      debugPrint(
          '[AdBlockGate] skipped: gate disabled, ad-free or no provider');
      return true;
    }
    final tv = television || DevicePresentationService.instance.isTelevision;
    final analytics = context.read<SettingsProvider?>()?.analytics;
    var asked = false;
    while (provider.adBlockGateEnabled) {
      final sources = _sources(provider, television: tv);
      final watch = Stopwatch()..start();
      final blocked = await _cache.check(
          _key(provider, sources), () => _scan(context, sources));
      debugPrint('[AdBlockGate] wait=${watch.elapsedMilliseconds}ms '
          'result=${blocked == null ? 'pending; allow' : blocked ? 'blocked' : 'allow'}');
      if (!context.mounted) return false;
      if (!provider.adBlockGateEnabled || blocked != true || AdsPolicy.adFree) {
        break;
      }
      analytics?.trackAdBlockerGate(
          outcome: 'detected', download: download, television: tv);
      final plus = AdsPolicy.offersPlus(context);
      final choice =
          await _ask(context, television: tv, again: asked, plus: plus);
      if (!context.mounted) return false;
      if (choice == _Choice.plus) {
        analytics?.trackAdBlockerGate(
            outcome: 'plus', download: download, television: tv);
        await AdsPolicy.openPlus(context);
        if (!context.mounted) return false;
        // Paid on the way: nothing left to block. Otherwise ask again.
        if (AdsPolicy.adFree) break;
        continue;
      }
      if (choice != _Choice.retry) {
        analytics?.trackAdBlockerGate(
            outcome: 'cancelled', download: download, television: tv);
        return false;
      }
      asked = true;
      invalidate(forgetPopups: true);
    }
    if (asked) {
      analytics?.trackAdBlockerGate(
          outcome: 'cleared', download: download, television: tv);
    }
    return context.mounted;
  }

  /// [_Choice.retry] checks again, after the viewer turned the blocker
  /// off; [_Choice.plus] (offered when [plus]) opens FlixQuest Plus.
  Future<_Choice?> _ask(BuildContext context,
      {required bool television, required bool again, bool plus = false}) {
    final message = again
        ? tr('ad_blocker_still_detected')
        : '${tr('ad_blocker_message')}\n\n${tr('ad_blocker_private_dns_hint')}';
    if (television) {
      return showTvDialog<_Choice>(
        context: context,
        title: tr('ad_blocker_title'),
        content: Text(message),
        actions: [
          TvDialogAction(
            label: tr('ad_blocker_retry'),
            isPrimary: true,
            onPressed: () => Navigator.pop(context, _Choice.retry),
          ),
          if (plus)
            TvDialogAction(
              label: tr('plus_go_ad_free'),
              onPressed: () => Navigator.pop(context, _Choice.plus),
            ),
          TvDialogAction(
            label: tr('cancel'),
            onPressed: () => Navigator.pop(context, _Choice.cancel),
          ),
        ],
      );
    }
    return showDialog<_Choice>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final palette = AppPalette.of(dialogContext);
        return Dialog(
          backgroundColor: palette.surface,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.hero),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpace.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: palette.idleFill,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        PhosphorIcons.shieldWarning(),
                        size: 22,
                        color: palette.foreground,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Text(
                    tr('ad_blocker_title'),
                    style: AppType.sectionHeader.copyWith(
                      fontFamily: AppType.bold,
                      color: palette.foreground,
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    message,
                    style: AppType.body.copyWith(color: palette.mutedText),
                  ),
                  const SizedBox(height: AppSpace.xxl),
                  PillButton(
                    label: tr('ad_blocker_retry'),
                    primary: true,
                    onPressed: () =>
                        Navigator.pop(dialogContext, _Choice.retry),
                  ),
                  if (plus) ...<Widget>[
                    const SizedBox(height: AppSpace.md),
                    PillButton(
                      label: tr('plus_go_ad_free'),
                      leading: const PlusMark(),
                      onPressed: () =>
                          Navigator.pop(dialogContext, _Choice.plus),
                    ),
                  ],
                  const SizedBox(height: AppSpace.md),
                  PillButton(
                    label: tr('cancel'),
                    onPressed: () =>
                        Navigator.pop(dialogContext, _Choice.cancel),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _Choice { retry, plus, cancel }
