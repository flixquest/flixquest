import 'package:flutter/widgets.dart';

import '../provider/settings_provider.dart';
import '../services/device_presentation_service.dart';
import '../tv/platform/device_presentation.dart';

/// Applies the saved app mode and leaves the old interface's routes on a switch.
class AppPresentation extends StatefulWidget {
  const AppPresentation({
    required this.settings,
    required this.detectedPresentation,
    required this.navigatorKey,
    required this.builder,
    super.key,
  });

  final SettingsProvider settings;
  final DevicePresentation detectedPresentation;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget Function(BuildContext, DevicePresentation) builder;

  @override
  State<AppPresentation> createState() => _AppPresentationState();
}

class _AppPresentationState extends State<AppPresentation> {
  late DevicePresentation _presentation;

  void _syncService() {
    DevicePresentationService.instance.isTelevision =
        _presentation == DevicePresentation.television;
  }

  void _onAppModeChanged() {
    final presentation =
        widget.settings.appMode.resolve(widget.detectedPresentation);
    if (presentation == _presentation) return;

    widget.navigatorKey.currentState?.popUntil((route) => route.isFirst);
    setState(() => _presentation = presentation);
    _syncService();
  }

  @override
  void initState() {
    super.initState();
    _presentation =
        widget.settings.appMode.resolve(widget.detectedPresentation);
    _syncService();
    widget.settings.addListener(_onAppModeChanged);
  }

  @override
  void didUpdateWidget(AppPresentation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.settings, widget.settings)) {
      oldWidget.settings.removeListener(_onAppModeChanged);
      widget.settings.addListener(_onAppModeChanged);
    }
    _onAppModeChanged();
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onAppModeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _presentation);
}
