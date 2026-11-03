// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'billing.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PlusPlanImpl _$$PlusPlanImplFromJson(Map<String, dynamic> json) =>
    _$PlusPlanImpl(
      code: json['code'] as String,
      name: json['name'] as String? ?? 'FlixQuest Plus',
      amountCents: (json['amount_cents'] as num).toInt(),
      currency: json['currency'] as String? ?? 'USD',
      intervalDays: (json['interval_days'] as num).toInt(),
      termsVersion: json['terms_version'] as String,
    );

Map<String, dynamic> _$$PlusPlanImplToJson(_$PlusPlanImpl instance) =>
    <String, dynamic>{
      'code': instance.code,
      'name': instance.name,
      'amount_cents': instance.amountCents,
      'currency': instance.currency,
      'interval_days': instance.intervalDays,
      'terms_version': instance.termsVersion,
    };

_$TopupLimitsImpl _$$TopupLimitsImplFromJson(Map<String, dynamic> json) =>
    _$TopupLimitsImpl(
      minCents: (json['topup_min_cents'] as num?)?.toInt() ?? 200,
      maxCents: (json['topup_max_cents'] as num?)?.toInt() ?? 50000,
      suggestedCents: (json['suggested_topups_cents'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const <int>[500, 1000, 2000],
    );

Map<String, dynamic> _$$TopupLimitsImplToJson(_$TopupLimitsImpl instance) =>
    <String, dynamic>{
      'topup_min_cents': instance.minCents,
      'topup_max_cents': instance.maxCents,
      'suggested_topups_cents': instance.suggestedCents,
    };

_$PatreonOfferImpl _$$PatreonOfferImplFromJson(Map<String, dynamic> json) =>
    _$PatreonOfferImpl(
      enabled: json['enabled'] as bool? ?? false,
      pledgeUrl: json['pledge_url'] as String?,
      recommendedCents: (json['recommended_cents'] as num?)?.toInt() ?? 200,
    );

Map<String, dynamic> _$$PatreonOfferImplToJson(_$PatreonOfferImpl instance) =>
    <String, dynamic>{
      'enabled': instance.enabled,
      'pledge_url': instance.pledgeUrl,
      'recommended_cents': instance.recommendedCents,
    };

_$PlusCatalogImpl _$$PlusCatalogImplFromJson(Map<String, dynamic> json) =>
    _$PlusCatalogImpl(
      purchasesEnabled: json['purchases_enabled'] as bool? ?? false,
      plans: (json['plans'] as List<dynamic>?)
              ?.map((e) => PlusPlan.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <PlusPlan>[],
      wallet: json['wallet'] == null
          ? const TopupLimits()
          : TopupLimits.fromJson(json['wallet'] as Map<String, dynamic>),
      patreon: json['patreon'] == null
          ? const PatreonOffer()
          : PatreonOffer.fromJson(json['patreon'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$PlusCatalogImplToJson(_$PlusCatalogImpl instance) =>
    <String, dynamic>{
      'purchases_enabled': instance.purchasesEnabled,
      'plans': instance.plans.map((e) => e.toJson()).toList(),
      'wallet': instance.wallet.toJson(),
      'patreon': instance.patreon.toJson(),
    };

_$PlusEntitlementImpl _$$PlusEntitlementImplFromJson(
        Map<String, dynamic> json) =>
    _$PlusEntitlementImpl(
      adFree: json['ad_free'] as bool? ?? false,
      startsAt: json['starts_at'] == null
          ? null
          : DateTime.parse(json['starts_at'] as String),
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      revision: (json['revision'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$PlusEntitlementImplToJson(
        _$PlusEntitlementImpl instance) =>
    <String, dynamic>{
      'ad_free': instance.adFree,
      'starts_at': instance.startsAt?.toIso8601String(),
      'expires_at': instance.expiresAt?.toIso8601String(),
      'revision': instance.revision,
    };

_$PlusDiscountImpl _$$PlusDiscountImplFromJson(Map<String, dynamic> json) =>
    _$PlusDiscountImpl(
      type: json['type'] as String,
      percentOff: (json['percent_off'] as num?)?.toInt(),
      amountOffCents: (json['amount_off_cents'] as num?)?.toInt(),
      periodsRemaining: (json['periods_remaining'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$PlusDiscountImplToJson(_$PlusDiscountImpl instance) =>
    <String, dynamic>{
      'type': instance.type,
      'percent_off': instance.percentOff,
      'amount_off_cents': instance.amountOffCents,
      'periods_remaining': instance.periodsRemaining,
    };

_$PlusRenewalImpl _$$PlusRenewalImplFromJson(Map<String, dynamic> json) =>
    _$PlusRenewalImpl(
      mode: json['mode'] as String?,
      autoRenew: json['auto_renew'] as bool? ?? false,
      nextChargeCents: (json['next_charge_cents'] as num?)?.toInt(),
      nextChargeAt: json['next_charge_at'] == null
          ? null
          : DateTime.parse(json['next_charge_at'] as String),
      lapsedAt: json['lapsed_at'] == null
          ? null
          : DateTime.parse(json['lapsed_at'] as String),
      cancelledAt: json['cancelled_at'] == null
          ? null
          : DateTime.parse(json['cancelled_at'] as String),
      amountCents: (json['amount_cents'] as num?)?.toInt() ?? 200,
      intervalDays: (json['interval_days'] as num?)?.toInt() ?? 31,
      termsVersion: json['terms_version'] as String?,
      currentTermsVersion: json['current_terms_version'] as String?,
      termsOutdated: json['terms_outdated'] as bool? ?? false,
      discount: json['discount'] == null
          ? null
          : PlusDiscount.fromJson(json['discount'] as Map<String, dynamic>),
      lastErrorCode: json['last_error_code'] as String?,
    );

Map<String, dynamic> _$$PlusRenewalImplToJson(_$PlusRenewalImpl instance) =>
    <String, dynamic>{
      'mode': instance.mode,
      'auto_renew': instance.autoRenew,
      'next_charge_cents': instance.nextChargeCents,
      'next_charge_at': instance.nextChargeAt?.toIso8601String(),
      'lapsed_at': instance.lapsedAt?.toIso8601String(),
      'cancelled_at': instance.cancelledAt?.toIso8601String(),
      'amount_cents': instance.amountCents,
      'interval_days': instance.intervalDays,
      'terms_version': instance.termsVersion,
      'current_terms_version': instance.currentTermsVersion,
      'terms_outdated': instance.termsOutdated,
      'discount': instance.discount?.toJson(),
      'last_error_code': instance.lastErrorCode,
    };

_$WalletBalanceImpl _$$WalletBalanceImplFromJson(Map<String, dynamic> json) =>
    _$WalletBalanceImpl(
      id: _id(json['id']),
      currency: json['currency'] as String? ?? 'USD',
      balanceCents: (json['balance_cents'] as num?)?.toInt() ?? 0,
      spendableCents: (json['spendable_cents'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'active',
      frozen: json['frozen'] as bool? ?? false,
      revision: (json['revision'] as num?)?.toInt() ?? 0,
      periodsFundable: (json['periods_fundable'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$WalletBalanceImplToJson(_$WalletBalanceImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'currency': instance.currency,
      'balance_cents': instance.balanceCents,
      'spendable_cents': instance.spendableCents,
      'status': instance.status,
      'frozen': instance.frozen,
      'revision': instance.revision,
      'periods_fundable': instance.periodsFundable,
    };

_$PayCoinImpl _$$PayCoinImplFromJson(Map<String, dynamic> json) =>
    _$PayCoinImpl(
      code: json['code'] as String,
      ticker: json['ticker'] as String,
      name: json['name'] as String,
      network: json['network'] as String? ?? '',
      networkLabel: json['network_label'] as String? ?? '',
      logoUrl: json['logo_url'] as String?,
      extraId: json['extra_id'] as String?,
      popular: json['popular'] as bool? ?? false,
    );

Map<String, dynamic> _$$PayCoinImplToJson(_$PayCoinImpl instance) =>
    <String, dynamic>{
      'code': instance.code,
      'ticker': instance.ticker,
      'name': instance.name,
      'network': instance.network,
      'network_label': instance.networkLabel,
      'logo_url': instance.logoUrl,
      'extra_id': instance.extraId,
      'popular': instance.popular,
    };

_$TopupPaymentImpl _$$TopupPaymentImplFromJson(Map<String, dynamic> json) =>
    _$TopupPaymentImpl(
      id: _id(json['id']),
      status: json['status'] as String,
      coin: PayCoin.fromJson(json['coin'] as Map<String, dynamic>),
      amount: json['amount'] as String?,
      paid: json['paid'] as String?,
      remaining: json['remaining'] as String?,
      address: json['address'] as String?,
      extraId: json['extra_id'] as String?,
      uri: json['uri'] as String?,
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$$TopupPaymentImplToJson(_$TopupPaymentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'status': instance.status,
      'coin': instance.coin.toJson(),
      'amount': instance.amount,
      'paid': instance.paid,
      'remaining': instance.remaining,
      'address': instance.address,
      'extra_id': instance.extraId,
      'uri': instance.uri,
      'expires_at': instance.expiresAt?.toIso8601String(),
      'created_at': instance.createdAt?.toIso8601String(),
    };

_$WalletTopupImpl _$$WalletTopupImplFromJson(Map<String, dynamic> json) =>
    _$WalletTopupImpl(
      id: json['id'] as String,
      status: json['status'] as String,
      provider: json['provider'] as String? ?? 'nowpayments',
      amountCents: (json['amount_cents'] as num).toInt(),
      creditedCents: (json['credited_cents'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      activatePlus: json['activate_plus'] as bool? ?? false,
      nextAction: json['next_action'] as String? ?? 'none',
      checkoutUrl: json['checkout_url'] as String?,
      checkoutStep: json['checkout_step'] as String?,
      payment: json['payment'] == null
          ? null
          : TopupPayment.fromJson(json['payment'] as Map<String, dynamic>),
      payCurrency: json['pay_currency'] as String?,
      errorCode: json['error_code'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      creditedAt: json['credited_at'] == null
          ? null
          : DateTime.parse(json['credited_at'] as String),
    );

Map<String, dynamic> _$$WalletTopupImplToJson(_$WalletTopupImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'status': instance.status,
      'provider': instance.provider,
      'amount_cents': instance.amountCents,
      'credited_cents': instance.creditedCents,
      'currency': instance.currency,
      'activate_plus': instance.activatePlus,
      'next_action': instance.nextAction,
      'checkout_url': instance.checkoutUrl,
      'checkout_step': instance.checkoutStep,
      'payment': instance.payment?.toJson(),
      'pay_currency': instance.payCurrency,
      'error_code': instance.errorCode,
      'created_at': instance.createdAt?.toIso8601String(),
      'credited_at': instance.creditedAt?.toIso8601String(),
    };

_$WalletTransactionImpl _$$WalletTransactionImplFromJson(
        Map<String, dynamic> json) =>
    _$WalletTransactionImpl(
      id: _id(json['id']),
      type: json['type'] as String,
      amountCents: (json['amount_cents'] as num).toInt(),
      balanceAfterCents: (json['balance_after_cents'] as num?)?.toInt(),
      reference: _id(json['reference']),
      source: json['source'] as String?,
      periodStartsAt: json['period_starts_at'] == null
          ? null
          : DateTime.parse(json['period_starts_at'] as String),
      periodEndsAt: json['period_ends_at'] == null
          ? null
          : DateTime.parse(json['period_ends_at'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$$WalletTransactionImplToJson(
        _$WalletTransactionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'amount_cents': instance.amountCents,
      'balance_after_cents': instance.balanceAfterCents,
      'reference': instance.reference,
      'source': instance.source,
      'period_starts_at': instance.periodStartsAt?.toIso8601String(),
      'period_ends_at': instance.periodEndsAt?.toIso8601String(),
      'created_at': instance.createdAt?.toIso8601String(),
    };

_$PatreonLinkImpl _$$PatreonLinkImplFromJson(Map<String, dynamic> json) =>
    _$PatreonLinkImpl(
      id: json['id'] as String,
      status: json['status'] as String,
      errorCode: json['error_code'] as String?,
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      url: json['url'] as String?,
    );

Map<String, dynamic> _$$PatreonLinkImplToJson(_$PatreonLinkImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'status': instance.status,
      'error_code': instance.errorCode,
      'expires_at': instance.expiresAt?.toIso8601String(),
      'completed_at': instance.completedAt?.toIso8601String(),
      'url': instance.url,
    };

_$PatreonMembershipImpl _$$PatreonMembershipImplFromJson(
        Map<String, dynamic> json) =>
    _$PatreonMembershipImpl(
      enabled: json['enabled'] as bool? ?? false,
      pledgeUrl: json['pledge_url'] as String?,
      linked: json['linked'] as bool? ?? false,
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
      patronStatus: json['patron_status'] as String?,
      activePatron: json['active_patron'] as bool? ?? false,
      pledgeCents: (json['pledge_cents'] as num?)?.toInt() ?? 0,
      willPayCents: (json['will_pay_cents'] as num?)?.toInt() ?? 0,
      cadenceMonths: (json['pledge_cadence_months'] as num?)?.toInt(),
      coversPlus: json['covers_plus'] as bool? ?? false,
      lastChargeAt: json['last_charge_at'] == null
          ? null
          : DateTime.parse(json['last_charge_at'] as String),
      lastChargeStatus: json['last_charge_status'] as String?,
      nextChargeAt: json['next_charge_at'] == null
          ? null
          : DateTime.parse(json['next_charge_at'] as String),
      freeTrial: json['free_trial'] as bool? ?? false,
      creditedCents: (json['credited_cents'] as num?)?.toInt() ?? 0,
      plusPending: json['plus_pending'] as bool? ?? false,
      needsReauthorization: json['needs_reauthorization'] as bool? ?? false,
      linkedAt: json['linked_at'] == null
          ? null
          : DateTime.parse(json['linked_at'] as String),
      lastSyncedAt: json['last_synced_at'] == null
          ? null
          : DateTime.parse(json['last_synced_at'] as String),
      lastErrorCode: json['last_error_code'] as String?,
      link: json['link'] == null
          ? null
          : PatreonLink.fromJson(json['link'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$PatreonMembershipImplToJson(
        _$PatreonMembershipImpl instance) =>
    <String, dynamic>{
      'enabled': instance.enabled,
      'pledge_url': instance.pledgeUrl,
      'linked': instance.linked,
      'full_name': instance.fullName,
      'email': instance.email,
      'patron_status': instance.patronStatus,
      'active_patron': instance.activePatron,
      'pledge_cents': instance.pledgeCents,
      'will_pay_cents': instance.willPayCents,
      'pledge_cadence_months': instance.cadenceMonths,
      'covers_plus': instance.coversPlus,
      'last_charge_at': instance.lastChargeAt?.toIso8601String(),
      'last_charge_status': instance.lastChargeStatus,
      'next_charge_at': instance.nextChargeAt?.toIso8601String(),
      'free_trial': instance.freeTrial,
      'credited_cents': instance.creditedCents,
      'plus_pending': instance.plusPending,
      'needs_reauthorization': instance.needsReauthorization,
      'linked_at': instance.linkedAt?.toIso8601String(),
      'last_synced_at': instance.lastSyncedAt?.toIso8601String(),
      'last_error_code': instance.lastErrorCode,
      'link': instance.link?.toJson(),
    };

_$PlusAccountImpl _$$PlusAccountImplFromJson(Map<String, dynamic> json) =>
    _$PlusAccountImpl(
      entitlements: json['entitlements'] == null
          ? const PlusEntitlement()
          : PlusEntitlement.fromJson(
              json['entitlements'] as Map<String, dynamic>),
      serverTime: json['server_time'] == null
          ? null
          : DateTime.parse(json['server_time'] as String),
      refreshAfterSeconds:
          (json['refresh_after_seconds'] as num?)?.toInt() ?? 300,
      renewal: json['subscription'] == null
          ? null
          : PlusRenewal.fromJson(json['subscription'] as Map<String, dynamic>),
      wallet: json['wallet'] == null
          ? null
          : WalletBalance.fromJson(json['wallet'] as Map<String, dynamic>),
      pendingTopups: (json['pending_topups'] as List<dynamic>?)
              ?.map((e) => WalletTopup.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <WalletTopup>[],
      patreon: json['patreon'] == null
          ? null
          : PatreonMembership.fromJson(json['patreon'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$PlusAccountImplToJson(_$PlusAccountImpl instance) =>
    <String, dynamic>{
      'entitlements': instance.entitlements.toJson(),
      'server_time': instance.serverTime?.toIso8601String(),
      'refresh_after_seconds': instance.refreshAfterSeconds,
      'subscription': instance.renewal?.toJson(),
      'wallet': instance.wallet?.toJson(),
      'pending_topups': instance.pendingTopups.map((e) => e.toJson()).toList(),
      'patreon': instance.patreon?.toJson(),
    };

_$CouponRedemptionImpl _$$CouponRedemptionImplFromJson(
        Map<String, dynamic> json) =>
    _$CouponRedemptionImpl(
      type: json['type'] as String,
      freeDays: (json['free_days'] as num?)?.toInt(),
      percentOff: (json['percent_off'] as num?)?.toInt(),
      amountOffCents: (json['amount_off_cents'] as num?)?.toInt(),
      discountPeriods: (json['discount_periods'] as num?)?.toInt(),
      summary: json['summary'] as String?,
    );

Map<String, dynamic> _$$CouponRedemptionImplToJson(
        _$CouponRedemptionImpl instance) =>
    <String, dynamic>{
      'type': instance.type,
      'free_days': instance.freeDays,
      'percent_off': instance.percentOff,
      'amount_off_cents': instance.amountOffCents,
      'discount_periods': instance.discountPeriods,
      'summary': instance.summary,
    };
