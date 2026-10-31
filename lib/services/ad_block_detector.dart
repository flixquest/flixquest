import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/adsterra_playback_ads_config.dart';
import '../provider/app_dependency_provider.dart';
import 'ad_delivery.dart';

/// Resolves a host with the device's own DNS, the path every ad request takes.
typedef HostLookup = Future<List<InternetAddress>> Function(String host);

/// Whether a host exists in public DNS; null when no public resolver answered.
typedef PublicHostLookup = Future<bool?> Function(String host);
typedef AdBlockCheck = Future<bool> Function();

/// Where one device's ads load from, before FlixQuest's redirectors are
/// resolved. Each [required] source serves an ad of its own; each
/// [alternatives] chain serves one ad from whichever source can. A null
/// source cannot be probed, so its chain never counts as blocked.
typedef AdSources = ({Set<Uri?> required, List<Set<Uri?>> alternatives});

/// [AdSources] as hosts, ready to probe.
class AdHosts {
  const AdHosts({this.required = const {}, this.alternatives = const []});

  final Set<String> required;
  final List<Set<String>> alternatives;

  Set<String> get all =>
      {...required, for (final chain in alternatives) ...chain};

  /// Whether these unreachable hosts leave an ad with nowhere to load from.
  bool blockedBy(Set<String> unreachable) =>
      required.any(unreachable.contains) ||
      alternatives.any(
          (chain) => chain.isNotEmpty && chain.every(unreachable.contains));
}

/// Detects DNS-level ad blocking: Private DNS (AdGuard DNS, NextDNS), local
/// VPN blockers (AdGuard, Blokada, RethinkDNS), hosts files (AdAway) and
/// network filters such as Pi-hole. Apps have no browser extensions, so this
/// is how Android users block FlixQuest's ads.
///
/// Only the hosts FlixQuest's live ads load from are probed ([adHosts]), so a
/// blocker that leaves Adsterra and ExoClick alone never stops playback.
/// A blocker is reported on positive evidence; inconclusive checks let
/// playback continue:
/// - an ad host answers with a sinkhole address (`0.0.0.0`, `::`, loopback);
/// - or the device cannot resolve an ad host, twice, while public DNS over
///   HTTPS finds it and a neutral control resolves on the device. A retired
///   ad domain fails publicly too. Optional HTTPS and WebView checks share
///   the same deadline; one failed check cannot hide another positive result.
class AdBlockDetector {
  AdBlockDetector({
    HostLookup? lookup,
    PublicHostLookup? publicLookup,
    http.Client? client,
    List<String>? publicResolvers,
    this.timeout = const Duration(seconds: 6),
  })  : _lookup = lookup ?? InternetAddress.lookup,
        _publicLookup = publicLookup ??
            _dnsOverHttps(client, publicResolvers ?? _publicResolvers);

  final HostLookup _lookup;
  final PublicHostLookup _publicLookup;

  /// Past this, the check gives up and reports no blocker.
  final Duration timeout;

  static const _publicResolvers = [
    'https://cloudflare-dns.com/dns-query',
    'https://dns.google/resolve',
  ];

  static const dnsControlHosts = {'example.com', 'www.wikipedia.org'};

  /// FlixQuest's own pages and redirectors; never an ad host.
  static bool isFirstPartyHost(String host) =>
      host == 'flix.quest' || host.endsWith('.flix.quest');

  /// Where the ads this device can show load from, as [AdSources]: banners
  /// and Adsterra's Social Bar on their own, and the popup and VAST chains,
  /// whose next network serves when one cannot. Only these are probed: a
  /// blocker that stops ad domains FlixQuest does not use leaves its ads
  /// showing.
  static AdSources adSources(AppDependencyProvider provider,
      {bool television = false}) {
    final adsterra = provider.adsterraPlaybackAds;
    final socialBar = adsterra.interstitial;
    return (
      required: {
        for (final catalog in provider.activeBannerCatalogs)
          if (!television || catalog.tvEnabled)
            for (final unit in catalog.units.values) unit.scriptUrl,
        if (adsterra.enabled && !television && socialBar != null)
          _source(socialBar),
      },
      alternatives: [
        {
          for (final source
              in provider.vastPreroll.sourcesFor(television: television))
            source.tagUrl,
        },
        for (final stage in television
            ? const [PlaybackAdStage.streamFound]
            : [PlaybackAdStage.streamFound, ...PlaybackAdStage.triggers])
          {
            for (final placement in _popupChain(provider, stage, television))
              _source(placement),
          },
      ]..removeWhere((chain) => chain.isEmpty),
    );
  }

  /// Every third-party host in [adSources].
  static Set<String> adHosts(AppDependencyProvider provider,
          {bool television = false}) =>
      {
        for (final source in _all(adSources(provider, television: television)))
          if (source != null && !isFirstPartyHost(source.host)) source.host,
      }..remove('');

  /// Direct links served through FlixQuest, such as ExoClick's
  /// `flix.quest/api/exoclick-popup`, whose ad host rotates on the server.
  static Set<Uri> adRedirects(AppDependencyProvider provider,
          {bool television = false}) =>
      {
        for (final source in _all(adSources(provider, television: television)))
          if (source != null && isFirstPartyHost(source.host)) source,
      };

  static Iterable<Uri?> _all(AdSources sources) =>
      [...sources.required, for (final chain in sources.alternatives) ...chain];

  /// A FlixQuest-hosted tag page loads its network's scripts out of sight,
  /// so it is an unknown (null) source that never counts as blocked.
  static Uri? _source(PlaybackAdPlacement placement) =>
      placement.smartlinkUrl ?? placement.scriptUrl;

  /// Mirrors the playback ad service: the selected network, then its
  /// fallbacks, each with its own switch. TV only has `tv_popunder`.
  static Iterable<PlaybackAdPlacement> _popupChain(
      AppDependencyProvider provider,
      PlaybackAdStage stage,
      bool television) sync* {
    final selected = television
        ? provider.tvPlaybackPopunderNetwork
        : provider.playbackPopunderNetwork;
    if (selected == null ||
        (stage.triggerKey != null &&
            provider.popupTrigger(stage)?.enabled != true)) {
      return;
    }
    final adsterra = provider.adsterraPlaybackAds;
    for (final network in {
      selected,
      ...provider.playbackPopunderFallbackNetworks,
    }) {
      if (network == AdNetwork.adsterra) {
        if (adsterra.forStage(stage, television: television)
            case final placement?) {
          yield placement;
        }
        // Viewers rotate through an experiment's variants.
        if (adsterra.enabled &&
            stage == PlaybackAdStage.streamFound &&
            !television) {
          yield* [...?adsterra.streamFoundExperiment?.variants]
              .map((variant) => variant.placement);
        }
        continue;
      }
      final popup = provider.popunderAdsFor(network);
      final placement = stage == PlaybackAdStage.streamFound
          ? popup.activeFor(television: television)
          : popup.activeForTrigger(stage);
      if (placement != null) yield placement;
    }
  }

  /// What blockers answer instead of a real address.
  @visibleForTesting
  static bool isSinkhole(InternetAddress address) {
    final bytes = address.rawAddress;
    // IPv4-mapped IPv6 must be interpreted as IPv4, including 127.x and 0.x.
    if (bytes.length == 16 &&
        bytes.take(10).every((byte) => byte == 0) &&
        bytes[10] == 255 &&
        bytes[11] == 255) {
      return bytes[12] == 127 || bytes.skip(12).every((byte) => byte == 0);
    }
    return address.isLoopback || bytes.every((byte) => byte == 0);
  }

  /// Each of [hosts] serves an ad of its own; of each [alternatives] chain,
  /// one reachable host is enough, so only a fully blocked chain counts.
  /// [observedBlocked] hosts failed for a real popup ([AdDelivery.blocked]);
  /// they count once public DNS shows the host exists and local DNS is
  /// healthy, so a retired domain or an offline device is never blamed.
  Future<bool> isBlocking(Set<String> hosts,
      {List<Set<String>> alternatives = const [],
      Set<String> observedBlocked = const {},
      Iterable<AdBlockCheck> additionalChecks = const []}) async {
    final chains = alternatives.where((chain) => chain.isNotEmpty).toList();
    if (hosts.isEmpty && chains.isEmpty && additionalChecks.isEmpty) {
      return false;
    }
    Future<bool>? controls;
    Future<bool> healthyDns() => controls ??= Stream<_LocalAnswer>.fromFutures(
          dnsControlHosts.map(_resolveLocally),
        ).any((answer) => answer == _LocalAnswer.address);
    final checked = <String, Future<bool>>{};
    Future<bool> blocked(String host) =>
        checked[host] ??= _guard(() => observedBlocked.contains(host)
            ? _isObservedBlockConfirmed(host, healthyDns)
            : _isHostBlocked(host, healthyDns));
    try {
      return await Stream<bool>.fromFutures([
        for (final host in hosts) blocked(host),
        for (final chain in chains)
          Future.wait(chain.map(blocked))
              .then((results) => results.every((result) => result)),
        for (final check in additionalChecks) _guard(check),
      ]).any((blocked) => blocked).timeout(timeout);
    } on TimeoutException {
      debugPrint('[AdBlockDetector] timed out; assuming no blocker');
      return false;
    }
  }

  Future<bool> _guard(AdBlockCheck check) async {
    try {
      return await check();
    } catch (error) {
      debugPrint('[AdBlockDetector] inconclusive check: $error');
      return false;
    }
  }

  Future<bool> _isHostBlocked(
      String host, Future<bool> Function() healthyDns) async {
    final local = await _resolveLocally(host);
    if (local == _LocalAnswer.sinkhole) {
      if (!await healthyDns()) return false;
      debugPrint('[AdBlockDetector] sinkholed ad host: $host');
      return true;
    }
    if (local == _LocalAnswer.address || local == _LocalAnswer.unknown) {
      return false;
    }
    if (await _publicLookup(host) == true && await healthyDns()) {
      // Rule out a one-off resolver failure before blaming a blocker.
      final again = await _resolveLocally(host);
      if (again == _LocalAnswer.none || again == _LocalAnswer.sinkhole) {
        debugPrint('[AdBlockDetector] $host resolves publicly but not here');
        return true;
      }
    }
    return false;
  }

  Future<bool> _isObservedBlockConfirmed(
      String host, Future<bool> Function() healthyDns) async {
    if (await _publicLookup(host) != true || !await healthyDns()) return false;
    debugPrint('[AdBlockDetector] a popup could not reach $host');
    return true;
  }

  Future<_LocalAnswer> _resolveLocally(String host) async {
    try {
      final addresses =
          await _lookup(host).timeout(const Duration(milliseconds: 1500));
      if (addresses.isEmpty) return _LocalAnswer.none;
      return addresses.every(isSinkhole)
          ? _LocalAnswer.sinkhole
          : _LocalAnswer.address;
    } on SocketException {
      return _LocalAnswer.none;
    } on TimeoutException {
      return _LocalAnswer.unknown;
    }
  }

  /// Independent public resolvers check both A and AAAA records in parallel.
  /// A real answer from either confirms existence; missing, filtered and
  /// malformed answers cannot override another resolver's positive answer.
  static PublicHostLookup _dnsOverHttps(
          http.Client? sharedClient, List<String> resolvers) =>
      (host) async {
        Future<bool?> query(String resolver, String type) async {
          final client = sharedClient ?? http.Client();
          try {
            final response = await client.get(
              Uri.parse(resolver)
                  .replace(queryParameters: {'name': host, 'type': type}),
              headers: const {'accept': 'application/dns-json'},
            ).timeout(const Duration(milliseconds: 1200));
            if (response.statusCode != 200) return null;
            final json = jsonDecode(response.body);
            if (json is! Map) return null;
            if (json['Status'] == 3) return false;
            if (json['Status'] != 0) return null;
            final answers = json['Answer'];
            return answers is List &&
                answers.any((answer) {
                  if (answer is! Map ||
                      answer['type'] != (type == 'A' ? 1 : 28)) {
                    return false;
                  }
                  final data = answer['data'];
                  final address =
                      data is String ? InternetAddress.tryParse(data) : null;
                  return address != null && !isSinkhole(address);
                });
          } catch (error) {
            debugPrint('[AdBlockDetector] $resolver unavailable ($error)');
            return null;
          } finally {
            if (sharedClient == null) client.close();
          }
        }

        final answers = await Future.wait([
          for (final resolver in resolvers)
            for (final type in ['A', 'AAAA']) query(resolver, type),
        ]);
        if (answers.contains(true)) return true;
        return answers.isNotEmpty && answers.every((answer) => answer == false)
            ? false
            : null;
      };
}

enum _LocalAnswer { address, sinkhole, none, unknown }
