import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../catalog/media_item.dart';
import '../catalog/title_logos.dart';
import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import '../functions/function.dart';
import '../provider/app_dependency_provider.dart';
import '../provider/settings_provider.dart';

/// [item]'s logo artwork from TMDB, or [fallback] (its name as text) until the
/// logo is found, or when it has none.
///
/// Logos are drawn in the space the text would take, left aligned and never
/// wider than the spotlight, so a wide wordmark and a stacked one read at a
/// similar size.
class TitleLogo extends StatefulWidget {
  const TitleLogo({
    required this.item,
    required this.maxHeight,
    required this.fallback,
    this.settleDelay = Duration.zero,
    this.alignment = Alignment.bottomLeft,
    super.key,
  });

  final MediaItem item;
  final double maxHeight;
  final Widget fallback;

  /// How long [item] must stay put before its logo is looked up. A logo
  /// already found shows at once.
  final Duration settleDelay;

  /// Where the logo sits in its box; the TV sets it bottom left, under the
  /// spotlight's text.
  final AlignmentGeometry alignment;

  @override
  State<TitleLogo> createState() => _TitleLogoState();
}

class _TitleLogoState extends State<TitleLogo> {
  /// Sharp enough at the billboard's size on a 1080p panel, and a fraction of
  /// `original`.
  static const _imageSize = 'w500';

  TitleLogos? _logos;
  String? _path;
  Timer? _settleTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final logos = TitleLogoScope.maybeOf(context);
    if (!identical(logos, _logos)) {
      _logos = logos;
      _lookUp();
    }
  }

  @override
  void didUpdateWidget(TitleLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.kind != widget.item.kind ||
        oldWidget.item.id != widget.item.id) {
      _lookUp();
    }
  }

  void _lookUp() {
    _settleTimer?.cancel();
    final logos = _logos;
    final item = widget.item;
    _path = logos != null && logos.isKnown(item) ? logos.known(item) : null;
    if (logos == null || logos.isKnown(item)) return;
    void resolve() {
      logos.resolve(item).then((path) {
        if (!mounted || path == null) return;
        if (!identical(widget.item, item) || !identical(_logos, logos)) return;
        setState(() => _path = path);
      });
    }

    if (widget.settleDelay == Duration.zero) {
      resolve();
    } else {
      _settleTimer = Timer(widget.settleDelay, resolve);
    }
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = _path;
    if (path == null) return widget.fallback;
    final settings = context.watch<SettingsProvider>();
    final proxy = context.watch<AppDependencyProvider>().tmdbProxy;
    final baseUrl = buildImageUrl(
      TMDB_BASE_IMAGE_URL,
      proxy,
      settings.enableProxy,
      context,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = math.min(constraints.maxWidth, widget.maxHeight * 5);
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: widget.maxHeight,
          ),
          child: CachedNetworkImage(
            cacheManager: cacheProp(),
            imageUrl: '$baseUrl$_imageSize$path',
            memCacheWidth:
                (maxWidth * MediaQuery.devicePixelRatioOf(context)).round(),
            fit: BoxFit.contain,
            alignment: widget.alignment.resolve(Directionality.of(context)),
            fadeInDuration: const Duration(milliseconds: 220),
            fadeOutDuration: Duration.zero,
            // The name holds the space until the artwork has decoded, and
            // stays if it never does.
            placeholder: (_, __) => widget.fallback,
            errorWidget: (_, __, ___) => widget.fallback,
            imageBuilder: (_, image) => Semantics(
              label: widget.item.title,
              image: true,
              child: Image(
                image: image,
                fit: BoxFit.contain,
                alignment: widget.alignment,
              ),
            ),
          ),
        );
      },
    );
  }
}
