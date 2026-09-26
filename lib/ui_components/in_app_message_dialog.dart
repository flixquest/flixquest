import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/in_app_message_payload.dart';
import 'app_ui_components.dart';

class InAppMessageDialog extends StatelessWidget {
  final InAppMessagePayload payload;

  const InAppMessageDialog({
    super.key,
    required this.payload,
  });

  static Future<void> show(
      BuildContext context, InAppMessagePayload payload) async {
    switch (payload.displayType) {
      case 'bottom_sheet':
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => _InAppBottomSheetWidget(payload: payload),
        );
        break;
      case 'banner':
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
        ScaffoldMessenger.of(context).showMaterialBanner(
          MaterialBanner(
            elevation: 8,
            backgroundColor: Colors.transparent,
            forceActionsBelow: false,
            padding: EdgeInsets.zero,
            content: _InAppBannerWidget(payload: payload),
            actions: const [SizedBox.shrink()],
          ),
        );
        break;
      case 'modal':
      default:
        await showDialog(
          context: context,
          barrierDismissible: true,
          barrierColor: Colors.black.withValues(alpha: 0.75),
          builder: (context) => InAppMessageDialog(payload: payload),
        );
        break;
    }
  }

  Future<void> _handleAction(BuildContext context) async {
    Navigator.of(context).pop();
    if (payload.actionUrl != null && payload.actionUrl!.isNotEmpty) {
      final uri = Uri.parse(payload.actionUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1F1E) : Colors.white;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Image with Gradient & Close Button
              if (payload.imageUrl != null && payload.imageUrl!.isNotEmpty)
                Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: payload.imageUrl!,
                      height: 190,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const AppCachedImagePlaceholder(),
                      errorWidget: (context, url, error) =>
                          const SizedBox.shrink(),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              cardBg.withValues(alpha: 0.7),
                              cardBg,
                            ],
                            stops: const [0.3, 0.8, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            PhosphorIcons.x(PhosphorIconsStyle.bold),
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12, right: 12),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        PhosphorIcons.x(PhosphorIconsStyle.bold),
                        size: 20,
                        color: theme.iconTheme.color?.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),

              // Content Section
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
                            size: 14,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'NOTIFICATION',
                            style: TextStyle(
                              fontFamily: 'FigtreeSB',
                              fontSize: 11,
                              color: primaryColor,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Title
                    Text(
                      payload.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: 'FigtreeSB',
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                      ),
                    ),

                    // Body
                    if (payload.body.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        payload.body,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'Figtree',
                          fontSize: 14,
                          color: theme.textTheme.bodyMedium?.color
                              ?.withValues(alpha: 0.85),
                          height: 1.45,
                        ),
                      ),
                    ],

                    const SizedBox(height: 22),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              side: BorderSide(
                                color:
                                    theme.dividerColor.withValues(alpha: 0.3),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Dismiss',
                              style: TextStyle(
                                fontFamily: 'FigtreeSB',
                                fontSize: 14,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                        ),
                        if (payload.actionUrl != null &&
                            payload.actionUrl!.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _handleAction(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    payload.buttonText ?? 'View Now',
                                    style: const TextStyle(
                                      fontFamily: 'FigtreeSB',
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    PhosphorIcons.arrowSquareOut(
                                        PhosphorIconsStyle.bold),
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InAppBottomSheetWidget extends StatelessWidget {
  final InAppMessagePayload payload;

  const _InAppBottomSheetWidget({required this.payload});

  Future<void> _handleAction(BuildContext context) async {
    Navigator.of(context).pop();
    if (payload.actionUrl != null && payload.actionUrl!.isNotEmpty) {
      final uri = Uri.parse(payload.actionUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1F1E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        border: Border(
          top: BorderSide(
            color: primaryColor.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 30,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: 20 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Optional Image
          if (payload.imageUrl != null && payload.imageUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: CachedNetworkImage(
                imageUrl: payload.imageUrl!,
                height: 170,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => const AppCachedImagePlaceholder(),
                errorWidget: (context, url, error) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Title
          Text(
            payload.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: 'FigtreeSB',
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),

          // Body
          if (payload.body.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              payload.body,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'Figtree',
                fontSize: 14,
                color:
                    theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.85),
                height: 1.4,
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      fontFamily: 'FigtreeSB',
                      fontSize: 14,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
              ),
              if (payload.actionUrl != null &&
                  payload.actionUrl!.isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleAction(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          payload.buttonText ?? 'Check It Out',
                          style: const TextStyle(
                            fontFamily: 'FigtreeSB',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _InAppBannerWidget extends StatelessWidget {
  final InAppMessagePayload payload;

  const _InAppBannerWidget({required this.payload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF242524) : Colors.white;

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Thumbnail or Icon
            if (payload.imageUrl != null && payload.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: CachedNetworkImage(
                  imageUrl: payload.imageUrl!,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const AppCachedImagePlaceholder(),
                  errorWidget: (context, url, error) =>
                      _buildDefaultIcon(primaryColor),
                ),
              )
            else
              _buildDefaultIcon(primaryColor),

            const SizedBox(width: 12),

            // Title & Body
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    payload.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontFamily: 'FigtreeSB',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (payload.body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      payload.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'Figtree',
                        fontSize: 12.5,
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Action or Close
            if (payload.actionUrl != null && payload.actionUrl!.isNotEmpty)
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: primaryColor.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                  final uri = Uri.parse(payload.actionUrl!);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: Icon(
                  PhosphorIcons.arrowSquareOut(PhosphorIconsStyle.bold),
                  color: primaryColor,
                  size: 20,
                ),
              )
            else
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                },
                icon: Icon(
                  PhosphorIcons.x(PhosphorIconsStyle.bold),
                  size: 18,
                  color: theme.iconTheme.color?.withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultIcon(Color primaryColor) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        PhosphorIcons.megaphone(PhosphorIconsStyle.fill),
        color: primaryColor,
        size: 22,
      ),
    );
  }
}
