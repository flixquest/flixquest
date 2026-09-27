import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/banner_ad.dart';
import '../provider/app_dependency_provider.dart';
import 'start_io_banner_widget.dart';

/// Kept for source compatibility with the existing banner call sites.
enum HostedBannerVariant { standard, tall }

/// Compatibility wrapper for the former hosted/Unity banner surface.
///
/// Existing `native` and `unity` values both select Start.io. A remotely
/// configured `none` still hides banners, preserving the old kill switch.
class RemoteHostedAdsBanner extends StatelessWidget {
  const RemoteHostedAdsBanner({
    required this.loadAds,
    required this.placement,
    this.variant = HostedBannerVariant.standard,
    super.key,
  });

  /// Retained so callers compiled against the hosted-banner API do not need to
  /// change. Start.io supplies the banner and this callback is not invoked.
  final Future<List<BannerAd>> Function() loadAds;
  final String placement;
  final HostedBannerVariant variant;

  @override
  Widget build(BuildContext context) {
    final dependencies = context.watch<AppDependencyProvider?>();
    if (dependencies == null || !dependencies.isStartIoBannerActive) {
      return const SizedBox.shrink();
    }
    return StartIoBannerWidget(
      placement: placement,
      testMode: dependencies.unityTestMode,
      variant: variant == HostedBannerVariant.tall
          ? StartIoBannerVariant.tall
          : StartIoBannerVariant.standard,
    );
  }
}
