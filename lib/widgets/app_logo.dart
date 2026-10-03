import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dio/dio.dart';

import '../core/cache/cache_policy.dart';
import '../core/network/network_runtime.dart';
import 'package:provider/provider.dart';
import 'package:xml/xml.dart';

import '../provider/app_dependency_provider.dart';

@visibleForTesting
bool isValidRemoteLogoSvg(String source) {
  if (source.isEmpty) return false;
  try {
    final document = XmlDocument.parse(source);
    return document.rootElement.name.local.toLowerCase() == 'svg';
  } catch (_) {
    return false;
  }
}

/// Displays the Remote Config logo when available and a bundled asset when it
/// is not. Seasonal theme logos take precedence over the general app logo.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.fallbackAsset = 'assets/images/logo.png',
    this.fallbackColor,
  });

  final double? width;
  final double? height;
  final BoxFit fit;
  final String fallbackAsset;
  final Color? fallbackColor;

  @override
  Widget build(BuildContext context) {
    final logoUrl = context.select<AppDependencyProvider, String>(
      (provider) => provider.effectiveLogoUrl,
    );
    final uri = Uri.tryParse(logoUrl);
    final canLoadRemote = uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;

    if (!canLoadRemote) return _fallback();

    final path = uri.path.toLowerCase();
    if (path.endsWith('.svg')) {
      return _SafeRemoteSvg(
        uri: uri,
        width: width,
        height: height,
        fit: fit,
        fallback: _fallback,
      );
    }

    return CachedNetworkImage(
      imageUrl: logoUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, __) => _fallback(),
      errorWidget: (_, __, ___) => _fallback(),
    );
  }

  Widget _fallback() {
    if (fallbackAsset.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(
        fallbackAsset,
        width: width,
        height: height,
        fit: fit,
        colorFilter: fallbackColor == null
            ? null
            : ColorFilter.mode(fallbackColor!, BlendMode.srcIn),
      );
    }
    return Image.asset(
      fallbackAsset,
      width: width,
      height: height,
      fit: fit,
      color: fallbackColor,
    );
  }
}

/// Downloads and validates remote SVG XML before handing it to flutter_svg.
/// This prevents HTML error pages, placeholder values, and malformed files
/// from reaching the asynchronous vector compiler as uncaught exceptions.
class _SafeRemoteSvg extends StatefulWidget {
  const _SafeRemoteSvg({
    required this.uri,
    required this.fit,
    required this.fallback,
    this.width,
    this.height,
  });

  final Uri uri;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function() fallback;

  @override
  State<_SafeRemoteSvg> createState() => _SafeRemoteSvgState();
}

class _SafeRemoteSvgState extends State<_SafeRemoteSvg> {
  static const _maximumLogoBytes = 1024 * 1024;
  late Future<String?> _svg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_SafeRemoteSvg oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri) _load();
  }

  void _load() {
    _svg = _fetchSvg(widget.uri);
  }

  static Future<String?> _fetchSvg(Uri uri) async {
    try {
      final response = await NetworkRuntime.publicDio.get<List<int>>(uri.toString(),
          options: Options(responseType: ResponseType.bytes,
            receiveTimeout: const Duration(seconds: 12),
            extra: {'cachePolicy': CachePolicy.logo}));
      if ((response.statusCode ?? 0) < 200 || (response.statusCode ?? 0) >= 300) return null;
      final bytes = response.data ?? const <int>[];
      if (bytes.isEmpty || bytes.length > _maximumLogoBytes) return null;
      final source = utf8.decode(bytes, allowMalformed: false).trim();
      return isValidRemoteLogoSvg(source) ? source : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _svg,
      builder: (context, snapshot) {
        final source = snapshot.data;
        if (source == null) return widget.fallback();
        return SvgPicture.string(
          source,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          placeholderBuilder: (_) => widget.fallback(),
          errorBuilder: (_, __, ___) => widget.fallback(),
        );
      },
    );
  }
}
