import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'ad_block_detector.dart';

/// Learns where FlixQuest's own ad redirectors send viewers right now, such
/// as ExoClick's rotating delivery domain behind `flix.quest/api/exoclick-popup`.
/// The redirect is read, never followed, so the network sees no request and
/// counts no impression.
class AdRedirectResolver {
  AdRedirectResolver({
    http.Client Function()? clientFactory,
    DateTime Function()? now,
    this.validFor = const Duration(hours: 1),
    this.requestTimeout = const Duration(seconds: 3),
  })  : _clientFactory = clientFactory ?? http.Client.new,
        _now = now ?? DateTime.now;

  final http.Client Function() _clientFactory;
  final DateTime Function() _now;

  /// The server keeps a delivery domain for a day; an hour is fresh enough.
  final Duration validFor;
  final Duration requestTimeout;
  final _resolved = <Uri, ({String host, DateTime at})>{};

  Future<Set<String>> hosts(Iterable<Uri> redirects) async =>
      (await Future.wait(redirects.map(host))).nonNulls.toSet();

  /// [sources] as hosts. A redirect that cannot be read, or an unknown
  /// (null) source, is left out: it cannot be judged.
  Future<Set<String>> resolve(Set<Uri?> sources) async => {
        for (final host in await Future.wait(sources.nonNulls.map((source) =>
            AdBlockDetector.isFirstPartyHost(source.host)
                ? host(source)
                : Future.value(source.host))))
          if (host != null && host.isNotEmpty) host,
      };

  /// The ad host [redirect] points to; the last one seen when it cannot be
  /// read now, and null when it never could.
  Future<String?> host(Uri redirect) async {
    final known = _resolved[redirect];
    if (known != null && _now().difference(known.at) < validFor) {
      return known.host;
    }
    final client = _clientFactory();
    try {
      final request = http.Request('HEAD', redirect)
        ..followRedirects = false
        ..headers['cache-control'] = 'no-cache';
      final response = await client.send(request).timeout(requestTimeout);
      final location = response.headers['location'];
      if (response.statusCode < 300 ||
          response.statusCode >= 400 ||
          location == null) {
        return known?.host;
      }
      final host = redirect.resolve(location).host;
      if (host.isEmpty || AdBlockDetector.isFirstPartyHost(host)) {
        return known?.host;
      }
      _resolved[redirect] = (host: host, at: _now());
      return host;
    } catch (error) {
      debugPrint('[AdBlockDetector] $redirect unresolved ($error)');
      return known?.host;
    } finally {
      // Closing also aborts a request that outlives its timeout.
      client.close();
    }
  }
}
