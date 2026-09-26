import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/provider_load_state.dart';
import 'app_logo.dart';

class ProviderLoadingWidget extends StatefulWidget {
  final List<ProviderLoadState> providers;
  final int currentIndex;
  final String? additionalMessage;

  const ProviderLoadingWidget({
    required this.providers,
    required this.currentIndex,
    this.additionalMessage,
    super.key,
  });

  @override
  State<ProviderLoadingWidget> createState() => _ProviderLoadingWidgetState();
}

class _ProviderLoadingWidgetState extends State<ProviderLoadingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void didUpdateWidget(ProviderLoadingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final viewport = MediaQuery.sizeOf(context);
    final isLandscape = viewport.width > viewport.height;
    final useSplitLayout = isLandscape && viewport.width >= 620;
    final horizontalMargin = useSplitLayout ? 16.0 : 20.0;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(
        horizontal: horizontalMargin,
        vertical: useSplitLayout ? 10 : 20,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: useSplitLayout ? 26 : 32,
        vertical: useSplitLayout ? 22 : 34,
      ),
      constraints: BoxConstraints(
        maxWidth: useSplitLayout ? 780 : 440,
        minHeight: useSplitLayout ? 0 : 340,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryContainer.withValues(alpha: .22),
            colors.surfaceContainerHigh.withValues(alpha: .88),
            colors.surface.withValues(alpha: .94),
          ],
        ),
        borderRadius: BorderRadius.circular(useSplitLayout ? 10 : 12),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: .46),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: .18),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: colors.primary.withValues(alpha: .07),
            blurRadius: 48,
          ),
        ],
      ),
      child: useSplitLayout
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: _buildIdentity(compact: true)),
                Container(
                  width: 1,
                  height: 150,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  color: colors.outlineVariant.withValues(alpha: .42),
                ),
                Expanded(
                  flex: 2,
                  child: _buildProviderProgress(compact: true),
                ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIdentity(compact: false),
                const SizedBox(height: 24),
                _buildProviderProgress(compact: false),
              ],
            ),
    );
  }

  Widget _buildIdentity({required bool compact}) {
    final colors = Theme.of(context).colorScheme;
    final logoSize = compact ? 52.0 : 72.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(compact ? 12 : 18),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                colors.primary.withValues(alpha: .22),
                colors.primary.withValues(alpha: .08),
                Colors.transparent,
              ],
            ),
            border: Border.all(
              color: colors.primary.withValues(alpha: .12),
            ),
          ),
          child: AppLogo(height: logoSize, width: logoSize),
        ),
        SizedBox(height: compact ? 14 : 22),
        Text(
          tr('loading_video_sources'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: compact ? TextAlign.start : TextAlign.center,
          style: TextStyle(
            color: colors.onSurface,
            fontSize: compact ? 17 : 19,
            fontWeight: FontWeight.w600,
            fontFamily: 'Figtree',
            letterSpacing: .2,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr('finding_best_source'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: compact ? TextAlign.start : TextAlign.center,
          style: TextStyle(
            color: colors.onSurfaceVariant.withValues(alpha: .78),
            fontSize: 13,
            fontFamily: 'Figtree',
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildProviderProgress({required bool compact}) {
    final colors = Theme.of(context).colorScheme;
    final completed = widget.providers.where((provider) {
      return provider.status == ProviderStatus.success ||
          provider.status == ProviderStatus.failed;
    }).length;
    final progress = widget.providers.isEmpty
        ? null
        : (completed / widget.providers.length).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: colors.primary.withValues(alpha: .11),
                  valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                ),
              ),
            ),
            if (widget.providers.isNotEmpty) ...[
              const SizedBox(width: 12),
              Text(
                '$completed/${widget.providers.length}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: compact ? 15 : 22),
        FadeTransition(
          opacity: _fadeAnimation,
          child: _buildProviderCarousel(compact: compact),
        ),
        if (widget.additionalMessage != null) ...[
          SizedBox(height: compact ? 10 : 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: .3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    widget.additionalMessage!,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: .8),
                      fontSize: 13,
                      fontFamily: 'Figtree',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProviderCarousel({required bool compact}) {
    final int prevIndex =
        widget.currentIndex > 0 ? widget.currentIndex - 1 : -1;
    final int nextIndex = widget.currentIndex < widget.providers.length - 1
        ? widget.currentIndex + 1
        : -1;

    if (widget.providers.isEmpty) {
      return _buildEmptyProviderItem(compact: compact);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (prevIndex >= 0)
          _buildProviderItem(
            widget.providers[prevIndex],
            compact: compact,
          ),
        if (widget.currentIndex < widget.providers.length)
          _buildProviderItem(
            widget.providers[widget.currentIndex],
            isCurrent: true,
            compact: compact,
          ),
        if (nextIndex >= 0)
          _buildProviderItem(
            widget.providers[nextIndex],
            compact: compact,
          ),
      ],
    );
  }

  Widget _buildEmptyProviderItem({required bool compact}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: compact ? 12 : 15,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                color: colors.onSurface.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderItem(
    ProviderLoadState provider, {
    bool isCurrent = false,
    required bool compact,
  }) {
    final bool isHighlighted = isCurrent;
    final double opacity = isHighlighted ? 1.0 : 0.52;
    final double fontSize = isHighlighted ? (compact ? 15.5 : 16.5) : 13.5;
    final double iconSize = isHighlighted ? (compact ? 21 : 23) : 18;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      margin: EdgeInsets.symmetric(vertical: compact ? 3 : 5),
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isHighlighted ? 20 : 16,
            vertical: isHighlighted ? (compact ? 10 : 13) : (compact ? 7 : 10),
          ),
          decoration: BoxDecoration(
            color: isHighlighted
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isHighlighted
                ? Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.25),
                    width: 1.2,
                  )
                : null,
          ),
          child: Row(
            children: [
              // Status icon
              _buildStatusIcon(provider.status, iconSize),
              const SizedBox(width: 14),

              // Provider name and advertised catalogue/languages.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.fullName,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: fontSize,
                        fontWeight:
                            isHighlighted ? FontWeight.w600 : FontWeight.w500,
                        fontFamily: 'Figtree',
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Every row advertises its catalogue so the coverage of
                    // the neighbouring sources is visible too, not just the
                    // one currently being tried.
                    if (provider.content?.trim().isNotEmpty == true) ...[
                      SizedBox(height: isHighlighted ? 3 : 2),
                      Text(
                        provider.content!.trim(),
                        maxLines: isHighlighted ? (compact ? 2 : 3) : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: isHighlighted
                              ? (compact ? 11.5 : 12)
                              : (compact ? 10.5 : 11),
                          fontFamily: 'Figtree',
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(ProviderStatus status, double iconSize) {
    switch (status) {
      case ProviderStatus.pending:
        return Icon(
          PhosphorIcons.hourglass(),
          size: iconSize,
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
        );
      case ProviderStatus.loading:
        return SizedBox(
          width: iconSize,
          height: iconSize,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        );
      case ProviderStatus.success:
        return Icon(
          PhosphorIcons.checkCircle(),
          size: iconSize,
          color: const Color(0xFF4CAF50),
        );
      case ProviderStatus.failed:
        return Icon(
          PhosphorIcons.warningCircle(),
          size: iconSize,
          color: const Color(0xFFEF5350),
        );
    }
  }
}
