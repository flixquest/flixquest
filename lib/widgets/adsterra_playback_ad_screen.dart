import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../models/adsterra_playback_ads_config.dart';
import 'adsterra_banner_widget.dart';

/// Hands a Play Store link to a store app and reports whether one opened.
typedef StoreLauncher = Future<bool> Function(Uri uri);

/// Never a browser: `externalNonBrowserApplication` fails instead of falling
/// back to one.
Future<bool> openStoreApp(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);

enum _Phase { script, page }

/// A visible, disposable ad surface with no hidden preloading or refresh.
///
/// Script tags (Adsterra's Social Bar and Popunder, Clickadu's onclick tag) run
/// in one WebView. Advertiser pages (Smartlinks, Direct Links and the popups a
/// script emits) open in FlixQuest's own ad page,
/// never in an external browser. On that page the close control and Back stay
/// hidden until the final redirect has served visible content, capped at
/// [closeDelayCap].
class AdsterraPlaybackAdScreen extends StatefulWidget {
  const AdsterraPlaybackAdScreen(
      {required this.placement,
      required this.stage,
      this.storeLauncher,
      this.holdClose = true,
      super.key});
  final PlaybackAdPlacement placement;
  final PlaybackAdStage stage;
  final StoreLauncher? storeLauncher;

  /// Whether the ad page hides its close control until the ad is served.
  /// False for a page the viewer opened themselves, such as a video ad's
  /// "Visit advertiser".
  final bool holdClose;

  /// The longest the viewer waits for a way out, whatever the ad does.
  static const closeDelayCap = Duration(seconds: 5);

  /// How long a page with visible content must go without another navigation
  /// before it counts as the final redirect.
  static const redirectSettle = Duration(milliseconds: 800);

  @override
  State<AdsterraPlaybackAdScreen> createState() =>
      _AdsterraPlaybackAdScreenState();
}

class _AdsterraPlaybackAdScreenState extends State<AdsterraPlaybackAdScreen>
    with WidgetsBindingObserver {
  WebViewController? _script;
  WebViewController? _page;
  Timer? _loadTimer;
  Timer? _durationTimer;
  Timer? _contentTimer;
  Timer? _settleTimer;
  Timer? _closeCapTimer;
  _Phase _phase = _Phase.script;
  bool _pageReady = false;
  bool _closeAllowed = false;
  bool _checkingContent = false;
  int _documentGeneration = 0;
  DateTime? _lastPointer;
  bool _finished = false;

  // The script page keeps an immediate close; the ad page waits.
  bool get _closable =>
      !widget.holdClose || _phase == _Phase.script || _closeAllowed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _durationTimer =
        Timer(widget.placement.maxDuration, () => _finish('max_duration'));
    final smartlink = widget.placement.trackedSmartlinkUrl;
    _log(
        'starting mode=${smartlink != null ? 'smartlink' : 'script'} loadTimeoutMs=${widget.placement.loadTimeout.inMilliseconds}');
    if (smartlink != null) {
      unawaited(_openPage(smartlink));
    } else {
      _loadTimer =
          Timer(widget.placement.loadTimeout, () => _finish('load_timeout'));
      unawaited(_loadScript());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _finish('app_lifecycle_${state.name}');
    }
  }

  Future<void> _loadScript() async {
    try {
      _log(
          'loading script ${widget.placement.scriptUrl} base=${AdsterraBannerWidget.documentBaseUrl}');
      final controller = WebViewController();
      _script = controller;
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await _prepareAndroid(controller);
      await controller.setBackgroundColor(Colors.black);
      await controller.addJavaScriptChannel('PlaybackAd',
          onMessageReceived: _onScriptMessage);
      await controller.setOnConsoleMessage((message) =>
          _log('script console ${message.level.name}: ${message.message}'));
      await controller.setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: _onScriptNavigation,
        onPageStarted: (url) => _log('script document started ${_origin(url)}'),
        onPageFinished: (url) =>
            _log('script document finished ${_origin(url)}'),
        onWebResourceError: (error) {
          _log(
              'script resource error code=${error.errorCode} ${error.description} origin=${_origin(error.url ?? '')} path=${Uri.tryParse(error.url ?? '')?.path ?? ''} mainFrame=${error.isForMainFrame}');
          if (error.isForMainFrame == true) _finish('script_main_frame_error');
        },
        onHttpError: (error) {
          if ((error.response?.statusCode ?? 0) >= 400) {
            _log(
                'script HTTP ${error.response?.statusCode} ${_origin((error.request?.uri ?? error.response?.uri).toString())}');
          }
        },
      ));
      if (!mounted || _finished) return;
      setState(() {});
      await controller.loadHtmlString(
        playbackAdHtml(widget.placement, widget.stage),
        baseUrl: AdsterraBannerWidget.documentBaseUrl,
      );
    } catch (error) {
      _log('script unavailable ($error)');
      _finish('script_setup_error');
    }
  }

  void _onScriptMessage(JavaScriptMessage message) {
    if (!mounted || _finished || _phase != _Phase.script) return;
    try {
      final payload = jsonDecode(message.message);
      switch (payload['event']) {
        case 'failed':
          _log('script failure: ${payload['detail'] ?? 'script or page error'}');
          _finish('script_failed');
        case 'done':
          _finish('continue_control');
        case 'script':
          _log('tag script loaded; waiting for the tag to fetch its ad');
        case 'request':
          // The tag's own requests, to see where it stops before arming.
          _log('tag request ${payload['url']} ${payload['detail']}');
        case 'loaded':
          // A loaded script is not proof of an impression. The Popunder is
          // armed now and waits for the viewer's tap on Continue; the maximum
          // duration still bounds the wait.
          if (widget.stage == PlaybackAdStage.streamFound) _loadTimer?.cancel();
          _log(widget.placement.network == PlaybackAdNetwork.clickadu
              ? 'tag fetched its ad; Continue enabled'
              : 'script loaded');
        case 'rendered':
          _loadTimer?.cancel();
        case 'offer':
          final uri = Uri.tryParse(payload['url'] as String);
          if (uri != null) _openPopup(uri);
      }
    } catch (_) {
      // Ignore malformed messages from third-party content.
    }
  }

  NavigationDecision _onScriptNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    // The document is loaded from a string, so any main-frame request comes
    // from page script or a popup window. Never navigate this WebView itself:
    // about:blank or the unresolvable base URL would replace the armed tag.
    if (!request.isMainFrame) {
      return _webUrl(uri)
          ? NavigationDecision.navigate
          : NavigationDecision.prevent;
    }
    _log(
        'script main-frame navigation scheme=${uri?.scheme} origin=${_origin(request.url)}');
    if (_webUrl(uri) && request.url != AdsterraBannerWidget.documentBaseUrl) {
      _openPopup(uri!);
    }
    return NavigationDecision.prevent;
  }

  bool get _tappedRecently =>
      _lastPointer != null &&
      DateTime.now().difference(_lastPointer!) <= const Duration(seconds: 2);

  void _openPopup(Uri uri) {
    // Social Bar advertiser links require a real touch. Popunder URLs may
    // arrive from the tag's delayed trigger after the Continue tap.
    if (widget.stage == PlaybackAdStage.beforeLoader && !_tappedRecently) {
      _log('popup ignored without a recent tap ${_origin(uri.toString())}');
      return;
    }
    _log('popup URL received ${_origin(uri.toString())}');
    unawaited(_openPage(uri));
  }

  /// Shows one advertiser URL in the ad page and follows its redirect chain
  /// there. Later popups are ignored.
  Future<void> _openPage(Uri uri) async {
    if (!mounted || _finished || _page != null) return;
    _log(
        'opening ad page ${_origin(uri.toString())} subId=${widget.placement.subId ?? 'none'}');
    final page = WebViewController();
    _page = page;
    _loadTimer?.cancel();
    _loadTimer =
        Timer(widget.placement.loadTimeout, () => _finish('page_load_timeout'));
    _closeCapTimer = Timer(AdsterraPlaybackAdScreen.closeDelayCap,
        () => _allowClose('cap_reached'));
    // Deactivate the tag so it cannot open a second page.
    unawaited(_stop(_script));
    var mainUrl = uri;
    try {
      await page.setJavaScriptMode(JavaScriptMode.unrestricted);
      await _prepareAndroid(page);
      await page.setBackgroundColor(Colors.white);
      await page.setOnConsoleMessage((message) =>
          _log('page console ${message.level.name}: ${message.message}'));
      await page.setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          if (request.url == 'about:blank') return NavigationDecision.navigate;
          final target = Uri.tryParse(request.url);
          if (_webUrl(target)) {
            if (request.isMainFrame) mainUrl = target!;
            return NavigationDecision.navigate;
          }
          if (request.isMainFrame && target != null) {
            unawaited(_openAppLink(page, target));
          } else {
            _log('blocked navigation scheme=${target?.scheme}');
          }
          return NavigationDecision.prevent;
        },
        onPageStarted: _onPageStarted,
        onPageFinished: (url) => _inspectPage(page, url),
        onWebResourceError: (error) {
          if (error.isForMainFrame == true) {
            _log(
                'page error code=${error.errorCode} ${error.description} origin=${_origin(error.url ?? '')}');
            _finish('page_main_frame_error');
          }
        },
        onHttpError: (error) {
          final failedUrl = error.request?.uri ?? error.response?.uri;
          final status = error.response?.statusCode ?? 0;
          if (failedUrl == mainUrl && status >= 400) {
            _log('page HTTP $status ${_origin(failedUrl.toString())}');
            _finish('page_http_error');
          }
        },
      ));
      if (!mounted || _finished) return;
      setState(() => _phase = _Phase.page);
      await page.loadRequest(uri);
    } catch (error) {
      _log('ad page unavailable ($error)');
      _finish('page_setup_error');
    }
  }

  void _onPageStarted(String url) {
    if (url == 'about:blank' || _finished) return;
    _log('page started ${_origin(url)}');
    // A new document means the redirect chain is still moving.
    _documentGeneration++;
    _contentTimer?.cancel();
    _settleTimer?.cancel();
    _loadTimer?.cancel();
    _loadTimer =
        Timer(widget.placement.loadTimeout, () => _finish('page_load_timeout'));
    if (mounted) setState(() => _pageReady = false);
  }

  void _inspectPage(WebViewController page, String url) {
    if (_finished || url == 'about:blank') return;
    _log('page finished ${_origin(url)}; checking content');
    final generation = _documentGeneration;
    unawaited(_checkContent(page, generation));
    _contentTimer?.cancel();
    _contentTimer = Timer.periodic(const Duration(milliseconds: 500),
        (_) => unawaited(_checkContent(page, generation)));
  }

  Future<void> _checkContent(WebViewController page, int generation) async {
    if (!mounted || _finished || _checkingContent) return;
    _checkingContent = true;
    try {
      // DOM presence is a loading diagnostic, never a paid-impression signal.
      final result = await page.runJavaScriptReturningResult('''
(function(){var b=document.body;
function visible(el){var r=el.getBoundingClientRect(),s=getComputedStyle(el);
return r.width>=40&&r.height>=24&&r.bottom>0&&r.right>0&&r.top<innerHeight&&r.left<innerWidth&&
s.display!=='none'&&s.visibility!=='hidden'&&Number(s.opacity)>0;}
var text=b?b.innerText.trim().length:0;
var media=b?Array.from(b.querySelectorAll('img,iframe,video,canvas,svg,object,embed,input,button')).filter(visible).length:0;
var background=b&&visible(b)&&getComputedStyle(b).backgroundImage!=='none';
return JSON.stringify({ready:!!(b&&((text>20&&visible(b))||media>0||background)),
textLength:text,visibleElements:media,title:document.title.substring(0,80),
type:document.contentType});})()
''');
      if (!mounted || _finished || generation != _documentGeneration) return;
      final report = result is String ? jsonDecode(result) : result;
      // A link that answers with XML, JSON or text (such as an ad server's
      // empty VAST response) has no page to show; leave instead of waiting.
      final type = report is Map ? report['type'] : null;
      if (type is String &&
          type.isNotEmpty &&
          type != 'text/html' &&
          type != 'application/xhtml+xml') {
        _log('page is $type, not a web page');
        _finish('page_not_html');
        return;
      }
      final ready = report is Map ? report['ready'] == true : report == true;
      if (ready) {
        _log(report is Map
            ? 'visible page content text=${report['textLength']} elements=${report['visibleElements']} title=${report['title']}'
            : 'page content present');
        _onContentVisible(generation);
      }
    } catch (error) {
      // Some landing pages disable script inspection. Treat the finished
      // document as shown rather than rejecting a potentially valid page.
      if (mounted && !_finished && generation == _documentGeneration) {
        _log('content inspection unavailable ($error)');
        _onContentVisible(generation);
      }
    } finally {
      _checkingContent = false;
    }
  }

  void _onContentVisible(int generation) {
    _contentTimer?.cancel();
    _loadTimer?.cancel();
    setState(() => _pageReady = true);
    // Allow closing only if no further redirect starts in the settle window.
    _settleTimer?.cancel();
    _settleTimer = Timer(AdsterraPlaybackAdScreen.redirectSettle, () {
      if (generation == _documentGeneration) _allowClose('ad_served');
    });
  }

  void _allowClose(String reason) {
    if (!mounted || _finished || _closeAllowed) return;
    _closeCapTimer?.cancel();
    _log('close enabled reason=$reason');
    setState(() => _closeAllowed = true);
  }

  /// App-install offers often end in a market:// or intent:// link, which a
  /// WebView cannot load; blocking it alone leaves an empty redirect page.
  /// Show the offer's web page in place. Only the viewer's own tap (such as
  /// Install) may hand the link to a store app, never to a browser.
  Future<void> _openAppLink(WebViewController page, Uri target) async {
    if (!mounted || _finished) return;
    final link = offerAppLink(target);
    if (link == null) {
      _log('blocked navigation scheme=${target.scheme}');
      return;
    }
    if (_tappedRecently && link.app != null) {
      _log('opening store app scheme=${link.app!.scheme} after tap');
      var opened = false;
      try {
        opened = await (widget.storeLauncher ?? openStoreApp)(link.app!);
      } catch (error) {
        _log('store app launch error ($error)');
      }
      if (opened || !mounted || _finished) return;
    }
    if (link.web != null) {
      _log(
          'loading web fallback ${_origin(link.web.toString())} for scheme=${target.scheme}');
      await page.loadRequest(link.web!);
    } else {
      _log('blocked navigation scheme=${target.scheme}; no web fallback');
    }
  }

  static bool _debuggingEnabled = false;

  /// Ad tags set cookies from their own domains inside a page loaded from the
  /// app's placeholder origin; Android WebView blocks those third-party
  /// cookies by default. Debug builds can also be inspected from
  /// chrome://inspect.
  Future<void> _prepareAndroid(WebViewController controller) async {
    final platform = controller.platform;
    if (platform is! AndroidWebViewController) return;
    try {
      if (kDebugMode && !_debuggingEnabled) {
        _debuggingEnabled = true;
        await AndroidWebViewController.enableDebugging(true);
      }
      await AndroidWebViewCookieManager(
              const PlatformWebViewCookieManagerCreationParams())
          .setAcceptThirdPartyCookies(platform, true);
    } catch (error) {
      _log('third-party cookies unavailable ($error)');
    }
  }

  bool _webUrl(Uri? uri) =>
      uri != null &&
      const {'https', 'http'}.contains(uri.scheme) &&
      uri.host.isNotEmpty;

  String _origin(String url) {
    final uri = Uri.tryParse(url);
    return _webUrl(uri) ? uri!.origin : 'unknown';
  }

  void _log(String message) => debugPrint(
      '[AdsterraPage] ${widget.placement.network.name}/${widget.stage.name}: $message');

  void _finish([String reason = 'completed']) {
    if (!mounted || _finished) return;
    _finished = true;
    _cancelTimers();
    _log(
        'closing reason=$reason phase=${_phase.name} pageReady=$_pageReady closeAllowed=$_closeAllowed');
    // Deactivate before navigation; late messages cannot open an advertiser
    // over the loader/player after this screen is dismissed.
    unawaited(_stop(_script));
    unawaited(_stop(_page));
    final route = ModalRoute.of(context);
    if (route?.isCurrent == true) {
      Navigator.of(context).pop();
    } else if (route?.isActive == true) {
      Navigator.of(context).removeRoute(route!);
    }
  }

  void _cancelTimers() {
    _loadTimer?.cancel();
    _durationTimer?.cancel();
    _contentTimer?.cancel();
    _settleTimer?.cancel();
    _closeCapTimer?.cancel();
  }

  Future<void> _stop(WebViewController? controller) async {
    try {
      await controller?.setJavaScriptMode(JavaScriptMode.disabled);
      await controller?.loadRequest(Uri.parse('about:blank'));
    } catch (_) {}
  }

  @override
  void dispose() {
    if (!_finished) {
      _log(
          'disposed before completion (remote config or route removal) phase=${_phase.name}');
    }
    WidgetsBinding.instance.removeObserver(this);
    _finished = true;
    _cancelTimers();
    unawaited(_stop(_script));
    unawaited(_stop(_page));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _phase == _Phase.page ? _page : _script;
    final loadingPage = _phase == _Phase.page && !_pageReady;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_closable) {
          _finish('system_back');
        } else {
          _log('back ignored until the ad is served');
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          title: const Text('Advertisement', style: TextStyle(fontSize: 14)),
          actions: [
            if (_closable)
              IconButton(
                  tooltip: 'Close ad',
                  onPressed: () => _finish('user_close'),
                  icon: const Icon(Icons.close))
          ],
          bottom: loadingPage
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: LinearProgressIndicator(minHeight: 2))
              : null,
        ),
        body: SafeArea(
          child: controller == null
              ? const Center(child: CircularProgressIndicator())
              : Listener(
                  onPointerDown: (_) => _lastPointer = DateTime.now(),
                  child: Stack(children: [
                    Positioned.fill(child: _webView(controller)),
                    if (loadingPage)
                      const Center(
                          child: Card(
                              child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Loading advertisement…'),
                        ]),
                      ))),
                  ]),
                ),
        ),
      ),
    );
  }

  Widget _webView(WebViewController controller) {
    PlatformWebViewWidgetCreationParams params =
        PlatformWebViewWidgetCreationParams(controller: controller.platform);
    if (controller.platform is AndroidWebViewController) {
      // Avoid SurfaceTexture buffer exhaustion when arriving from video playback.
      params = AndroidWebViewWidgetCreationParams
          .fromPlatformWebViewWidgetCreationParams(params,
              displayWithHybridComposition: true);
    }
    // A fresh key per controller: the script and ad pages are separate views.
    return WebViewWidget.fromPlatformCreationParams(
        key: ObjectKey(controller), params: params);
  }
}

/// The Play Store and web pages behind a market:// or intent:// offer link.
/// `app` opens the store app; `web` is what the ad page can show instead.
/// Returns null for any other scheme.
({Uri? app, Uri? web})? offerAppLink(Uri link) {
  Uri? web(String? value) {
    final uri = value == null ? null : Uri.tryParse(value);
    return uri != null &&
            const {'https', 'http'}.contains(uri.scheme) &&
            uri.host.isNotEmpty
        ? uri
        : null;
  }

  Uri? listing(String? package) => package == null || package.isEmpty
      ? null
      : Uri.https('play.google.com', '/store/apps/details', {'id': package});

  switch (link.scheme) {
    case 'market':
      final package = link.queryParameters['id'];
      if (package == null || package.isEmpty) return null;
      return (
        app: link,
        web: Uri.https(
            'play.google.com', '/store/apps/details', link.queryParameters),
      );
    case 'intent':
      // intent://host/path#Intent;scheme=https;package=x;S.browser_fallback_url=...;end
      final extras = <String, String>{};
      for (final part in link.fragment.split(';')) {
        final at = part.indexOf('=');
        if (at > 0) extras[part.substring(0, at)] = part.substring(at + 1);
      }
      final package = extras['package'];
      final fallback = extras['S.browser_fallback_url'];
      final scheme = extras['scheme'];
      final page =
          web(fallback == null ? null : Uri.decodeComponent(fallback)) ??
          (scheme == 'https' || scheme == 'http'
              ? web('$scheme://${link.host}${link.path}'
                  '${link.hasQuery ? '?${link.query}' : ''}')
              : null) ??
          listing(package);
      final app = package == null || package.isEmpty
          ? null
          : Uri(scheme: 'market', host: 'details', queryParameters: {
              'id': package,
            });
      return app == null && page == null ? null : (app: app, web: page);
  }
  return null;
}

/// Reports rendering only
/// when a creative occupies visible space. The Continue control is a real DOM
/// button that stays disabled until the Popunder tag has loaded, so the
/// viewer's tap is the gesture the tag opens its popup from. Nothing clicks it
/// programmatically. Defer the head script so document.body and the controls
/// exist when it runs.
String playbackAdHtml(PlaybackAdPlacement placement, PlaybackAdStage stage) {
  if (placement.isSmartlink) {
    throw ArgumentError('Smartlinks use direct WebView navigation.');
  }
  final escape = const HtmlEscape(HtmlEscapeMode.attribute);
  final script = escape.convert(placement.scriptUrl.toString());
  // Clickadu's onclick tag finds its zone on its own script element.
  final zone = placement.zoneId == null
      ? ''
      : ' data-clocid="${escape.convert(placement.zoneId!)}"';
  final popunder = stage == PlaybackAdStage.streamFound;
  // Clickadu's tag fetches its ad (`/adx/get/`) a few seconds after its script
  // loads, and a tap before that opens nothing. Enable Continue only once
  // that request has finished; the load timeout covers a tag that never arms.
  final armed = placement.network == PlaybackAdNetwork.clickadu
      ? '''<script>(function(){var done=false;function arm(){if(done)return;done=true;setTimeout(function(){fqSignal('loaded');},300);}
window.fqTagLoaded=function(){fqSignal('script');};
var host=new URL('$script'.replace(/&amp;/g,'&')).host;
try{new PerformanceObserver(function(list){list.getEntries().forEach(function(e){var u=new URL(e.name);if(u.host===host)fqSignal('request',u.pathname,Math.round(e.duration)+'ms status='+(e.responseStatus===undefined?'?':e.responseStatus));if(e.name.indexOf('/adx/get/')>=0)arm();});}).observe({type:'resource',buffered:true});}
catch(e){window.fqTagLoaded=function(){fqSignal('script');arm();};}})();</script>'''
      : '';
  final onLoad = placement.network == PlaybackAdNetwork.clickadu
      ? 'fqTagLoaded()'
      : "fqSignal('loaded')";
  return '''<!doctype html><html><head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>html,body{margin:0;width:100%;height:100%;background:#000;color:#fff;font-family:sans-serif}
#fq-controls{height:100%;display:flex;flex-direction:column;gap:12px;align-items:center;justify-content:center}
#fq-continue{padding:16px 24px;background:#fff;color:#000;border:0;border-radius:24px;font-size:16px}
#fq-continue:disabled{opacity:.5}
#fq-note{font-size:12px;color:#aaa}</style>
<script>
function fqSignal(event,url,detail){if(event==='loaded'){var b=document.getElementById("fq-continue");if(b){b.disabled=false;b.textContent="Continue to player";}}PlaybackAd.postMessage(JSON.stringify({event:event,url:url,detail:detail}));}
window.addEventListener('error',function(event){fqSignal('failed',null,event.message||'script resource failed');});
</script>
${popunder ? '$armed<script defer data-cfasync="false"$zone src="$script" onload="$onLoad" onerror="fqSignal(\'failed\')"></script>' : ''}
</head><body>
${popunder ? '''<main id="fq-controls"><button id="fq-continue" type="button" disabled>Loading…</button><div id="fq-note">Sponsored: an ad may open</div></main><script>
document.getElementById("fq-continue").addEventListener("click",function(){
 setTimeout(function(){fqSignal("done");},750);
});
</script>''' : '''<script>
var fqVisible=false,fqAbsent=0;
setInterval(function(){
 var visible=Array.from(document.querySelectorAll('iframe,img,video')).some(function(el){
  var r=el.getBoundingClientRect(),s=getComputedStyle(el);
  return r.width>=40&&r.height>=40&&r.right>0&&r.bottom>0&&r.left<innerWidth&&r.top<innerHeight&&s.visibility!=='hidden'&&s.display!=='none'&&s.opacity!=='0';
 });
 if(visible){if(!fqVisible)fqSignal('rendered');fqVisible=true;fqAbsent=0;}
 else if(fqVisible&&++fqAbsent>=3)fqSignal('done');
},300);
</script><script data-cfasync="false" src="$script" onload="fqSignal('loaded')" onerror="fqSignal('failed')"></script>'''}
</body></html>''';
}
