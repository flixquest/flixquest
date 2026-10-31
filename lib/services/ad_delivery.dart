/// What a popup's request to its network's own host showed.
enum AdDelivery {
  /// The host answered: an ad, its redirect, an HTTP error or a no-ad page.
  /// A network with nothing to serve is not an ad blocker.
  reached,

  /// The request failed the way blockers make it fail, whatever the blocker:
  /// no address, a refused or reset connection, a block page answering with
  /// another site's certificate, or a WebView content filter.
  blocked,
}

/// Chromium's net errors that blockers cause. Timeouts, offline errors and
/// untrusted certificate authorities (old devices) are left out: a slow or
/// outdated device produces them too.
const _blockingErrors = {
  'ERR_NAME_NOT_RESOLVED',
  'ERR_NAME_RESOLUTION_FAILED',
  'ERR_ADDRESS_INVALID',
  'ERR_ADDRESS_UNREACHABLE',
  'ERR_CONNECTION_REFUSED',
  'ERR_CONNECTION_RESET',
  'ERR_CONNECTION_CLOSED',
  'ERR_BLOCKED_BY_CLIENT',
  'ERR_BLOCKED_BY_ADMINISTRATOR',
  'ERR_CERT_COMMON_NAME_INVALID',
  'ERR_SSL_PROTOCOL_ERROR',
};

/// Whether a WebView load error, such as `net::ERR_NAME_NOT_RESOLVED`, is
/// one a blocker causes.
bool isBlockingLoadError(String description) {
  final code = RegExp(r'ERR_[A-Z_]+').firstMatch(description)?.group(0);
  return code != null && _blockingErrors.contains(code);
}
