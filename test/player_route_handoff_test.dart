import 'package:flixquest/functions/player_route_handoff.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('player handoff disposes the loader and returns to its parent',
      (tester) async {
    var loaderDisposals = 0;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => _Loader(
                  onDispose: () => loaderDisposals++,
                ),
              ),
            ),
            child: const Text('Open loader'),
          );
        }),
      ),
    ));

    await tester.tap(find.text('Open loader'));
    await tester.pumpAndSettle();
    expect(find.text('Loading sources'), findsOneWidget);

    await tester.tap(find.text('Open player'));
    await tester.pump();

    expect(find.text('Player'), findsOneWidget);
    expect(find.text('Loading sources'), findsNothing);
    expect(loaderDisposals, 1);

    await tester.tap(find.text('Close player'));
    await tester.pumpAndSettle();

    expect(find.text('Open loader'), findsOneWidget);
    expect(find.text('Loading sources'), findsNothing);
  });
}

class _Loader extends StatefulWidget {
  const _Loader({required this.onDispose});

  final VoidCallback onDispose;

  @override
  State<_Loader> createState() => _LoaderState();
}

class _LoaderState extends State<_Loader> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(
          children: [
            const Text('Loading sources'),
            TextButton(
              onPressed: () => handoffLoaderToPlayer<void>(
                context,
                (context) => Scaffold(
                  body: Column(
                    children: [
                      const Text('Player'),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close player'),
                      ),
                    ],
                  ),
                ),
              ),
              child: const Text('Open player'),
            ),
          ],
        ),
      );
}
