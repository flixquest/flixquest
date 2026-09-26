import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../app/tv_design.dart';
import '../focus/tv_focusable.dart';

class TvStatePanel extends StatelessWidget {
  const TvStatePanel({
    required this.title,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  factory TvStatePanel.error({
    required VoidCallback onRetry,
    String message = 'Check your connection and try again.',
  }) {
    return TvStatePanel(
      title: 'Something went wrong',
      message: message,
      icon: PhosphorIcons.warningCircle(),
      actionLabel: 'Retry',
      onAction: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: colors.primary, size: 54),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: TvDesign.foreground,
                fontFamily: 'FigtreeBold',
                fontSize: 30,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 20,
                height: 1.35,
              ),
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: 26),
              TvFocusable(
                semanticLabel: actionLabel!,
                onActivate: onAction!,
                focusScale: 1.025,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        colors.primary,
                        Color.lerp(
                          colors.primary,
                          colors.primaryContainer,
                          0.3,
                        )!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        PhosphorIcons.arrowClockwise(),
                        color: colors.onPrimary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        actionLabel!,
                        style: TextStyle(
                          color: colors.onPrimary,
                          fontFamily: 'FigtreeSB',
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
