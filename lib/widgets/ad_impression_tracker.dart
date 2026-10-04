import 'dart:async';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Measures continuous foreground visibility of a successfully loaded creative.
class AdImpressionTracker extends StatefulWidget {
  const AdImpressionTracker(
      {required this.onImpression, required this.child, super.key});
  final VoidCallback onImpression;
  final Widget child;
  @override
  State<AdImpressionTracker> createState() => _AdImpressionTrackerState();
}

class _AdImpressionTrackerState extends State<AdImpressionTracker>
    with WidgetsBindingObserver {
  final _visibilityKey = UniqueKey();
  Timer? _timer;
  bool _visible = false, _reported = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _update();
  }

  bool get _eligible =>
      _visible && _foreground && (ModalRoute.of(context)?.isCurrent ?? true);
  void _update() {
    if (_reported) return;
    if (!_eligible) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer(const Duration(seconds: 1), () {
      _timer = null;
      if (!mounted || !_eligible || _reported) return;
      _reported = true;
      widget.onImpression();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => VisibilityDetector(
        key: _visibilityKey,
        onVisibilityChanged: (info) {
          _visible = info.visibleFraction >= .5;
          _update();
        },
        child: widget.child,
      );
}
