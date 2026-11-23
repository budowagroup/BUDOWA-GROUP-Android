import 'package:flutter_test/flutter_test.dart';
import 'package:budowa_group/read_only_diagnostics.dart';

void main() {
  test('exactly nine unique tabs with correct first data rows', () {
    expect(readOnlyTabs.length, 9);
    expect(readOnlyTabs.where((tab) => tab.book == 'hours').length, 5);
    expect(readOnlyTabs.where((tab) => tab.book == 'finance').length, 4);
    expect(readOnlyTabs.map((tab) => '${tab.book}:${tab.tab}').toSet().length, 9);
    expect(readOnlyTabs.singleWhere((t) => t.tab == 'Розрахунок').firstDataRow, 5);
    expect(readOnlyTabs.singleWhere((t) => t.tab == 'Панель').firstDataRow, 3);
  });

  test('diagnostic payloads only read one row, never write', () {
    for (final tab in readOnlyTabs) {
      final payload = readOnlyPayload(tab);
      expect(payload['action'], 'read');
      expect(payload['book'], tab.book);
      expect(payload['tab'], tab.tab);
      expect(payload['start'], tab.firstDataRow);
      expect(payload['limit'], 1);
      expect(payload.length, 5);
      expect(payload.containsKey('values'), isFalse);
    }
  });

  test('nine successful reads are reported in order', () async {
    var reads = 0;
    final progress = <int>[];
    final result = await checkReadOnlyTabs((tab) async {
      reads += 1;
      return <String, dynamic>{'ok': true, 'rows': [['Тест']]};
    }, onChecked: (done, _) => progress.add(done));
    expect(reads, 9);
    expect(result.length, 9);
    expect(result.every((r) => r.accessible && r.containsValues), isTrue);
    expect(progress, [1, 2, 3, 4, 5, 6, 7, 8, 9]);
  });

  test('one read failure never prevents checks for other tabs', () async {
    final result = await checkReadOnlyTabs((tab) async {
      if (tab.tab == 'Операції') throw Exception('FORBIDDEN');
      return <String, dynamic>{'ok': true, 'rows': []};
    });
    expect(result.length, 9);
    expect(result.where((r) => !r.accessible).length, 1);
    expect(result.singleWhere((r) => !r.accessible).errorCode, 'FORBIDDEN');
    expect(result.where((r) => r.accessible).length, 8);
    expect(result.where((r) => r.accessible).every((r) => !r.containsValues), isTrue);
  });

  test('malformed responses are not displayed as success', () async {
    final result = await checkReadOnlyTabs((tab) async =>
        <String, dynamic>{'ok': true, 'rows': [{'wrong': 'shape'}]});
    expect(result.every((r) => !r.accessible), isTrue);
  });
}
