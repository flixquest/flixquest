import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/app_dependency_provider.dart';
import 'ad_block_gate.dart';

/// Lives under the home route's Overlay so WebView checks can finish while
/// the viewer browses. Warmup never opens the blocker prompt.
class AdBlockWarmup extends StatefulWidget {
  const AdBlockWarmup(
      {required this.child, this.gate, this.networkChanges, super.key});
  final Widget child;
  final AdBlockGate? gate;
  final Stream<List<ConnectivityResult>>? networkChanges;

  @override
  State<AdBlockWarmup> createState() => _AdBlockWarmupState();
}

class _AdBlockWarmupState extends State<AdBlockWarmup>
    with WidgetsBindingObserver {
  late final AdBlockGate _gate = widget.gate ?? AdBlockGate.instance;
  StreamSubscription<List<ConnectivityResult>>? _network;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _network = (widget.networkChanges ?? Connectivity().onConnectivityChanged)
        .listen((_) {
      _gate.invalidate(forgetPopups: true);
      _schedule();
    }, onError: (Object _) {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.watch<AppDependencyProvider>();
    _schedule();
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      final state = WidgetsBinding.instance.lifecycleState;
      if (mounted && (state == null || state == AppLifecycleState.resumed)) {
        unawaited(_gate.warmUp(context));
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _gate.invalidate();
    if (state == AppLifecycleState.resumed) _schedule();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_network?.cancel());
    _gate.invalidate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
