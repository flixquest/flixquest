import 'package:easy_localization/easy_localization.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '/constants/app_constants.dart';
import 'package:flutter/material.dart';
import '../../widgets/app_logo.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../ui_components/app_ui_components.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('about')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: AppResponsiveContent(
          maxWidth: 680,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 112,
                height: 112,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: .18),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: const AppLogo(),
                ),
              ),
              const SizedBox(height: 18),
              Text('FlixQuest',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 5),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.data?.version ?? currentAppVersion;
                  return Text(
                    tr('app_version', namedArgs: {'version': version}),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  );
                },
              ),
              const SizedBox(height: 26),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      Text(
                        tr('endorsment'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(height: 1.5),
                      ),
                      const SizedBox(height: 18),
                      InkWell(
                        borderRadius: BorderRadius.circular(9),
                        onTap: () => launchUrl(
                            Uri.parse('https://themoviedb.org'),
                            mode: LaunchMode.externalApplication),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Image.asset('assets/images/tmdb_logo.png',
                              height: 42),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(PhosphorIcons.bug()),
                      title: Text(tr('report_issue')),
                      trailing: Icon(PhosphorIcons.arrowSquareOut(), size: 18),
                      onTap: () {
                        launchUrl(
                          Uri.parse(
                              'https://github.com/beamlakaschalew/cinemax/issues/new/choose'),
                        );
                      },
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          Text(tr('follow_cinemax'),
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 14),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SocialIconContainer(
                                  platformIcon: PhosphorIcons.instagramLogo(),
                                  uri: 'https://instagram.com/flixquestapp'),
                              SocialIconContainer(
                                  platformIcon: PhosphorIcons.telegramLogo(),
                                  uri: 'https://t.me/flixquestapp'),
                              SocialIconContainer(
                                  platformIcon: PhosphorIcons.githubLogo(),
                                  uri:
                                      'https://github.com/beamlakaschalew/cinemax'),
                              SocialIconContainer(
                                  platformIcon: PhosphorIcons.envelopeSimple(),
                                  uri: 'mailto:flixquestapp@gmail.com'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Text(tr('made_with'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(tr('year_range',
                  namedArgs: {'startYear': '2018', 'endYear': '2026'})),
            ],
          ),
        ),
      ),
    );
  }
}

class SocialIconContainer extends StatelessWidget {
  const SocialIconContainer({
    required this.platformIcon,
    required this.uri,
    super.key,
  });

  final IconData platformIcon;
  final String uri;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: PlatformIcon(platformIcon: platformIcon, uri: uri),
    );
  }
}

class PlatformIcon extends StatelessWidget {
  const PlatformIcon({
    required this.platformIcon,
    required this.uri,
    super.key,
  });

  final IconData platformIcon;
  final String uri;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        launchUrl(Uri.parse(uri), mode: LaunchMode.externalApplication);
      },
      child: Icon(
        platformIcon,
      ),
    );
  }
}
