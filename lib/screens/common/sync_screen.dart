import '../../data/sync/sync_runtime.dart';
import '../../data/sync/sync_runner.dart';
import '../../design/app_palette.dart';
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
    final session = AuthRuntime.session;
    final coordinator = SyncRuntime.coordinator;
    if (!SyncRuntime.enabled || coordinator == null || session.user == null) {
      final guest = session.user == null;
      return Scaffold(appBar: const PageAppBar(title: 'Sync'), body: EmptyState(
        icon: PhosphorIcons.cloudSlash(), title: 'Your library is saved on this device',
        message: guest ? 'Sign in to sync your library across devices.' : 'Cloud sync is currently unavailable.',
        actionLabel: guest ? 'Sign in' : null,
        onAction: guest ? () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const LoginScreen())) : null,
      ));
    }
    final runners = [coordinator.bookmarks, coordinator.recents, coordinator.wellnessSync];
    return Scaffold(appBar: const PageAppBar(title: 'Sync'), body: AnimatedBuilder(
      animation: Listenable.merge([session, for (final runner in runners) runner.status, for (final runner in runners) runner.lastSynced]),
      builder: (context, _) {
        final busy = runners.any((runner) => runner.status.value == 'syncing');
        return ListView(padding: const EdgeInsets.all(20), children: [
          Text('Keep your library up to date on all your devices.', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 20),
          _syncTile(context, 'Bookmarks', coordinator.bookmarks),
          _syncTile(context, 'Continue watching', coordinator.recents),
          _syncTile(context, 'Viewing insights', coordinator.wellnessSync),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.sync), label: Text(busy ? 'Syncing…' : 'Sync now'),
            onPressed: busy || session.user == null ? null : () async {
              final success = await coordinator.syncAll();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
                success ? 'Your library is up to date.' : 'Could not sync. Your changes are saved on this device.')));
            },
          ),
        ]);
      },
    ));
  }
  Widget _syncTile(BuildContext context, String title, SyncRunner runner) {
    final stamp = runner.lastSynced.value?.toLocal();
    final message = switch (runner.status.value) {
      'syncing' => 'Syncing…',
      'error' => 'Waiting to retry',
      _ => stamp == null ? 'Ready to sync' : 'Last synced ${stamp.toString().split('.').first}',
    };
    return ListTile(contentPadding: EdgeInsets.zero, title: Text(title), subtitle: Text(message),
        trailing: runner.status.value == 'syncing' ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppPalette.of(context).mutedText)) : null);
  }
}

class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});
  @override
  Widget build(BuildContext context) => AuthRuntime.enabled
      ? const LaravelSyncScreen() : const legacy.SyncScreen();
}
