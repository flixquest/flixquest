import 'package:xml/xml.dart';

/// IAB VAST error codes the client reports through `[ERRORCODE]`.
abstract final class VastError {
  static const xmlParsing = 100;
  static const wrapperGeneral = 300;
  static const wrapperTimeout = 301;
  static const wrapperLimit = 302;
  static const noAdsAfterWrapper = 303;
  static const linearGeneral = 400;
  static const mediaTimeout = 402;
  static const noSupportedMedia = 403;
  static const mediaDisplay = 405;
}

/// Failure while resolving a tag, with the code to report.
class VastException implements Exception {
  const VastException(this.code, this.message);
  final int code;
  final String message;

  @override
  String toString() => 'VastException($code): $message';
}

class VastMediaFile {
  const VastMediaFile({
    required this.url,
    required this.type,
    this.delivery,
    this.width,
    this.height,
    this.bitrate,
    this.apiFramework,
  });

  final Uri url;
  final String type;
  final String? delivery;
  final int? width;
  final int? height;

  /// Kbps.
  final int? bitrate;
  final String? apiFramework;

  /// Native players can show progressive MP4/WebM and HLS. VPAID and other
  /// interactive creatives need a browser runtime.
  bool get isPlayable {
    if (apiFramework != null && apiFramework!.isNotEmpty) return false;
    final mime = type.toLowerCase();
    return mime == 'video/mp4' ||
        mime == 'video/webm' ||
        mime == 'video/3gpp' ||
        mime == 'application/x-mpegurl' ||
        mime == 'application/vnd.apple.mpegurl';
  }
}

/// `skipoffset`: an absolute time or a percentage of the duration.
class VastSkipOffset {
  const VastSkipOffset.time(Duration this.time) : percent = null;
  const VastSkipOffset.percent(double this.percent) : time = null;

  final Duration? time;
  final double? percent;

  Duration resolve(Duration duration) =>
      time ?? duration * ((percent ?? 0) / 100);

  static VastSkipOffset? parse(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final text = value.trim();
    if (text.endsWith('%')) {
      final percent = double.tryParse(text.substring(0, text.length - 1));
      return percent == null || percent < 0 || percent > 100
          ? null
          : VastSkipOffset.percent(percent);
    }
    final time = parseVastTime(text);
    return time == null ? null : VastSkipOffset.time(time);
  }
}

/// A `progress` tracking event with its offset.
class VastProgressEvent {
  const VastProgressEvent(this.offset, this.url);
  final VastSkipOffset offset;
  final Uri url;
}

/// A playable linear ad with the tracking of its wrappers merged in.
class VastAd {
  VastAd({
    required this.id,
    required this.adSystem,
    required this.duration,
    required this.mediaFiles,
    this.skipOffset,
    this.clickThrough,
    List<Uri>? impressions,
    List<Uri>? errors,
    Map<String, List<Uri>>? tracking,
    List<VastProgressEvent>? progress,
    List<Uri>? clickTracking,
  })  : impressions = impressions ?? [],
        errors = errors ?? [],
        tracking = tracking ?? {},
        progress = progress ?? [],
        clickTracking = clickTracking ?? [];

  final String? id;
  final String? adSystem;
  final Duration duration;
  final List<VastMediaFile> mediaFiles;
  final VastSkipOffset? skipOffset;
  final Uri? clickThrough;
  final List<Uri> impressions;
  final List<Uri> errors;

  /// Event name (`start`, `firstQuartile`, `skip`, ...) to its URLs.
  final Map<String, List<Uri>> tracking;
  final List<VastProgressEvent> progress;
  final List<Uri> clickTracking;

  /// Null when the ad cannot be skipped.
  Duration? get skipAfter => skipOffset?.resolve(duration);

  /// The file closest to [maxHeight] without going over, at most [maxBitrate]
  /// when the server states one. Falls back to the smallest playable file.
  VastMediaFile? pickMediaFile({required int maxHeight, int? maxBitrate}) {
    final playable = mediaFiles.where((file) => file.isPlayable).toList();
    if (playable.isEmpty) return null;
    // Progressive MP4 starts fastest and is the most widely decodable.
    int rank(VastMediaFile file) {
      final type = file.type.toLowerCase();
      if (type == 'video/mp4') return 0;
      if (type.contains('mpegurl')) return 1;
      return 2;
    }

    playable.sort((a, b) {
      final byType = rank(a).compareTo(rank(b));
      if (byType != 0) return byType;
      return (b.height ?? 0).compareTo(a.height ?? 0);
    });
    final bestType = rank(playable.first);
    final candidates =
        playable.where((file) => rank(file) == bestType).toList();
    return candidates.firstWhere(
      (file) =>
          (file.height ?? 0) <= maxHeight &&
          (maxBitrate == null ||
              file.bitrate == null ||
              file.bitrate! <= maxBitrate),
      orElse: () => candidates.last,
    );
  }
}

/// One `<Ad>` element: either a playable InLine or a Wrapper to follow.
class VastAdNode {
  VastAdNode._({
    required this.id,
    required this.adSystem,
    this.wrapperTagUri,
    this.linear,
    required this.impressions,
    required this.errors,
    required this.tracking,
    required this.progress,
    required this.clickTracking,
  });

  final String? id;
  final String? adSystem;

  /// Set for a Wrapper.
  final Uri? wrapperTagUri;

  /// Set for an InLine ad with a linear creative.
  final VastLinear? linear;
  final List<Uri> impressions;
  final List<Uri> errors;
  final Map<String, List<Uri>> tracking;
  final List<VastProgressEvent> progress;
  final List<Uri> clickTracking;

  bool get isWrapper => wrapperTagUri != null;

  /// Merges the tracking of the wrappers that led here, outermost first.
  VastAd toAd(List<VastAdNode> wrappers) {
    final linear = this.linear!;
    final tracking = <String, List<Uri>>{};
    void addTracking(Map<String, List<Uri>> from) {
      from.forEach((event, urls) =>
          tracking.putIfAbsent(event, () => <Uri>[]).addAll(urls));
    }

    for (final wrapper in wrappers) {
      addTracking(wrapper.tracking);
    }
    addTracking(this.tracking);
    return VastAd(
      id: id,
      adSystem: adSystem,
      duration: linear.duration,
      mediaFiles: linear.mediaFiles,
      skipOffset: linear.skipOffset,
      clickThrough: linear.clickThrough,
      impressions: [
        for (final wrapper in wrappers) ...wrapper.impressions,
        ...impressions,
      ],
      errors: [
        for (final wrapper in wrappers) ...wrapper.errors,
        ...errors,
      ],
      tracking: tracking,
      progress: [
        for (final wrapper in wrappers) ...wrapper.progress,
        ...progress,
      ],
      clickTracking: [
        for (final wrapper in wrappers) ...wrapper.clickTracking,
        ...clickTracking,
      ],
    );
  }
}

class VastLinear {
  const VastLinear({
    required this.duration,
    required this.mediaFiles,
    this.skipOffset,
    this.clickThrough,
  });
  final Duration duration;
  final List<VastMediaFile> mediaFiles;
  final VastSkipOffset? skipOffset;
  final Uri? clickThrough;
}

/// Parsed VAST document.
class VastDocument {
  const VastDocument({required this.ads, required this.errors});

  /// Ads in document order. An empty list is a valid no-fill response.
  final List<VastAdNode> ads;

  /// Document-level `<Error>` URLs, used when no ad was returned.
  final List<Uri> errors;

  static VastDocument parse(String xml) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(xml.trim());
    } on XmlException catch (error) {
      throw VastException(VastError.xmlParsing, error.message);
    }
    final root = document.rootElement;
    if (root.localName != 'VAST') {
      throw const VastException(VastError.xmlParsing, 'Root is not <VAST>');
    }
    final ads = <VastAdNode>[];
    final adElements = root.findElements('Ad').toList();
    // Pods play in sequence order; standalone ads follow in document order.
    adElements.sort((a, b) {
      final sa = int.tryParse(a.getAttribute('sequence') ?? '');
      final sb = int.tryParse(b.getAttribute('sequence') ?? '');
      if (sa == null && sb == null) return 0;
      if (sa == null) return 1;
      if (sb == null) return -1;
      return sa.compareTo(sb);
    });
    for (final ad in adElements) {
      final node = _parseAd(ad);
      if (node != null) ads.add(node);
    }
    return VastDocument(ads: ads, errors: _urls(root.findElements('Error')));
  }

  static VastAdNode? _parseAd(XmlElement ad) {
    final inline = ad.getElement('InLine');
    final wrapper = ad.getElement('Wrapper');
    final body = inline ?? wrapper;
    if (body == null) return null;
    final tracking = <String, List<Uri>>{};
    final progress = <VastProgressEvent>[];
    final clickTracking = <Uri>[];
    VastLinear? linear;
    for (final creative in body
        .findElements('Creatives')
        .expand((creatives) => creatives.findElements('Creative'))) {
      final linearElement = creative.getElement('Linear');
      if (linearElement == null) continue;
      _collectTracking(linearElement, tracking, progress);
      final clicks = linearElement.getElement('VideoClicks');
      clickTracking.addAll(_urls(clicks?.findElements('ClickTracking') ?? []));
      if (inline != null && linear == null) {
        final duration =
            parseVastTime(_text(linearElement.getElement('Duration')));
        final mediaFiles = <VastMediaFile>[
          for (final file in linearElement
                  .getElement('MediaFiles')
                  ?.findElements('MediaFile') ??
              const <XmlElement>[])
            if (_url(_text(file)) case final url?)
              VastMediaFile(
                url: url,
                type: file.getAttribute('type') ?? '',
                delivery: file.getAttribute('delivery'),
                width: int.tryParse(file.getAttribute('width') ?? ''),
                height: int.tryParse(file.getAttribute('height') ?? ''),
                bitrate: int.tryParse(file.getAttribute('bitrate') ?? '') ??
                    int.tryParse(file.getAttribute('maxBitrate') ?? ''),
                apiFramework: file.getAttribute('apiFramework'),
              ),
        ];
        if (duration != null && duration > Duration.zero) {
          linear = VastLinear(
            duration: duration,
            mediaFiles: mediaFiles,
            skipOffset:
                VastSkipOffset.parse(linearElement.getAttribute('skipoffset')),
            clickThrough: _url(_text(clicks?.getElement('ClickThrough'))),
          );
        }
      }
    }
    final wrapperTag = wrapper == null
        ? null
        : _url(_text(wrapper.getElement('VASTAdTagURI')));
    if (inline != null && linear == null) return null;
    if (wrapper != null && wrapperTag == null) return null;
    return VastAdNode._(
      id: ad.getAttribute('id'),
      adSystem: _text(body.getElement('AdSystem')),
      wrapperTagUri: wrapperTag,
      linear: linear,
      impressions: _urls(body.findElements('Impression')),
      errors: _urls(body.findElements('Error')),
      tracking: tracking,
      progress: progress,
      clickTracking: clickTracking,
    );
  }

  static void _collectTracking(XmlElement linear,
      Map<String, List<Uri>> tracking, List<VastProgressEvent> progress) {
    for (final event
        in linear.getElement('TrackingEvents')?.findElements('Tracking') ??
            const <XmlElement>[]) {
      final name = event.getAttribute('event');
      final url = _url(_text(event));
      if (name == null || url == null) continue;
      if (name == 'progress') {
        final offset = VastSkipOffset.parse(event.getAttribute('offset'));
        if (offset != null) progress.add(VastProgressEvent(offset, url));
      } else {
        tracking.putIfAbsent(name, () => <Uri>[]).add(url);
      }
    }
  }

  static String? _text(XmlElement? element) {
    final text = element?.innerText.trim();
    return text == null || text.isEmpty ? null : text;
  }

  static Uri? _url(String? value) {
    if (value == null) return null;
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
            (uri.scheme == 'https' || uri.scheme == 'http') &&
            uri.host.isNotEmpty
        ? uri
        : null;
  }

  static List<Uri> _urls(Iterable<XmlElement> elements) => [
        for (final element in elements)
          if (_url(_text(element)) case final url?) url,
      ];
}

/// `HH:MM:SS` or `HH:MM:SS.mmm`.
Duration? parseVastTime(String? value) {
  if (value == null) return null;
  final match =
      RegExp(r'^(\d{1,2}):(\d{2}):(\d{2})(?:\.(\d{1,3}))?$').firstMatch(
    value.trim(),
  );
  if (match == null) return null;
  final millis =
      match.group(4) == null ? 0 : int.parse(match.group(4)!.padRight(3, '0'));
  return Duration(
    hours: int.parse(match.group(1)!),
    minutes: int.parse(match.group(2)!),
    seconds: int.parse(match.group(3)!),
    milliseconds: millis,
  );
}

/// Replaces the VAST macros a native client can fill.
Uri expandVastMacros(
  Uri url, {
  int? errorCode,
  Duration? adPlayhead,
  Duration? contentPlayhead,
  Uri? assetUri,
}) {
  String time(Duration value) {
    final ms = value.inMilliseconds;
    final hours = ms ~/ 3600000;
    final minutes = (ms ~/ 60000) % 60;
    final seconds = (ms ~/ 1000) % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(hours)}:${two(minutes)}:${two(seconds)}.'
        '${(ms % 1000).toString().padLeft(3, '0')}';
  }

  final cacheBuster =
      (DateTime.now().microsecondsSinceEpoch % 100000000).toString();
  final values = <String, String>{
    'CACHEBUSTING': cacheBuster,
    'TIMESTAMP': DateTime.now().toUtc().toIso8601String(),
    if (errorCode != null) 'ERRORCODE': '$errorCode',
    if (adPlayhead != null) 'ADPLAYHEAD': time(adPlayhead),
    if (contentPlayhead != null) 'CONTENTPLAYHEAD': time(contentPlayhead),
    if (assetUri != null) 'ASSETURI': assetUri.toString(),
  };
  var text = url.toString();
  values.forEach((macro, value) {
    final encoded = Uri.encodeComponent(value);
    text = text
        .replaceAll('[$macro]', encoded)
        .replaceAll('%5B$macro%5D', encoded)
        .replaceAll('%5b$macro%5d', encoded);
  });
  return Uri.tryParse(text) ?? url;
}
