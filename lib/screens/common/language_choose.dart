import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../mobile/widgets/page_kit.dart';
import '../../mobile/widgets/settings_kit.dart';
import '../../models/app_languages.dart';
import '/provider/settings_provider.dart';

/// The languages the app itself is translated into, named in the current
/// language.
List<AppLanguages> appLanguageChoices() => <AppLanguages>[
      AppLanguages(
        languageFlag: 'assets/images/country_flags/united-kingdom.png',
        languageName: tr('english'),
        languageCode: 'en',
      ),
      AppLanguages(
        languageFlag: 'assets/images/country_flags/united-arab-emirates.png',
        languageName: tr('arabic'),
        languageCode: 'ar',
      ),
      AppLanguages(
        languageFlag: 'assets/images/country_flags/spain.png',
        languageName: tr('spanish'),
        languageCode: 'es',
      ),
      AppLanguages(
        languageFlag: 'assets/images/country_flags/india.png',
        languageName: tr('hindi'),
        languageCode: 'hi',
      ),
    ];

class AppLanguageChoose extends StatelessWidget {
  const AppLanguageChoose({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    return Scaffold(
      backgroundColor: palette.page,
      appBar: PageAppBar(title: tr('choose_language')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              gutter,
              AppSpace.sm,
              gutter,
              AppSpace.xxxl + MediaQuery.paddingOf(context).bottom,
            ),
            children: <Widget>[
              SettingsGroup(
                title: tr('app_language'),
                children: <Widget>[
                  for (final language in appLanguageChoices())
                    SelectableRow(
                      label: language.languageName,
                      leading: LanguageFlag(language.languageFlag),
                      selected: settings.appLanguage == language.languageCode,
                      onTap: () {
                        settings.appLanguage = language.languageCode;
                        EasyLocalization.of(context)!
                            .setLocale(Locale(language.languageCode));
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
