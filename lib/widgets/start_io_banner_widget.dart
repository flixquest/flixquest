import 'package:flutter/material.dart';
import 'package:startapp_sdk/startapp.dart';

import '../services/start_io_ads_service.dart';

enum StartIoBannerVariant { standard, tall }

/// A Start.io banner that owns one native banner view for its whole lifetime.
///
/// On Android TV the banner is display-only: it never takes D-pad focus and
/// ignores pointer input. Android TV's app quality rules forbid clickable,
/// non-full-screen ads that open a web page or a phone-only app, and a
/// focusable platform view would also trap remote navigation. TV banners are
/// paid by viewable impression, so nothing is lost.
class StartIoBannerWidget extends StatefulWidget {
  const StartIoBannerWidget({
    required this.placement,
    required this.testMode,
    this.variant = StartIoBannerVariant.standard,
    this.keywords = StartIoAdsService.catalogKeywords,
    this.padding = const EdgeInsets.fromLTRB(20, 14, 20, 6),
    super.key,
  });

  final String placement;
  final bool testMode;
  final StartIoBannerVariant variant;
  final String keywords;
  final EdgeInsetsGeometry padding;

  @override
  State<StartIoBannerWidget> createState() => _StartIoBannerWidgetState();
}

class _StartIoBannerWidgetState extends State<StartIoBannerWidget> {
  StartAppBannerAd? _ad;

  bool get _television => StartIoAdsService.instance.isTelevision;

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
      placement: StartIoAdsService.instance.tagFor(widget.placement),
      testMode: widget.testMode,
      keywords: widget.keywords,
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
    Widget banner = StartAppBanner(ad);
    if (_television) {
      // A thin banner keeps its label beside it, so the unit stays one
      // banner high; a rectangle has room for the label on top.
      final labelled = widget.variant == StartIoBannerVariant.standard
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const _AdLabel(),
                const SizedBox(width: 10),
                banner,
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _AdLabel(),
                const SizedBox(height: 6),
                banner,
              ],
            );
      banner = ExcludeFocus(child: IgnorePointer(child: labelled));
    }
    return Padding(
      padding: widget.padding,
      child: Center(child: banner),
    );
  }
}

class _AdLabel extends StatelessWidget {
  const _AdLabel();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface.withValues(
          alpha: .6,
        );
    return Text(
      'AD',
      style: TextStyle(
        color: color,
        fontFamily: 'FigtreeSB',
        fontSize: 11,
        letterSpacing: 1.6,
      ),
    );
  }
}
