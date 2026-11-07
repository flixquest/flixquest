import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../screens/common/about.dart';
import '../../screens/common/bookmark_screen.dart';
import '../../screens/common/settings.dart';
import '../../screens/wellness/wellness_screen.dart';
import '../widgets/page_kit.dart';
import 'playlists_screen.dart';

class MyFlixQuestScreen extends StatelessWidget {
  const MyFlixQuestScreen({super.key});
  @override
  Widget build(BuildContext context) {
    void open(Widget page) => Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => page));
    return SafeArea(
        child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            children: [
          Padding(
              padding: const EdgeInsets.all(24),
              child: Text(tr('my_flixquest'),
                  style: Theme.of(context).textTheme.headlineMedium)),
          ListRow(
              icon: PhosphorIcons.bookmarkSimple(),
              label: tr('my_list'),
              onTap: () => open(const BookmarkScreen())),
          ListRow(
              icon: PhosphorIcons.listBullets(),
              label: tr('playlists'),
              onTap: () => open(const PlaylistsScreen())),
          ListRow(
              icon: PhosphorIcons.chartDonut(),
              label: tr('tv_insights'),
              onTap: () => open(const WellnessScreen())),
          ListRow(
              icon: PhosphorIcons.slidersHorizontal(),
              label: tr('settings'),
              onTap: () => open(const Settings())),
          ListRow(
              icon: PhosphorIcons.info(),
              label: tr('about'),
              onTap: () => open(const AboutPage())),
        ]));
  }
}
