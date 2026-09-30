import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/app_palette.dart';
import '../design/app_tokens.dart';
import '../mobile/widgets/page_kit.dart';
import '../models/in_app_message_payload.dart';
import 'app_ui_components.dart';

/// A message sent from the console: a modal, a bottom sheet or a banner, as
/// its payload asks. All three are in the app's palette: the artwork, a
/// small kicker (the one touch of the accent), the title and text, and ink
/// pills.
class InAppMessageDialog extends StatelessWidget {
  const InAppMessageDialog({super.key, required this.payload});

  final InAppMessagePayload payload;

  static Future<void> show(
    BuildContext context,
    InAppMessagePayload payload,
  ) async {
    switch (payload.displayType) {
      case 'bottom_sheet':
        await showAppSheet<void>(
          context,
          builder: (context) => _InAppBottomSheetWidget(payload: payload),
        );
        break;
      case 'banner':
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentMaterialBanner();
        messenger.showMaterialBanner(
          MaterialBanner(
            elevation: 0,
            backgroundColor: Colors.transparent,
            dividerColor: Colors.transparent,
            forceActionsBelow: false,
            padding: EdgeInsets.zero,
            content: _InAppBannerWidget(payload: payload),
            actions: const [SizedBox.shrink()],
          ),
        );
        break;
      case 'modal':
      default:
        await showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (context) => InAppMessageDialog(payload: payload),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Dialog(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.hero),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: _MessageContent(
            payload: payload,
            dismissLabel: tr('in_app_dismiss'),
            imageRadius: 0,
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xl,
              AppSpace.lg,
              AppSpace.xl,
              AppSpace.lg,
            ),
          ),
        ),
      ),
    );
  }
}

class _InAppBottomSheetWidget extends StatelessWidget {
  const _InAppBottomSheetWidget({required this.payload});

  final InAppMessagePayload payload;

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpace.gutter(context);
    return SingleChildScrollView(
      child: _MessageContent(
        payload: payload,
        dismissLabel: tr('close'),
        imageRadius: AppRadii.card,
        padding: EdgeInsets.fromLTRB(gutter, 0, gutter, AppSpace.xl),
      ),
    );
  }
}

/// The artwork, kicker, title, text and actions shared by the modal and the
/// sheet.
class _MessageContent extends StatelessWidget {
  const _MessageContent({
    required this.payload,
    required this.dismissLabel,
    required this.imageRadius,
    required this.padding,
  });

  final InAppMessagePayload payload;
  final String dismissLabel;
  final double imageRadius;
  final EdgeInsets padding;

  bool get _hasAction => payload.actionUrl?.isNotEmpty == true;

  Future<void> _act(BuildContext context) async {
    Navigator.of(context).pop();
    if (!_hasAction) return;
    await _openUrl(payload.actionUrl!);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final image = payload.imageUrl;
    final artwork = image == null || image.isEmpty
        ? null
        : AspectRatio(
            aspectRatio: 16 / 9,
            child: CachedNetworkImage(
              imageUrl: image,
              fit: BoxFit.cover,
              placeholder: (_, __) => const AppCachedImagePlaceholder(),
              errorWidget: (_, __, ___) => ColoredBox(
                color: palette.raisedSurface,
              ),
            ),
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (artwork != null)
          Padding(
            padding: imageRadius == 0
                ? EdgeInsets.zero
                : EdgeInsets.fromLTRB(padding.left, 0, padding.right, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(imageRadius),
              child: artwork,
            ),
          ),
        Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('in_app_kicker').toUpperCase(),
                style: AppType.kicker.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                payload.title,
                style: AppType.sectionHeader.copyWith(
                  fontFamily: AppType.bold,
                  fontSize: 20,
                  height: 1.25,
                  color: palette.foreground,
                ),
              ),
              if (payload.body.isNotEmpty) ...[
                const SizedBox(height: AppSpace.sm),
                Text(
                  payload.body,
                  style: AppType.body.copyWith(color: palette.secondaryText),
                ),
              ],
              const SizedBox(height: AppSpace.xl),
              if (_hasAction) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _act(context),
                    icon: Icon(PhosphorIcons.arrowSquareOut(), size: 18),
                    label: Text(payload.buttonText ?? tr('in_app_open')),
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
              ],
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(dismissLabel),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A slim card under the status bar: a thumbnail, the title and one line,
/// and an open or close button at the end.
class _InAppBannerWidget extends StatelessWidget {
  const _InAppBannerWidget({required this.payload});

  final InAppMessagePayload payload;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final hasAction = payload.actionUrl?.isNotEmpty == true;
    final image = payload.imageUrl;
    final messenger = ScaffoldMessenger.of(context);
    Widget placeholderIcon() => Icon(
          PhosphorIcons.bellSimple(),
          color: palette.mutedText,
          size: 22,
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.md,
        AppSpace.sm,
        AppSpace.md,
        AppSpace.sm,
      ),
      child: Material(
        color: palette.raisedSurface,
        borderRadius: BorderRadius.circular(AppRadii.hero),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: hasAction
              ? () async {
                  messenger.hideCurrentMaterialBanner();
                  await _openUrl(payload.actionUrl!);
                }
              : null,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpace.md,
              AppSpace.md,
              AppSpace.xs,
              AppSpace.md,
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  child: SizedBox.square(
                    dimension: 44,
                    child: ColoredBox(
                      color: palette.surface,
                      child: image == null || image.isEmpty
                          ? placeholderIcon()
                          : CachedNetworkImage(
                              imageUrl: image,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => placeholderIcon(),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        payload.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.cardTitle.copyWith(
                          fontSize: 15,
                          color: palette.foreground,
                        ),
                      ),
                      if (payload.body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          payload.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.metadata.copyWith(
                            fontSize: 13,
                            color: palette.mutedText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: hasAction
                      ? payload.buttonText ?? tr('in_app_open')
                      : tr('close'),
                  color: palette.foreground,
                  onPressed: () async {
                    messenger.hideCurrentMaterialBanner();
                    if (hasAction) await _openUrl(payload.actionUrl!);
                  },
                  icon: Icon(
                    hasAction
                        ? PhosphorIcons.arrowSquareOut()
                        : PhosphorIcons.x(),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null && await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
