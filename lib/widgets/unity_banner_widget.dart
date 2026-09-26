import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

import '../provider/app_dependency_provider.dart';
import '../services/unity_ads_service.dart';

/// A wrapper widget for [UnityBannerAd] that adapts to FlixQuest's theme,
/// layout constraints, and handles silent failure when ads fail to load or fill.
class UnityBannerWidget extends StatefulWidget {
  const UnityBannerWidget({
    required this.placement,
    this.placementId,
    this.size = BannerSize.standard,
    super.key,
  });

  /// Surface identifier where this banner is displayed (e.g. 'movie_list', 'tv_detail').
  final String placement;

  /// Optional specific placement ID. If null or empty, uses the provider's configured ID.
  final String? placementId;

  /// The size format of the Unity banner. Defaults to [BannerSize.standard] (320x50).
  final BannerSize size;

  @override
  State<UnityBannerWidget> createState() => _UnityBannerWidgetState();
}

class _UnityBannerWidgetState extends State<UnityBannerWidget> {
  bool _isLoaded = false;
  bool _hasFailed = false;

  @override
  void initState() {
    super.initState();
    _ensureInitialized();
  }

  void _ensureInitialized() {
    final dependencies = context.read<AppDependencyProvider>();
    if (!UnityAdsService.instance.isInitialized &&
        !UnityAdsService.instance.isInitializing) {
      UnityAdsService.instance.initialize(
        gameId: dependencies.unityGameIdAndroid,
        testMode: dependencies.unityTestMode,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasFailed) {
      // User requirement: fail silently
      return const SizedBox.shrink();
    }

    final dependencies = context.watch<AppDependencyProvider>();
    final effectivePlacementId = widget.placementId?.trim().isNotEmpty == true
        ? widget.placementId!.trim()
        : dependencies.unityBannerPlacementId;

    if (effectivePlacementId.isEmpty) {
      return const SizedBox.shrink();
    }

    final adWidget = ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(
        width: widget.size.width.toDouble(),
        height: widget.size.height.toDouble(),
        child: UnityBannerAd(
          placementId: effectivePlacementId,
          size: widget.size,
          onLoad: (placementId) {
            if (mounted) {
              setState(() {
                _isLoaded = true;
                _hasFailed = false;
              });
            }
          },
          onClick: (placementId) {
            debugPrint(
                'UnityBannerWidget: Ad clicked ($placementId) on surface ${widget.placement}');
          },
          onShown: (placementId) {
            debugPrint(
                'UnityBannerWidget: Ad shown ($placementId) on surface ${widget.placement}');
          },
          onFailed: (placementId, error, errorMessage) {
            debugPrint(
              'UnityBannerWidget: Ad failed ($placementId) on surface ${widget.placement}: $error - $errorMessage',
            );
            if (mounted) {
              setState(() {
                _hasFailed = true;
              });
            }
          },
        ),
      ),
    );

    return Padding(
      padding: _isLoaded
          ? const EdgeInsets.fromLTRB(20, 10, 20, 6)
          : EdgeInsets.zero,
      child: Center(child: adWidget),
    );
  }
}
