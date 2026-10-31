import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/adsterra_playback_ads_config.dart';
import '../provider/app_dependency_provider.dart';

/// Resolves a host with the device's own DNS, the path every ad request takes.
typedef HostLookup = Future<List<InternetAddress>> Function(String host);

/// Whether a host exists in public DNS; null when no public resolver answered.
typedef PublicHostLookup = Future<bool?> Function(String host);
typedef AdBlockCheck = Future<bool> Function();

/// Detects DNS-level ad blocking: Private DNS (AdGuard DNS, NextDNS), local
/// VPN blockers (AdGuard, Blokada, RethinkDNS), hosts files (AdAway) and
/// network filters such as Pi-hole. Apps have no browser extensions, so this
/// is how Android users block FlixQuest's ads.
///
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

  /// A stable ad-domain probe catches DNS filtering even when a network's
  /// rotating script/smartlink domains have not reached blocklists yet.
  /// This is only a DNS lookup; no ad is requested from this host.
  static const dnsProbeHosts = {
    'doubleclick.net',
    'pagead2.googlesyndication.com',
    'ads.pubmatic.com',
  };
  static const dnsControlHosts = {'example.com', 'www.wikipedia.org'};

  /// The live banner catalog, Adsterra placements, selected and fallback popup
  /// networks and enabled VAST tags. FlixQuest-hosted pages are not ad hosts.
  static Set<String> adHosts(AppDependencyProvider provider) {
    final playback = provider.adsterraPlaybackAds;
    final popups = [
      for (final network in {
        provider.playbackPopunderNetwork,
        provider.tvPlaybackPopunderNetwork,
        ...provider.playbackPopunderFallbackNetworks,
      })
        if (network != null && network != AdNetwork.adsterra)
          provider.popunderAdsFor(network),
    ];
    final placements = <PlaybackAdPlacement?>[
      if (playback.enabled) ...[
        playback.interstitial,
        playback.popunder,
        playback.tvPopunder,
        ...playback.triggerPlacements.values,
        ...?playback.streamFoundExperiment?.variants
            .map((variant) => variant.placement),
      ],
      for (final popup in popups)
        if (popup.enabled) ...[
          popup.popunder,
          popup.tvPopunder,
          ...popup.triggerPlacements.values,
        ],
    ];
    return {
      for (final catalog in provider.activeBannerCatalogs)
        for (final unit in catalog.units.values) unit.scriptUrl.host,
      for (final placement in placements) ...[
        if (placement?.scriptUrl != null) placement!.scriptUrl!.host,
        if (placement?.smartlinkUrl != null) placement!.smartlinkUrl!.host,
      ],
      if (provider.vastPreroll.enabled)
        for (final source in provider.vastPreroll.sources) source.tagUrl.host,
    }..removeWhere((host) => host.isEmpty);
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

  Future<bool> isBlocking(Set<String> hosts,
      {Iterable<AdBlockCheck> additionalChecks = const []}) async {
    if (hosts.isEmpty && additionalChecks.isEmpty) return false;
    Future<bool>? controls;
    Future<bool> healthyDns() => controls ??= Stream<_LocalAnswer>.fromFutures(
          dnsControlHosts.map(_resolveLocally),
        ).any((answer) => answer == _LocalAnswer.address);
    try {
      return await Stream<bool>.fromFutures([
        for (final host in hosts)
          _guard(() => _isHostBlocked(host, healthyDns)),
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
