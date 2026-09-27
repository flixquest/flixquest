import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../mobile/widgets/page_kit.dart';
import '../../mobile/widgets/settings_kit.dart';
import '../../widgets/app_logo.dart';
import '/constants/app_constants.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    return Scaffold(
      backgroundColor: palette.page,
      appBar: PageAppBar(title: tr('about')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              gutter,
              AppSpace.lg,
              gutter,
              AppSpace.xxxl + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.card * 3),
                  child: const SizedBox.square(dimension: 96, child: AppLogo()),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              Text(
                'FlixQuest',
                textAlign: TextAlign.center,
                style: AppType.scaled(context, AppType.pageTitle)
                    .copyWith(color: palette.foreground),
              ),
              const SizedBox(height: AppSpace.xs),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.data?.version ?? currentAppVersion;
                  return Text(
                    tr('app_version', namedArgs: {'version': version}),
                    textAlign: TextAlign.center,
                    style: AppType.metadata.copyWith(color: palette.mutedText),
                  );
                },
              ),
              const SizedBox(height: AppSpace.xxl),
              SettingsGroup(
                title: tr('about'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpace.lg),
                    child: Column(
                      children: [
                        Text(
                          tr('endorsment'),
                          textAlign: TextAlign.center,
                          style: AppType.body
                              .copyWith(color: palette.secondaryText),
                        ),
                        const SizedBox(height: AppSpace.md),
                        // TMDB's logo is artwork and keeps its own colours.
                        InkWell(
                          borderRadius: BorderRadius.circular(AppRadii.card),
                          onTap: () => _open('https://themoviedb.org'),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpace.md),
                            child: Image.asset(
                              'assets/images/tmdb_logo.png',
                              height: 36,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListRow(
                    icon: PhosphorIcons.bug(),
                    label: tr('report_issue'),
                    showsNext: false,
                    trailing: Icon(
                      PhosphorIcons.arrowSquareOut(),
                      size: 18,
                      color: palette.mutedText,
                    ),
                    onTap: () => _open(
                      'https://github.com/beamlakaschalew/cinemax/issues/new/choose',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xxl),
              SettingsGroup(
                title: tr('follow_cinemax'),
                children: [
                  _LinkRow(
                    icon: PhosphorIcons.instagramLogo(),
                    label: 'Instagram',
                    uri: 'https://instagram.com/flixquestapp',
                  ),
                  _LinkRow(
                    icon: PhosphorIcons.telegramLogo(),
                    label: 'Telegram',
                    uri: 'https://t.me/flixquestapp',
                  ),
                  _LinkRow(
                    icon: PhosphorIcons.githubLogo(),
                    label: 'GitHub',
                    uri: 'https://github.com/beamlakaschalew/cinemax',
                  ),
                  _LinkRow(
                    icon: PhosphorIcons.envelopeSimple(),
                    label: 'flixquestapp@gmail.com',
                    uri: 'mailto:flixquestapp@gmail.com',
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xxl),
              Text(
                tr('made_with'),
                textAlign: TextAlign.center,
                style: AppType.cardTitle.copyWith(color: palette.foreground),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                tr(
                  'year_range',
                  namedArgs: {'startYear': '2018', 'endYear': '2026'},
                ),
                textAlign: TextAlign.center,
                style: AppType.metadata.copyWith(color: palette.mutedText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _open(String uri) =>
    launchUrl(Uri.parse(uri), mode: LaunchMode.externalApplication);

/// A place to follow FlixQuest, which opens outside the app.
class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.icon, required this.label, required this.uri});

  final IconData icon;
  final String label;
  final String uri;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      icon: icon,
      label: label,
      showsNext: false,
      trailing: Icon(
        PhosphorIcons.arrowSquareOut(),
        size: 18,
        color: AppPalette.of(context).mutedText,
      ),
      onTap: () => _open(uri),
    );
  }
}
