import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flixquest/core/cache/cache_policy.dart';
import 'package:flixquest/core/error/failure.dart';
import 'package:flixquest/core/json/json_reader.dart';
import 'package:flixquest/core/network/interceptors/error_interceptor.dart';
import '../models/billing.dart';

/// A billing request that did not succeed. Laravel names billing outcomes
/// with a stable [code] (`wallet_insufficient_balance`, `coupon_invalid`...),
/// which the app matches instead of showing provider or server wording.
class BillingError implements Exception {
  const BillingError(this.failure, {this.code, this.message});
  final Failure failure;
  final String? code;
  final String? message;

  bool get offline => failure is NetworkFailure || failure is TimeoutFailure;

  @override
  String toString() => 'BillingError(${code ?? failure.runtimeType})';
}

/// FlixQuest Plus and the prepaid wallet. Every request is owner-scoped and
/// uncached; price, user and callback URLs always come from the server.
///
/// Methods throw [BillingError]; the Plus controller is the boundary that
/// turns them into screen state.
class BillingRepository {
  const BillingRepository(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> _request(String path,
      {String method = 'GET',
      Object? data,
      Map<String, dynamic>? query,
      bool authenticated = true}) async {
    try {
      final response = await _dio.request<Object>(path,
          data: data,
          queryParameters: query,
          options: Options(method: method, extra: {
            'authRequired': authenticated,
            'cachePolicy': CachePolicy.noStore
          }));
      final body = response.data;
      if (body is! Map<String, dynamic> || body['success'] != true) {
        throw const BillingError(
            Failure.unknown(message: 'Invalid server response.'));
      }
      return body;
    } on DioException catch (error) {
      final data = error.response?.data;
      final body = data is Map<String, dynamic> ? data : const {};
      throw BillingError(failureForDio(error),
          code: JsonReader.asString(body['code']),
          message: JsonReader.asString(body['message']));
    }
  }

  T _parse<T>(T Function() read) {
    try {
      return read();
    } on BillingError {
      rethrow;
    } catch (_) {
      throw const BillingError(
          Failure.unknown(message: 'Invalid server response.'));
    }
  }

  Future<PlusCatalog> plans() async {
    final body = await _request('billing/plans', authenticated: false);
    return _parse(() => PlusCatalog.fromJson(body));
  }

  /// The canonical access answer; works for guests too (always no access).
  Future<PlusAccount> entitlements() async {
    final body = await _request('user/entitlements');
    return _parse(() => PlusAccount.fromJson(body));
  }

  /// Access, renewal, balance and the latest unsettled top-ups.
  Future<PlusAccount> wallet() async {
    final body = await _request('wallet');
    return _parse(() => PlusAccount.fromJson(body));
  }

  Future<WalletHistoryPage> transactions({String? cursor}) async {
    final body = await _request('wallet/transactions',
        query: cursor == null ? null : {'cursor': cursor});
    return _parse(() => WalletHistoryPage(
          [
            for (final entry in body['transactions'] as List)
              WalletTransaction.fromJson(
                  Map<String, dynamic>.from(entry as Map)),
          ],
          JsonReader.asString(body['next_cursor']),
        ));
  }

  /// A repeated [idempotencyKey] returns the same top-up, so a retried tap
  /// never opens a second invoice.
  Future<WalletTopup> createTopup(
      {required int amountCents,
      required String idempotencyKey,
      bool activatePlus = false,
      String? termsVersion}) async {
    final body = await _request('wallet/topups', method: 'POST', data: {
      'amount_cents': amountCents,
      'idempotency_key': idempotencyKey,
      if (activatePlus) ...{
        'activate_plus': true,
        'terms_version': termsVersion
      },
    });
    return _topup(body);
  }

  /// The coins a top-up can be paid in, popular ones first.
  Future<List<PayCoin>> coins() async {
    final body = await _request('billing/coins', authenticated: false);
    return _parse(() => <PayCoin>[
          for (final coin in body['coins'] as List)
            PayCoin.fromJson(Map<String, dynamic>.from(coin as Map)),
        ]);
  }

  /// Pays [id] in [coin]: Laravel creates the payment (or returns the one
  /// already waiting in that coin) whose address and amount the app shows.
  Future<WalletTopup> payTopup(String id, String coin,
          {bool emailReceipt = false}) async =>
      _topup(await _request('wallet/topups/${Uri.encodeComponent(id)}/payment',
          method: 'POST',
          data: {'pay_currency': coin, 'email_receipt': emailReceipt}));

  Future<WalletTopup> topup(String id) async =>
      _topup(await _request('wallet/topups/${Uri.encodeComponent(id)}'));

  /// Asks Laravel to look the payment up with NOWPayments again.
  Future<WalletTopup> reconcileTopup(String id) async => _topup(await _request(
      'wallet/topups/${Uri.encodeComponent(id)}/reconcile',
      method: 'POST'));

  WalletTopup _topup(Map<String, dynamic> body) => _parse(() =>
      WalletTopup.fromJson(Map<String, dynamic>.from(body['topup'] as Map)));

  /// A short-lived link a phone opens to add funds to this account, which a
  /// TV shows as a QR code. Only an HTTPS link is accepted.
  Future<({Uri url, DateTime expiresAt})> topupLink() async {
    final body = await _request('wallet/topup-link', method: 'POST');
    return _parse(() {
      final url = Uri.parse(body['url'] as String);
      if (url.scheme != 'https' || url.host.isEmpty) {
        throw const FormatException('Insecure top-up link');
      }
      return (
        url: url,
        expiresAt: DateTime.parse(body['expires_at'] as String),
      );
    });
  }

  /// Turns wallet renewal on under [termsVersion]; buys a period at once
  /// only when there is no paid time left.
  Future<PlusAccount> enableWalletRenewal(String termsVersion) async {
    final body = await _request('billing/subscription/wallet',
        method: 'PUT',
        data: {'auto_renew': true, 'terms_version': termsVersion});
    return _parse(() => PlusAccount.fromJson(body));
  }

  /// Stops future debits; paid time and the balance stay.
  Future<PlusAccount> disableWalletRenewal() async {
    final body = await _request('billing/subscription/wallet',
        method: 'PATCH', data: {'auto_renew': false});
    return _parse(() => PlusAccount.fromJson(body));
  }

  // ---- Patreon -----------------------------------------------------------

  /// The account's Patreon link and membership.
  Future<PatreonMembership> patreon() async {
    final body = await _request('billing/patreon');
    return _parse(() => PatreonMembership.fromJson(
        Map<String, dynamic>.from(body['patreon'] as Map)));
  }

  /// A short link that signs in to Patreon and links it to this account.
  /// With [activatePlus] the viewer agrees, under [termsVersion], to start
  /// Plus from the balance once a charge covers a period. Only an HTTPS
  /// link is accepted.
  Future<PatreonLink> startPatreonLink(
      {bool activatePlus = false, String? termsVersion}) async {
    final body = await _request('billing/patreon/link', method: 'POST', data: {
      if (activatePlus) ...{
        'activate_plus': true,
        'terms_version': termsVersion
      },
    });
    return _parse(() {
      final link =
          PatreonLink.fromJson(Map<String, dynamic>.from(body['link'] as Map));
      final url = Uri.parse(link.url ?? '');
      if (url.scheme != 'https' || url.host.isEmpty) {
        throw const FormatException('Insecure Patreon link');
      }
      return link;
    });
  }

  /// Where a link the app opened has got to, and the membership.
  Future<(PatreonLink, PatreonMembership)> patreonLink(String id) async {
    final body =
        await _request('billing/patreon/link/${Uri.encodeComponent(id)}');
    return _parse(() => (
          PatreonLink.fromJson(Map<String, dynamic>.from(body['link'] as Map)),
          PatreonMembership.fromJson(
              Map<String, dynamic>.from(body['patreon'] as Map)),
        ));
  }

  /// Asks Laravel to read the membership from Patreon now.
  Future<PlusAccount> syncPatreon() async {
    final body = await _request('billing/patreon/sync', method: 'POST');
    return _parse(() => PlusAccount.fromJson(body));
  }

  /// Stops the pledge funding this account; credit already added stays.
  Future<PlusAccount> unlinkPatreon() async {
    final body = await _request('billing/patreon', method: 'DELETE');
    return _parse(() => PlusAccount.fromJson(body));
  }

  Future<(PlusAccount, CouponRedemption)> redeemCoupon(String code) async {
    final body = await _request('billing/coupons/redeem',
        method: 'POST', data: {'code': code.trim()});
    return _parse(() => (
          PlusAccount.fromJson(body),
          CouponRedemption.fromJson(
              Map<String, dynamic>.from(body['redemption'] as Map)),
        ));
  }
}

/// A random (version 4) UUID for idempotency keys.
String newIdempotencyKey([Random? random]) {
  final source = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => source.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
