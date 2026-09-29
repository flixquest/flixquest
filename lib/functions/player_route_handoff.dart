import 'package:flutter/material.dart';

/// Opens the player and removes its loading route in the same navigation step.
///
/// A player can start rendering video before an animated replacement finishes.
/// Removing the loader immediately prevents its artwork and source panel from
/// remaining in the navigator underneath the video surface on Android TV.
Future<T?> handoffLoaderToPlayer<T extends Object?>(
  BuildContext context,
  WidgetBuilder playerBuilder,
) {
  final navigator = Navigator.of(context);
  final loaderRoute = ModalRoute.of(context);
  if (loaderRoute == null) {
    throw StateError('Player handoff requires a loading route.');
  }
  final playerResult = navigator.push<T>(
    PageRouteBuilder<T>(
      pageBuilder: (context, _, __) => playerBuilder(context),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );
  navigator.removeRoute(loaderRoute);
  return playerResult;
}
