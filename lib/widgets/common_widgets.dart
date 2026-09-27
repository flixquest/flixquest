// ignore_for_file: avoid_unnecessary_containers
import 'package:better_player_plus/better_player.dart';
import 'package:clipboard/clipboard.dart';
import 'package:flixquest/services/globle_method.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_constants.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import '../provider/settings_provider.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../ui_components/app_ui_components.dart';
import '../design/skeleton.dart';
//import '../screens/common/news_screen.dart';

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

Widget detailImageShimmer(String themeMode) => ShimmerBase(
      themeMode: themeMode,
      child: CarouselSlider(
        options: CarouselOptions(
          enableInfiniteScroll: false,
          viewportFraction: 1,
        ),
        items: [
          Row(
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Stack(
                        alignment: AlignmentDirectional.bottomStart,
                        children: [
                          SizedBox(
                            height: 180,
                            child: Container(
                              decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(AppUI.cardRadius),
                                  color: Colors.grey.shade600),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Container(
                              color: Colors.black38,
                              height: 40,
                            ),
                          )
                        ]),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  child: Container(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Stack(
                          alignment: AlignmentDirectional.bottomStart,
                          children: [
                            SizedBox(
                              height: 180,
                              child: Container(
                                decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(AppUI.cardRadius),
                                    color: Colors.white),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Container(
                                color: Colors.black38,
                                height: 40,
                              ),
                            )
                          ]),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

Widget detailImageImageSimmer(String themeMode) => ShimmerBase(
    themeMode: themeMode,
    child: Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppUI.cardRadius),
          color: Colors.grey.shade600),
    ));

Widget detailVideoShimmer(String themeMode) => SizedBox(
      width: double.infinity,
      child: ShimmerBase(
        themeMode: themeMode,
        child: CarouselSlider.builder(
          options: CarouselOptions(
            disableCenter: true,
            viewportFraction: 0.8,
            enlargeCenterPage: false,
            autoPlay: true,
          ),
          itemBuilder: (context, index, pageViewIndex) => Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              height: 205,
              width: double.infinity,
              child: Column(
                children: [
                  Expanded(
                    flex: 5,
                    child: Container(
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppUI.cardRadius),
                          color: Colors.grey.shade600),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5.0),
                              color: Colors.grey.shade600),
                        )),
                  )
                ],
              ),
            ),
          ),
          itemCount: 5,
        ),
      ),
    );

Widget detailVideoImageShimmer(String themeMode) => ShimmerBase(
    themeMode: themeMode,
    child: Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppUI.cardRadius),
          color: Colors.grey.shade600),
    ));

class ShimmerBase extends StatelessWidget {
  const ShimmerBase({super.key, required this.child, required this.themeMode});

  final Widget child;

  /// Unused: the pulse takes its tones from the theme.
  final String themeMode;

  @override
  Widget build(BuildContext context) => SkeletonTint(child: child);
}

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
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .82,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colors.error.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon ?? PhosphorIcons.warningCircle(),
                    color: colors.error,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    title ?? tr('playback_failed'),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(9),
                border:
                    Border.all(color: colors.outline.withValues(alpha: .16)),
              ),
              child: Text(
                error,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 16),
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
              const SizedBox(height: 10),
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
            const SizedBox(height: 16),
            Center(
              child: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.data?.version ?? currentAppVersion;
                  return Text(
                    'v$version',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant.withValues(alpha: .7),
                    ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0x14FFFFFF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    PhosphorIcons.arrowSquareOut(),
                    color: BetterPlayerColors.secondary,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('open_external'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'FigtreeBold',
                          fontSize: 19,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        tr('video_source'),
                        style: const TextStyle(
                          color: BetterPlayerColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            for (var index = 0; index < entries.length; index++) ...[
              AppStreamSourceTile(
                index: index + 1,
                title: entries[index].key,
                subtitle: tr('video_source'),
                onTap: () => _openExternally(context, entries[index].value),
              ),
              if (index != entries.length - 1) const SizedBox(height: 10),
            ],
          ],
        ),
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

// class SubtitleCopy extends StatelessWidget {
//   const SubtitleCopy({Key? key, required this.subtitleSources}) : super(key: key);

//   final List<BetterPlayerSubtitlesSource> subtitleSources;

//   @override
//   Widget build(BuildContext context) {
//     return Column(children: [  const SizedBox(
//               height: 10,
//             ),
//             Text('Copy subtitle:'),
//             SizedBox(
//               width: double.infinity,
//               height: 50,
//               child: ListView.builder(
//                   itemCount: subtitleSources.length,
//                   scrollDirection: Axis.horizontal,
//                   itemBuilder: ((context, index) {
//                     final url =
//                         Uri.encodeFull(
//                     subtitleSources.elementAt(index).content);
//                     return Padding(
//                       padding: const EdgeInsets.all(8.0),
//                       child: TextButton(
//                           onPressed: () async {
//                             if (await canLaunchUrl(Uri.parse(url))) {
//                               await launchUrl(
//                                   Uri.parse(
//                                       subtitleSources.entries.elementAt(index).value),
//                                   mode:
//                                       LaunchMode.externalNonBrowserApplication);
//                             }
//                           },
//                           onLongPress: () async {
//                             FlutterClipboard.copy(
//                                     subtitleSources.entries.elementAt(index).value)
//                                 .then((value) {
//                               GlobalMethods.showScaffoldMessage(
//                                   tr("video_link_copied"), context);
//                               Navigator.pop(context);
//                             });
//                           },
//                           child: Text(subtitleSources.entries.elementAt(index).key)),
//                     );
//                   })),
//             )
//       ],
//     );
//   }
// }

class LeadingDot extends StatelessWidget {
  const LeadingDot({super.key});

  @override
  Widget build(BuildContext context) {
    String appLang = Provider.of<SettingsProvider>(context).appLanguage;
    return Container(
      color: Theme.of(context).primaryColor,
      width: 10,
      height: 25,
      margin: appLang == 'ar'
          ? const EdgeInsets.only(left: 8)
          : const EdgeInsets.only(right: 8),
    );
  }
}
