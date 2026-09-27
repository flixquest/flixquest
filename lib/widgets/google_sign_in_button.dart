import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../mobile/widgets/pill_button.dart';

/// Continue with Google, as a soft pill the width of the form; it keeps its
/// label and shows a small spinner while the sign-in runs.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
    super.key,
  });

  final VoidCallback? onPressed;
  final bool loading;
  final bool enabled;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: PillButton(
          height: 50,
          busy: loading,
          icon: PhosphorIcons.googleLogo(),
          label: tr('continue_with_google'),
          onPressed: enabled ? onPressed : null,
        ),
      );
}
