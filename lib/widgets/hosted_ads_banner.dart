import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../models/banner_ad.dart';
import '../provider/app_dependency_provider.dart';
import '../services/hosted_ads_repository.dart';
import '../services/start_io_ads_service.dart';
import 'start_io_banner_widget.dart';

final CacheManager _adImageCache = CacheManager(
  Config(
    'flixquest_ad_images',
    stalePeriod: const Duration(minutes: 15),
    maxNrOfCacheObjects: 24,
  ),
);

enum HostedBannerVariant {
  standard,
  tall;

  bool get isTall => this == HostedBannerVariant.tall;
}

/// One banner slot shared by the two ad sources.
///
/// The hosted `/ads` banner (announcements and calls to action from our own
/// backend) and the Start.io banner are independent: each has its own
/// switch and either can be live without the other. [HostedBannerMode]
/// decides what happens when both are live in the same slot. A remotely
/// configured `banner_ad_network=none` still hides everything.
class RemoteHostedAdsBanner extends StatefulWidget {
  const RemoteHostedAdsBanner({
    required this.placement,
    this.loadAds,
    this.variant = HostedBannerVariant.standard,
    this.keywords = StartIoAdsService.catalogKeywords,
    this.padding = const EdgeInsets.fromLTRB(20, 14, 20, 6),
    super.key,
  });

  /// Replaces the shared `/ads` loader; used by tests.
  final Future<List<BannerAd>> Function()? loadAds;
  final String placement;
  final HostedBannerVariant variant;
  final String keywords;
  final EdgeInsetsGeometry padding;

  @override
  State<RemoteHostedAdsBanner> createState() => _RemoteHostedAdsBannerState();
}

class _RemoteHostedAdsBannerState extends State<RemoteHostedAdsBanner> {
  Future<List<BannerAd>>? _ads;

  Future<List<BannerAd>> _load(AppDependencyProvider dependencies) =>
      widget.loadAds?.call() ??
      HostedAdsRepository.instance.load(dependencies.flixquestAPIURL);

  @override
  Widget build(BuildContext context) {
    final dependencies = context.watch<AppDependencyProvider?>();
    if (dependencies == null || dependencies.bannerAdNetwork == 'none') {
      return const SizedBox.shrink();
    }
    final television = StartIoAdsService.instance.isTelevision;
    final hostedActive = dependencies.isHostedBannerActive;
    // Both sources can show on Android TV; their widgets stay display-only.
    final startIoActive = dependencies.isStartIoBannerActive;
    if (!hostedActive) return _startIo(dependencies, widget.padding);
    final ads = _ads ??= _load(dependencies);
    final priority = dependencies.hostedBannerMode == HostedBannerMode.priority;

    return FutureBuilder<List<BannerAd>>(
      future: ads,
      builder: (context, snapshot) {
        final settled = snapshot.connectionState == ConnectionState.done;
        final shown = (snapshot.data ?? const <BannerAd>[])
            .where(
              (ad) =>
                  ad.appliesTo(widget.placement, television: television) &&
                  dependencies.isBannerEnabled(ad.key, widget.placement),
            )
            .toList(growable: false);
        final hosted = shown.isEmpty
            ? null
            : HostedAdsBanner(
                ads: shown,
                variant: widget.variant,
                interactive: !television,
                padding: widget.padding,
              );
        // In priority mode Start.io waits for the answer, so a slot that a
        // hosted ad takes never loads (and bills) a banner underneath it.
        final showStartIo =
            startIoActive && (!priority || (settled && hosted == null));
        if (hosted == null && !showStartIo) return const SizedBox.shrink();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (hosted != null) hosted,
            if (showStartIo)
              _startIo(
                dependencies,
                hosted == null ? widget.padding : _tucked(widget.padding),
              ),
          ],
        );
      },
    );
  }

  /// Keeps the Start.io banner close under a hosted banner it shares a slot
  /// with, instead of doubling the gap.
  EdgeInsetsGeometry _tucked(EdgeInsetsGeometry padding) =>
      padding.resolve(Directionality.of(context)).copyWith(top: 6);

  Widget _startIo(
    AppDependencyProvider dependencies,
    EdgeInsetsGeometry padding,
  ) {
    if (!dependencies.isStartIoBannerActive) {
      return const SizedBox.shrink();
    }
    return StartIoBannerWidget(
      placement: widget.placement,
      testMode: dependencies.unityTestMode,
      keywords: widget.keywords,
      padding: padding,
      variant: widget.variant == HostedBannerVariant.tall
          ? StartIoBannerVariant.tall
          : StartIoBannerVariant.standard,
    );
  }
}

/// A banner for surfaces that never passed their own ad loader: the stream
/// loader, Live TV and the TV details page.
class StartIoAdSlot extends StatelessWidget {
  const StartIoAdSlot({
    required this.placement,
    this.variant = HostedBannerVariant.tall,
    this.keywords = StartIoAdsService.catalogKeywords,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final String placement;
  final HostedBannerVariant variant;
  final String keywords;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => RemoteHostedAdsBanner(
        placement: placement,
        variant: variant,
        keywords: keywords,
        padding: padding,
      );
}

/// The hosted announcement / call-to-action banner served by `/ads`.
class HostedAdsBanner extends StatelessWidget {
  const HostedAdsBanner({
    required this.ads,
    this.variant = HostedBannerVariant.standard,
    this.interactive = true,
    this.padding = const EdgeInsets.fromLTRB(20, 14, 20, 6),
    super.key,
  });

  final List<BannerAd> ads;
  final HostedBannerVariant variant;

  /// The widest a banner grows, so a tablet doesn't stretch it edge to edge.
  static const _maxWidth = 640.0;

  /// Android TV's quality rules forbid an in-page ad that opens a web page, so
  /// TV shows the banner without a tap target or D-pad focus.
  final bool interactive;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final validAds = ads
        .where((ad) => ad.imageUrl.isNotEmpty && ad.targetUrl.isNotEmpty)
        .toList(growable: false);
    if (validAds.isEmpty) return const SizedBox.shrink();
    var shownAds = validAds;
    if (variant.isTall) {
      final preferred =
          validAds.where((ad) => ad.shape != 'wide').toList(growable: false);
      if (preferred.isNotEmpty) shownAds = preferred;
    }
    final dependencies = context.watch<AppDependencyProvider>();
    final config = dependencies.bannerConfigFor(shownAds.first.key);
    final shape = config.shape ?? shownAds.first.shape;
    final aspectRatio = config.aspectRatio ?? shownAds.first.aspectRatio;
    var ratio = shape == 'square'
        ? 1.0
        : shape == 'portrait'
            ? .75
            : shape == 'wide'
                ? 3.2
                : aspectRatio;
    if (variant.isTall && config.shape == null && config.aspectRatio == null) {
      ratio = shape == 'square' || shape == 'portrait' ? ratio : 2.2;
    }

    // The banner keeps the image's own shape, so nothing is cropped, and
    // sits centred. A remotely set width or height only caps its size.
    final maxWidth = config.width ?? _maxWidth;
    final maxHeight = config.height ?? (variant.isTall ? 420.0 : 320.0);
    Widget banner = _AdImageRatio(
      imageUrl: shownAds.first.imageUrl,
      fallback: ratio,
      builder: (context, imageRatio) => LayoutBuilder(
        builder: (context, constraints) {
          var width = math.min(constraints.maxWidth, maxWidth);
          var height = width / imageRatio;
          if (height > maxHeight) {
            height = maxHeight;
            width = height * imageRatio;
          }
          return Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: _CachedAdCarousel(
                ads: shownAds,
                width: width,
                height: height,
                interactive: interactive,
              ),
            ),
          );
        },
      ),
    );
    if (!interactive) {
      banner = ExcludeFocus(child: IgnorePointer(child: banner));
    }
    return Padding(padding: padding, child: banner);
  }
}

/// Reads the ad image's own width-to-height ratio, so a banner sized from it
/// shows the whole image. Until the image loads, [fallback] stands in.
class _AdImageRatio extends StatefulWidget {
  const _AdImageRatio({
    required this.imageUrl,
    required this.fallback,
    required this.builder,
  });

  final String imageUrl;
  final double fallback;
  final Widget Function(BuildContext context, double ratio) builder;

  @override
  State<_AdImageRatio> createState() => _AdImageRatioState();
}

class _AdImageRatioState extends State<_AdImageRatio> {
  late final ImageStreamListener _listener =
      ImageStreamListener(_onImage, onError: (_, __) {});
  ImageStream? _stream;
  double? _ratio;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(_AdImageRatio oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl == widget.imageUrl) return;
    _ratio = null;
    _resolve();
  }

  void _resolve() {
    final stream = CachedNetworkImageProvider(
      widget.imageUrl,
      cacheManager: _adImageCache,
    ).resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  void _onImage(ImageInfo info, bool _) {
    final image = info.image;
    final ratio = image.height == 0 ? null : image.width / image.height;
    info.dispose();
    if (ratio == null || ratio == _ratio) return;
    setState(() => _ratio = ratio);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _ratio ?? widget.fallback);
}

Future<void> _open(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) return;
  try {
    await launchUrlString(url, mode: LaunchMode.externalApplication);
  } catch (_) {
    // A broken link must not surface as an error on a browsing screen.
  }
}

class _CachedAdCarousel extends StatefulWidget {
  const _CachedAdCarousel({
    required this.ads,
    required this.width,
    required this.height,
    required this.interactive,
  });

  final List<BannerAd> ads;
  final double width;
  final double height;
  final bool interactive;

  @override
  State<_CachedAdCarousel> createState() => _CachedAdCarouselState();
}

class _CachedAdCarouselState extends State<_CachedAdCarousel> {
  final PageController _controller = PageController();
  Timer? _rotationTimer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    if (widget.ads.length > 1) {
      _rotationTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        if (!mounted) return;
        _index = (_index + 1) % widget.ads.length;
        _controller.animateToPage(
          _index,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: PageView.builder(
        controller: _controller,
        itemCount: widget.ads.length,
        onPageChanged: (index) => _index = index,
        itemBuilder: (context, index) {
          final ad = widget.ads[index];
          return GestureDetector(
            onTap: widget.interactive
                ? () => unawaited(_open(ad.targetUrl))
                : null,
            child: Semantics(
              label: ad.altText.isEmpty ? ad.name : ad.altText,
              image: true,
              child: CachedNetworkImage(
                imageUrl: ad.imageUrl,
                cacheManager: _adImageCache,
                fit: BoxFit.cover,
                placeholder: (_, __) => const SizedBox.shrink(),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          );
        },
      ),
    );
  }
}
