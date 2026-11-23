import 'package:flutter_test/flutter_test.dart';
import 'package:budowa_group/edit_reference_data.dart';

void main() {
  test('work hours use employees and projects from their real tabs', () {
    final specs = lookupSpecsFor('hours', 'Робочі години');
    expect(specs.map((s) => s.formColumn).toList(), [1, 2]);
    expect(specs.map((s) => s.tab).toList(), ['Працівники', 'Обʼєкти']);
  });

  test('financial operations use buyer and two distinct directory columns', () {
    final specs = lookupSpecsFor('finance', 'Операції');
    expect(specs.map((s) => s.formColumn).toList(), [2, 6, 7]);
    expect(specs.map((s) => s.sourceColumn).toList(), [0, 0, 1]);
  });

  test('read-only reference calls never send a write action', () {
    final req = lookupReadRequest('hours', 'Працівники', 4);
    expect(req['action'], 'read');
    expect(req['limit'], 100);
    expect(req.containsKey('values'), false);
  });

  test('reference values are unique and exact while tabs are cached', () async {
    var requests = 0;
    final choices = await loadLookupOptions('finance', 'Операції', (payload) async {
      requests++;
      final tab = payload['tab'];
      final start = payload['start'];
      if (start != 4) return {'ok': true, 'rows': []};
      if (tab == 'Закупівельники') return {
        'ok': true, 'rows': [['Ігор'], ['Ігор'], ['Роман']]
      };
      return {
        'ok': true, 'rows': [
          ['Матеріали', 'Łomianki'],
          ['Інструменти', 'Rembertow'],
          ['Матеріали', 'Łomianki'],
        ]
      };
    });
    expect(requests, 2);
    expect(choices[2], ['Ігор', 'Роман']);
    expect(choices[6], ['Матеріали', 'Інструменти']);
    expect(choices[7], ['Łomianki', 'Rembertow']);
  });

  test('empty mandatory reference is never accepted', () async {
    expect(
      () => loadLookupOptions('hours', 'Робочі години', (_) async =>
          {'ok': true, 'rows': []}),
      throwsFormatException,
    );
  });

  test('malformed references fail closed before form submission', () async {
    expect(
      () => loadLookupOptions('hours', 'Історія ставок', (_) async =>
          {'ok': true, 'rows': [{'invalid': 'shape'}]}),
      throwsFormatException,
    );
  });

  test('rate history only uses employee dropdown', () {
    final specs = lookupSpecsFor('hours', 'Історія ставок');
    expect(specs.single.formColumn, 0);
  });
}
