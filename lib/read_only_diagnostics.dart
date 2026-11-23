import 'package:flutter/material.dart';

/// TEST-only connectivity checks. Never issue create, update, or delete.
class ReadOnlyTab {
  final String book;
  final String tab;
  final int firstDataRow;

  const ReadOnlyTab(this.book, this.tab, this.firstDataRow);
}

const readOnlyTabs = <ReadOnlyTab>[
  ReadOnlyTab('hours', 'Робочі години', 4),
  ReadOnlyTab('hours', 'Розрахунок', 5),
  ReadOnlyTab('hours', 'Працівники', 4),
  ReadOnlyTab('hours', 'Обʼєкти', 4),
  ReadOnlyTab('hours', 'Історія ставок', 4),
  ReadOnlyTab('finance', 'Операції', 4),
  ReadOnlyTab('finance', 'Панель', 3),
  ReadOnlyTab('finance', 'Закупівельники', 4),
  ReadOnlyTab('finance', 'Довідники', 4),
];

Map<String, Object> readOnlyPayload(ReadOnlyTab tab) => <String, Object>{
  'action': 'read',
  'book': tab.book,
  'tab': tab.tab,
  'start': tab.firstDataRow,
  'limit': 1,
};

class TabCheckResult {
  final ReadOnlyTab tab;
  final bool accessible;
  final bool containsValues;
  final String? errorCode;

  const TabCheckResult(
    this.tab, {
    required this.accessible,
    this.containsValues = false,
    this.errorCode,
  });
}

String _safeError(Object exception) {
  final message = exception.toString();
  for (final code in const [
    'FORBIDDEN',
    'TOKEN_REJECTED',
    'INVALID_TOKEN',
    'INVALID_BOOK',
    'INVALID_TAB',
    'SHEET_MISSING',
    'API_ERROR',
  ]) {
    if (message.contains(code)) return code;
  }
  return 'Помилка мережі або відповіді';
}

/// Inspect a single existing row in every TEST sheet.
/// Empty data is not confused with an API failure.
Future<List<TabCheckResult>> checkReadOnlyTabs(
  Future<Map<String, dynamic>> Function(ReadOnlyTab tab) read, {
  void Function(int checked, TabCheckResult result)? onChecked,
}) async {
  final results = <TabCheckResult>[];
  for (final tab in readOnlyTabs) {
    TabCheckResult result;
    try {
      final response = await read(tab);
      final data = response['rows'];
      if (response['ok'] != true ||
          data is! List ||
          data.any((row) => row is! List)) {
        throw const FormatException('Некоректна відповідь API');
      }
      final containsValues = data.any((row) =>
          (row as List).any((value) =>
              value != null && value.toString().trim().isNotEmpty));
      result = TabCheckResult(
        tab,
        accessible: true,
        containsValues: containsValues,
      );
    } catch (exception) {
      result = TabCheckResult(
        tab,
        accessible: false,
        errorCode: _safeError(exception),
      );
    }
    results.add(result);
    onChecked?.call(results.length, result);
  }
  return results;
}

class ReadOnlyDiagnosticsScreen extends StatefulWidget {
  final Future<Map<String, dynamic>> Function(ReadOnlyTab tab) read;
  final String apiVersion;
  final String dataSource;

  const ReadOnlyDiagnosticsScreen({
    super.key,
    required this.read,
    required this.apiVersion,
    required this.dataSource,
  });

  @override
  State<ReadOnlyDiagnosticsScreen> createState() =>
      _ReadOnlyDiagnosticsScreenState();
}

class _ReadOnlyDiagnosticsScreenState
    extends State<ReadOnlyDiagnosticsScreen> {
  bool _running = false;
  List<TabCheckResult> _results = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _run();
    });
  }

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _results = [];
    });
    await checkReadOnlyTabs(
      widget.read,
      onChecked: (_, result) {
        if (!mounted) return;
        setState(() => _results = [..._results, result]);
      },
    );
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final successes = _results.where((item) => item.accessible).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Діагностика TEST')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Лише читання — жодних змін у Google Sheets',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text('API: ${widget.apiVersion}'),
              Text('Джерело: ${widget.dataSource}'),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _results.length / readOnlyTabs.length,
              ),
              const SizedBox(height: 8),
              Text(
                'Перевірено: ${_results.length}/9 • Доступні: $successes',
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: readOnlyTabs.length,
                  itemBuilder: (context, index) {
                    final tab = readOnlyTabs[index];
                    final checked = index < _results.length
                        ? _results[index]
                        : null;
                    final success = checked?.accessible == true;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        checked == null
                            ? Icons.hourglass_empty
                            : success
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                        color: checked == null
                            ? null
                            : success
                                ? Colors.green
                                : Colors.red,
                      ),
                      title: Text(tab.tab),
                      subtitle: Text(
                        checked == null
                            ? 'Ще не перевірено'
                            : success
                                ? checked.containsValues
                                    ? 'Читання успішне'
                                    : 'Читання успішне, рядок порожній'
                                : checked.errorCode ?? 'Помилка перевірки',
                      ),
                      trailing: Text(
                        tab.book == 'hours' ? 'Години' : 'Фінанси',
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  },
                ),
              ),
              FilledButton.icon(
                onPressed: _running ? null : _run,
                icon: const Icon(Icons.refresh),
                label: const Text('Перевірити ще раз'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
