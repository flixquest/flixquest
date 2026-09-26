import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/settings_provider.dart';
import '../../ui_components/app_ui_components.dart';
import '../movie/discover_movies_tab.dart';
import '../tv/discover_tv_tab.dart';
import 'search_view.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({
    super.key,
  });

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late TabController tabController;

  @override
  void initState() {
    tabController = TabController(length: 2, vsync: this);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final settings = Provider.of<SettingsProvider>(context);
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          AppResponsiveContent(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    color: colors.onSurface.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(9),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () => _openSearch(settings),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        child: Row(
                          children: [
                            Icon(PhosphorIcons.magnifyingGlass(),
                                color: colors.onSurfaceVariant),
                            const SizedBox(width: 12),
                            Text(
                              tr('search'),
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AppResponsiveContent(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TabBar(
              controller: tabController,
              tabs: [
                Tab(text: tr('movies')),
                Tab(text: tr('tv_series')),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: const [DiscoverMoviesTab(), DiscoverTVTab()],
            ),
          ),
        ],
      ),
    );
  }

  void _openSearch(SettingsProvider settings) {
    showSearch(
      context: context,
      delegate: Search(
        includeAdult: settings.isAdult,
        lang: settings.appLanguage,
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
