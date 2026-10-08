import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../models/adsterra_playback_ads_config.dart';
import 'network_banner_widget.dart';

/// Hands a Play Store link to a store app and reports whether one opened.
typedef StoreLauncher = Future<bool> Function(Uri uri);

/// Never a browser: `externalNonBrowserApplication` fails instead of falling
/// back to one.
Future<bool> openStoreApp(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);

enum _Phase { script, page }

/// A visible, disposable ad surface with no hidden preloading or refresh.
///
/// Script tags (Adsterra's Social Bar and Popunder, Clickadu's and Monetag's
/// onclick tags) run in one WebView. Advertiser pages (Smartlinks, Direct Links and the popups a
/// script emits) open in FlixQuest's own ad page,
/// never in an external browser. On that page a friendly placeholder covers
/// blank redirect pages, and the way on (and Back) waits until the final
/// redirect has shown its ad for [minimumView]. If the ad never gets there,
/// the placement's [PlaybackAdPlacement.closeFallback] lets the viewer on.
///
/// On a TV the remote drives it: the way on takes focus as it appears, and
/// the arrows stay on FlixQuest's controls instead of wandering into the page.
class AdsterraPlaybackAdScreen extends StatefulWidget {
  const AdsterraPlaybackAdScreen(
      {required this.placement,
      required this.stage,
      this.storeLauncher,
      this.holdClose = true,
      this.television = false,
      super.key});
  final PlaybackAdPlacement placement;
  final PlaybackAdStage stage;
  final StoreLauncher? storeLauncher;

  /// Whether the ad page hides its close control until the ad is served.
  /// False for a page the viewer opened themselves, such as a video ad's
  /// "Visit advertiser".
  final bool holdClose;

  /// Android TV: larger type, overscan margins and D-pad focus.
  final bool television;

  /// How long the final ad stays up before the viewer moves on, counted from
  /// when it first shows content, so the advertiser gets a real view.
  static const minimumView = Duration(seconds: 3);

  /// How long one content check may run. A check sent while the document is
  /// being replaced may never answer.
  static const contentCheckTimeout = Duration(seconds: 2);

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
  Timer? _fallbackTimer;
  Timer? _minimumViewTimer;
  Timer? _countdownTimer;
  Timer? _waitHintTimer;
  _Phase _phase = _Phase.script;
  bool _pageReady = false;
  bool _closeAllowed = false;

  /// The current document has been served and stopped redirecting.
  bool _served = false;
  bool _minimumViewDone = false;

  /// The document whose ad is being counted toward [minimumView].
  int? _visibleGeneration;
  final FocusNode _continueFocus = FocusNode(debugLabel: 'ad continue');

  /// The ad page has been shown; later redirects keep it on screen.
  bool _revealed = false;

  /// Back was pressed before the way on appeared.
  bool _waitHint = false;
  int _secondsLeft = 0;
  String? _advertiserHost;
  bool _checkingContent = false;
  int _documentGeneration = 0;
  DateTime? _lastPointer;
  bool _finished = false;

  /// Whether the hosted page ([PlaybackAdPlacement.pageUrl]) has loaded.
  /// Until then its own redirects may navigate the script WebView.
  bool _hostedPageLoaded = false;
  bool _automaticMonetagInstalled = false;

  bool get _automaticMonetag =>
      widget.placement.network == AdNetwork.monetag &&
      widget.stage == PlaybackAdStage.streamFound &&
      !widget.placement.isSmartlink;

  // The Social Bar page keeps an immediate close. Every other surface waits
  // for its ad to be seen, or for the placement's fallback.
  bool get _closable =>
      !widget.holdClose ||
      _closeAllowed ||
      (_phase == _Phase.script && widget.stage == PlaybackAdStage.beforeLoader);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _durationTimer =
        Timer(widget.placement.maxDuration, () => _finish('max_duration'));
    final smartlink = widget.placement.trackedSmartlinkUrl;
    _log(
        'starting mode=${widget.placement.mode} loadTimeoutMs=${widget.placement.loadTimeout.inMilliseconds}');
    if (smartlink != null) {
      unawaited(_openPage(smartlink));
    } else {
      // The tag page's own Play button leads on; Skip is the fallback.
      if (widget.stage == PlaybackAdStage.streamFound) _holdClose();
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
      final hostedPage = widget.placement.pageUrl;
      _log(hostedPage != null
          ? 'loading hosted page $hostedPage'
          : 'loading script ${widget.placement.scriptUrl} base=${NetworkBannerWidget.documentBaseUrl}');
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
        onPageFinished: (url) {
          _log('script document finished ${_origin(url)}');
          if (Uri.tryParse(url)?.host == hostedPage?.host) {
            _hostedPageLoaded = true;
          }
          if (url != 'about:blank') unawaited(_activateMonetag(controller));
        },
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
      if (hostedPage != null) {
        await controller.loadRequest(hostedPage);
      } else {
        await controller.loadHtmlString(
          playbackAdHtml(widget.placement, widget.stage),
          baseUrl: NetworkBannerWidget.documentBaseUrl,
        );
      }
    } catch (error) {
      _log('script unavailable ($error)');
      _finish('script_setup_error');
    }
  }

  Future<void> _activateMonetag(WebViewController controller) async {
    if (!_automaticMonetag ||
        _automaticMonetagInstalled ||
        !mounted ||
        _finished ||
        _page != null) {
      return;
    }
    _automaticMonetagInstalled = true;
    try {
      _log('automatic activation installed; waiting for the tag options '
          'mode=${widget.placement.mode}');
      await controller.runJavaScript(monetagAutomaticPlaybackScript);
    } catch (error) {
      _log('automatic Monetag activation unavailable ($error)');
      _finish('automatic_activation_error');
    }
  }

  void _onScriptMessage(JavaScriptMessage message) {
    if (!mounted || _finished || _phase != _Phase.script || _page != null) {
      return;
    }
    try {
      final payload = jsonDecode(message.message);
      switch (payload['event']) {
        case 'failed':
          _log(
              'script failure: ${payload['detail'] ?? 'script or page error'}');
          _finish('script_failed');
        case 'done':
          _finish('continue_control');
        case 'script':
          _log('tag script loaded; waiting for the tag to fetch its ad');
        case 'request':
          // The tag's own requests, to see where it stops before arming.
          _log('tag request ${payload['url']} ${payload['detail']}');
        case 'loaded':
          // A loaded script is not proof of an impression. Monetag starts
          // automatically once its options request finishes; the other tags
          // wait for the viewer's Continue tap.
          if (_automaticMonetag) {
            // Give the tag's asynchronous offer request its own load window,
            // just as advertiser redirects reset the page's load window.
            _loadTimer?.cancel();
            _loadTimer = Timer(widget.placement.loadTimeout,
                () => _finish('automatic_popup_timeout'));
          } else if (widget.stage == PlaybackAdStage.streamFound) {
            _loadTimer?.cancel();
          }
          final script = _script;
          if (script != null) unawaited(_activateMonetag(script));
          _log(widget.placement.network == AdNetwork.clickadu
              ? 'tag fetched its ad; Continue enabled'
              : 'script loaded');
        case 'activated':
          _log('Monetag popup triggered automatically; waiting for its URL');
        case 'empty':
          _log('Monetag options returned HTTP 204 No Content; '
              'no advertiser URL and no activation attempted '
              'request=${payload['url'] ?? 'unknown'} '
              'mode=${widget.placement.mode}');
          if (widget.placement.network == AdNetwork.monetag &&
              widget.placement.scriptUrl != null) {
            _log('This tag is running on the placeholder origin. '
                'For the registered site, publish mode=page with its hosted '
                'URL in monetag_playback_ads.');
          }
          _finish('monetag_no_content');
        case 'rendered':
          _loadTimer?.cancel();
        case 'offer':
          final uri = Uri.tryParse(payload['url'] as String);
          final target = _webUrl(uri)
              ? uri
              : uri == null
                  ? null
                  : offerAppLink(uri)?.web;
          if (target != null) _openPopup(target);
      }
    } catch (_) {
      // Ignore malformed messages from third-party content.
    }
  }

  NavigationDecision _onScriptNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    // Once the document is in place, any main-frame request comes from page
    // script or a popup window. Never navigate this WebView itself:
    // about:blank or the unresolvable base URL would replace the armed tag.
    if (!request.isMainFrame) {
      return _webUrl(uri)
          ? NavigationDecision.navigate
          : NavigationDecision.prevent;
    }
    // The hosted page itself, including the host's own redirects (such as a
    // trailing slash), loads here; after that it is the armed tag's document.
    final hostedPage = widget.placement.pageUrl;
    if (hostedPage != null &&
        !_hostedPageLoaded &&
        _webUrl(uri) &&
        uri?.host == hostedPage.host) {
      return NavigationDecision.navigate;
    }
    _log(
        'script main-frame navigation scheme=${uri?.scheme} origin=${_origin(request.url)}');
    // Monetag's tag detects the WebView and hands its ad to Chrome with an
    // intent:// link instead of a popup; show that link's web page here.
    final target = _webUrl(uri)
        ? uri
        : uri == null
            ? null
            : offerAppLink(uri)?.web;
    if (target != null &&
        target.host != Uri.parse(NetworkBannerWidget.documentBaseUrl).host) {
      _openPopup(target);
    } else if (target != null) {
      _log('ignored navigation back to the placeholder origin');
    }
    return NavigationDecision.prevent;
  }

  bool get _tappedRecently =>
      _lastPointer != null &&
      DateTime.now().difference(_lastPointer!) <= const Duration(seconds: 2);

  void _openPopup(Uri uri) {
    if (!_webUrl(uri)) return;
    final hostedPage = widget.placement.pageUrl;
    if (hostedPage != null &&
        uri.host == hostedPage.host &&
        uri.path.replaceFirst(RegExp(r'/$'), '') ==
            hostedPage.path.replaceFirst(RegExp(r'/$'), '')) {
      // Monetag may first try to reopen the publisher page in Chrome. That
      // is not the advertiser: keep the armed tag for the actual offer URL.
      _log('ignored popup back to the hosted tag page');
      return;
    }
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
    // The ad page starts its own wait, whatever the tag page allowed.
    _pageReady = false;
    _revealed = false;
    _holdClose();
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
          if (request.isMainFrame && isNoAdFallback(target)) {
            _onNoAd(target!);
            return NavigationDecision.prevent;
          }
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
        onPageStarted: (url) {
          final started = Uri.tryParse(url);
          if (_webUrl(started)) mainUrl = started!;
          _onPageStarted(url);
        },
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
    final started = Uri.tryParse(url);
    if (isNoAdFallback(started)) {
      _onNoAd(started!);
      return;
    }
    // A new document means the redirect chain is still moving: its ad, not
    // the previous page's, is the one the viewer must see.
    _documentGeneration++;
    _served = false;
    _minimumViewDone = false;
    _contentTimer?.cancel();
    _settleTimer?.cancel();
    _minimumViewTimer?.cancel();
    _countdownTimer?.cancel();
    _loadTimer?.cancel();
    _loadTimer =
        Timer(widget.placement.loadTimeout, () => _finish('page_load_timeout'));
    if (mounted) setState(() => _pageReady = false);
  }

  /// Trackers send traffic they will not pay for to a search engine's home
  /// page. There is no ad to see, so continue at once.
  void _onNoAd(Uri fallback) {
    _log('redirect chain ended on ${fallback.origin}, not an ad');
    _finish('no_ad_fallback');
  }

  void _inspectPage(WebViewController page, String url) {
    if (_finished || url == 'about:blank') return;
    _log('page finished ${_origin(url)}; checking content');
    final host = Uri.tryParse(url)?.host;
    if (host != null && host.isNotEmpty) {
      _advertiserHost = host.startsWith('www.') ? host.substring(4) : host;
    }
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
''').timeout(AdsterraPlaybackAdScreen.contentCheckTimeout);
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
    } on TimeoutException {
      // Dropped while the document was replaced: the next tick asks again.
      _log('content check timed out');
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
    // Repeated finish callbacks for one document must not restart its view.
    if (_visibleGeneration == generation) return;
    _visibleGeneration = generation;
    setState(() {
      _pageReady = true;
      _revealed = true;
      _secondsLeft = AdsterraPlaybackAdScreen.minimumView.inSeconds;
    });
    // The ad is final only if no further redirect starts in the settle
    // window, and the viewer moves on once it has been up [minimumView].
    _settleTimer?.cancel();
    _settleTimer = Timer(AdsterraPlaybackAdScreen.redirectSettle, () {
      if (generation != _documentGeneration) return;
      _served = true;
      if (_minimumViewDone) _allowClose('ad_served');
    });
    _minimumViewTimer?.cancel();
    _minimumViewTimer = Timer(AdsterraPlaybackAdScreen.minimumView, () {
      if (generation != _documentGeneration) return;
      _minimumViewDone = true;
      if (_served) _allowClose('ad_served');
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _finished || _closeAllowed || _secondsLeft <= 1) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  /// Starts the wait before the viewer can move on: until the final ad has
  /// been seen, or the placement's fallback if it never loads.
  void _holdClose() {
    _closeAllowed = false;
    _served = false;
    _minimumViewDone = false;
    _visibleGeneration = null;
    _fallbackTimer?.cancel();
    _minimumViewTimer?.cancel();
    _countdownTimer?.cancel();
    _fallbackTimer = Timer(
        widget.placement.closeFallback, () => _allowClose('fallback_reached'));
  }

  void _allowClose(String reason) {
    if (!mounted || _finished || _closeAllowed) return;
    _fallbackTimer?.cancel();
    _minimumViewTimer?.cancel();
    _countdownTimer?.cancel();
    _log('close enabled reason=$reason');
    setState(() {
      _closeAllowed = true;
      // At the fallback, show whatever the page has instead of the
      // placeholder.
      _revealed = true;
    });
    // The remote lands on the way on the moment it appears.
    if (widget.television) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_finished) _continueFocus.requestFocus();
      });
    }
  }

  /// Back (or OK on a remote) before the way on appears draws the eye to the
  /// wait instead of doing nothing.
  void _showWaitHint() {
    _waitHintTimer?.cancel();
    setState(() => _waitHint = true);
    _waitHintTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _waitHint = false);
    });
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

  /// Ad tags set cookies from their own domains inside a page loaded from the
  /// app's placeholder origin; Android WebView blocks those third-party
  /// cookies by default. Debug builds can also be inspected from
  /// chrome://inspect.
  Future<void> _prepareAndroid(WebViewController controller) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final userAgent = await controller.getUserAgent();
        if (userAgent != null && userAgent.isNotEmpty) {
          final browserAgent = userAgent
              .replaceAll(RegExp(r';\s*wv(?=[;)])'), '')
              .replaceAll(RegExp(r'\s+Version/4\.0\b'), '');
          if (browserAgent != userAgent) {
            await controller.setUserAgent(browserAgent);
          }
          _log('Android playback user agent: $browserAgent');
        }
      } catch (error) {
        _log('user agent configuration unavailable ($error)');
      }
    }
    await _prepareAndroidController(controller);
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
    _fallbackTimer?.cancel();
    _minimumViewTimer?.cancel();
    _countdownTimer?.cancel();
    _waitHintTimer?.cancel();
  }

  Future<void> _stop(WebViewController? controller) async {
    await _stopPlaybackController(controller);
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
    _continueFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _phase == _Phase.page ? _page : _script;
    final opening = _page != null;
    // The placeholder covers blank redirect pages until the ad has content,
    // and Monetag's tag page, which never shows anything itself. It takes
    // touches, so a tap on it never counts as a tap on the ad.
    final placeholder =
        (opening && !_revealed) || (_automaticMonetag && !opening);
    final redirecting = opening && _revealed && !_pageReady;
    final screen = Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(children: [
          _bar(context),
          SizedBox(
            height: 2,
            child: redirecting
                ? const LinearProgressIndicator(
                    minHeight: 2, backgroundColor: Colors.transparent)
                : null,
          ),
          Expanded(
            child: Stack(children: [
              if (controller != null)
                Positioned.fill(
                  child: Listener(
                    onPointerDown: (_) => _lastPointer = DateTime.now(),
                    child: _webView(controller),
                  ),
                ),
              Positioned.fill(
                // While it fades out, taps already belong to the ad.
                child: IgnorePointer(
                  ignoring: !placeholder,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: placeholder
                        ? _placeholder()
                        : const SizedBox.shrink(key: ValueKey('ad')),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_closable) {
          _finish('system_back');
        } else {
          _log('back ignored until the ad is served');
          _showWaitHint();
        }
      },
      child: widget.television
          ? Focus(autofocus: true, onKeyEvent: _onRemoteKey, child: screen)
          : screen,
    );
  }

  static final _arrowKeys = {
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
  };

  static final _selectKeys = {
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.gameButtonA,
  };

  /// The remote stays on FlixQuest's controls: the ad page is there to be
  /// seen, and a WebView that took focus would keep the remote. OK before
  /// the way on appears shows the wait; once it is there, any key finds it.
  KeyEventResult _onRemoteKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final arrow = _arrowKeys.contains(key);
    if (!arrow && !_selectKeys.contains(key)) return KeyEventResult.ignored;
    if (!_closable) {
      if (!arrow && event is KeyDownEvent) _showWaitHint();
      return KeyEventResult.handled;
    }
    if (!_continueFocus.hasPrimaryFocus) {
      _continueFocus.requestFocus();
      return KeyEventResult.handled;
    }
    // OK on the focused button activates it; arrows have nowhere to go.
    return arrow ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  Widget _placeholder() {
    final (icon, headline, message) = !widget.holdClose
        ? (
            Icons.open_in_new,
            'Opening the advertiser\'s page',
            'Your video is paused. It picks up again when you come back.',
          )
        : widget.stage == PlaybackAdStage.streamFound
            ? (
                Icons.play_circle_outline,
                'Your video is ready',
                'A short sponsored page comes first. Ads like this keep '
                    'FlixQuest free.',
              )
            : (
                Icons.open_in_new,
                'Opening the sponsor\'s page',
                'You can head back to FlixQuest in a few seconds.',
              );
    return _AdPlaceholder(
        key: const ValueKey('placeholder'),
        icon: icon,
        headline: headline,
        message: message,
        scale: _scale);
  }

  double get _scale => widget.television ? 1.4 : 1.0;

  /// "Ad" and who it is from, then the wait or the way on.
  Widget _bar(BuildContext context) {
    final host = _pageReady ? _advertiserHost : null;
    final scale = _scale;
    return SizedBox(
      height: 52 * scale,
      child: Padding(
        // TVs crop the picture's edges (overscan).
        padding: EdgeInsets.symmetric(
            horizontal: widget.television ? 48 : 12,
            vertical: widget.television ? 6 : 0),
        child: Row(children: [
          _AdBadge(scale: scale),
          SizedBox(width: 10 * scale),
          Expanded(
            child: Text(
              host == null
                  ? 'Sponsored · keeps FlixQuest free'
                  : 'Sponsored · $host',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white70, fontSize: 13 * scale),
            ),
          ),
          SizedBox(width: 8 * scale),
          if (_closable)
            Tooltip(
              message: 'Close ad',
              child: FilledButton.icon(
                focusNode: _continueFocus,
                onPressed: () => _finish('user_close'),
                icon: Icon(_continueIcon, size: 18 * scale),
                label: Text(_continueLabel),
                style: FilledButton.styleFrom(
                  visualDensity: widget.television
                      ? VisualDensity.standard
                      : VisualDensity.compact,
                  padding: EdgeInsets.symmetric(horizontal: 14 * scale),
                  textStyle: TextStyle(
                      fontSize: 14 * scale, fontWeight: FontWeight.w600),
                ).copyWith(
                  // A remote needs to see where it is.
                  side: WidgetStateProperty.resolveWith((states) =>
                      states.contains(WidgetState.focused)
                          ? const BorderSide(color: Colors.white, width: 3)
                          : null),
                ),
              ),
            )
          // On the tag page its own Play button leads on.
          else if (_phase == _Phase.page)
            _WaitPill(
              secondsLeft: _pageReady ? _secondsLeft : null,
              total: AdsterraPlaybackAdScreen.minimumView.inSeconds,
              emphasized: _waitHint,
              scale: scale,
            ),
        ]),
      ),
    );
  }

  String get _continueLabel {
    if (!widget.holdClose) return 'Back to video';
    if (widget.stage == PlaybackAdStage.beforeLoader) return 'Continue';
    return _phase == _Phase.script ? 'Skip' : 'Play now';
  }

  IconData get _continueIcon {
    if (!widget.holdClose) return Icons.arrow_back;
    if (widget.stage == PlaybackAdStage.beforeLoader) {
      return Icons.arrow_forward;
    }
    return _phase == _Phase.script ? Icons.skip_next : Icons.play_arrow;
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

class _AdBadge extends StatelessWidget {
  const _AdBadge({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) => Container(
        padding:
            EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2 * scale),
        decoration: BoxDecoration(
          color: const Color(0xFFFFC107),
          borderRadius: BorderRadius.circular(4 * scale),
        ),
        child: Text('Ad',
            style: TextStyle(
                color: Colors.black,
                fontSize: 12 * scale,
                fontWeight: FontWeight.w700)),
      );
}

/// Where the way on will appear: "Ad loading" until the final ad shows, then
/// "Continue in 3" with a ring that fills as the view completes.
class _WaitPill extends StatelessWidget {
  const _WaitPill(
      {required this.secondsLeft,
      required this.total,
      required this.emphasized,
      required this.scale});

  /// Null while the final ad is still loading.
  final int? secondsLeft;
  final int total;

  /// Back or OK was pressed: grow and brighten so the wait is noticed.
  final bool emphasized;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final seconds = secondsLeft;
    final label = seconds == null ? 'Ad loading' : 'Continue in $seconds';
    return Semantics(
      label: seconds == null
          ? 'The ad is loading'
          : 'You can continue in $seconds seconds',
      excludeSemantics: true,
      child: AnimatedScale(
        scale: emphasized ? 1.08 : 1,
        duration: const Duration(milliseconds: 150),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 7 * scale),
          decoration: BoxDecoration(
            color: emphasized ? Colors.white24 : Colors.white10,
            borderRadius: BorderRadius.circular(20 * scale),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox.square(
              dimension: 14 * scale,
              child: CircularProgressIndicator(
                value: seconds == null
                    ? null
                    : total <= 0
                        ? 1
                        : 1 - seconds / total,
                strokeWidth: 2,
                color: Colors.white,
                backgroundColor: Colors.white24,
              ),
            ),
            SizedBox(width: 8 * scale),
            Text(label,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13 * scale,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

/// What the viewer sees while the ad's redirects run, instead of blank pages.
class _AdPlaceholder extends StatelessWidget {
  const _AdPlaceholder(
      {required this.icon,
      required this.headline,
      required this.message,
      required this.scale,
      super.key});

  final IconData icon;
  final String headline;
  final String message;
  final double scale;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32 * scale),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon,
                  size: 56 * scale,
                  color: Theme.of(context).colorScheme.primary),
              SizedBox(height: 16 * scale),
              Text(headline,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20 * scale,
                      fontWeight: FontWeight.w600)),
              SizedBox(height: 8 * scale),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14 * scale,
                      height: 1.4)),
              SizedBox(height: 24 * scale),
              SizedBox(
                width: 140 * scale,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  borderRadius: BorderRadius.circular(2),
                  backgroundColor: Colors.white12,
                ),
              ),
            ]),
          ),
        ),
      );
}

/// A search engine's home page at the end of a redirect chain means the
/// tracker rejected the visit: there is no ad to show. App store listings and
/// every other page are left alone.
@visibleForTesting
bool isNoAdFallback(Uri? uri) {
  if (uri == null ||
      !const {'https', 'http'}.contains(uri.scheme) ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    return false;
  }
  final host = uri.host.toLowerCase();
  return RegExp(r'^(www\.)?google\.[a-z]{2,3}(\.[a-z]{2})?$').hasMatch(host) ||
      host == 'bing.com' ||
      host == 'www.bing.com';
}

bool _playbackDebuggingEnabled = false;

Future<void> _prepareAndroidController(WebViewController controller) async {
  final platform = controller.platform;
  if (platform is! AndroidWebViewController) return;
  try {
    if (kDebugMode && !_playbackDebuggingEnabled) {
      _playbackDebuggingEnabled = true;
      await AndroidWebViewController.enableDebugging(true);
    }
    await AndroidWebViewCookieManager(
            const PlatformWebViewCookieManagerCreationParams())
        .setAcceptThirdPartyCookies(platform, true);
  } catch (error) {
    debugPrint('[AdsterraPage] third-party cookies unavailable ($error)');
  }
}

Future<void> _stopPlaybackController(WebViewController? controller) async {
  try {
    await controller?.setJavaScriptMode(JavaScriptMode.disabled);
    await controller?.loadRequest(Uri.parse('about:blank'));
  } catch (_) {}
}

/// The current Onclick tag exposes onClickTrigger after loading its script,
/// before its asynchronous `/5/<zone>/` options request finishes. Wait for that
/// request and a short initialization grace period, then invoke the trigger
/// once. This does not dispatch a click or claim a trusted user gesture.
/// The screen's load timer bounds a missing hook/request; disabling JavaScript
/// on close cancels this document and prevents late activation.
@visibleForTesting
const monetagAutomaticPlaybackScript = r'''
(function(){
 if(window.fqMonetagAutomatic)return;
 window.fqMonetagAutomatic=true;
 var readyAt=null;
 var timer=setInterval(function(){
  var requests=performance.getEntriesByType('resource').filter(function(entry){
   try{return /^\/5\/\d+\/?$/.test(new URL(entry.name).pathname);}
   catch(e){return false;}
  });
  if(!requests.length)return;
  var request=requests[requests.length-1];
  if(request.responseStatus===204){
   clearInterval(timer);
   PlaybackAd.postMessage(JSON.stringify({event:'empty',url:request.name}));
   return;
  }
  if(typeof window.onClickTrigger!=='function')return;
  if(readyAt===null){readyAt=Date.now()+500;return;}
  if(Date.now()<readyAt)return;
  clearInterval(timer);
  PlaybackAd.postMessage(JSON.stringify({event:'activated'}));
  try{window.onClickTrigger();}
  catch(e){PlaybackAd.postMessage(JSON.stringify({event:'failed',detail:String(e)}));}
 },100);
})();
''';

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
/// programmatically. Its tap is caught on the window in the capture phase,
/// registered before the tag, so a tag that stops the click cannot leave
/// Continue dead. Defer the head script so document.body and the controls
/// exist when it runs.
String playbackAdHtml(PlaybackAdPlacement placement, PlaybackAdStage stage) {
  if (placement.isSmartlink) {
    throw ArgumentError('Smartlinks use direct WebView navigation.');
  }
  final escape = const HtmlEscape(HtmlEscapeMode.attribute);
  final script = escape.convert(placement.scriptUrl.toString());
  // Clickadu's and Monetag's onclick tags find their zone on their own
  // script element.
  final zoneAttribute = switch (placement.network) {
    AdNetwork.clickadu => 'data-clocid',
    AdNetwork.monetag => 'data-zone',
    AdNetwork.adsterra || AdNetwork.exoclick => null,
  };
  final zone = placement.zoneId == null || zoneAttribute == null
      ? ''
      : ' $zoneAttribute="${escape.convert(placement.zoneId!)}"';
  final popunder = stage == PlaybackAdStage.streamFound;
  // Clickadu's tag fetches its ad (`/adx/get/`) a few seconds after its script
  // loads, and a tap before that opens nothing. Enable Continue only once
  // that request has finished; the load timeout covers a tag that never arms.
  final armed = placement.network == AdNetwork.clickadu
      ? '''<script>(function(){var done=false;function arm(){if(done)return;done=true;setTimeout(function(){fqSignal('loaded');},300);}
window.fqTagLoaded=function(){fqSignal('script');};
var host=new URL('$script'.replace(/&amp;/g,'&')).host;
try{new PerformanceObserver(function(list){list.getEntries().forEach(function(e){var u=new URL(e.name);if(u.host===host)fqSignal('request',u.pathname,Math.round(e.duration)+'ms status='+(e.responseStatus===undefined?'?':e.responseStatus));if(e.name.indexOf('/adx/get/')>=0)arm();});}).observe({type:'resource',buffered:true});}
catch(e){window.fqTagLoaded=function(){fqSignal('script');arm();};}})();</script>'''
      : '';
  // Monetag's tag loads its ad code from rotating domains; log every request
  // so a tag that never opens anything shows where it stopped.
  final trace = placement.network == AdNetwork.monetag
      ? '''<script>try{new PerformanceObserver(function(list){list.getEntries().forEach(function(e){var u=new URL(e.name);fqSignal('request',u.host+u.pathname,Math.round(e.duration)+'ms status='+(e.responseStatus===undefined?'?':e.responseStatus));});}).observe({type:'resource',buffered:true});}catch(e){}</script>'''
      : '';
  final onLoad = placement.network == AdNetwork.clickadu
      ? 'fqTagLoaded()'
      : "fqSignal('loaded')";
  return '''<!doctype html><html><head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>html,body{margin:0;width:100%;height:100%;background:#000;color:#fff;font-family:Roboto,system-ui,sans-serif}
#fq-controls{height:100%;box-sizing:border-box;padding:0 32px;display:flex;flex-direction:column;gap:16px;align-items:center;justify-content:center;text-align:center}
#fq-title{font-size:20px;font-weight:600}
#fq-continue{min-width:200px;padding:16px 28px;background:#fff;color:#000;border:0;border-radius:28px;font-size:17px;font-weight:600}
#fq-continue:disabled{opacity:.5}
#fq-note{max-width:320px;font-size:13px;line-height:1.4;color:#aaa}</style>
<script>
function fqSignal(event,url,detail){if(event==='loaded'){var b=document.getElementById("fq-continue");if(b){b.disabled=false;b.textContent="\u25B6  Play now";}}PlaybackAd.postMessage(JSON.stringify({event:event,url:url,detail:detail}));}
window.addEventListener('error',function(event){fqSignal('failed',null,event.message||'script resource failed');});
</script>
${popunder ? '$armed$trace<script defer data-cfasync="false"$zone src="$script" onload="$onLoad" onerror="fqSignal(\'failed\')"></script>' : ''}
</head><body>
${popunder ? '''<main id="fq-controls"><div id="fq-title">Your video is ready</div><button id="fq-continue" type="button" disabled>One moment…</button><div id="fq-note">Sponsored: an ad may open first. Ads like this keep FlixQuest free.</div></main><script>
window.addEventListener("click",function(event){
 if(!event.target||event.target.id!=="fq-continue")return;
 setTimeout(function(){fqSignal("done");},750);
},true);
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
