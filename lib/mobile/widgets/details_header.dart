import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../catalog/details_controller.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import 'pill_button.dart';

/// The top of a details page (a title, a season, an episode): 16:9 artwork
/// that collapses into a bar with the page's name, and a round back button
/// over it.
class DetailsSliverHeader extends StatelessWidget {
  const DetailsSliverHeader({
    required this.title,
    required this.artwork,
    required this.collapsed,
    this.actions,
    super.key,
  });

  final String title;

  /// Fills the header; the header fades it into the page.
  final Widget artwork;

  /// Whether the artwork has scrolled away: the bar's title shows, and the
  /// buttons turn to the page's ink.
  final bool collapsed;

  /// Round buttons at the end, as [DetailsRoundButton]s.
  final List<Widget>? actions;

  static double heightFor(BuildContext context) =>
      MediaQuery.sizeOf(context).width * 9 / 16;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SliverAppBar(
      pinned: true,
      expandedHeight: heightFor(context),
      backgroundColor: palette.page,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      // Light icons over the artwork; the theme's own once it has scrolled
      // away.
      systemOverlayStyle: collapsed && !dark
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      leading: Padding(
        padding: const EdgeInsetsDirectional.only(start: AppSpace.sm),
        child: Center(
          child: DetailsRoundButton(
            icon: PhosphorIcons.caretLeft(),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onArtwork: !collapsed,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
      titleSpacing: 0,
      title: AnimatedOpacity(
        opacity: collapsed ? 1 : 0,
        duration: const Duration(milliseconds: 160),
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.sectionHeader.copyWith(color: palette.foreground),
        ),
      ),
      actions: <Widget>[
        for (final action in actions ?? const <Widget>[]) Center(child: action),
        const SizedBox(width: AppSpace.sm),
      ],
      flexibleSpace: DetailsBackdrop(artwork: artwork),
    );
  }
}

/// Tracks whether a details page's artwork has scrolled away, for
/// [DetailsSliverHeader.collapsed].
mixin CollapsingHeader<T extends StatefulWidget> on State<T> {
  final ScrollController scroll = ScrollController();
  bool collapsed = false;

  @override
  void initState() {
    super.initState();
    scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    final now = scroll.hasClients &&
        scroll.offset >
            DetailsSliverHeader.heightFor(context) - kToolbarHeight - 24;
    if (now != collapsed) setState(() => collapsed = now);
  }
}

/// [artwork] fading into the page at whatever height the header has
/// collapsed to, with a shade at the top for the status bar and the back
/// button. As it collapses the artwork rises a little slower than the page
/// and gives way to the page's colour.
class DetailsBackdrop extends StatelessWidget {
  const DetailsBackdrop({required this.artwork, super.key});

  final Widget artwork;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final settings =
        context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    return LayoutBuilder(
      builder: (context, constraints) {
        final current = settings?.currentExtent ?? constraints.maxHeight;
        final max = settings?.maxExtent ?? current;
        final min = settings?.minExtent ?? 0;
        final shown =
            max <= min ? 1.0 : ((current - min) / (max - min)).clamp(0.0, 1.0);
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned(
                top: (current - max) / 2,
                left: 0,
                right: 0,
                height: max,
                child: artwork,
              ),
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 120,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0x8C000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: const Alignment(0, 0.25),
                    end: Alignment.bottomCenter,
                    // Solid for the last few pixels, so no seam shows where
                    // the artwork meets the page.
                    stops: const <double>[0, .94, 1],
                    colors: <Color>[
                      palette.scrim(0),
                      palette.page,
                      palette.page,
                    ],
                  ),
                ),
              ),
              if (shown < 1) ColoredBox(color: palette.scrim(1 - shown)),
            ],
          ),
        );
      },
    );
  }
}

/// A round button over the artwork: translucent black with a white icon,
/// then the page's own ink once the artwork has scrolled away.
class DetailsRoundButton extends StatelessWidget {
  const DetailsRoundButton({
    required this.icon,
    required this.tooltip,
    required this.onArtwork,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final bool onArtwork;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: onArtwork
            ? const Color(0x61000000)
            : palette.page.withValues(alpha: 0),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        color: onArtwork ? const Color(0xFFFFFFFF) : palette.foreground,
        icon: Icon(icon, size: 22),
      ),
    );
  }
}

/// The main button, full width, with how far in the viewer is under it.
class DetailsPlayButton extends StatelessWidget {
  const DetailsPlayButton({
    required this.label,
    required this.resume,
    required this.busy,
    required this.onPressed,
    super.key,
  });

  final String label;
  final ResumePoint? resume;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final resume = this.resume;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: double.infinity,
          child: PillButton(
            label: label,
            icon: PhosphorIcons.play(PhosphorIconsStyle.fill),
            primary: true,
            busy: busy,
            height: 48,
            onPressed: busy ? null : onPressed,
          ),
        ),
        if (resume != null) ...<Widget>[
          const SizedBox(height: AppSpace.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: resume.progress,
                    minHeight: 3,
                    backgroundColor: palette.idleFill,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Text(
                tr('time_left', namedArgs: <String, String>{
                  'time': formatRuntime(Duration(seconds: resume.remaining)),
                }),
                style: AppType.metadata.copyWith(color: palette.mutedText),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A full-width secondary button under the main one: Download.
class DetailsSecondaryButton extends StatelessWidget {
  const DetailsSecondaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpace.sm),
        child: SizedBox(
          width: double.infinity,
          child: PillButton(
            label: label,
            icon: icon,
            height: 48,
            onPressed: onPressed,
          ),
        ),
      );
}

/// A details page's facts on one line, " · " between them: a year, a
/// rating with its star drawn as an icon (Figtree has none), a runtime.
class FactsLine extends StatelessWidget {
  const FactsLine({required this.facts, this.rating, super.key});

  /// Shown in order; the rating goes after the first when there is one.
  final List<String> facts;
  final double? rating;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final style = AppType.metadata.copyWith(
      color: palette.mutedText,
      fontSize: 13,
    );
    final rating = this.rating ?? 0;
    final parts = <List<InlineSpan>>[
      for (final fact in facts.take(1)) <InlineSpan>[TextSpan(text: fact)],
      if (rating > 0)
        <InlineSpan>[
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 3),
              child: Icon(
                PhosphorIcons.star(PhosphorIconsStyle.fill),
                size: 12,
                color: palette.mutedText,
              ),
            ),
          ),
          TextSpan(text: rating.toStringAsFixed(1)),
        ],
      for (final fact in facts.skip(1)) <InlineSpan>[TextSpan(text: fact)],
    ];
    return Text.rich(
      TextSpan(
        style: style,
        children: <InlineSpan>[
          for (var i = 0; i < parts.length; i++) ...<InlineSpan>[
            if (i > 0) const TextSpan(text: ' · '),
            ...parts[i],
          ],
        ],
      ),
    );
  }
}
