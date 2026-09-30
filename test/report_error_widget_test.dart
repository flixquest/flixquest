import 'package:flixquest/widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'FLIXQUEST_API_URL=https://example.com');
  });

  const longError =
      'This TV episode could not be found on our servers, try another one :(';

  // The `.icon` constructors build private subclasses, so match on the base
  // type rather than the exact runtime type.
  final retryButton = find.byWidgetPredicate((widget) => widget is FilledButton);
  final reportButton =
      find.byWidgetPredicate((widget) => widget is OutlinedButton);

  testWidgets('fits the error sheet in a compact landscape viewport',
      (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReportErrorWidget(
            error: longError,
            hideButton: false,
            onRetry: _noop,
          ),
        ),
      ),
    );

    expect(find.text(longError), findsOneWidget);
    expect(retryButton, findsOneWidget);
    expect(reportButton, findsOneWidget);
  });

  testWidgets('hides the report action when the caller asks for it',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReportErrorWidget(error: longError, hideButton: true),
        ),
      ),
    );

    expect(reportButton, findsNothing);
    expect(retryButton, findsNothing);
  });

  testWidgets('shows the installed app version, not a hardcoded one',
      (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'FlixQuest',
      packageName: 'com.test.fq',
      version: '9.9.9',
      buildNumber: '1',
      buildSignature: '',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReportErrorWidget(error: longError, hideButton: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('v9.9.9'), findsOneWidget);
  });

  testWidgets('retry closes the sheet and notifies the caller', (tester) async {
    var retries = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ReportErrorWidget.show(
                context,
                error: longError,
                onRetry: () => retries++,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(ReportErrorWidget), findsOneWidget);

    await tester.tap(retryButton);
    await tester.pumpAndSettle();

    expect(retries, 1);
    expect(find.byType(ReportErrorWidget), findsNothing);
  });
}

void _noop() {}
