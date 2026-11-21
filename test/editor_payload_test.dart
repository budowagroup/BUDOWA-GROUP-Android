import 'package:flutter_test/flutter_test.dart';
import 'package:budowa_group/sheet_record_editor.dart';

void main() {
  test('expected values use the actual editable column numbers', () {
    final fields = testFields('finance', 'Операції');
    final source = <String>[
      '', '21.11.2026', 'Ігор', '1,588.00', 'Витрати',
      'Повний опис', 'Матеріали', 'Rembertow Rafal', 'FV/2026/1'
    ];

    final expected = expectedEditableFields(fields, source);
    expect(expected.keys.toSet(), equals({'1','2','3','4','5','6','7','8'}));
    expect(expected['1'], '21.11.2026');
    expect(expected['3'], '1,588.00');
    expect(expected['8'], 'FV/2026/1');
    expect(expected.containsKey('undefined'), isFalse);
  });

  test('work hours expected values skip computed columns', () {
    final source = <String>[
      '20.11.2026', 'Тестовий працівник', 'Rembertow Rafal', '07:00',
      '17:00', '0,50', '9,50', '35,00 zł', '332,50 zł',
      '10,00 zł', 'ЛИСТОПАД 2026', '0,00 zł', '', '322,50 zł', '',
    ];
    final expected = expectedEditableFields(
        testFields('hours', 'Робочі години'), source);
    expect(expected.keys.toSet(), equals(
        {'0','1','2','3','4','5','9','10','11','12','14'}));
    expect(expected['5'], '0,50');
    expect(expected['9'], '10,00 zł');
    expect(expected.containsKey('6'), isFalse);
    expect(expected.containsKey('7'), isFalse);
    expect(expected.containsKey('8'), isFalse);
    expect(expected.containsKey('13'), isFalse);
  });

  test('verbatim values are preserved to detect concurrent updates', () {
    final fields = testFields('hours', 'Працівники');
    final expected = expectedEditableFields(
      fields, ['Тест', 'Майстер  ', '40,00 zł', 'Так', ''] );
    expect(expected['1'], 'Майстер  ');
    expect(expected['0'], 'Тест');
  });

  test('sorting does not lose the physical source spreadsheet row', () {
    final older = <String>['01.11.2026', 'Ігор'];
    final newer = <String>['21.11.2026', 'Роман'];
    final source = <List<String>>[older, newer];
    final physicalRows = <int>[17, 275];
    final newestFirst = source.reversed.toList();
    expect(sourceSheetRowForRecord(source, physicalRows, newestFirst.first), 275);
    expect(sourceSheetRowForRecord(source, physicalRows, newestFirst.last), 17);
  });

  test('non-source records cannot be edited', () {
    final source = <List<String>>[
      ['21.11.2026', 'Ігор'],
    ];
    expect(sourceSheetRowForRecord(source, [42], ['21.11.2026', 'Ігор']), isNull);
    expect(sourceSheetRowForRecord(source, [], source.first), isNull);
  });
}
