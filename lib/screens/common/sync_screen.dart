import 'package:flixquest/presentation/session/auth_runtime.dart';
import '../../legacy/firebase_auth/screens/common/sync_screen.dart' as legacy;
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../mobile/widgets/page_kit.dart';
import '../user/login_screen.dart';

class LaravelSyncScreen extends StatelessWidget {
  const LaravelSyncScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final guest = AuthRuntime.session.user == null;
    return Scaffold(appBar: const PageAppBar(title: 'Sync'), body: EmptyState(
      icon: PhosphorIcons.cloudSlash(), title: 'Your library is saved on this device',
      message: guest ? 'Sign in to manage your account.' : 'Cloud sync is currently unavailable.',
      actionLabel: guest ? 'Sign in' : null,
      onAction: guest ? () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const LoginScreen())) : null,
    ));
  }
}

class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});
  @override
  Widget build(BuildContext context) => AuthRuntime.enabled
      ? const LaravelSyncScreen() : const legacy.SyncScreen();
}
