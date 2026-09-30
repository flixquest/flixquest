import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../design/app_palette.dart';
import '../design/app_tokens.dart';
import '../design/skeleton.dart';
import '../models/provider_load_state.dart';

const _switchDuration = Duration(milliseconds: 220);

/// The source race while a stream resolves: the source being waited on, how
/// far through the list the race is, and every source's outcome so far.
///
/// Rows keep a steady height as the race moves on, so nothing below them
/// jumps while the viewer waits.
class ProviderLoadingWidget extends StatelessWidget {
  const ProviderLoadingWidget({
    required this.providers,
    required this.currentIndex,
    super.key,
  });

  final List<ProviderLoadState> providers;

  /// The source the race is waiting on, or the one it chose.
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final current = currentIndex >= 0 && currentIndex < providers.length
        ? providers[currentIndex]
        : null;
    final checked = providers
        .where((provider) =>
            provider.status == ProviderStatus.success ||
            provider.status == ProviderStatus.failed)
        .length;

    return Column(
      key: const ValueKey<String>('provider-loading-panel'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AnimatedSize(
          duration: _switchDuration,
          curve: Curves.easeOutCubic,
          alignment: AlignmentDirectional.topStart,
          child: AnimatedSwitcher(
            duration: _switchDuration,
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: AlignmentDirectional.topStart,
              children: <Widget>[
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            ),
            child: _CurrentSource(
              key: ValueKey<String>('${current?.codeName}:${current?.status}'),
              provider: current,
            ),
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        _RaceProgress(checked: checked, total: providers.length),
        const SizedBox(height: AppSpace.lg),
        if (providers.isEmpty)
          const _SourceChipsSkeleton()
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (var index = 0; index < providers.length; index++)
                _SourceChip(
                  provider: providers[index],
                  current: index == currentIndex,
                ),
            ],
          ),
      ],
    );
  }
}

/// The one line that says what the wait is for right now.
class _CurrentSource extends StatelessWidget {
  const _CurrentSource({required this.provider, super.key});

  final ProviderLoadState? provider;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final provider = this.provider;
    final status = provider?.status ?? ProviderStatus.pending;
    final headline = switch (status) {
      // Before any request starts, the source list itself is loading.
      ProviderStatus.pending => tr('loading_video_sources'),
      ProviderStatus.loading => tr(
          'playback_loader_checking',
          namedArgs: {'provider': provider!.fullName},
        ),
      ProviderStatus.success => tr(
          'playback_loader_found',
          namedArgs: {'provider': provider!.fullName},
        ),
      ProviderStatus.failed => provider!.fullName,
    };
    final content =
        status == ProviderStatus.pending ? null : provider?.content?.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: _StatusGlyph(
            status: status == ProviderStatus.pending
                ? ProviderStatus.loading
                : status,
            size: 20,
          ),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                headline,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.scaled(context, AppType.sectionHeader).copyWith(
                  color: palette.foreground,
                ),
              ),
              if (content?.isNotEmpty == true) ...<Widget>[
                const SizedBox(height: AppSpace.xs),
                Text(
                  content!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.scaled(context, AppType.metadata).copyWith(
                    color: palette.mutedText,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A thin bar of the sources that have answered, easing forward as each one
/// does, with the count beside it.
class _RaceProgress extends StatelessWidget {
  const _RaceProgress({required this.checked, required this.total});

  final int checked;
  final int total;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final target = total == 0 ? 0.0 : (checked / total).clamp(0.0, 1.0);
    return Row(
      children: <Widget>[
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 3,
              child: ColoredBox(
                color: palette.idleFill,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: target),
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: value,
                    child: ColoredBox(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (total > 0) ...<Widget>[
          const SizedBox(width: AppSpace.md),
          Text(
            tr(
              'playback_loader_progress',
              namedArgs: {'checked': '$checked', 'total': '$total'},
            ),
            style: AppType.scaled(context, AppType.metadata).copyWith(
              color: palette.mutedText,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}

/// One source and how it answered.
class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.provider, required this.current});

  final ProviderLoadState provider;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final status = provider.status;
    final settled =
        status == ProviderStatus.pending || status == ProviderStatus.failed;
    final fill = switch (status) {
      ProviderStatus.success => palette.idleFillStrong,
      _ when current || status == ProviderStatus.loading => palette.idleFill,
      _ => palette.idleFillFaint,
    };
    return AnimatedContainer(
      duration: _switchDuration,
      curve: Curves.easeOut,
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 11, 6),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _StatusGlyph(status: status, size: 14),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              provider.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.scaled(context, AppType.metadata).copyWith(
                color: settled && !current
                    ? palette.mutedText
                    : palette.foreground,
                fontFamily: current ? AppType.semiBold : AppType.regular,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceChipsSkeleton extends StatelessWidget {
  const _SourceChipsSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: <Widget>[
          for (final width in <double>[92, 68, 108, 80, 96])
            SkeletonBlock(width: width, height: 30, radius: AppRadii.chip),
        ],
      ),
    );
  }
}

/// Neutral throughout: spinners and marks stay off the accent, which is kept
/// for the progress bar (docs/mobile_redesign_guide.md, section 3.2).
class _StatusGlyph extends StatelessWidget {
  const _StatusGlyph({required this.status, required this.size});

  final ProviderStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return SizedBox.square(
      dimension: size,
      child: switch (status) {
        ProviderStatus.pending => Icon(
            PhosphorIcons.circle(),
            size: size,
            color: palette.mutedText.withValues(alpha: .55),
          ),
        ProviderStatus.loading => Padding(
            padding: EdgeInsets.all(size * .1),
            child: CircularProgressIndicator(
              strokeWidth: size < 18 ? 1.6 : 2.2,
              color: palette.mutedText,
            ),
          ),
        ProviderStatus.success => Icon(
            PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
            size: size,
            color: palette.foreground,
          ),
        ProviderStatus.failed => Icon(
            PhosphorIcons.xCircle(),
            size: size,
            color: palette.mutedText,
          ),
      },
    );
  }
}
