import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/api_constants.dart';
import '../../constants/app_constants.dart';
import '../../functions/function.dart';
import '../../models/tv.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../../ui_components/app_ui_components.dart';
import '../../provider/bookmark_provider.dart';
import '../../widgets/common_widgets.dart';
import 'tv_detail.dart';

class TVBookmark extends StatefulWidget {
  const TVBookmark({required this.tvList, super.key});

  final List<TV>? tvList;

  @override
  State<TVBookmark> createState() => _TVBookmarkState();
}

class _TVBookmarkState extends State<TVBookmark> {
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final proxy = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    final items = widget.tvList;
    if (items == null) return moviesAndTVShowGridShimmer(settings.appTheme);
    if (items.isEmpty) {
      return AppEmptyState(
        title: tr('bookmarks'),
        message: tr('no_tv_bookmarked'),
        icon: PhosphorIcons.bookmarkSimple(),
      );
    }
    return settings.defaultView == 'list'
        ? _buildList(context, items, settings, proxy)
        : _buildGrid(context, items, settings, proxy);
  }

  Widget _buildGrid(BuildContext context, List<TV> items,
      SettingsProvider settings, String proxy) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
          AppUI.pagePadding(context), 18, AppUI.pagePadding(context), 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: AppUI.mediaGridColumns(context),
        childAspectRatio: AppUI.mediaGridChildAspectRatio(context),
        crossAxisSpacing: AppUI.mediaGridCrossAxisSpacing,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length,
      itemBuilder: (_, index) => _TVGridCard(
        item: items[index],
        imageUrl: _imageUrl(context, items[index], settings, proxy),
        onOpen: () => _open(items[index]),
        onRemove: () => _remove(items, index),
        themeMode: settings.appTheme,
      ),
    );
  }

  Widget _buildList(BuildContext context, List<TV> items,
      SettingsProvider settings, String proxy) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
          AppUI.pagePadding(context), 16, AppUI.pagePadding(context), 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final item = items[index];
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: () => _open(item),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppUI.cardRadius),
                    child: CachedNetworkImage(
                      cacheManager: cacheProp(),
                      imageUrl: _imageUrl(context, item, settings, proxy),
                      width: 92,
                      height: 132,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          scrollingImageShimmer(settings.appTheme),
                      errorWidget: (_, __, ___) => Image.asset(
                        'assets/images/na_logo.png',
                        width: 92,
                        height: 132,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name ?? tr('not_available'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 10),
                        Row(children: [
                          AppRatingBadge(
                              rating: item.voteAverage, compact: true),
                          const SizedBox(width: 10),
                          Text(_year(item.firstAirDate)),
                        ]),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: tr('delete'),
                    onPressed: () => _remove(items, index),
                    icon: Icon(PhosphorIcons.bookmarkSimple()),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _imageUrl(
      BuildContext context, TV item, SettingsProvider settings, String proxy) {
    if (item.posterPath == null) return '';
    return buildImageUrl(
            TMDB_BASE_IMAGE_URL, proxy, settings.enableProxy, context) +
        settings.imageQuality +
        item.posterPath!;
  }

  String _year(String? value) =>
      value != null && value.length >= 4 ? value.substring(0, 4) : '—';

  void _open(TV item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TVDetailPage(tvSeries: item, heroId: '${item.id}'),
      ),
    );
  }

  Future<void> _remove(List<TV> items, int index) async {
    final id = items[index].id;
    if (id != null) {
      await Provider.of<BookmarkProvider>(context, listen: false).removeTV(id);
    }
  }
}

class _TVGridCard extends StatelessWidget {
  const _TVGridCard({
    required this.item,
    required this.imageUrl,
    required this.onOpen,
    required this.onRemove,
    required this.themeMode,
  });

  final TV item;
  final String imageUrl;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  final String themeMode;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppUI.cardRadius),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: AppUI.posterAspectRatio,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Hero(
                    tag: '${item.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppUI.cardRadius),
                      child: CachedNetworkImage(
                        cacheManager: cacheProp(),
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            scrollingImageShimmer(themeMode),
                        errorWidget: (_, __, ___) => Image.asset(
                          'assets/images/na_logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AppRatingBadge(rating: item.voteAverage, compact: true),
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: IconButton.filledTonal(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          tooltip: tr('delete'),
                          onPressed: onRemove,
                          icon: Icon(PhosphorIcons.x(), size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppUI.mediaGridTitleGap),
          SizedBox(
            width: double.infinity,
            height: AppUI.mediaGridTitleHeight,
            child: Text(
              item.name ?? tr('not_available'),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontFamily: 'FigtreeSB',
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
