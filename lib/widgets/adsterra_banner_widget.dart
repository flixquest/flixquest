import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/adsterra_ads_config.dart';

/// One WebView per visible banner. Config/size changes replace the view, while
/// ordinary parent rebuilds keep it loaded. There is no automatic refresh.
class AdsterraBannerWidget extends StatefulWidget {
  // Android's reserved app-content host gives local HTML a non-opaque origin
  // so scripts can use document.cookie/storage without adopting an ad server
  // or publisher website's origin. No request is made to this base URL.
  static const documentBaseUrl =
      'https://appassets.androidplatform.net/adsterra/';

  const AdsterraBannerWidget({
    required this.placement,
    required this.unit,
    this.television = false,
    this.padding = const EdgeInsets.fromLTRB(20, 14, 20, 6),
    super.key,
  });

  final String placement;
  final AdsterraBannerUnit unit;
  final bool television;
  final EdgeInsetsGeometry padding;

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  State<AdsterraBannerWidget> createState() => _AdsterraBannerWidgetState();
}

class _AdsterraBannerWidgetState extends State<AdsterraBannerWidget> {
  WebViewController? _controller;
  Timer? _timeout;
  bool _failed = false;
  DateTime? _lastPointerDown;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final controller = WebViewController();
      _controller = controller;
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(Colors.transparent);
      await controller.addJavaScriptChannel('AdsterraStatus',
          onMessageReceived: (message) {
        if (message.message == 'failed') _fail();
        if (message.message == 'loaded') _timeout?.cancel();
      });
      await controller.setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: _navigate,
        onWebResourceError: (error) {
          if (error.isForMainFrame == true) _fail();
        },
      ));
      if (!mounted) return;
      _timeout = Timer(const Duration(seconds: 20), _fail);
      await controller.loadHtmlString(widget.unit.html,
          baseUrl: AdsterraBannerWidget.documentBaseUrl);
      if (mounted && !_failed) setState(() {});
    } catch (_) {
      // A missing system WebView or an ad request failure must not break a
      // catalog screen or prevent playback.
      _fail();
    }
  }

  NavigationDecision _navigate(NavigationRequest request) {
    if (request.url == 'about:blank') return NavigationDecision.navigate;
    final uri = Uri.tryParse(request.url);
    if (uri == null || !const {'http', 'https'}.contains(uri.scheme)) {
      return NavigationDecision.prevent;
    }
    // The creative itself loads into an iframe. Keep its resource navigation
    // inside the view, and never let a redirect replace the Flutter banner.
    if (!request.isMainFrame) return NavigationDecision.navigate;
    final pointer = _lastPointerDown;
    if (mounted &&
        !widget.television &&
        pointer != null &&
        DateTime.now().difference(pointer) < const Duration(seconds: 2)) {
      _lastPointerDown = null;
      unawaited(_openOffer(uri));
    }
    return NavigationDecision.prevent;
  }

  Future<void> _openOffer(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Browser availability does not affect the screen hosting the ad.
    }
  }

  void _fail() {
    _timeout?.cancel();
    if (!mounted || _failed) return;
    setState(() => _failed = true);
    unawaited(_stop());
  }

  Future<void> _stop() async {
    try {
      await _controller?.setJavaScriptMode(JavaScriptMode.disabled);
      await _controller?.loadRequest(Uri.parse('about:blank'));
    } catch (_) {
      // The native view may already have been released.
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    unawaited(_stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_failed || controller == null) return const SizedBox.shrink();
    Widget view = SizedBox(
      width: widget.unit.size.width.toDouble(),
      height: widget.unit.size.height.toDouble(),
      child: Listener(
        onPointerDown: (_) => _lastPointerDown = DateTime.now(),
        child: WebViewWidget(controller: controller),
      ),
    );
    if (widget.television) {
      view = ExcludeFocus(child: IgnorePointer(child: view));
    }
    return Padding(
      padding: widget.padding,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AD',
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: .6),
                  fontFamily: 'FigtreeSB',
                  fontSize: 10,
                  letterSpacing: 1.6,
                )),
            const SizedBox(height: 4),
            view,
          ],
        ),
      ),
    );
  }
}
