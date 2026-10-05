import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../models/adsterra_playback_ads_config.dart';
import 'adsterra_banner_widget.dart';

/// A visible, disposable ad surface with no hidden preloading or refresh.
/// A WebView popup is presented as a separate visible page;
/// native apps cannot put browser windows behind their own activity.
class AdsterraPlaybackAdScreen extends StatefulWidget {
  const AdsterraPlaybackAdScreen(
      {required this.placement,
      required this.stage,
      this.externalLauncher,
      super.key});
  final PlaybackAdPlacement placement;
  final PlaybackAdStage stage;
  final Future<bool> Function(Uri)? externalLauncher;

  @override
  State<AdsterraPlaybackAdScreen> createState() =>
      _AdsterraPlaybackAdScreenState();
}

class _AdsterraPlaybackAdScreenState extends State<AdsterraPlaybackAdScreen>
    with WidgetsBindingObserver {
  WebViewController? _controller;
  WebViewController? _offer;
  Timer? _loadTimer;
  Timer? _durationTimer;
  Timer? _contentTimer;
  bool _pageLoading = false;
  bool _checkingContent = false;
  int _documentGeneration = 0;
  DateTime? _lastPointer;
  bool _finished = false;
  bool _offerOpening = false;
  bool _externalOpening = false;
  bool _externalDeparted = false;
  bool _externalReturned = false;
  bool _externalLaunchComplete = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTimer = Timer(widget.placement.loadTimeout, _finish);
    _durationTimer = Timer(widget.placement.maxDuration, _finish);
    unawaited(_load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_externalOpening) {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden) {
        _externalDeparted = true;
        _loadTimer?.cancel();
      } else if (state == AppLifecycleState.resumed && _externalDeparted) {
        _externalReturned = true;
        if (_externalLaunchComplete) _finish();
      } else if (state == AppLifecycleState.detached) {
        _finish();
      }
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _finish();
    }
  }

  Future<void> _load() async {
    final smartlink = widget.placement.trackedSmartlinkUrl;
    if (smartlink != null) {
      if (widget.placement.browser == PlaybackAdBrowser.external) {
        await _openExternal(smartlink);
      } else {
        await _loadSmartlink(smartlink);
      }
      return;
    }
    try {
      final controller = WebViewController();
      _controller = controller;
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(Colors.black);
      await controller.addJavaScriptChannel('PlaybackAd',
          onMessageReceived: (message) {
        if (!mounted || _finished) return;
        try {
          final payload = jsonDecode(message.message);
          switch (payload['event']) {
            case 'failed':
            case 'done':
              if (!_offerOpening) _finish();
            case 'loaded':
              // A loaded script is not proof of an interstitial impression.
              if (widget.stage == PlaybackAdStage.streamFound &&
                  !widget.placement.autoActivate) {
                _loadTimer?.cancel();
              }
              _log('script loaded');
            case 'rendered':
              _loadTimer?.cancel();
            case 'offer':
              final uri = Uri.tryParse(payload['url'] as String);
              if (uri != null) unawaited(_openOffer(uri));
            case 'activated':
              _log(
                  'publisher control activated programmatically; awaiting popup URL');
          }
        } catch (_) {
          // Ignore malformed messages from third-party content.
        }
      });
      await controller.setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          if (request.url == 'about:blank' ||
              request.url == AdsterraBannerWidget.documentBaseUrl) {
            return NavigationDecision.navigate;
          }
          final uri = Uri.tryParse(request.url);
          if (!_webUrl(uri)) return NavigationDecision.prevent;
          if (!request.isMainFrame) return NavigationDecision.navigate;
          unawaited(_openOffer(uri!));
          return NavigationDecision.prevent;
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame == true) _finish();
        },
      ));
      if (!mounted || _finished) return;
      setState(() {});
      await controller.loadHtmlString(
        playbackAdHtml(widget.placement, widget.stage),
        baseUrl: AdsterraBannerWidget.documentBaseUrl,
      );
    } catch (_) {
      _finish();
    }
  }

  bool _webUrl(Uri? uri) =>
      uri != null &&
      const {'https', 'http'}.contains(uri.scheme) &&
      uri.host.isNotEmpty;

  /// Direct navigation needs no DOM click or intermediary script. Use one
  /// visible WebView and preserve the network's HTTP redirect chain.
  Future<void> _loadSmartlink(Uri uri) async {
    _offerOpening = true;
    var mainUrl = uri;
    try {
      final controller = WebViewController();
      _offer = controller;
      _pageLoading = true;
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(Colors.white);
      await controller.setOnConsoleMessage((message) =>
          _log('console ${message.level.name}: ${message.message}'));
      await controller.setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          if (request.url == 'about:blank') return NavigationDecision.navigate;
          final target = Uri.tryParse(request.url);
          if (!_webUrl(target)) {
            _log('blocked navigation scheme=${target?.scheme}');
            return NavigationDecision.prevent;
          }
          if (request.isMainFrame) mainUrl = target!;
          return NavigationDecision.navigate;
        },
        onPageStarted: (url) {
          if (url == 'about:blank' || _finished) return;
          _log('page started ${_origin(url)}');
          _documentGeneration++;
          _contentTimer?.cancel();
          _loadTimer?.cancel();
          _loadTimer = Timer(widget.placement.loadTimeout, _finish);
          if (mounted) setState(() => _pageLoading = true);
        },
        onPageFinished: (url) {
          _inspectPage(controller, url);
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame == true) {
            _log('page error code=${error.errorCode} ${error.description}');
            _finish();
          }
        },
        onHttpError: (error) {
          final failedUrl = error.request?.uri ?? error.response?.uri;
          if (failedUrl == mainUrl &&
              (error.response?.statusCode ?? 0) >= 400) {
            _finish();
            _log(
                'HTTP ${error.response?.statusCode} ${_origin(failedUrl.toString())}');
          }
        },
      ));
      if (!mounted || _finished) return;
      setState(() {});
      await controller.loadRequest(uri);
    } catch (error) {
      _log('Smartlink unavailable ($error)');
      _finish();
    }
  }

  Future<void> _openOffer(Uri uri) async {
    if (!mounted || _finished || _offerOpening || !_webUrl(uri)) return;
    // Social Bar advertiser links require a real touch. Popunder URLs may arrive
    // from a delayed trigger or the optional publisher-control activation.
    if (widget.stage == PlaybackAdStage.beforeLoader &&
        (_lastPointer == null ||
            DateTime.now().difference(_lastPointer!) >
                const Duration(seconds: 2))) {
      return;
    }
    _offerOpening = true;
    _log(
        'popup URL received ${_origin(uri.toString())} browser=${widget.placement.browser.name}');
    _loadTimer?.cancel();
    if (widget.placement.browser == PlaybackAdBrowser.external) {
      await _stop(_controller);
      if (mounted && !_finished) await _openExternal(uri);
      return;
    }
    try {
      final offer = WebViewController();
      _offer = offer;
      _pageLoading = true;
      _loadTimer = Timer(widget.placement.loadTimeout, _finish);
      await offer.setJavaScriptMode(JavaScriptMode.unrestricted);
      await offer.setBackgroundColor(Colors.white);
      await offer.setOnConsoleMessage((message) =>
          _log('console ${message.level.name}: ${message.message}'));
      await offer.setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) =>
            request.url == 'about:blank' || _webUrl(Uri.tryParse(request.url))
                ? NavigationDecision.navigate
                : NavigationDecision.prevent,
        onWebResourceError: (error) {
          if (error.isForMainFrame == true) _finish();
        },
        onPageFinished: (url) => _inspectPage(offer, url),
        onHttpError: (error) {
          if ((error.response?.statusCode ?? 0) >= 400) {
            _log('popup HTTP ${error.response?.statusCode}');
          }
        },
      ));
      if (!mounted || _finished) return;
      await _stop(_controller);
      if (!mounted || _finished) return;
      setState(() {});
      await offer.loadRequest(uri);
    } catch (_) {
      _finish();
    }
  }

  void _inspectPage(WebViewController controller, String url) {
    if (_finished || url == 'about:blank') return;
    _log('page finished ${_origin(url)}; checking content');
    final generation = ++_documentGeneration;
    if (mounted) setState(() => _pageLoading = true);
    _loadTimer?.cancel();
    _loadTimer = Timer(widget.placement.loadTimeout, _finish);
    unawaited(_checkContent(controller, generation));
    _contentTimer?.cancel();
    _contentTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      unawaited(_checkContent(controller, generation));
    });
  }

  Future<void> _checkContent(
      WebViewController controller, int generation) async {
    if (!mounted || _finished || _checkingContent) return;
    _checkingContent = true;
    try {
      // DOM presence is a loading diagnostic, never a paid-impression signal.
      final result = await controller.runJavaScriptReturningResult('''
(function(){var b=document.body;
function visible(el){var r=el.getBoundingClientRect(),s=getComputedStyle(el);
return r.width>=40&&r.height>=24&&r.bottom>0&&r.right>0&&r.top<innerHeight&&r.left<innerWidth&&
s.display!=='none'&&s.visibility!=='hidden'&&Number(s.opacity)>0;}
var text=b?b.innerText.trim().length:0;
var media=b?Array.from(b.querySelectorAll('img,iframe,video,canvas,svg,object,embed,input,button')).filter(visible).length:0;
var background=b&&visible(b)&&getComputedStyle(b).backgroundImage!=='none';
return JSON.stringify({ready:!!(b&&((text>20&&visible(b))||media>0||background)),
textLength:text,visibleElements:media,title:document.title.substring(0,80)});})()
''');
      if (!mounted || _finished || generation != _documentGeneration) return;
      final report = result is String ? jsonDecode(result) : result;
      final ready = report is Map ? report['ready'] == true : report == true;
      if (ready) {
        _log(report is Map
            ? 'visible page content text=${report['textLength']} elements=${report['visibleElements']} title=${report['title']}'
            : 'page content present');
        _contentTimer?.cancel();
        _loadTimer?.cancel();
        setState(() => _pageLoading = false);
      }
    } catch (error) {
      // Some landing pages can disable script inspection. Keep the normal
      // page-finished behavior rather than rejecting a potentially valid page.
      if (mounted && !_finished && generation == _documentGeneration) {
        _log('content inspection unavailable ($error)');
        _contentTimer?.cancel();
        _loadTimer?.cancel();
        setState(() => _pageLoading = false);
      }
    } finally {
      _checkingContent = false;
    }
  }

  String _origin(String url) {
    final uri = Uri.tryParse(url);
    return _webUrl(uri) ? uri!.origin : 'unknown';
  }

  void _log(String message) =>
      debugPrint('[AdsterraPage] ${widget.stage.name}: $message');

  Future<void> _openExternal(Uri uri) async {
    if (!mounted || _finished || _externalOpening) return;
    _externalOpening = true;
    _offerOpening = true;
    _loadTimer?.cancel();
    _durationTimer?.cancel();
    _contentTimer?.cancel();
    _log('opening external browser ${_origin(uri.toString())}');
    setState(() {});
    try {
      final launched = await (widget.externalLauncher?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication))
          .timeout(widget.placement.loadTimeout, onTimeout: () => false);
      if (!mounted || _finished) return;
      _externalLaunchComplete = true;
      if (!launched || _externalReturned) {
        _finish();
      } else if (!_externalDeparted) {
        // A launch can succeed without leaving the app (or a chooser can be
        // cancelled). Never strand playback on an empty route in that case.
        _loadTimer = Timer(widget.placement.loadTimeout, _finish);
      }
    } catch (_) {
      _finish();
    }
  }

  void _finish() {
    if (!mounted || _finished) return;
    _finished = true;
    _loadTimer?.cancel();
    _durationTimer?.cancel();
    _contentTimer?.cancel();
    _log(_pageLoading ? 'closing: page never became ready' : 'closing ad');
    // Deactivate before navigation; late messages cannot open an advertiser
    // over the loader/player after this screen is dismissed.
    unawaited(_stop(_controller));
    unawaited(_stop(_offer));
    final route = ModalRoute.of(context);
    if (route?.isCurrent == true) {
      Navigator.of(context).pop();
    } else if (route?.isActive == true) {
      Navigator.of(context).removeRoute(route!);
    }
  }

  Future<void> _stop(WebViewController? controller) async {
    try {
      await controller?.setJavaScriptMode(JavaScriptMode.disabled);
      await controller?.loadRequest(Uri.parse('about:blank'));
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _finished = true;
    _loadTimer?.cancel();
    _durationTimer?.cancel();
    _contentTimer?.cancel();
    unawaited(_stop(_controller));
    unawaited(_stop(_offer));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _offer ?? _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text('Advertisement', style: TextStyle(fontSize: 14)),
        actions: [
          IconButton(
              tooltip: 'Close ad',
              onPressed: _finish,
              icon: const Icon(Icons.close))
        ],
      ),
      body: SafeArea(
          child: _externalOpening
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Return to FlixQuest to continue playback.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white)),
                  ),
                )
              : controller == null
                  ? const Center(child: CircularProgressIndicator())
                  : Listener(
                      onPointerDown: (_) => _lastPointer = DateTime.now(),
                      child: Stack(children: [
                        Positioned.fill(child: _webView(controller)),
                        if (_pageLoading)
                          const Center(
                              child: Card(
                                  child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 12),
                                  Text('Loading advertisement…'),
                                ]),
                          ))),
                      ]),
                    )),
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
    return WebViewWidget.fromPlatformCreationParams(params: params);
  }
}

/// Reports rendering only
/// when a creative occupies visible space. The Continue control is a real DOM
/// button. Optional activation is one programmatic click on that publisher
/// control; it does not forge a trusted gesture or click an advertiser element.
String playbackAdHtml(PlaybackAdPlacement placement, PlaybackAdStage stage) {
  if (placement.isSmartlink) {
    throw ArgumentError('Smartlinks use direct WebView navigation.');
  }
  final script = const HtmlEscape(HtmlEscapeMode.attribute)
      .convert(placement.scriptUrl.toString());
  final popunder = stage == PlaybackAdStage.streamFound;
  final autoActivate = popunder && placement.autoActivate;
  return '''<!doctype html><html><head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>html,body{margin:0;width:100%;height:100%;background:#000;color:#fff;font-family:sans-serif}
#fq-controls{height:100%;display:flex;align-items:center;justify-content:center}
#fq-continue{padding:16px 24px;background:#fff;color:#000;border:0;border-radius:24px;font-size:16px}</style>
<script>
var fqPopReady=false;
function fqSignal(event,url){if(event==='loaded'){fqPopReady=true;if(window.fqActivatePopunder)window.fqActivatePopunder();}PlaybackAd.postMessage(JSON.stringify({event:event,url:url}));}
window.addEventListener('error',function(){fqSignal('failed');});
</script>
${popunder ? '<script data-cfasync="false" src="$script" onload="fqSignal(\'loaded\')" onerror="fqSignal(\'failed\')"></script>' : ''}
</head><body>
${popunder ? '''<main id="fq-controls"><button id="fq-continue" type="button">Continue to player</button></main><script>
document.getElementById("fq-continue").addEventListener("click",function(event){
 if(event.isTrusted || ${!autoActivate})setTimeout(function(){fqSignal("done");},750);
});
${autoActivate ? '''var fqActivated=false;
window.fqActivatePopunder=function(){if(!fqPopReady||fqActivated)return;fqActivated=true;
 fqSignal("activated");document.getElementById("fq-continue").click();};
window.fqActivatePopunder();''' : ''}
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
