import 'package:flutter/material.dart';

import '../../catalog/media_item.dart';
import '../../mobile/screens/title_details_screen.dart';
import '../../models/tv.dart';

/// A series' page. Links, bookmarks, people and home-screen widgets open
/// series by this name; the page itself is the phone's
/// [TitleDetailsScreen].
class TVDetailPage extends StatelessWidget {
  const TVDetailPage({
    super.key,
    required this.tvSeries,
    required this.heroId,
  });

  final TV tvSeries;

  /// Kept for the callers that pass one; the page has no shared element.
  final String heroId;

  @override
  Widget build(BuildContext context) =>
      TitleDetailsScreen(item: MediaItem.fromSeries(tvSeries));
}
