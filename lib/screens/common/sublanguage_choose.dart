import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../mobile/widgets/page_kit.dart';
import '../../mobile/widgets/settings_kit.dart';
import '/models/sub_languages.dart';
import '/provider/settings_provider.dart';

/// The languages subtitles can be fetched in, named in the current language.
/// The first, with an empty code, is "any".
List<SubLanguages> subtitleLanguageChoices() => <SubLanguages>[
      SubLanguages(languageName: '', languageCode: '', englishName: 'any'),
      SubLanguages(
          languageName: tr('arabic'),
          languageCode: 'ar',
          englishName: 'Arabic'),
      SubLanguages(
          languageName: tr('bulgarian'),
          languageCode: 'bg',
          englishName: 'Bulgarian'),
      SubLanguages(
          languageName: tr('chinese'),
          languageCode: 'zh',
          englishName: 'Chinese'),
      SubLanguages(
          languageName: tr('croaitian'),
          languageCode: 'hr',
          englishName: 'Croaitian'),
      SubLanguages(
          languageName: tr('czech'), languageCode: 'cs', englishName: 'Czech'),
      SubLanguages(
          languageName: tr('danish'),
          languageCode: 'da',
          englishName: 'Danish'),
      SubLanguages(
          languageName: tr('dutch'), languageCode: 'nl', englishName: 'Dutch'),
      SubLanguages(
          languageName: tr('english'),
          languageCode: 'en',
          englishName: 'English'),
      SubLanguages(
          languageName: tr('estonian'),
          languageCode: 'et',
          englishName: 'Estonian'),
      SubLanguages(
          languageName: tr('finnish'),
          languageCode: 'fi',
          englishName: 'Finnish'),
      SubLanguages(
          languageName: tr('french'),
          languageCode: 'fr',
          englishName: 'French'),
      SubLanguages(
          languageName: tr('german'),
          languageCode: 'de',
          englishName: 'German'),
      SubLanguages(
          languageName: tr('greek'), languageCode: 'el', englishName: 'Greek'),
      SubLanguages(
          languageName: tr('hebrew'),
          languageCode: 'he',
          englishName: 'Hebrew'),
      SubLanguages(
          languageName: tr('hindi'), languageCode: 'hi', englishName: 'Hindi'),
      SubLanguages(
          languageName: tr('hungarian'),
          languageCode: 'hu',
          englishName: 'Hungarian'),
      SubLanguages(
          languageName: tr('indonesian'),
          languageCode: 'id',
          englishName: 'Indonesian'),
      SubLanguages(
          languageName: tr('italian'),
          languageCode: 'it',
          englishName: 'Italian'),
      SubLanguages(
          languageName: tr('japanese'),
          languageCode: 'ja',
          englishName: 'Japanese'),
      SubLanguages(
          languageName: tr('korean'),
          languageCode: 'ko',
          englishName: 'Korean'),
      SubLanguages(
          languageName: tr('latvian'),
          languageCode: 'lv',
          englishName: 'Latvian'),
      SubLanguages(
          languageName: tr('lithuanian'),
          languageCode: 'lt',
          englishName: 'Lithuanian'),
      SubLanguages(
          languageName: tr('malay'), languageCode: 'ms', englishName: 'Malay'),
      SubLanguages(
          languageName: tr('norwegian'),
          languageCode: 'no',
          englishName: 'Norwegian'),
      SubLanguages(
          languageName: tr('polish'),
          languageCode: 'pl',
          englishName: 'Polish'),
      SubLanguages(
          languageName: tr('portuguese'),
          languageCode: 'pt',
          englishName: 'Portuguese'),
      SubLanguages(
          languageName: tr('romanian'),
          languageCode: 'ro',
          englishName: 'Romanian'),
      SubLanguages(
          languageName: tr('russian'),
          languageCode: 'ru',
          englishName: 'Russian'),
      SubLanguages(
          languageName: tr('slovak'),
          languageCode: 'sk',
          englishName: 'Slovak'),
      SubLanguages(
          languageName: tr('slovene'),
          languageCode: 'sl',
          englishName: 'Slovene'),
      SubLanguages(
          languageName: tr('spanish'),
          languageCode: 'es',
          englishName: 'Spanish'),
      SubLanguages(
          languageName: tr('swedish'),
          languageCode: 'sv',
          englishName: 'Swedish'),
      SubLanguages(
          languageName: tr('thai'), languageCode: 'th', englishName: 'Thai'),
      SubLanguages(
          languageName: tr('turkish'),
          languageCode: 'tr',
          englishName: 'Turkish'),
      SubLanguages(
          languageName: tr('ukrainian'),
          languageCode: 'uk',
          englishName: 'Ukrainian'),
    ];

/// The name to show for the subtitle language [code].
String subtitleLanguageName(String code) {
  if (code.isEmpty) return tr('any');
  for (final language in subtitleLanguageChoices()) {
    if (language.languageCode == code) return language.languageName;
  }
  return code;
}

class SubLangChoose extends StatelessWidget {
  const SubLangChoose({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    return Scaffold(
      backgroundColor: palette.page,
      appBar: PageAppBar(title: tr('choose_subtitle_language')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              gutter,
              AppSpace.sm,
              gutter,
              AppSpace.xxxl + MediaQuery.paddingOf(context).bottom,
            ),
            children: <Widget>[
              SettingsGroup(
                title: tr('subtitle_language'),
                children: <Widget>[
                  for (final language in subtitleLanguageChoices())
                    SelectableRow(
                      label: language.languageName.isEmpty
                          ? tr('any')
                          : language.languageName,
                      subtitle: language.languageCode.isEmpty
                          ? null
                          : language.englishName,
                      selected: settings.defaultSubtitleLanguage ==
                          language.languageCode,
                      onTap: () => settings.defaultSubtitleLanguage =
                          language.languageCode,
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
