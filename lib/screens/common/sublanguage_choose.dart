import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../functions/language_names.dart';
import '../../mobile/widgets/page_kit.dart';
import '../../mobile/widgets/settings_kit.dart';
import '/models/sub_languages.dart';
import '/provider/settings_provider.dart';

/// The languages subtitles can be fetched in, named in the current language.
/// The first, with an empty code, is "any".
List<SubLanguages> subtitleLanguageChoices() => <SubLanguages>[
      SubLanguages(languageName: '', languageCode: '', englishName: 'any'),
      for (final language in appLanguages)
        SubLanguages(
          languageName: tr(language.translationKey),
          languageCode: language.code,
          englishName: _englishName(language.translationKey),
        ),
    ];

/// The name to show for the subtitle language [code].
String subtitleLanguageName(String code) =>
    code.isEmpty ? tr('any') : languageDisplayName(code);

String _englishName(String translationKey) =>
    '${translationKey[0].toUpperCase()}${translationKey.substring(1)}';

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
