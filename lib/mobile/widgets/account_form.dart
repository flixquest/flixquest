import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../widgets/app_logo.dart';
import 'page_kit.dart';
import 'pill_button.dart';

/// An account page (sign in, sign up, change a password…): the logo or an
/// icon, a heading and a line under it, then the fields and one main button
/// that shows it's working, instead of the page turning into a spinner.
class AccountFormPage extends StatelessWidget {
  const AccountFormPage({
    required this.title,
    required this.children,
    this.heading,
    this.message,
    this.icon,
    this.logo = false,
    this.onLogoDoubleTap,
    super.key,
  });

  /// The bar's title.
  final String title;
  final String? heading;
  final String? message;

  /// A mark for what the page does, in a soft circle; the app's logo when
  /// [logo] is set instead.
  final IconData? icon;
  final bool logo;
  final VoidCallback? onLogoDoubleTap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final icon = this.icon;
    final heading = this.heading;
    final message = this.message;
    return Scaffold(
      backgroundColor: palette.page,
      appBar: PageAppBar(title: title),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            gutter,
            AppSpace.sm,
            gutter,
            AppSpace.xxxl + MediaQuery.paddingOf(context).bottom,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (logo)
                  Center(
                    child: GestureDetector(
                      onDoubleTap: onLogoDoubleTap,
                      child: const Hero(
                        tag: 'logo_shadow',
                        child: SizedBox.square(
                          dimension: 84,
                          child: AppLogo(),
                        ),
                      ),
                    ),
                  )
                else if (icon != null)
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: palette.idleFill,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 28, color: palette.foreground),
                    ),
                  ),
                if (heading != null) ...<Widget>[
                  const SizedBox(height: AppSpace.lg),
                  Text(
                    heading,
                    textAlign: TextAlign.center,
                    style: AppType.scaled(context, AppType.pageTitle)
                        .copyWith(color: palette.foreground),
                  ),
                ],
                if (message != null) ...<Widget>[
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: AppType.body.copyWith(color: palette.mutedText),
                  ),
                ],
                const SizedBox(height: AppSpace.xxl),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The page's one main action, full width: its label stays, and a small
/// spinner takes the icon's place while it runs.
class AccountSubmitButton extends StatelessWidget {
  const AccountSubmitButton({
    required this.label,
    required this.busy,
    required this.onPressed,
    this.icon,
    this.destructive = false,
    super.key,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpace.md),
        child: SizedBox(
          width: double.infinity,
          child: PillButton(
            primary: true,
            destructive: destructive,
            height: 50,
            busy: busy,
            icon: icon,
            label: label,
            onPressed: onPressed,
          ),
        ),
      );
}

/// Space under one field before the next.
class AccountFieldGap extends StatelessWidget {
  const AccountFieldGap({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(height: AppSpace.md);
}

/// "or", between two ways of doing the same thing.
class AccountOrDivider extends StatelessWidget {
  const AccountOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
      child: Row(
        children: <Widget>[
          Expanded(child: Divider(color: palette.hairline, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              tr('or'),
              style: AppType.metadata.copyWith(color: palette.mutedText),
            ),
          ),
          Expanded(child: Divider(color: palette.hairline, height: 1)),
        ],
      ),
    );
  }
}

/// A quiet link under the form: Forgot password.
class AccountLink extends StatelessWidget {
  const AccountLink({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.sm),
      child: Center(
        child: TextButton(
          style: TextButton.styleFrom(foregroundColor: palette.mutedText),
          onPressed: onPressed,
          child: Text(
            label,
            style: AppType.cardTitle.copyWith(
              fontSize: 14,
              color: palette.mutedText,
            ),
          ),
        ),
      ),
    );
  }
}
