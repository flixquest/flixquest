import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../design/skeleton.dart';
import '../../mobile/widgets/details_parts.dart';
import '../../mobile/widgets/page_kit.dart';
import '../../video_providers/names.dart';
import '../../video_providers/scraper_api.dart';

class ProviderChooseScreen extends StatefulWidget {
  const ProviderChooseScreen({super.key});

  @override
  State<ProviderChooseScreen> createState() => _ProviderChooseScreenState();
}

class _ProviderChooseScreenState extends State<ProviderChooseScreen> {
  List<VideoProvider> _providers = const [];
  bool _loading = true;
  bool _refreshing = false;
  String? _discoveryError;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    if (_refreshing) return;
    final apiUrl = context.read<AppDependencyProvider>().flixquestAPIURL;
    final settings = context.read<SettingsProvider>();
    if (mounted) {
      setState(() {
        _refreshing = true;
        _loading = _providers.isEmpty;
        _discoveryError = null;
      });
    }

    final available = <VideoProvider>[];
    String? error;
    try {
      available.addAll(await ScraperApi(apiUrl).getProviders());
    } catch (exception) {
      error = exception.toString();
    }
    available.add(VideoProvider.directVixSrc);

    if (!mounted) return;
    setState(() {
      _providers = settings.orderStreamProviders(available);
      _discoveryError = error;
      _loading = false;
      _refreshing = false;
    });
  }

  void _reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final provider = _providers.removeAt(oldIndex);
      _providers.insert(newIndex, provider);
    });
    context.read<SettingsProvider>().setStreamProviderOrder(_providers);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    return Scaffold(
      backgroundColor: palette.page,
      appBar: PageAppBar(
        title: tr('provider_precedence'),
        actions: [
          IconButton(
            tooltip: tr('refresh'),
            onPressed: _refreshing ? null : _loadProviders,
            icon: Icon(PhosphorIcons.arrowsClockwise()),
          ),
        ],
      ),
      body: SkeletonSwitcher(
        loading: _loading,
        skeleton: const ListSkeleton(
          introLines: 3,
          rows: 7,
          leadingWidth: 36,
          leadingHeight: 36,
          circle: true,
          scrolls: true,
        ),
        child: RefreshIndicator(
          color: palette.foreground,
          backgroundColor: palette.raisedSurface,
          onRefresh: _loadProviders,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              top: AppSpace.xs,
              bottom: AppSpace.xxxl + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: gutter),
                child: Text(
                  tr('provider_precedence_help'),
                  style: AppType.body.copyWith(color: palette.mutedText),
                ),
              ),
              if (_discoveryError != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(gutter, AppSpace.lg, gutter, 0),
                  child: DetailsMessage(
                    message: tr('check_connection'),
                    onRetry: _loadProviders,
                  ),
                ),
              KickerHeading(
                plural('video_source_count', _providers.length),
              ),
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: _providers.length,
                onReorder: _reorder,
                proxyDecorator: (child, _, __) => Material(
                  color: palette.raisedSurface,
                  elevation: 0,
                  child: child,
                ),
                itemBuilder: (context, index) {
                  final provider = _providers[index];
                  final alias = provider.alias?.trim();
                  final content = provider.content?.trim() ?? '';
                  return ReorderableDelayedDragStartListener(
                    key: ValueKey(provider.codeName),
                    index: index,
                    child: ListRow(
                      label: alias == null || alias.isEmpty
                          ? '${tr('video_source')} ${index + 1}'
                          : alias,
                      subtitle: content.isEmpty ? null : content,
                      trailing: ReorderableDragStartListener(
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpace.sm),
                          child: Icon(
                            PhosphorIcons.dotsSixVertical(),
                            color: palette.mutedText,
                          ),
                        ),
                      ),
                      leadingNumber: index + 1,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
