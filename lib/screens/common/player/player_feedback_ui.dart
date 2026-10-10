import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design/app_tokens.dart';
import 'player_sheet_ui.dart';

/// Progress feedback uses the app's snackbar surface and its matching ink.
SnackBar playerProgressSnackBar({
  required String message,
  Duration duration = const Duration(seconds: 30),
}) =>
    SnackBar(
      duration: duration,
      content: Row(
        children: [
          SizedBox.square(
            dimension: 20,
            child: Builder(
              builder: (context) => CircularProgressIndicator(
                strokeWidth: 2,
                color: DefaultTextStyle.of(context).style.color,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(message)),
        ],
      ),
    );

/// Actions over video use the same type, soft fill and corners as app buttons.
class PlayerActionButton extends StatelessWidget {
  const PlayerActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
    this.autofocus = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
        },
        child: FilledButton.icon(
          autofocus: autofocus,
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            textStyle: const WidgetStatePropertyAll(AppType.button),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.button),
              ),
            ),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              final active = states.contains(WidgetState.focused) ||
                  states.contains(WidgetState.pressed);
              return primary || active
                  ? const Color(0xF2FFFFFF)
                  : const Color(0x38FFFFFF);
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              final active = states.contains(WidgetState.focused) ||
                  states.contains(WidgetState.pressed);
              return primary || active ? Colors.black : Colors.white;
            }),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
        ),
      );
}

/// A compact recovery panel that also fits embedded portrait playback.
class PlayerErrorView extends StatelessWidget {
  const PlayerErrorView({
    required this.title,
    required this.message,
    required this.actions,
    this.icon = Icons.error_outline_rounded,
    this.onClose,
    this.closeLabel,
    super.key,
  });

  final String title;
  final String message;
  final List<Widget> actions;
  final IconData icon;
  final VoidCallback? onClose;
  final String? closeLabel;

  @override
  Widget build(BuildContext context) => PlayerTheme(
        onVideo: true,
        child: ColoredBox(
          color: Colors.black,
          child: LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxHeight < 280;
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(compact ? 12 : 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Container(
                    padding: EdgeInsets.all(compact ? 14 : 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161616),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(icon, size: 24, color: Colors.white70),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontFamily: AppType.semiBold,
                                  color: Colors.white,
                                  fontSize: 18,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            if (onClose != null) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: onClose,
                                tooltip: closeLabel ??
                                    MaterialLocalizations.of(context)
                                        .closeButtonTooltip,
                                icon: const Icon(Icons.close_rounded, size: 20),
                                style: IconButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  backgroundColor: Colors.white10,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppRadii.button),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          message,
                          style: const TextStyle(
                            fontFamily: AppType.regular,
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                        SizedBox(height: compact ? 12 : 18),
                        Wrap(spacing: 8, runSpacing: 8, children: actions),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      );
}
