import 'dart:io';

import 'package:flixquest/services/ad_block_detector.dart';
import 'package:flutter_test/flutter_test.dart';

// Run against the local Postman simulation; no real ad server is contacted.
void main() {
  final base = Platform.environment['FQ_AD_BLOCK_SIMULATION_URL'];
  final skip = base == null
      ? 'Start ad-block-probes.sim.yaml and set FQ_AD_BLOCK_SIMULATION_URL'
      : false;
  Uri endpoint(String path) => Uri.parse('$base/$path');

  AdBlockDetector dnsDetector({bool brokenDnsResponse = false}) =>
      AdBlockDetector(
        publicResolvers: [
          endpoint(brokenDnsResponse ? 'hang' : 'dns').toString()
        ],
        lookup: (host) async {
          if (AdBlockDetector.dnsControlHosts.contains(host)) {
            return [InternetAddress('1.1.1.1')];
          }
          throw const SocketException('NXDOMAIN');
        },
      );
  test('real DNS JSON accepts IPv6-only public records', () async {
    expect(await dnsDetector().isBlocking({'ipv6.example'}), isTrue);
  }, skip: skip);
  test('retired domains, malformed DNS and stalled resolvers allow playback',
      () async {
    expect(await dnsDetector().isBlocking({'retired.example'}), isFalse);
    expect(await dnsDetector().isBlocking({'unreadable.example'}), isFalse);
    expect(
        await dnsDetector(brokenDnsResponse: true).isBlocking({'ipv6.example'}),
        isFalse);
  }, skip: skip);
}
