import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../../ui_components/app_ui_components.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('choose_provider_order')),
        actions: [
          IconButton(
            tooltip: tr('refresh'),
            onPressed: _refreshing ? null : _loadProviders,
            icon: Icon(PhosphorIcons.arrowsClockwise()),
          ),
        ],
      ),
      body: AppResponsiveContent(
        maxWidth: 720,
        padding: EdgeInsets.zero,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadProviders,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    _ProviderOrderHeader(providerCount: _providers.length),
                    const SizedBox(height: 16),
                    if (_discoveryError != null) ...[
                      _ProviderDiscoveryError(
                        message: _discoveryError!,
                        onRetry: _loadProviders,
                      ),
                      const SizedBox(height: 12),
                    ],
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: _providers.length,
                      onReorder: _reorder,
                      itemBuilder: (context, index) {
                        final provider = _providers[index];
                        final alias = provider.alias?.trim();
                        return Padding(
                          key: ValueKey(provider.codeName),
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Card(
                            margin: EdgeInsets.zero,
                            elevation: 0,
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerLow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                              side: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant
                                    .withValues(alpha: .55),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: _PriorityBadge(priority: index + 1),
                              title: Text(
                                alias == null || alias.isEmpty
                                    ? '${tr('video_source')} ${index + 1}'
                                    : alias,
                                style: const TextStyle(
                                  fontFamily: 'FigtreeSB',
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: provider.content?.trim().isNotEmpty ==
                                      true
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 5),
                                      child: Text(
                                        provider.content!.trim(),
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                          height: 1.3,
                                        ),
                                      ),
                                    )
                                  : null,
                              trailing: ReorderableDragStartListener(
                                index: index,
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    PhosphorIcons.dotsSixVertical(),
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    _ProviderOrderHelp(text: tr('provider_precedence_help')),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ProviderOrderHeader extends StatelessWidget {
  const _ProviderOrderHeader({required this.providerCount});

  final int providerCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primaryContainer,
            colors.tertiaryContainer.withValues(alpha: .7),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: .7),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              PhosphorIcons.stack(),
              color: colors.primary,
              size: 27,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('provider_precedence'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontFamily: 'FigtreeSB',
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('choose_provider_order'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: .7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$providerCount',
              style: TextStyle(
                color: colors.primary,
                fontFamily: 'FigtreeSB',
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final int priority;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$priority',
        style: TextStyle(
          color: colors.primary,
          fontFamily: 'FigtreeSB',
          fontSize: 16,
        ),
      ),
    );
  }
}

class _ProviderDiscoveryError extends StatelessWidget {
  const _ProviderDiscoveryError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(PhosphorIcons.warningCircle(), color: colors.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
            TextButton(onPressed: onRetry, child: Text(tr('retry'))),
          ],
        ),
      ),
    );
  }
}

class _ProviderOrderHelp extends StatelessWidget {
  const _ProviderOrderHelp({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(PhosphorIcons.info(), size: 24, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
