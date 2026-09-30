import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../design/app_tokens.dart';

/// The frame around a full-screen image: black edge to edge in every theme,
/// with a back button, the title and a download button floating over the
/// top in the player's black glass, and an optional [footer] (a counter)
/// over the bottom.
class ImageViewerChrome extends StatelessWidget {
  const ImageViewerChrome({
    required this.title,
    required this.onDownload,
    required this.downloadLabel,
    required this.child,
    this.footer,
    super.key,
  });

  final String title;
  final VoidCallback onDownload;
  final String downloadLabel;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            child,
            // A light scrim so the bar reads over bright images.
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 140,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x99000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
            ),
            // Pinned to the top: the stack is StackFit.expand, so an
            // unpositioned bar would stretch to full height and centre.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.md,
                    vertical: AppSpace.sm,
                  ),
                  child: Row(
                    children: [
                      BetterPlayerControlButton(
                        icon: PhosphorIcons.arrowLeft(),
                        label:
                            MaterialLocalizations.of(context).backButtonTooltip,
                        onPressed: () => Navigator.maybePop(context),
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: AppType.semiBold,
                            fontSize: 16,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 8),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpace.md),
                      BetterPlayerControlButton(
                        icon: PhosphorIcons.downloadSimple(),
                        label: downloadLabel,
                        onPressed: onDownload,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (footer != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.xl),
                    child: Center(child: footer),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "3 / 12", in a black-glass pill.
class ImageViewerCounter extends StatelessWidget {
  const ImageViewerCounter({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: BetterPlayerColors.idle,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: AppType.semiBold,
            fontSize: 14,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
