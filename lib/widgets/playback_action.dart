import 'dart:async';

import 'package:flutter/material.dart';

/// Gives a playback entry point immediate feedback and keeps all playback
/// actions on its route from opening overlapping loaders while it awaits work.
class PlaybackAction extends StatefulWidget {
  const PlaybackAction({
    required this.onStart,
    required this.builder,
    super.key,
  });

  final FutureOr<void> Function() onStart;
  final Widget Function(BuildContext context, bool busy, VoidCallback start)
      builder;

  static final _pending = Expando<bool>('pending playback');

  /// The lock is taken synchronously, before connectivity, metadata, ads, or
  /// configuration can yield. Inactive routes cannot start another player.
  static Future<void> run(
    BuildContext context,
    FutureOr<void> Function() action,
  ) async {
    if (!context.mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    final owner = route ?? Navigator.of(context);
    if (_pending[owner] == true) return;
    _pending[owner] = true;
    try {
      await action();
    } finally {
      _pending[owner] = null;
    }
  }

  @override
  State<PlaybackAction> createState() => _PlaybackActionState();
}

class _PlaybackActionState extends State<PlaybackAction> {
  bool _busy = false;

  Future<void> _start() async {
    if (_busy || !mounted) return;
    await PlaybackAction.run(context, () async {
      setState(() => _busy = true);
      try {
        await widget.onStart();
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _busy, _start);
}
