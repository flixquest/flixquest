// Freezed forwards constructor parameter annotations onto generated fields.
// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flixquest/core/json/json_reader.dart';

part 'billing.freezed.dart';
part 'billing.g.dart';

/// FlixQuest Plus as Laravel describes it. Paid access ([PlusEntitlement]),
/// the renewal agreement ([PlusRenewal]) and the prepaid balance
/// ([WalletBalance]) stay separate: money in the wallet is not Plus, and a
/// switched-on renewal is not paid time.

String? _id(Object? value) => JsonReader.asString(value);

@freezed
class PlusPlan with _$PlusPlan {
  const factory PlusPlan({
    required String code,
    @Default('FlixQuest Plus') String name,
    @JsonKey(name: 'amount_cents') required int amountCents,
    @Default('USD') String currency,
    @JsonKey(name: 'interval_days') required int intervalDays,
    @JsonKey(name: 'terms_version') required String termsVersion,
  }) = _PlusPlan;
  factory PlusPlan.fromJson(Map<String, dynamic> json) =>
      _$PlusPlanFromJson(json);
}

@freezed
class TopupLimits with _$TopupLimits {
  const TopupLimits._();
  const factory TopupLimits({
    @JsonKey(name: 'topup_min_cents') @Default(200) int minCents,
    @JsonKey(name: 'topup_max_cents') @Default(50000) int maxCents,
    @JsonKey(name: 'suggested_topups_cents')
    @Default(<int>[500, 1000, 2000])
    List<int> suggestedCents,
  }) = _TopupLimits;
  factory TopupLimits.fromJson(Map<String, dynamic> json) =>
      _$TopupLimitsFromJson(json);

  /// The suggestions Laravel would accept, in order; a misconfigured list
  /// (amounts under the minimum) never offers an amount that is refused.
  List<int> get offeredCents {
    final offered = suggestedCents
        .where((cents) => cents >= minCents && cents <= maxCents)
        .toSet()
        .toList()
      ..sort();
    return offered.isEmpty ? <int>[minCents] : offered;
  }
}

/// Patreon as the catalog offers it: a pledge that adds to the balance, for
/// viewers who can't pay in crypto.
@freezed
class PatreonOffer with _$PatreonOffer {
  const factory PatreonOffer({
    @Default(false) bool enabled,
    @JsonKey(name: 'pledge_url') String? pledgeUrl,

    /// The monthly pledge that pays for every Plus period on its own.
    @JsonKey(name: 'recommended_cents') @Default(200) int recommendedCents,
  }) = _PatreonOffer;
  factory PatreonOffer.fromJson(Map<String, dynamic> json) =>
      _$PatreonOfferFromJson(json);
}

/// The public catalog: what Plus costs and whether top-ups are open.
@freezed
class PlusCatalog with _$PlusCatalog {
  const PlusCatalog._();
  const factory PlusCatalog({
    @JsonKey(name: 'purchases_enabled') @Default(false) bool purchasesEnabled,
    @Default(<PlusPlan>[]) List<PlusPlan> plans,
    @Default(TopupLimits()) TopupLimits wallet,
    @Default(PatreonOffer()) PatreonOffer patreon,
  }) = _PlusCatalog;
  factory PlusCatalog.fromJson(Map<String, dynamic> json) =>
      _$PlusCatalogFromJson(json);

  PlusPlan? get plan => plans.isEmpty ? null : plans.first;
}

@freezed
class PlusEntitlement with _$PlusEntitlement {
  const factory PlusEntitlement({
    @JsonKey(name: 'ad_free') @Default(false) bool adFree,
    @JsonKey(name: 'starts_at') DateTime? startsAt,
    @JsonKey(name: 'expires_at') DateTime? expiresAt,
    @Default(0) int revision,
  }) = _PlusEntitlement;
  factory PlusEntitlement.fromJson(Map<String, dynamic> json) =>
      _$PlusEntitlementFromJson(json);
}

/// A coupon discount waiting for the coming renewals.
@freezed
class PlusDiscount with _$PlusDiscount {
  const factory PlusDiscount({
    required String type,
    @JsonKey(name: 'percent_off') int? percentOff,
    @JsonKey(name: 'amount_off_cents') int? amountOffCents,
    @JsonKey(name: 'periods_remaining') @Default(0) int periodsRemaining,
  }) = _PlusDiscount;
  factory PlusDiscount.fromJson(Map<String, dynamic> json) =>
      _$PlusDiscountFromJson(json);
}

@freezed
class PlusRenewal with _$PlusRenewal {
  const PlusRenewal._();
  const factory PlusRenewal({
    String? mode,
    @JsonKey(name: 'auto_renew') @Default(false) bool autoRenew,
    @JsonKey(name: 'next_charge_cents') int? nextChargeCents,
    @JsonKey(name: 'next_charge_at') DateTime? nextChargeAt,
    @JsonKey(name: 'lapsed_at') DateTime? lapsedAt,
    @JsonKey(name: 'cancelled_at') DateTime? cancelledAt,
    @JsonKey(name: 'amount_cents') @Default(200) int amountCents,
    @JsonKey(name: 'interval_days') @Default(31) int intervalDays,
    @JsonKey(name: 'terms_version') String? termsVersion,
    @JsonKey(name: 'current_terms_version') String? currentTermsVersion,
    @JsonKey(name: 'terms_outdated') @Default(false) bool termsOutdated,
    PlusDiscount? discount,
    @JsonKey(name: 'last_error_code') String? lastErrorCode,
  }) = _PlusRenewal;
  factory PlusRenewal.fromJson(Map<String, dynamic> json) =>
      _$PlusRenewalFromJson(json);

  /// Renewal stopped because the balance ran short, not by choice.
  bool get lapsedForFunds =>
      lastErrorCode == 'wallet_insufficient_balance' || lapsedAt != null;
}

@freezed
class WalletBalance with _$WalletBalance {
  const WalletBalance._();
  const factory WalletBalance({
    @JsonKey(fromJson: _id) String? id,
    @Default('USD') String currency,
    @JsonKey(name: 'balance_cents') @Default(0) int balanceCents,
    @JsonKey(name: 'spendable_cents') @Default(0) int spendableCents,
    @Default('active') String status,
    @Default(false) bool frozen,
    @Default(0) int revision,
    @JsonKey(name: 'periods_fundable') @Default(0) int periodsFundable,
  }) = _WalletBalance;
  factory WalletBalance.fromJson(Map<String, dynamic> json) =>
      _$WalletBalanceFromJson(json);

  bool get closed => status == 'closed';
}

/// A coin a top-up can be paid in, as Laravel names it for both clients.
@freezed
class PayCoin with _$PayCoin {
  const PayCoin._();
  const factory PayCoin({
    required String code,
    required String ticker,
    required String name,
    @Default('') String network,
    @JsonKey(name: 'network_label') @Default('') String networkLabel,
    @JsonKey(name: 'logo_url') String? logoUrl,

    /// `memo` or `destination_tag` when a deposit needs one to be matched.
    @JsonKey(name: 'extra_id') String? extraId,
    @Default(false) bool popular,
  }) = _PayCoin;
  factory PayCoin.fromJson(Map<String, dynamic> json) =>
      _$PayCoinFromJson(json);

  /// Matches a search by ticker, name, network or code.
  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return '$ticker $name $networkLabel $code'.toLowerCase().contains(needle);
  }

  /// Only NOWPayments' own HTTPS logos are drawn.
  String? get trustedLogo {
    final uri = Uri.tryParse(logoUrl ?? '');
    return uri != null && uri.scheme == 'https' && uri.host == 'nowpayments.io'
        ? logoUrl
        : null;
  }
}

/// The payment FlixQuest's checkout created for the chosen coin. The
/// [address] and [extraId] are only sent while there is something to pay.
/// Amounts stay strings: every decimal of a crypto amount matters.
@freezed
class TopupPayment with _$TopupPayment {
  const TopupPayment._();
  const factory TopupPayment({
    @JsonKey(fromJson: _id) String? id,
    required String status,
    required PayCoin coin,
    String? amount,
    String? paid,
    String? remaining,
    String? address,
    @JsonKey(name: 'extra_id') String? extraId,
    String? uri,
    @JsonKey(name: 'expires_at') DateTime? expiresAt,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _TopupPayment;
  factory TopupPayment.fromJson(Map<String, dynamic> json) =>
      _$TopupPaymentFromJson(json);

  /// What is still to send: the rest of a partial payment, else all of it.
  String? get due => remaining ?? amount;
}

/// One crypto payment that adds USD credit once NOWPayments settles it.
@freezed
class WalletTopup with _$WalletTopup {
  const WalletTopup._();
  const factory WalletTopup({
    required String id,
    required String status,

    /// `nowpayments` (crypto) or `patreon` (a credited pledge charge).
    @Default('nowpayments') String provider,
    @JsonKey(name: 'amount_cents') required int amountCents,
    @JsonKey(name: 'credited_cents') @Default(0) int creditedCents,
    @Default('USD') String currency,
    @JsonKey(name: 'activate_plus') @Default(false) bool activatePlus,
    @JsonKey(name: 'next_action') @Default('none') String nextAction,
    @JsonKey(name: 'checkout_url') String? checkoutUrl,

    /// Where FlixQuest's own checkout is: `preparing`, `choose_coin`,
    /// `send`, `send_remaining`, `confirming`, `credited` or `closed`.
    @JsonKey(name: 'checkout_step') String? checkoutStep,
    TopupPayment? payment,
    @JsonKey(name: 'pay_currency') String? payCurrency,
    @JsonKey(name: 'error_code') String? errorCode,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'credited_at') DateTime? creditedAt,
  }) = _WalletTopup;
  factory WalletTopup.fromJson(Map<String, dynamic> json) =>
      _$WalletTopupFromJson(json);

  /// The checkout step, worked out from the status for a server that does
  /// not send one.
  String get step =>
      checkoutStep ??
      switch (status) {
        'settled' => 'credited',
        'creating' || 'unknown' => 'preparing',
        'partially_paid' => 'send_remaining',
        _ when !isOpen => 'closed',
        _ => payCurrency == null ? 'choose_coin' : 'confirming',
      };

  static const openStatuses = {
    'creating',
    'pending',
    'unknown',
    'partially_paid'
  };

  bool get isOpen => openStatuses.contains(status);
  bool get settled => status == 'settled';
  bool get failed => const {'failed', 'expired', 'reversed'}.contains(status);
}

@freezed
class WalletTransaction with _$WalletTransaction {
  const factory WalletTransaction({
    @JsonKey(fromJson: _id) String? id,
    required String type,
    @JsonKey(name: 'amount_cents') required int amountCents,
    @JsonKey(name: 'balance_after_cents') int? balanceAfterCents,
    @JsonKey(fromJson: _id) String? reference,

    /// Where a credit came from: `nowpayments` or `patreon`.
    String? source,
    @JsonKey(name: 'period_starts_at') DateTime? periodStartsAt,
    @JsonKey(name: 'period_ends_at') DateTime? periodEndsAt,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _WalletTransaction;
  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      _$WalletTransactionFromJson({
        ...json,
        'period_starts_at': JsonReader.asMap(json['period'])?['starts_at'],
        'period_ends_at': JsonReader.asMap(json['period'])?['ends_at'],
      });
}

/// One page of the wallet history, newest first.
class WalletHistoryPage {
  const WalletHistoryPage(this.transactions, this.nextCursor);
  final List<WalletTransaction> transactions;
  final String? nextCursor;
}

/// One "connect Patreon" request. [url] (only in the answer that created
/// it) is opened in a browser, or shown as a QR code on a TV.
@freezed
class PatreonLink with _$PatreonLink {
  const PatreonLink._();
  const factory PatreonLink({
    required String id,

    /// `pending`, `authorized`, `linked`, `failed`, `cancelled` or `expired`.
    required String status,
    @JsonKey(name: 'error_code') String? errorCode,
    @JsonKey(name: 'expires_at') DateTime? expiresAt,
    @JsonKey(name: 'completed_at') DateTime? completedAt,
    String? url,
  }) = _PatreonLink;
  factory PatreonLink.fromJson(Map<String, dynamic> json) =>
      _$PatreonLinkFromJson(json);

  /// Still waiting for the viewer in the browser.
  bool get isOpen => status == 'pending' || status == 'authorized';
  bool get linked => status == 'linked';
}

/// The account's Patreon link and membership, as Patreon last reported it.
/// A pledge is wallet credit, not Plus: Plus still comes from the balance.
@freezed
class PatreonMembership with _$PatreonMembership {
  const PatreonMembership._();
  const factory PatreonMembership({
    @Default(false) bool enabled,
    @JsonKey(name: 'pledge_url') String? pledgeUrl,
    @Default(false) bool linked,
    @JsonKey(name: 'full_name') String? fullName,
    String? email,
    @JsonKey(name: 'patron_status') String? patronStatus,
    @JsonKey(name: 'active_patron') @Default(false) bool activePatron,
    @JsonKey(name: 'pledge_cents') @Default(0) int pledgeCents,
    @JsonKey(name: 'will_pay_cents') @Default(0) int willPayCents,
    @JsonKey(name: 'pledge_cadence_months') int? cadenceMonths,

    /// The pledge alone pays for every Plus period.
    @JsonKey(name: 'covers_plus') @Default(false) bool coversPlus,
    @JsonKey(name: 'last_charge_at') DateTime? lastChargeAt,
    @JsonKey(name: 'last_charge_status') String? lastChargeStatus,
    @JsonKey(name: 'next_charge_at') DateTime? nextChargeAt,
    @JsonKey(name: 'free_trial') @Default(false) bool freeTrial,
    @JsonKey(name: 'credited_cents') @Default(0) int creditedCents,

    /// Plus starts from the balance once a charge covers a period.
    @JsonKey(name: 'plus_pending') @Default(false) bool plusPending,
    @JsonKey(name: 'needs_reauthorization')
    @Default(false)
    bool needsReauthorization,
    @JsonKey(name: 'linked_at') DateTime? linkedAt,
    @JsonKey(name: 'last_synced_at') DateTime? lastSyncedAt,
    @JsonKey(name: 'last_error_code') String? lastErrorCode,
    PatreonLink? link,
  }) = _PatreonMembership;
  factory PatreonMembership.fromJson(Map<String, dynamic> json) =>
      _$PatreonMembershipFromJson(json);

  /// Patreon could not charge the pledge last time.
  bool get declined => patronStatus == 'declined_patron';

  /// What the patron pays each charge: the coming amount, else the current.
  int get monthlyCents => willPayCents > 0 ? willPayCents : pledgeCents;
}

/// Everything account-scoped the Plus screens render. [renewal] and
/// [wallet] are absent from the entitlement-only endpoint.
@freezed
class PlusAccount with _$PlusAccount {
  const factory PlusAccount({
    @Default(PlusEntitlement()) PlusEntitlement entitlements,
    @JsonKey(name: 'server_time') DateTime? serverTime,
    @JsonKey(name: 'refresh_after_seconds')
    @Default(300)
    int refreshAfterSeconds,
    @JsonKey(name: 'subscription') PlusRenewal? renewal,
    WalletBalance? wallet,
    @JsonKey(name: 'pending_topups')
    @Default(<WalletTopup>[])
    List<WalletTopup> pendingTopups,
    PatreonMembership? patreon,
  }) = _PlusAccount;
  factory PlusAccount.fromJson(Map<String, dynamic> json) =>
      _$PlusAccountFromJson(json);
}

@freezed
class CouponRedemption with _$CouponRedemption {
  const factory CouponRedemption({
    required String type,
    @JsonKey(name: 'free_days') int? freeDays,
    @JsonKey(name: 'percent_off') int? percentOff,
    @JsonKey(name: 'amount_off_cents') int? amountOffCents,
    @JsonKey(name: 'discount_periods') int? discountPeriods,
    String? summary,
  }) = _CouponRedemption;
  factory CouponRedemption.fromJson(Map<String, dynamic> json) =>
      _$CouponRedemptionFromJson(json);
}
