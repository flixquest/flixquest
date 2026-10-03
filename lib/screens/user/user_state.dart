import '../../presentation/session/auth_runtime.dart';
import '../../presentation/session/session_gate.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../flixquest_main.dart';
import '../../provider/app_dependency_provider.dart';
import '../../services/app_update_service.dart';
import '../../services/auth_session_controller.dart';
import '../../tv/app/tv_home_shell.dart';
import '../../tv/platform/device_presentation.dart';
import '../../tv/platform/tv_debug_options.dart';
import '../../tv/screens/tv_landing_screen.dart';
import '../common/landing_screen.dart';
import '../common/update_screen.dart';

class UserState extends StatefulWidget {
  const UserState({
    required this.devicePresentation,
    super.key,
  });

  final DevicePresentation devicePresentation;

  @override
  State<UserState> createState() => _UserStateState();
}

class _UserStateState extends State<UserState> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    if (widget.devicePresentation == DevicePresentation.handheld) {
      _loadPackageInfo();
    }
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _packageInfo = info);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appDependency = context.watch<AppDependencyProvider>();

    if (widget.devicePresentation == DevicePresentation.handheld &&
        appDependency.isForcedUpdate &&
        _packageInfo != null) {
      final isUpdateAvailable = AppUpdateService.isAvailable(
        packageInfo: _packageInfo!,
        remoteVersion: appDependency.latestAppVersion,
        latestBuildNumber: appDependency.latestBuildNumber,
        minimumBuildNumber: appDependency.minimumBuildNumber,
      );
      if (isUpdateAvailable) {
        return const UpdateScreen(isForced: true);
      }
    }

    final authSession = AuthSessionController.instance..initialize();
    Widget shell(BuildContext context, bool isAuthenticated) {
      final previewTvHome =
          widget.devicePresentation == DevicePresentation.television &&
              TvDebugOptions.previewHomeShell;
      return presentationShellFor(
        devicePresentation: widget.devicePresentation,
        isAuthenticated: isAuthenticated || previewTvHome,
      );
    }
    return AuthRuntime.enabled
        ? SessionGate(session: AuthRuntime.session, builder: shell)
        : AuthStateRouter(userIdListenable: authSession.userId, builder: shell);
  }
}

class AuthStateRouter extends StatelessWidget {
  const AuthStateRouter({
    required this.userIdListenable,
    required this.builder,
    super.key,
  });

  final ValueListenable<String?> userIdListenable;
  final Widget Function(BuildContext context, bool isAuthenticated) builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: userIdListenable,
      builder: (context, userId, _) => KeyedSubtree(
        key: ValueKey(userId ?? 'signed-out'),
        child: builder(context, userId != null),
      ),
    );
  }
}

Widget presentationShellFor({
  required DevicePresentation devicePresentation,
  required bool isAuthenticated,
}) {
  return switch ((devicePresentation, isAuthenticated)) {
    (DevicePresentation.television, true) => const TvHomeShell(),
    (DevicePresentation.television, false) => const TvLandingScreen(),
    (DevicePresentation.handheld, true) => const FlixQuestHomePage(),
    (DevicePresentation.handheld, false) => const LandingScreen(),
  };
}
