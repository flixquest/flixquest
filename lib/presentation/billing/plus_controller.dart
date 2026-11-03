import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flixquest/core/error/failure.dart';
import 'package:flixquest/core/storage/kv_store.dart';

import '../../data/ads/ads_policy.dart';
import '../../data/models/billing.dart';
import '../../data/repositories/billing_repository.dart';

/// FlixQuest Plus for the signed-in account: access, renewal, balance and the
/// top-up being paid for. Laravel decides everything; this keeps the last
/// verified answer, follows the account and drives [AdsPolicy].
///
/// Every response is tagged with the revision it was requested under, so an
/// answer for an account that has since signed out never reaches the next
/// one. A verified entitlement is cached for its owner and trusted offline
/// until the earlier of its paid expiry and [offlineGrace] after the check.
class PlusController extends ChangeNotifier {
  PlusController({
    required BillingRepository repository,
    required KvStore store,
    required ValueListenable<String?> owner,
    DateTime Function()? now,
    this.pollInterval = const Duration(seconds: 4),
    this.pollWindow = const Duration(minutes: 2),
    this.slowPollInterval = const Duration(seconds: 15),
    this.slowPollWindow = const Duration(minutes: 30),
  })  : _repository = repository,
        _store = store,
        _ownerSource = owner,
        _now = now ?? DateTime.now;

  final BillingRepository _repository;
  final KvStore _store;
  final ValueListenable<String?> _ownerSource;
  final DateTime Function() _now;
  final Duration pollInterval;
  final Duration pollWindow;

  /// After [pollWindow], checks keep going at this pace until
  /// [slowPollWindow]: sending from an exchange, then waiting for the chain,
  /// often takes longer than two minutes.
  final Duration slowPollInterval;
  final Duration slowPollWindow;

  /// How long a verified entitlement stays usable without the network.
  static const offlineGrace = Duration(hours: 24);

  /// Coming back to the app within this long of a check does not ask
  /// Laravel again; the timer armed by the last answer keeps the pace.
  static const resumeRecheckAfter = Duration(minutes: 2);
  static const _cacheKey = 'plus.account';

  String? _owner;
  int _revision = 0;
  bool _started = false;
  bool _disposed = false;
  bool _foreground = true;

  /// The signed-in account (`user:<id>`), or null for guests.
  String? get owner => _owner;
  bool get signedIn => _owner != null;

  PlusCatalog? _catalog;
  DateTime? _catalogAt;
  PlusCatalog? get catalog => _catalog;
  PlusPlan? get plan => _catalog?.plan;

  PlusAccount? _account;
  PlusAccount? get account => _account;
  PlusEntitlement? get entitlement => _account?.entitlements;
  PlusRenewal? get renewal => _account?.renewal;
  WalletBalance? get wallet => _account?.wallet;

  /// The account's Patreon link, once a Plus screen has read it.
  PatreonMembership? get patreon => _account?.patreon;

  /// Patreon as the catalog offers it.
  PatreonOffer get patreonOffer => _catalog?.patreon ?? const PatreonOffer();

  /// Server time minus this device's clock, from the last verified answer.
  Duration _offset = Duration.zero;
  DateTime? _verifiedAt;
  bool _fromCache = false;

  /// When the account was last confirmed with Laravel, in server time.
  DateTime? get verifiedAt => _verifiedAt;

  /// The account on screen is the cached copy, not yet re-confirmed.
  bool get showingCached => _fromCache;

  DateTime get serverNow => _now().toUtc().add(_offset);

  bool _loading = false;

  /// The first answer for this account is still on its way.
  bool get loading => _loading && _account == null;
  bool get refreshing => _loading;

  BillingError? _error;
  BillingError? get error => _error;

  Future<void>? _inFlight;
  Timer? _refreshTimer;
  Timer? _expiryTimer;

  /// Paid, unexpired access confirmed by Laravel within [offlineGrace].
  bool get adFree {
    final entitlement = this.entitlement;
    final verified = _verifiedAt;
    if (entitlement == null || !entitlement.adFree || verified == null) {
      return false;
    }
    final now = serverNow;
    final expires = entitlement.expiresAt;
    if (expires != null && !now.isBefore(expires)) return false;
    return now.difference(verified) < offlineGrace;
  }

  /// When paid access ends, if there is any.
  DateTime? get activeUntil => adFree ? entitlement?.expiresAt : null;

  /// The share of the current paid stretch already used, for progress rings.
  double get periodProgress {
    final starts = entitlement?.startsAt;
    final ends = entitlement?.expiresAt;
    if (!adFree || starts == null || ends == null) return 0;
    final total = ends.difference(starts).inSeconds;
    if (total <= 0) return 1;
    return (serverNow.difference(starts).inSeconds / total).clamp(0.0, 1.0);
  }

  /// The coupon discount the coming periods use, while it has periods left.
  PlusDiscount? get discount {
    final discount = renewal?.discount;
    return discount == null || discount.periodsRemaining < 1 ? null : discount;
  }

  /// What one period at [priceCents] takes from the balance under
  /// [discount], rounded the way Laravel rounds it. The top-up itself is
  /// never discounted: it is credit, and the coupon is spent on the periods
  /// that credit buys.
  int chargeFor(int priceCents) {
    final discount = this.discount;
    if (discount == null) return priceCents;
    final off = discount.percentOff != null
        ? priceCents * discount.percentOff! ~/ 100
        : min(priceCents, discount.amountOffCents ?? 0);
    return priceCents - off;
  }

  /// How many periods at [priceCents] [cents] of balance pays for, the
  /// discounted ones first.
  int periodsFundedBy(int cents, int priceCents) {
    if (priceCents < 1) return 0;
    final charge = chargeFor(priceCents);
    final discounted = discount?.periodsRemaining ?? 0;
    if (charge < 1) return discounted + cents ~/ priceCents;
    final cheap = min(discounted, cents ~/ charge);
    return cheap + (cents - cheap * charge) ~/ priceCents;
  }

  /// Purchases are open and this viewer could benefit from Plus.
  bool get shouldSuggest => !adFree && (_catalog?.purchasesEnabled ?? false);

  bool _celebrate = false;

  /// Plus just started in this session; the celebration shows once.
  bool get celebrationPending => _celebrate;
  void takeCelebration() {
    if (!_celebrate) return;
    _celebrate = false;
    notifyListeners();
  }

  String? _pendingCoupon;

  /// A code from a flix.quest/c/… link, kept until someone signed in can
  /// redeem it (a guest who taps one signs in first).
  String? get pendingCoupon => _pendingCoupon;

  void offerCoupon(String code) {
    _pendingCoupon = code;
    notifyListeners();
  }

  /// The prompt for [pendingCoupon] was shown; it is not offered again.
  void takePendingCoupon() {
    if (_pendingCoupon == null) return;
    _pendingCoupon = null;
    notifyListeners();
  }

  // ---- lifecycle ---------------------------------------------------------

  /// Restores the cached answer for the current account (so a paying viewer
  /// never sees a first-frame ad) and checks again in the background.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _ownerSource.addListener(_onOwnerChanged);
    _adopt(_ownerSource.value);
    unawaited(refreshCatalog());
  }

  void _onOwnerChanged() {
    if (_ownerSource.value == _owner) return;
    _adopt(_ownerSource.value);
  }

  void _adopt(String? owner) {
    _revision++;
    _owner = owner;
    _account = null;
    _verifiedAt = null;
    _fromCache = false;
    _error = null;
    _celebrate = false;
    _inFlight = null;
    _retryTopup = null;
    _stopTopupWatch();
    _stopPatreonWatch();
    _refreshTimer?.cancel();
    _expiryTimer?.cancel();
    if (owner != null) _restoreCache(owner);
    _publish();
    if (owner != null) unawaited(refresh());
  }

  void onResume() {
    _foreground = true;
    if (_catalogAt == null ||
        _now().difference(_catalogAt!) > const Duration(minutes: 10)) {
      unawaited(refreshCatalog());
    }
    if (_owner == null) return;
    // A quick trip out of the app does not ask again; open top-ups and
    // Patreon links below are still checked straight away.
    final verified = _verifiedAt;
    if (!_fromCache &&
        verified != null &&
        serverNow.difference(verified) < resumeRecheckAfter) {
      _scheduleRefresh();
    } else {
      unawaited(refresh());
    }
    // Back from the payment page: look at the open top-up straight away.
    final topup = _topup;
    if (topup != null && topup.isOpen) _watchTopup(topup, restart: true);
    // Back from Patreon in the browser: see whether the link went through.
    if (_patreonLink?.isOpen ?? false) unawaited(checkPatreonLink());
  }

  void onPause() {
    _foreground = false;
    _refreshTimer?.cancel();
    _pollTimer?.cancel();
    _patreonTimer?.cancel();
  }

  // ---- reads -------------------------------------------------------------

  Future<void> refreshCatalog() async {
    try {
      final catalog = await _repository.plans();
      if (_disposed) return;
      _catalog = catalog;
      _catalogAt = _now();
      notifyListeners();
    } on BillingError catch (_) {
      // The cached catalog, or none, keeps the offer hidden or as it was.
    }
  }

  /// Whether the next check should read the balance too. Laravel opens a
  /// wallet for any account whose balance is read, so accounts that never
  /// touched Plus only ask about access until they open a Plus screen.
  bool get _wantsWallet =>
      adFree ||
      _account?.wallet?.id != null ||
      _account?.renewal?.mode != null ||
      (_account?.pendingTopups.isNotEmpty ?? false) ||
      (_account?.patreon?.linked ?? false) ||
      (_patreonLink?.isOpen ?? false) ||
      (_topup?.isOpen ?? false);

  /// One request per account at a time; later callers share it. [full] also
  /// reads the balance, renewal and unsettled top-ups, for the Plus screens.
  Future<void> refresh({bool full = false}) {
    if (_owner == null) return Future.value();
    final wallet = full || _wantsWallet;
    final current = _inFlight;
    if (current != null && (_inFlightFull || !wallet)) return current;
    final revision = _revision;
    final next = (current ?? Future<void>.value())
        .then((_) => _refresh(revision, wallet: wallet));
    _inFlightFull = wallet;
    late final Future<void> tracked;
    tracked = next.whenComplete(() {
      if (identical(_inFlight, tracked)) _inFlight = null;
    });
    return _inFlight = tracked;
  }

  bool _inFlightFull = false;

  Future<void> _refresh(int revision, {required bool wallet}) async {
    if (revision != _revision || _disposed) return;
    _loading = true;
    notifyListeners();
    try {
      final account = wallet
          ? await _repository.wallet()
          : await _repository.entitlements();
      if (revision != _revision || _disposed) return;
      _accept(account);
      _error = null;
    } on BillingError catch (error) {
      if (revision != _revision || _disposed) return;
      _error = error;
      if (error.failure is UnauthorizedFailure ||
          error.failure is ForbiddenFailure) {
        // This account has no Plus to show (signed out, guest or disabled).
        _account = null;
        _verifiedAt = null;
        unawaited(_store.remove(_cacheKey));
      }
    } finally {
      if (revision == _revision && !_disposed) {
        _loading = false;
        _scheduleRefresh();
        _publish();
      }
    }
  }

  /// Folds a fresh, owner-scoped answer in. Calls that return only part of
  /// the account keep the parts they leave out.
  void _accept(PlusAccount fresh) {
    final previous = _account;
    final wasAdFree = adFree && !_fromCache;
    final hadVerified = _verifiedAt != null && !_fromCache;
    final serverTime = fresh.serverTime ?? _now().toUtc();
    _offset = serverTime.difference(_now().toUtc());
    _verifiedAt = serverTime;
    _fromCache = false;
    _account = fresh.copyWith(
      renewal: fresh.renewal ?? previous?.renewal,
      wallet: fresh.wallet ?? previous?.wallet,
      patreon: fresh.patreon ?? previous?.patreon,
      pendingTopups: fresh.renewal == null && fresh.wallet == null
          ? previous?.pendingTopups ?? const []
          : fresh.pendingTopups,
    );
    // Plus that starts while the app is open (a payment, a code) is
    // celebrated once; opening the app as a paying member is not.
    if (adFree && hadVerified && !wasAdFree) _celebrate = true;
    unawaited(_writeCache());
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    if (_owner == null || !_foreground) return;
    final seconds = (_account?.refreshAfterSeconds ?? 300).clamp(30, 900);
    _refreshTimer =
        Timer(Duration(seconds: seconds), () => unawaited(refresh()));
  }

  /// Pushes the access decision out and arms a timer for when it changes.
  void _publish() {
    if (_disposed) return;
    AdsPolicy.update(adFree: adFree);
    _expiryTimer?.cancel();
    if (adFree) {
      final limits = <DateTime>[
        _verifiedAt!.add(offlineGrace),
        if (entitlement?.expiresAt case final expires?) expires,
      ]..sort();
      final wait =
          limits.first.difference(serverNow) + const Duration(seconds: 1);
      _expiryTimer = Timer(wait.isNegative ? Duration.zero : wait, () {
        _publish();
        // Renewal happens on Laravel's side at the boundary; ask again.
        unawaited(refresh());
      });
    }
    notifyListeners();
  }

  // ---- offline cache -----------------------------------------------------

  void _restoreCache(String owner) {
    final saved = _store.getJson(_cacheKey);
    if (saved is! Map<String, dynamic> || saved['owner'] != owner) return;
    try {
      final account = PlusAccount.fromJson(
          Map<String, dynamic>.from(saved['account'] as Map));
      final verified = DateTime.parse(saved['verified_at'] as String);
      _offset = Duration(milliseconds: (saved['offset_ms'] as num).toInt());
      _account = account;
      _verifiedAt = verified;
      _fromCache = true;
    } catch (_) {
      unawaited(_store.remove(_cacheKey));
    }
  }

  Future<void> _writeCache() async {
    final owner = _owner;
    final account = _account;
    final verified = _verifiedAt;
    if (owner == null || account == null || verified == null) return;
    try {
      await _store.setJson(_cacheKey, {
        'owner': owner,
        'account': account.copyWith(pendingTopups: const []).toJson(),
        'verified_at': verified.toIso8601String(),
        'offset_ms': _offset.inMilliseconds,
      });
    } catch (_) {/* Offline access simply waits for the next check. */}
  }

  // ---- actions -----------------------------------------------------------

  /// Runs [work] for the current account; an answer that arrives after the
  /// account changed is dropped and reported as such.
  Future<T> _owned<T>(Future<T> Function() work) async {
    if (_owner == null) {
      throw const BillingError(Failure.unauthorized(),
          code: 'sign_in_required');
    }
    final revision = _revision;
    final result = await work();
    if (revision != _revision || _disposed) {
      throw const BillingError(Failure.conflict(), code: 'session_changed');
    }
    return result;
  }

  /// The idempotency key of a top-up whose answer never arrived, kept so
  /// trying the same top-up again cannot open a second invoice.
  ({String key, int cents, bool activate})? _retryTopup;

  /// Creates a top-up invoice. The caller opens [WalletTopup.checkoutUrl];
  /// the controller keeps checking until Laravel credits it.
  Future<WalletTopup> startTopup(int amountCents,
      {bool activatePlus = false}) async {
    final retry = _retryTopup;
    final key = retry != null &&
            retry.cents == amountCents &&
            retry.activate == activatePlus
        ? retry.key
        : newIdempotencyKey();
    _retryTopup = (key: key, cents: amountCents, activate: activatePlus);
    try {
      final topup = await _owned(() => _repository.createTopup(
            amountCents: amountCents,
            idempotencyKey: key,
            activatePlus: activatePlus,
            termsVersion: activatePlus ? termsVersion : null,
          ));
      _retryTopup = null;
      _watchTopup(topup, restart: true);
      return topup;
    } on BillingError catch (error) {
      // Only an answer that may never have arrived keeps the key.
      if (!error.offline && error.code != 'checkout_pending') {
        _retryTopup = null;
      }
      rethrow;
    }
  }

  /// The terms the viewer is shown and agrees to.
  String? get termsVersion =>
      renewal?.currentTermsVersion ?? plan?.termsVersion;

  /// Turns on wallet renewal under the current terms.
  Future<void> enableRenewal() async {
    final terms = termsVersion;
    if (terms == null) {
      throw const BillingError(Failure.unknown(), code: 'billing_unavailable');
    }
    final account = await _owned(() => _repository.enableWalletRenewal(terms));
    _acceptChange(account);
  }

  Future<void> disableRenewal() async {
    final account = await _owned(_repository.disableWalletRenewal);
    _acceptChange(account);
  }

  Future<CouponRedemption> redeemCoupon(String code) async {
    final (account, redemption) =
        await _owned(() => _repository.redeemCoupon(code));
    _acceptChange(account);
    return redemption;
  }

  /// A change's answer leaves out unsettled top-ups; read them back.
  void _acceptChange(PlusAccount account) {
    final pending = _account?.pendingTopups ?? const <WalletTopup>[];
    _accept(account.copyWith(pendingTopups: pending));
    _publish();
    unawaited(refresh(full: true));
  }

  // ---- in-app checkout --------------------------------------------------

  List<PayCoin>? _coins;
  DateTime? _coinsAt;
  bool _loadingCoins = false;
  BillingError? _coinsError;

  /// The coins a top-up can be paid in, once loaded; popular ones first.
  List<PayCoin>? get coins => _coins;
  bool get loadingCoins => _loadingCoins;
  BillingError? get coinsError => _coinsError;

  /// Loads the coin list; a list under ten minutes old is kept.
  Future<void> loadCoins({bool force = false}) async {
    if (_loadingCoins) return;
    final loadedAt = _coinsAt;
    if (!force &&
        _coins != null &&
        loadedAt != null &&
        _now().difference(loadedAt) < const Duration(minutes: 10)) {
      return;
    }
    _loadingCoins = true;
    _coinsError = null;
    notifyListeners();
    try {
      final coins = await _repository.coins();
      if (_disposed) return;
      _coins = coins;
      _coinsAt = _now();
    } on BillingError catch (error) {
      if (_disposed) return;
      _coinsError = error;
    } finally {
      if (!_disposed) {
        _loadingCoins = false;
        notifyListeners();
      }
    }
  }

  /// Pays the followed top-up in [coin]: Laravel creates the payment and the
  /// checkout shows its address and exact amount. Asking again for the same
  /// coin returns the same payment, re-quoted if its amount ran out.
  Future<WalletTopup> payWith(String coin, {bool emailReceipt = false}) async {
    final current = _topup;
    if (current == null) {
      throw const BillingError(Failure.unknown(), code: 'topup_closed');
    }
    final next = await _owned(() =>
        _repository.payTopup(current.id, coin, emailReceipt: emailReceipt));
    if (_topup?.id != current.id) return next;
    _watchTopup(next, restart: true);
    return next;
  }

  /// A link for a phone to add funds to this account; TVs show it as a QR.
  Future<({Uri url, DateTime expiresAt})> topupLink() =>
      _owned(_repository.topupLink);

  Future<WalletHistoryPage> history({String? cursor}) =>
      _owned(() => _repository.transactions(cursor: cursor));

  // ---- top-up watch ------------------------------------------------------

  WalletTopup? _topup;
  Timer? _pollTimer;
  DateTime? _pollUntil;
  DateTime? _slowPollUntil;
  int _polls = 0;
  bool _checking = false;

  /// The top-up being paid for in this session, as last reported.
  WalletTopup? get topup => _topup;

  /// The automatic checks gave up; the viewer can still check by hand.
  bool get topupWatchExpired =>
      _topup != null && _topup!.isOpen && _pollTimer == null && !_checking;

  bool get checkingTopup => _checking;

  /// Follows [topup] even if it was started elsewhere (another device).
  void followTopup(WalletTopup topup) => _watchTopup(topup, restart: true);

  void _watchTopup(WalletTopup topup, {bool restart = false}) {
    _topup = topup;
    if (!topup.isOpen) {
      _stopTopupWatch(keep: true);
      notifyListeners();
      return;
    }
    if (restart || _pollUntil == null) _restartPollWindow();
    _pollTimer?.cancel();
    _pollTimer = Timer(pollInterval, () => unawaited(checkTopup()));
    notifyListeners();
  }

  /// Checks the top-up now. Every few automatic checks, and every manual
  /// one, ask Laravel to look the payment up with NOWPayments again.
  Future<void> checkTopup({bool manual = false}) async {
    final current = _topup;
    if (current == null || _checking) return;
    _pollTimer?.cancel();
    _pollTimer = null;
    _checking = true;
    if (manual) _restartPollWindow(keepCount: true);
    notifyListeners();
    final revision = _revision;
    try {
      _polls++;
      final reconcile = manual || _polls % 4 == 0;
      final next = reconcile
          ? await _repository.reconcileTopup(current.id)
          : await _repository.topup(current.id);
      if (revision != _revision || _disposed) return;
      // Something happened (coin chosen elsewhere, deposit seen): look
      // closely again for a while.
      if (next.step != current.step ||
          next.payment?.status != current.payment?.status) {
        _restartPollWindow(keepCount: true);
      }
      _topup = next;
      if (next.settled) {
        _stopTopupWatch(keep: true);
        await refresh(full: true);
      }
    } on BillingError catch (_) {
      // A missed check is retried until the window closes.
    } finally {
      if (revision == _revision && !_disposed) {
        _checking = false;
        final topup = _topup;
        final wait = _nextPoll();
        _pollTimer =
            topup != null && topup.isOpen && _foreground && wait != null
                ? Timer(wait, () => unawaited(checkTopup()))
                : null;
        notifyListeners();
      }
    }
  }

  void _restartPollWindow({bool keepCount = false}) {
    final now = _now();
    _pollUntil = now.add(pollWindow);
    _slowPollUntil = now.add(slowPollWindow);
    if (!keepCount) _polls = 0;
  }

  /// The wait before the next automatic check, or null once both windows
  /// have closed.
  Duration? _nextPoll() {
    final now = _now();
    final fast = _pollUntil;
    final slow = _slowPollUntil;
    if (fast != null && now.isBefore(fast)) return pollInterval;
    if (slow != null && now.isBefore(slow)) return slowPollInterval;
    return null;
  }

  /// Forgets the finished top-up once its result has been shown.
  void dismissTopup() {
    _stopTopupWatch();
    notifyListeners();
  }

  void _stopTopupWatch({bool keep = false}) {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollUntil = null;
    _slowPollUntil = null;
    _checking = false;
    if (!keep) _topup = null;
  }

  // ---- Patreon ------------------------------------------------------------

  PatreonLink? _patreonLink;
  Timer? _patreonTimer;
  bool _checkingPatreon = false;

  /// The "connect Patreon" link opened in this session, as last reported.
  PatreonLink? get patreonLink => _patreonLink;
  bool get checkingPatreon => _checkingPatreon;

  /// Asks for a link to open in a browser (or show as a QR code on a TV)
  /// and follows it until the viewer finishes on Patreon. With
  /// [activatePlus] they agree to start Plus from the balance once a
  /// charge covers a period, under the current terms.
  Future<PatreonLink> startPatreonLink({bool activatePlus = false}) async {
    final terms = termsVersion;
    if (activatePlus && terms == null) {
      throw const BillingError(Failure.unknown(), code: 'billing_unavailable');
    }
    final link = await _owned(() => _repository.startPatreonLink(
        activatePlus: activatePlus, termsVersion: terms));
    _patreonLink = link;
    _schedulePatreonCheck();
    notifyListeners();
    return link;
  }

  /// Checks the followed link now; a finished link reads the account again.
  Future<void> checkPatreonLink() async {
    final current = _patreonLink;
    if (current == null || _checkingPatreon) return;
    _patreonTimer?.cancel();
    _checkingPatreon = true;
    notifyListeners();
    final revision = _revision;
    try {
      final (link, membership) = await _repository.patreonLink(current.id);
      if (revision != _revision || _disposed) return;
      // Keep the URL: the TV keeps showing it while the link is open.
      _patreonLink = link.copyWith(url: link.url ?? current.url);
      final account = _account;
      if (account != null) _account = account.copyWith(patreon: membership);
      if (link.linked) await refresh(full: true);
    } on BillingError catch (_) {
      // A missed check is retried while the link is open.
    } finally {
      if (revision == _revision && !_disposed) {
        _checkingPatreon = false;
        _schedulePatreonCheck();
        notifyListeners();
      }
    }
  }

  void _schedulePatreonCheck() {
    _patreonTimer?.cancel();
    final link = _patreonLink;
    final expires = link?.expiresAt;
    if (link == null || !link.isOpen || !_foreground) return;
    if (expires != null && !_now().toUtc().isBefore(expires)) {
      _patreonLink = link.copyWith(status: 'expired');
      return;
    }
    _patreonTimer = Timer(pollInterval, () => unawaited(checkPatreonLink()));
  }

  /// Forgets the followed link once its outcome has been shown.
  void dismissPatreonLink() {
    _stopPatreonWatch();
    notifyListeners();
  }

  void _stopPatreonWatch() {
    _patreonTimer?.cancel();
    _patreonTimer = null;
    _patreonLink = null;
    _checkingPatreon = false;
  }

  /// Reads the membership from Patreon now, crediting a new charge.
  Future<void> syncPatreon() async {
    final account = await _owned(_repository.syncPatreon);
    _acceptChange(account);
  }

  /// Stops the pledge funding this account; the credit it added stays.
  Future<void> unlinkPatreon() async {
    final account = await _owned(_repository.unlinkPatreon);
    _stopPatreonWatch();
    _acceptChange(account);
  }

  @override
  void dispose() {
    _disposed = true;
    _ownerSource.removeListener(_onOwnerChanged);
    _refreshTimer?.cancel();
    _expiryTimer?.cancel();
    _pollTimer?.cancel();
    _patreonTimer?.cancel();
    super.dispose();
  }
}
