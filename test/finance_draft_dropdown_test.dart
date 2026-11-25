import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budowa_group/hours_entry_form.dart';

void main() {
  testWidgets('finance operations use reference dropdowns and object colors',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: FinanceTabDraftForm(
      tab: 'Операції',
      options: const {2: ['Тестовий покупець'], 6: ['Тестова категорія'],
        7: ['Тестовий об’єкт']},
      objectColor: (_) => Colors.orange,
    )));
    final dropdowns = find.byType(DropdownButtonFormField<String>);
    expect(dropdowns, findsNWidgets(4));
    await tester.tap(dropdowns.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Тестовий покупець').last);
    await tester.pumpAndSettle();
    expect(find.text('Тестовий покупець'), findsWidgets);
    await tester.ensureVisible(dropdowns.at(1));
    await tester.tap(dropdowns.at(1));
    await tester.pumpAndSettle();
    final income = find.text('Надходження').last;
    final expense = find.text('Витрати').last;
    expect(tester.widget<Text>(income).style?.color, const Color(0xFF176B4D));
    expect(tester.widget<Text>(expense).style?.color, const Color(0xFFAD3C32));
    await tester.tap(expense);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
