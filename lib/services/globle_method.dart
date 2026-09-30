import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flixquest/models/custom_exceptions.dart';
import 'package:flutter/material.dart';

import '../design/app_palette.dart';
import '../design/app_tokens.dart';

class GlobalMethods {
  Future<void> authErrorHandle(String subtitle, BuildContext context) =>
      _showMessage(
        context,
        title: tr('error_occured'),
        message: subtitle,
        onOk: () => Navigator.pop(context),
      );

  /// A notice the user acknowledges before leaving the page it came from
  /// (a password-reset email that has been sent).
  Future<void> checkMessage(String subtitle, BuildContext context) =>
      _showMessage(
        context,
        message: subtitle,
        dismissible: false,
        onOk: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
      );

  /// A small dialog in the app's style: an optional title, the message in
  /// secondary text, and one ink OK pill.
  static Future<void> _showMessage(
    BuildContext context, {
    required String message,
    required VoidCallback onOk,
    String? title,
    bool dismissible = true,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: dismissible,
      builder: (dialogContext) {
        final palette = AppPalette.of(dialogContext);
        return Dialog(
          backgroundColor: palette.surface,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.hero),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xl,
                AppSpace.xl,
                AppSpace.xl,
                AppSpace.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(
                      title,
                      style: AppType.sectionHeader.copyWith(
                        fontFamily: AppType.bold,
                        color: palette.foreground,
                      ),
                    ),
                    const SizedBox(height: AppSpace.sm),
                  ],
                  Text(
                    message,
                    style: AppType.body.copyWith(color: palette.secondaryText),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onOk,
                      child: Text(tr('ok')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static void showErrorScaffoldMessengerMediaLoad(
      Exception error, BuildContext context, String server) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(milliseconds: 1500),
        content: Text(
          error is FormatException
              ? tr('internal_error')
              : error is TimeoutException
                  ? tr('timed_out')
                  : error is SocketException
                      ? tr('internet_problem')
                      : error is NotFoundException
                          ? tr('media_not_found', namedArgs: {'s': server})
                          : error is ServerDownException
                              ? tr('server_is_down', namedArgs: {'s': server})
                              : error is ChannelsNotFoundException
                                  ? tr('channels_fetch_failed')
                                  : tr('general_error',
                                      namedArgs: {'e': error.toString()}),
          style: const TextStyle(fontFamily: 'Figtree'),
        )));
  }

  static void showErrorScaffoldMessengerGeneral(
      Exception error, BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(milliseconds: 1500),
        content: Text(
          error is TimeoutException
              ? tr('timed_out')
              : error is SocketException
                  ? tr('internet_problem')
                  : tr('general_error', namedArgs: {'e': error.toString()}),
          style: const TextStyle(fontFamily: 'Figtree'),
        )));
  }

  static void showScaffoldMessage(String message, BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(milliseconds: 4000),
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Figtree'),
        )));
  }

  static void showCustomScaffoldMessage(
      SnackBar message, BuildContext? context) async {
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(message);
    }
  }
}
