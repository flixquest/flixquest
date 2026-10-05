import 'package:flixquest/models/adsterra_ads_config.dart';
import 'package:flutter/widgets.dart';
// The fake exercises the actual public WebView controller/widget boundary.
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

const testAdsterraCatalog = '''{
  "units": {
    "mobile": {"key":"mobile_key","script_url":"https://ads.example/mobile_key/invoke.js","size":"320x50"},
    "rectangle": {"key":"rectangle_key","script_url":"https://ads.example/rectangle_key/invoke.js","size":"300x250"},
    "wide": {"key":"wide_key","script_url":"https://ads.example/wide_key/invoke.js","size":"728x90"}
  },
  "defaults": {
    "standard": ["mobile"], "tall": ["rectangle"],
    "tv_standard": ["mobile"], "tv_tall": ["rectangle"]
  }
}''';

AdsterraAdsConfig testAdsterraConfig(
        {bool enabled = true, bool tvEnabled = true}) =>
    AdsterraAdsConfig.parse(testAdsterraCatalog,
        enabled: enabled, tvEnabled: tvEnabled);

class FakeAdsterraWebViewPlatform extends WebViewPlatform {
  final controllers = <FakeAdsterraWebViewController>[];
  bool signalLoaded = true;
  bool pageHasContent = true;
  final widgetParams = <PlatformWebViewWidgetCreationParams>[];

  @override
  PlatformWebViewController createPlatformWebViewController(
      PlatformWebViewControllerCreationParams params) {
    final controller = FakeAdsterraWebViewController(params, signalLoaded)
      ..pageHasContent = pageHasContent;
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
          PlatformNavigationDelegateCreationParams params) =>
      FakeAdsterraNavigationDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
      PlatformWebViewWidgetCreationParams params) {
    widgetParams.add(params);
    return _FakeWebViewWidget(params);
  }
}

class FakeAdsterraWebViewController extends PlatformWebViewController {
  FakeAdsterraWebViewController(super.params, this.signalLoaded)
      : super.implementation();

  final bool signalLoaded;
  final htmlLoads = <String>[];
  final baseUrls = <String?>[];
  final requests = <Uri>[];
  JavaScriptMode? javaScriptMode;
  JavaScriptChannelParams? channel;
  FakeAdsterraNavigationDelegate? delegate;
  bool pageHasContent = true;
  final evaluatedScripts = <String>[];

  @override
  Future<void> setOnConsoleMessage(
      void Function(JavaScriptConsoleMessage) onConsoleMessage) async {}

  @override
  Future<Object> runJavaScriptReturningResult(String javaScript) async {
    evaluatedScripts.add(javaScript);
    return pageHasContent;
  }

  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {
    javaScriptMode = mode;
  }

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {
    channel = params;
  }

  @override
  Future<void> setPlatformNavigationDelegate(
      PlatformNavigationDelegate handler) async {
    delegate = handler as FakeAdsterraNavigationDelegate;
  }

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {
    htmlLoads.add(html);
    baseUrls.add(baseUrl);
    if (signalLoaded) send('loaded');
  }

  void send(String message) =>
      channel?.onMessageReceived(JavaScriptMessage(message: message));

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    requests.add(params.uri);
  }
}

class FakeAdsterraNavigationDelegate extends PlatformNavigationDelegate {
  FakeAdsterraNavigationDelegate(super.params) : super.implementation();
  NavigationRequestCallback? onNavigationRequest;
  WebResourceErrorCallback? onWebResourceError;
  PageEventCallback? onPageFinished;
  PageEventCallback? onPageStarted;
  HttpResponseErrorCallback? onHttpError;

  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback callback) async {
    onHttpError = callback;
  }

  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {
    onPageFinished = callback;
  }

  @override
  Future<void> setOnPageStarted(PageEventCallback callback) async {
    onPageStarted = callback;
  }

  @override
  Future<void> setOnNavigationRequest(
      NavigationRequestCallback callback) async {
    onNavigationRequest = callback;
  }

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {
    onWebResourceError = callback;
  }
}

class _FakeWebViewWidget extends PlatformWebViewWidget {
  _FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: Color(0xffaaaaaa), key: ValueKey('fake-webview'));
}
