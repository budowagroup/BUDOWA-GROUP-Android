/// Reference values for TEST write forms, retrieved from the same authorized
/// Google Apps Script API as all accounting records. No mutation is performed.
class LookupSpec {
  final int formColumn;
  final String book;
  final String tab;
  final int sourceColumn;
  final bool required;

  const LookupSpec(
    this.formColumn, this.book, this.tab, this.sourceColumn, {
    this.required = false,
  });
}

List<LookupSpec> lookupSpecsFor(String book, String tab) {
  if (book == 'hours' && tab == 'Робочі години') {
    return const [
      LookupSpec(1, 'hours', 'Працівники', 0, required: true),
      LookupSpec(2, 'hours', 'Обʼєкти', 0, required: true),
    ];
  }
  if (book == 'hours' && tab == 'Історія ставок') {
    return const [
      LookupSpec(0, 'hours', 'Працівники', 0, required: true),
    ];
  }
  if (book == 'finance' && tab == 'Операції') {
    return const [
      LookupSpec(2, 'finance', 'Закупівельники', 0, required: true),
      LookupSpec(6, 'finance', 'Довідники', 0),
      LookupSpec(7, 'finance', 'Довідники', 1),
    ];
  }
  return const [];
}

Map<String, Object> lookupReadRequest(
  String book, String tab, int start,
) => {
  'action': 'read',
  'book': book,
  'tab': tab,
  'start': start,
  'limit': 100,
};

/// Fetch every page of the small reference tables, retaining exact spelling.
/// Never use hardcoded employee names, projects, or purchasing agents.
Future<Map<int, List<String>>> loadLookupOptions(
  String book,
  String tab,
  Future<Map<String, dynamic>> Function(Map<String, dynamic>) read,
) async {
  final specs = lookupSpecsFor(book, tab);
  final cached = <String, List<List<dynamic>>>{};
  const pageSize = 100;
  const maxPages = 5;
  for (final spec in specs) {
    final key = '${spec.book}/${spec.tab}';
    if (cached.containsKey(key)) continue;
    final collected = <List<dynamic>>[];
    var start = 4;
    var finished = false;
    for (var page = 0; page < maxPages; page++) {
      final response = await read(lookupReadRequest(spec.book, spec.tab, start));
      if (response['ok'] != true) {
        throw const FormatException('Сервер не підтвердив довідник');
      }
      final raw = response['rows'];
      if (raw is! List || raw.any((item) => item is! List)) {
        throw const FormatException('Некоректні дані довідника');
      }
      final portion = raw.cast<List>();
      collected.addAll(portion.map((row) => List<dynamic>.from(row)));
      if (portion.length < pageSize) {
        finished = true;
        break;
      }
      start += pageSize;
    }
    if (!finished) {
      throw const FormatException('Довідник перевищує безпечний ліміт');
    }
    cached[key] = collected;
  }
  final result = <int, List<String>>{};
  for (final spec in specs) {
    final source = cached['${spec.book}/${spec.tab}']!;
    final seen = <String>{};
    for (final row in source) {
      final value = spec.sourceColumn < row.length
          ? (row[spec.sourceColumn] ?? '').toString().trim()
          : '';
      if (value.isNotEmpty) seen.add(value);
    }
    final options = seen.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (options.isEmpty && spec.required) {
      throw FormatException('Довідник «${spec.tab}» порожній');
    }
    result[spec.formColumn] = options;
  }
  return result;
}
