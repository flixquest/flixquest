import 'package:flutter/material.dart';
import 'package:startapp_sdk/startapp.dart';

import '../services/start_io_ads_service.dart';

enum StartIoBannerVariant { standard, tall }

/// A Start.io banner that owns one native banner view for its whole lifetime.
class StartIoBannerWidget extends StatefulWidget {
  const StartIoBannerWidget({
    required this.placement,
    required this.testMode,
    this.variant = StartIoBannerVariant.standard,
    super.key,
  });

  final String placement;
  final bool testMode;
  final StartIoBannerVariant variant;

  @override
  State<StartIoBannerWidget> createState() => _StartIoBannerWidgetState();
}

class _StartIoBannerWidgetState extends State<StartIoBannerWidget> {
  StartAppBannerAd? _ad;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(StartIoBannerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placement != widget.placement ||
        oldWidget.testMode != widget.testMode ||
        oldWidget.variant != widget.variant) {
      _ad?.dispose();
      _ad = null;
      _load();
    }
  }

  Future<void> _load() async {
    final ad = await StartIoAdsService.instance.loadBanner(
      placement: widget.placement,
      testMode: widget.testMode,
      type: widget.variant == StartIoBannerVariant.tall
          ? StartAppBannerType.MREC
          : StartAppBannerType.BANNER,
    );
    if (!mounted) {
      ad?.dispose();
      return;
    }
    if (ad != null) setState(() => _ad = ad);
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Center(child: StartAppBanner(ad)),
    );
  }
}
