import 'package:budowa_group/app_navigation_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('navigation fails explicitly before MaterialApp is attached', () {
    final navigation = AppNavigationController();
    expect(
      () => navigation.push<void>(const SizedBox()),
      throwsStateError,
    );
  });

  testWidgets(
    'root State can open a diagnostic route and receive its pop result',
    (tester) async {
      await tester.pumpWidget(const _RootHarness());
      await tester.tap(find.text('Перевірити всі 9 вкладок (читання)'));
      await tester.pumpAndSettle();

      expect(find.text('Діагностика TEST'), findsOneWidget);
      await tester.tap(find.text('Готово'));
      await tester.pumpAndSettle();

      expect(find.text('Повернулися'), findsOneWidget);
      expect(find.text('Діагностика TEST'), findsNothing);
    },
  );

  testWidgets('root State can show a snackbar', (tester) async {
    await tester.pumpWidget(const _RootHarness());
    await tester.tap(find.text('Показати повідомлення'));
    await tester.pump();
    expect(find.text('TEST-запис збережено.'), findsOneWidget);
  });
}

class _RootHarness extends StatefulWidget {
  const _RootHarness();

  @override
  State<_RootHarness> createState() => _RootHarnessState();
}

/// Mirrors BudowaApp: the State that invokes navigation builds MaterialApp.
class _RootHarnessState extends State<_RootHarness> {
  final navigation = AppNavigationController();
  bool returned = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigation.navigatorKey,
      scaffoldMessengerKey: navigation.scaffoldMessengerKey,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () async {
                  final result = await navigation.push<bool>(
                    const _DiagnosticsProbe(),
                  );
                  if (mounted && result == true) {
                    setState(() => returned = true);
                  }
                },
                child: const Text('Перевірити всі 9 вкладок (читання)'),
              ),
              ElevatedButton(
                onPressed: () => navigation.showMessage('TEST-запис збережено.'),
                child: const Text('Показати повідомлення'),
              ),
              if (returned) const Text('Повернулися'),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiagnosticsProbe extends StatelessWidget {
  const _DiagnosticsProbe();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Діагностика TEST')),
        body: Center(
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Готово'),
          ),
        ),
      );
}
