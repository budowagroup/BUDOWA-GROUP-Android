import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budowa_group/sheet_presentation.dart';

void main() {
  test('legacy API uses verified spreadsheet snapshot', () {
    final style = SheetPresentation.fromResponse({'ok': true});
    expect(style.live, isFalse);
    expect(style.objectColor('Stare Babice Grzegorz'), const Color(0xFFE8EAED));
    expect(style.operationColor('Витрати'), Colors.white);
  });

  test('server metadata replaces snapshot colors and month choices', () {
    final style = SheetPresentation.fromResponse({'presentation': {
      'objectColors': {'New project': '#123456'},
      'operationColors': {'Надходження': '#D9EAD3','Витрати':'#FFFFFF'},
      'buyerColors': {'Test buyer':'#AABBCC'},
      'categoryColors': {'Test category':'#CCDDEE'},
      'advanceMonths': ['СІЧЕНЬ 2027'],
      'paymentMonths': ['ЛЮТИЙ 2027'],
    }});
    expect(style.live, isTrue);
    expect(style.objectColor('New project'), const Color(0xFF123456));
    expect(style.financeColor(2, 'Test buyer'), const Color(0xFFAABBCC));
    expect(style.financeColor(6, 'Test category'), const Color(0xFFCCDDEE));
    expect(style.advanceMonths, ['СІЧЕНЬ 2027']);
    expect(style.paidMonths, ['ЛЮТИЙ 2027']);
    expect(style.objectColor('Legionowo Michał'), Colors.white);
  });
}
