import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budowa_group/admin_pin_screen.dart';

void main() {
  testWidgets('password is obscured and submitted only to verifier', (tester) async {
    String? received;
    await tester.pumpWidget(MaterialApp(home: AdminPinScreen(
      adminEmail: 'test@example.invalid',
      verify: (value) async { received = value; },
    )));
    expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isTrue);
    await tester.enterText(find.byType(TextField), 'unit-test-secret-123*');
    expect(find.byWidgetPredicate((w) =>
      w is Text && w.data == 'unit-test-secret-123*'), findsNothing);
    await tester.tap(find.text('Підтвердити'));
    await tester.pump();
    expect(received, 'unit-test-secret-123*');
  });
  testWidgets('invalid password displays only a generic error', (tester) async {
    await tester.pumpWidget(MaterialApp(home: AdminPinScreen(
      adminEmail: 'test@example.invalid',
      verify: (_) async { throw Exception('ADMIN_PIN_INVALID'); },
    )));
    await tester.enterText(find.byType(TextField), 'fake-wrong-test-code');
    await tester.tap(find.text('Підтвердити'));
    await tester.pump();
    expect(find.text('Неправильний пароль адміністратора.'), findsOneWidget);
    expect(find.byWidgetPredicate((w) =>
      w is Text && w.data == 'fake-wrong-test-code'), findsNothing);
  });
}
