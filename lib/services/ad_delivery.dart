/// What a popup's redirect chain showed before its ad appeared.
enum AdDelivery {
  /// The ad appeared, or the network answered with no ad (its no-ad page or
  /// an HTTP error). A network with nothing to serve is not an ad blocker.
  reached,

  /// A content filter stopped a hop: `ERR_BLOCKED_BY_CLIENT`, or a block page
  /// answering with another site's certificate. Counts once public DNS shows
  /// the host exists.
  blocked,

  /// A hop could not be reached: no address, or a refused or reset
  /// connection. Blocker DNS (a sinkhole or a missing name) does this, and so
  /// does an outage, so it counts only when the device's own DNS sinkholes
  /// the host or cannot resolve it while public DNS can.
  unreachable,
}

/// Chromium's net errors that only a filter produces.
const _filteredErrors = {
  'ERR_BLOCKED_BY_CLIENT',
  'ERR_BLOCKED_BY_ADMINISTRATOR',
  'ERR_CERT_COMMON_NAME_INVALID',
  'ERR_SSL_PROTOCOL_ERROR',
};

/// Chromium's net errors that a blocker's DNS causes, among other things.
/// Timeouts, offline errors and untrusted certificate authorities (old
/// devices) are left out: a slow or outdated device produces them too.
const _unreachableErrors = {
  'ERR_NAME_NOT_RESOLVED',
  'ERR_NAME_RESOLUTION_FAILED',
  'ERR_ADDRESS_INVALID',
  'ERR_ADDRESS_UNREACHABLE',
  'ERR_CONNECTION_REFUSED',
  'ERR_CONNECTION_RESET',
  'ERR_CONNECTION_CLOSED',
};

/// What a WebView load error, such as `net::ERR_NAME_NOT_RESOLVED`, says
/// about a blocker; null when it says nothing.
AdDelivery? deliveryForLoadError(String description) {
  final code = RegExp(r'ERR_[A-Z_]+').firstMatch(description)?.group(0);
  if (_filteredErrors.contains(code)) return AdDelivery.blocked;
  if (_unreachableErrors.contains(code)) return AdDelivery.unreachable;
  return null;
}
