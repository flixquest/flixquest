import 'package:flutter/material.dart';
import '../../flixquest_main.dart';
import '../../tv/app/tv_home_shell.dart';
import '../../tv/platform/device_presentation.dart';

class UserState extends StatelessWidget {
  const UserState({required this.devicePresentation, super.key});
  final DevicePresentation devicePresentation;
  @override
  Widget build(BuildContext context) =>
      devicePresentation == DevicePresentation.television
          ? const TvHomeShell()
          : const FlixQuestHomePage();
}
