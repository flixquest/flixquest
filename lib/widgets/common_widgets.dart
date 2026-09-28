import 'package:better_player_plus/better_player.dart';
import 'package:clipboard/clipboard.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';
import '../design/app_palette.dart';
import '../design/app_tokens.dart';
import '../mobile/widgets/page_kit.dart';
import '../screens/common/player/player_sheet_ui.dart';
import '../services/globle_method.dart';

class AppStreamingService {
  const AppStreamingService(this.imagePath, this.name, this.providerId);

  final String imagePath;
  final String name;
  final int providerId;
}

const appStreamingServices = <AppStreamingService>[
  AppStreamingService('assets/images/netflix.png', 'Netflix', 8),
  AppStreamingService('assets/images/amazon_prime.png', 'Prime Video', 9),
  AppStreamingService('assets/images/disney_plus.png', 'Disney+', 337),
  AppStreamingService('assets/images/hulu.png', 'Hulu', 15),
  AppStreamingService('assets/images/hbo_max.png', 'Max', 384),
  AppStreamingService('assets/images/apple_tv.png', 'Apple TV+', 350),
  AppStreamingService('assets/images/peacock.png', 'Peacock', 387),
  AppStreamingService('assets/images/itunes.png', 'iTunes', 2),
  AppStreamingService('assets/images/youtube.png', 'YouTube', 188),
  AppStreamingService('assets/images/paramount.png', 'Paramount+', 531),
  AppStreamingService('assets/images/netflix.png', 'Netflix Kids', 175),
];

/// Why a title can't play: a muted icon and the title, what went wrong in
/// plain text, then Retry (when the caller can try again) and the link to
/// report it, as ink pills. The app's version sits at the foot for reports.
class ReportErrorWidget extends StatelessWidget {
  const ReportErrorWidget({
    super.key,
    required this.error,
    required this.hideButton,
    this.title,
    this.icon,
    this.onRetry,
  });

  final String error;
  final bool hideButton;
  final String? title;
  final IconData? icon;

  /// Shown as the primary action when the caller can re-attempt the load.
  final VoidCallback? onRetry;

  /// Opens the sheet with the chrome the app's other bottom sheets use.
  static Future<void> show(
    BuildContext context, {
    required String error,
    String? title,
    IconData? icon,
    bool hideButton = false,
    VoidCallback? onRetry,
  }) {
    return showAppSheet<void>(
      context,
      builder: (_) => ReportErrorWidget(
        error: error,
        hideButton: hideButton,
        title: title,
        icon: icon,
        onRetry: onRetry,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .82,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(gutter, AppSpace.sm, gutter, AppSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon ?? PhosphorIcons.warningCircle(),
                  size: 24,
                  color: palette.mutedText,
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Text(
                    title ?? tr('playback_failed'),
                    style: AppType.sectionHeader.copyWith(
                      fontFamily: AppType.bold,
                      color: palette.foreground,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              error,
              style: AppType.body.copyWith(color: palette.secondaryText),
            ),
            const SizedBox(height: AppSpace.xl),
            if (onRetry != null) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onRetry!();
                  },
                  icon: Icon(PhosphorIcons.arrowClockwise()),
                  label: Text(tr('retry')),
                ),
              ),
              const SizedBox(height: AppSpace.sm),
            ],
            if (!hideButton)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await launchUrl(
                      Uri.parse('https://t.me/flixquestgroup'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  icon: Icon(PhosphorIcons.telegramLogo()),
                  label: Text(
                    tr('report_telegram'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            const SizedBox(height: AppSpace.lg),
            Center(
              child: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.data?.version ?? currentAppVersion;
                  return Text(
                    'v$version',
                    style: AppType.metadata.copyWith(color: palette.mutedText),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExternalPlay extends StatelessWidget {
  const ExternalPlay(
      {super.key, required this.videoSources, required this.subtitleSources});

  final Map<String, String> videoSources;
  final List<BetterPlayerSubtitlesSource> subtitleSources;

  @override
  Widget build(BuildContext context) {
    final entries = videoSources.entries.toList();
    final colors = BetterPlayerPanelColors.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('open_external'),
                  style: TextStyle(
                    color: colors.foreground,
                    fontFamily: 'FigtreeBold',
                    fontSize: 19,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tr('video_source'),
                  style: TextStyle(color: colors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          for (final entry in entries)
            PlayerChoiceCard(
              title: entry.key,
              subtitle: tr('video_source'),
              thumbnail: PlayerThumbnail(
                width: 44,
                height: 44,
                child: Icon(PhosphorIcons.arrowSquareOut()),
              ),
              onTap: () => _openExternally(context, entry.value),
            ),
        ],
      ),
    );
  }

  Future<void> _openExternally(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
      return;
    }
    await FlutterClipboard.copy(url);
    if (!context.mounted) return;
    GlobalMethods.showScaffoldMessage(tr('video_link_copied'), context);
  }
}
