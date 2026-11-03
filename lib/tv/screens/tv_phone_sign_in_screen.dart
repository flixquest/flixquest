import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/error/failure.dart';
import '../../data/models/tv_sign_in.dart';
import '../../provider/settings_provider.dart';
import '../../services/auth_navigation_service.dart';
import '../../services/flixquest_auth_service.dart';
import '../app/tv_design.dart';
import '../widgets/tv_device_limit_picker.dart';
import '../widgets/tv_pill_button.dart';
import 'tv_auth_screen.dart';

/// Signing the TV in from a phone, the way YouTube's TV app does: the QR code
/// opens FlixQuest's sign-in page on the phone, where the viewer signs in,
/// signs up or continues with Google, and this screen signs in by itself once
/// the phone approves. Nothing is typed with the remote.
///
/// The screen checks back every few seconds and takes a new code whenever
/// one expires or is turned down on the phone.
class TvPhoneSignInScreen extends StatefulWidget {
  const TvPhoneSignInScreen({super.key});

  @override
  State<TvPhoneSignInScreen> createState() => _TvPhoneSignInScreenState();
}

class _TvPhoneSignInScreenState extends State<TvPhoneSignInScreen> {
  final _authService = FlixQuestAuthService();
  TvSignInCode? _code;
  String? _problem;
  String? _notice;
  bool _signingIn = false;

  /// Bumped for each code and on dispose, so a superseded wait stops.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _newCode();
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _newCode({String? notice}) async {
    final generation = ++_generation;
    setState(() {
      _code = null;
      _problem = null;
      _notice = notice;
    });
    try {
      final code = await _authService.startTvSignIn();
      if (!mounted || generation != _generation) return;
      setState(() => _code = code);
      unawaited(_waitForPhone(code, generation));
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _problem = tr('tv_phone_sign_in_failed'));
      }
    }
  }

  /// Checks one at a time, so the device-limit picker holds the next check.
  Future<void> _waitForPhone(TvSignInCode code, int generation) async {
    bool current() => mounted && generation == _generation;
    while (true) {
      await Future<void>.delayed(code.interval);
      if (!current()) return;
      TvSignInCheck? check;
      try {
        check = await _authService.withinDeviceLimit(
          (replaceDeviceId) => _authService.checkTvSignIn(
            code.deviceCode,
            replaceDeviceId: replaceDeviceId,
          ),
          pick: _pickDeviceToSignOut,
        );
      } catch (_) {
        // Outages pass; an expired code says so once the server is back.
        continue;
      }
      if (!current()) return;
      switch (check?.status) {
        case TvSignInStatus.pending:
          continue;
        case TvSignInStatus.approved:
          return _finish(check!);
        case TvSignInStatus.denied:
          return _newCode(notice: tr('tv_phone_sign_in_denied'));
        // Expired, or the device picker was backed out of.
        case TvSignInStatus.expired || null:
          return _newCode();
      }
    }
  }

  Future<void> _finish(TvSignInCheck check) async {
    setState(() => _signingIn = true);
    context.read<SettingsProvider>().analytics.trackLogin('phone');
    await AuthNavigationService.returnToAppRoot(
      context,
      authenticatedUserId: check.session!.user.id.toString(),
    );
  }

  Future<int?> _pickDeviceToSignOut(DeviceLimitFailure limit) async =>
      mounted ? showTvDeviceLimitPicker(context, limit) : null;

  void _useRemote() {
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(builder: (_) => const TvAuthScreen.signIn()),
    );
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final palette = TvPalette.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: TvDesign.surfaceFor(context),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.9, -1),
            radius: 1.4,
            colors: <Color>[
              accent.withValues(alpha: palette.dark ? 0.16 : 0.08),
              palette.page.withValues(alpha: 0),
            ],
          ),
        ),
        child: SafeArea(
          minimum: const EdgeInsets.symmetric(horizontal: 48, vertical: 28),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 650;
              final qrSize = (constraints.maxHeight * 0.66).clamp(200.0, 380.0);
              return Row(
                children: <Widget>[
                  Expanded(child: _instructions(context, compact)),
                  SizedBox(width: compact ? 32 : 56),
                  _qr(context, qrSize),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _instructions(BuildContext context, bool compact) {
    final palette = TvPalette.of(context);
    final code = _code;
    final body = TextStyle(
      color: palette.mutedText,
      fontSize: compact ? 15 : 18,
      height: 1.35,
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          tr('tv_phone_sign_in'),
          style: TextStyle(
            color: palette.foreground,
            fontFamily: 'FigtreeBold',
            fontSize: compact ? 28 : 36,
            letterSpacing: -0.45,
            height: 1.1,
          ),
        ),
        SizedBox(height: compact ? 16 : 24),
        for (final (index, key) in const <String>[
          'tv_phone_sign_in_step1',
          'tv_phone_sign_in_step2',
          'tv_phone_sign_in_step3',
        ].indexed)
          Padding(
            padding: EdgeInsets.only(bottom: compact ? 10 : 14),
            child: Row(
              children: <Widget>[
                Container(
                  width: compact ? 26 : 30,
                  height: compact ? 26 : 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.idleFill,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: palette.foreground,
                      fontFamily: 'FigtreeSB',
                      fontSize: compact ? 13 : 15,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tr(key),
                    style: TextStyle(
                      color: palette.foreground,
                      fontFamily: 'FigtreeSB',
                      fontSize: compact ? 16 : 19,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(height: compact ? 8 : 14),
        if (code != null) ...<Widget>[
          Text(
            tr(
              'tv_phone_sign_in_or_visit',
              args: <String>['${code.url.host}${code.url.path}'],
            ),
            style: body,
          ),
          const SizedBox(height: 4),
          Text(
            code.userCode,
            style: TextStyle(
              color: palette.foreground,
              fontFamily: 'FigtreeBold',
              fontSize: compact ? 30 : 38,
              letterSpacing: 4,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr('tv_phone_sign_in_renews'),
            style: body.copyWith(fontSize: compact ? 13 : 15),
          ),
        ],
        if (_notice != null) ...<Widget>[
          SizedBox(height: compact ? 10 : 14),
          Text(
            _notice!,
            style: body.copyWith(
              color: palette.foreground,
              fontFamily: 'FigtreeSB',
            ),
          ),
        ],
        SizedBox(height: compact ? 18 : 26),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            TvPillButton(
              label: tr('tv_phone_sign_in_use_remote'),
              icon: PhosphorIcons.keyboard(),
              autofocus: true,
              enabled: !_signingIn,
              height: compact ? 46 : 52,
              onActivate: _useRemote,
            ),
            TvPillButton(
              label: tr('tv_phone_sign_in_new_code'),
              icon: PhosphorIcons.arrowsClockwise(),
              enabled: !_signingIn && (_code != null || _problem != null),
              height: compact ? 46 : 52,
              onActivate: _newCode,
            ),
          ],
        ),
      ],
    );
  }

  Widget _qr(BuildContext context, double size) {
    final code = _code;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(TvDesign.cardRadius * 2),
      ),
      child: _signingIn
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox.square(
                  dimension: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  tr('tv_phone_sign_in_signing_in'),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontFamily: 'FigtreeSB',
                    fontSize: 17,
                  ),
                ),
              ],
            )
          : code != null
              ? Semantics(
                  label: tr('tv_phone_sign_in_step1'),
                  image: true,
                  child: QrImageView(
                    data: code.completeUrl.toString(),
                    size: size,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.all(20),
                  ),
                )
              : _problem != null
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        _problem!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          height: 1.35,
                        ),
                      ),
                    )
                  : const SizedBox.square(
                      dimension: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.black45,
                      ),
                    ),
    );
  }
}
