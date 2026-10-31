import 'auth_session.dart';

/// A code the TV shows, as text and as a QR link, so a phone can sign it in.
/// [deviceCode] stays on the TV: only it redeems the phone's approval.
class TvSignInCode {
  const TvSignInCode({
    required this.deviceCode,
    required this.userCode,
    required this.url,
    required this.completeUrl,
    required this.expiresAt,
    required this.interval,
  });

  factory TvSignInCode.fromJson(Map<String, dynamic> json) {
    final deviceCode = json['device_code'];
    final userCode = json['user_code'];
    final url = Uri.tryParse(json['verification_url'] as String? ?? '');
    final completeUrl =
        Uri.tryParse(json['verification_url_complete'] as String? ?? '');
    final expiresAt = DateTime.tryParse(json['expires_at'] as String? ?? '');
    if (deviceCode is! String ||
        deviceCode.isEmpty ||
        userCode is! String ||
        userCode.isEmpty ||
        url == null ||
        completeUrl == null ||
        expiresAt == null) {
      throw const FormatException('Invalid TV sign-in code');
    }
    final interval = json['interval'];
    return TvSignInCode(
      deviceCode: deviceCode,
      userCode: userCode,
      url: url,
      completeUrl: completeUrl,
      expiresAt: expiresAt,
      interval:
          Duration(seconds: interval is int && interval > 0 ? interval : 5),
    );
  }

  final String deviceCode;

  /// As the TV shows it: BCDF-GHJK.
  final String userCode;

  /// Where the code is typed, for phones that can't scan.
  final Uri url;

  /// The QR code's link, with the code filled in.
  final Uri completeUrl;
  final DateTime expiresAt;

  /// How long the TV waits between checks.
  final Duration interval;
}

enum TvSignInStatus { pending, approved, denied, expired }

/// One check on a [TvSignInCode]; [session] once the phone has approved it.
class TvSignInCheck {
  const TvSignInCheck(this.status, [this.session]);

  final TvSignInStatus status;
  final AuthSession? session;
}
