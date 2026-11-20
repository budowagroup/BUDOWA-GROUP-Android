import 'hours_entry_form.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

const apiUrl = String.fromEnvironment('APPS_SCRIPT_URL');
const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BudowaApp());
}

class BudowaApp extends StatefulWidget {
  const BudowaApp({super.key});
  @override
  State<BudowaApp> createState() => _BudowaAppState();
}

class _BudowaAppState extends State<BudowaApp> {
  late final GoogleSignIn google = GoogleSignIn(
    scopes: const ['email', 'profile'],
    serverClientId: googleWebClientId.isEmpty ? null : googleWebClientId,
  );
  GoogleSignInAccount? account;
  String? token;
  String? role;
  String? error;
  bool busy = false;
  bool showLaunchSplash = true;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => showLaunchSplash = false);
    });
  }
  String book = 'hours';
  String tab = 'Робочі години';
  List<List<String>> rows = [];

  // Labels verified against the TEST sheets' actual header rows.
  List<String> get columnLabels {
    if (book == 'hours') {
      switch (tab) {
        case 'Робочі години':
          return const ['Дата', 'Працівник', 'Об’єкт', 'Від', 'До', 'Перерва', 'Час', 'Ставка', 'Сума', 'Аванс', 'Місяць', 'Оплата', 'Місяць', 'Залишок', 'Примітка'];
        case 'Працівники':
          return const ['Працівник', 'Посада', 'Ставка netto/год', 'Активний', 'Примітка', 'Активні працівники'];
        case 'Обʼєкти':
          return const ['Об’єкт', 'Адреса', 'Активний', 'Примітка', 'Активні об’єкти'];
        case 'Історія ставок':
          return const ['Працівник', 'Діє від', 'Ставка netto/год', 'Примітка'];
        case 'Розрахунок':
          return const ['Працівник', 'Дні', 'Години', 'Нараховано', 'Аванс', 'Виплачено', 'До виплати',
            'Дні', 'Години', 'Нараховано', 'Аванс', 'Виплачено', 'До виплати',
            'Дні', 'Години', 'Нараховано', 'Аванс', 'Виплачено', 'До виплати',
            'Дні', 'Години', 'Нараховано', 'Аванс', 'Виплачено', 'До виплати',
            'Дні', 'Години', 'Нараховано', 'Аванс', 'Виплачено', 'До виплати'];
      }
    }
    switch (tab) {
      case 'Операції':
        return const ['', 'Дата', 'Хто', 'Сума', 'Тип операції', 'Опис', 'Категорія', 'Об’єкт', 'Документ №'];
      case 'Закупівельники':
        return const ['Ім’я', 'Надходження', 'Витрати', 'Баланс'];
      case 'Довідники':
        return const ['Категорії', 'Об’єкти'];
    }
    return const [];
  }

  String columnLabel(int index) =>
      index < columnLabels.length ? columnLabels[index] : 'Колонка ${index + 1}';

  bool hasVisibleValues(List<String> record) =>
      record.any((value) => value.trim().isNotEmpty);

  String cell(List<String> row, int i) =>
      i < row.length ? row[i].trim() : '';

  Widget infoLine(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 138, child: Text(label,
        style: const TextStyle(fontSize: 13, color: Color(0xFF51647A)))),
      const SizedBox(width: 6),
      Expanded(child: SelectableText(value,
        style: const TextStyle(fontSize: 14))),
    ]),
  );

  Widget dataCard(List<String> record, int index) {
    final isHours = book == 'hours';
    final titleColumn = isHours
        ? (tab == 'Робочі години' ? 1 : 0)
        : (tab == 'Операції' ? 5 : 0);
    final title = cell(record, titleColumn);
    final heading = title.isNotEmpty ? title : 'Без назви';
    final isCalculation = isHours && tab == 'Розрахунок';
    final isWork = isHours && tab == 'Робочі години';
    final isOperation = !isHours && tab == 'Операції';
    final isDirectory = !isHours && tab == 'Довідники';
    final isWorker = isHours && tab == 'Працівники';
    final isSite = isHours && tab == 'Обʼєкти';
    final sections = const [
      'Серпень 2026', 'Вересень 2026', 'Жовтень 2026',
      'Листопад 2026', 'Грудень 2026',
    ];
    return Card(
      color: const Color(0xF5FFFFFF),
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!isDirectory)
            Text(heading, style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700,
              color: Color(0xFF17365B))),
          if (isWork && cell(record,2).isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 3),
              child: Text(cell(record,2), style: const TextStyle(
                color: Color(0xFF51647A)))),
          if (isWork && (cell(record,3).isNotEmpty || cell(record,4).isNotEmpty))
            infoLine('Час роботи', '${cell(record,3)} – ${cell(record,4)}'),
          if (isOperation && cell(record,1).isNotEmpty)
            infoLine('Дата', cell(record,1)),
          if (isOperation && cell(record,4).isNotEmpty)
            infoLine('Тип', cell(record,4)),
          if (isOperation && cell(record,3).isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(
              cell(record,3), style: TextStyle(fontSize: 21,
                fontWeight: FontWeight.bold,
                color: cell(record,4)=='Витрати'
                  ? const Color(0xFFAD3C32) : const Color(0xFF176B4D)))),
          for (var i=0; i<record.length; i++)
            if (cell(record,i).isNotEmpty &&
                i != titleColumn &&
                !(isWork && (i==0 || i==2 || i==3 || i==4)) &&
                !(isOperation && (i==1 || i==3 || i==4)) &&
                !(isWorker && i==5) &&
                !(isSite && i==4))
              if (isCalculation) ...[
                if (i>0 && (i-1)%6==0)
                  Padding(padding: const EdgeInsets.only(top: 13, bottom: 3),
                    child: Text(sections[(i-1)~/6],
                      style: const TextStyle(fontWeight: FontWeight.bold,
                        color: Color(0xFF17365B)))),
                infoLine(columnLabel(i), cell(record,i)),
              ] else
                infoLine(columnLabel(i), cell(record,i)),
        ]),
      ),
    );
  }

  Widget directoriesView() {
    final categories = <String>{};
    final sites = <String>{};
    for (final record in rows) {
      if (cell(record,0).isNotEmpty) categories.add(cell(record,0));
      if (cell(record,1).isNotEmpty) sites.add(cell(record,1));
    }
    Widget section(String title, Set<String> values) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(4,12,4,8),
          child: Text('$title (${values.length})',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
              color: Color(0xFF17365B)))),
        for (final value in values)
          Card(color: const Color(0xF5FFFFFF),
            margin: const EdgeInsets.only(bottom: 6),
            child: Padding(padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
              child: SizedBox(width: double.infinity,
                child: Text(value, style: const TextStyle(fontSize: 15))))),
      ]);
    return ListView(children: [
      section('Категорії', categories),
      section('Об’єкти', sites),
    ]);
  }

  Widget workHoursView() {
    final grouped = <String, List<List<String>>>{};
    for (final record in rows) {
      if (!hasVisibleValues(record)) continue;
      final date = cell(record,0).isEmpty ? 'Без дати' : cell(record,0);
      grouped.putIfAbsent(date, () => <List<String>>[]).add(record);
    }
    DateTime? parseDate(String value) {
      final parts = value.split('.');
      if (parts.length != 3) return null;
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day == null || month == null || year == null) return null;
      final date = DateTime(year,month,day);
      return date.day==day && date.month==month && date.year==year
          ? date : null;
    }
    final dates = grouped.keys.toList()..sort((a,b) {
      final da = parseDate(a); final db = parseDate(b);
      if (da!=null && db!=null) return db.compareTo(da);
      if (da!=null) return -1;
      if (db!=null) return 1;
      return a.compareTo(b);
    });
    return ListView.builder(
      key: const ValueKey('work-hours-by-date'),
      itemCount: dates.length,
      itemBuilder: (context,i) {
        final date = dates[i]; final records = grouped[date]!;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.fromLTRB(4,12,4,8),
            child: Row(children: [
              const Icon(Icons.calendar_today, size: 17,
                color: Color(0xFF17365B)),
              const SizedBox(width: 7),
              Expanded(child: Text(date, style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.bold,
                color: Color(0xFF17365B)))),
              Text('${records.length} записів'),
            ])),
          for (var j=0;j<records.length;j++) dataCard(records[j],j),
        ]);
      },
    );
  }

  Widget financeDashboard() {
    // Panel is a report layout, not a row-based transaction table.
    // Preserve spreadsheet errors visibly rather than replacing them with zero.
    String valueAt(int row, int col) =>
        row < rows.length && col < rows[row].length ? rows[row][col] : '';
    Widget metric(String label, String value) => Card(
      color: const Color(0xF5FFFFFF),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Color(0xFF51647A))),
          const SizedBox(height: 5),
          SelectableText(value.isEmpty ? '—' : value,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
              color: value.contains('#REF!') ? Colors.red.shade800 : const Color(0xFF17365B))),
        ]),
      ),
    );
    // API starts from row 3 for this tab; row 3 is rows[0].
    return ListView(children: [
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.75,
        children: [
          metric('Надходження', valueAt(0, 2)),
          metric('Витрати', valueAt(1, 2)),
          metric('Баланс', valueAt(2, 2)),
          metric('З/П працівникам', valueAt(3, 2)),
        ],
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Баланс за об’єктами',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      // Object totals are in B8:F14 (API rows 5..11). Row 7 is a header.
      for (var i = 5; i < rows.length && i <= 11; i++)
        if (valueAt(i, 1).isNotEmpty && valueAt(i, 1) != 'Об’єкт')
          Card(color: const Color(0xF5FFFFFF), child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(valueAt(i, 1), style: const TextStyle(fontWeight: FontWeight.bold)),
              for (final pair in <(String, int)>[
                ('З/П Загальна', 2), ('Витрати', 3),
                ('Надходження', 4), ('Баланс', 5)])
                Padding(padding: const EdgeInsets.only(top: 5),
                  child: Row(children: [
                    SizedBox(width: 135, child: Text(pair.$1)),
                    Expanded(child: SelectableText(valueAt(i, pair.$2))),
                  ])),
            ]),
          )),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Закупівельники',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      // The separate buyers table starts at B16:E16 (API row 13).
      // B=name, C=income, D=expenses, E=balance; never reuse object labels.
      for (var i = 14; i < rows.length; i++)
        if (valueAt(i, 1).isNotEmpty && valueAt(i, 1) != 'Закупівельник')
          Card(color: const Color(0xF5FFFFFF), child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(valueAt(i, 1), style: const TextStyle(fontWeight: FontWeight.bold)),
              for (final pair in <(String, int)>[
                ('Надходження', 2), ('Витрати', 3), ('Баланс', 4)])
                Padding(padding: const EdgeInsets.only(top: 5),
                  child: Row(children: [
                    SizedBox(width: 135, child: Text(pair.$1)),
                    Expanded(child: SelectableText(valueAt(i, pair.$2))),
                  ])),
            ]),
          )),
    ]);
  }

  Future<Map<String, dynamic>> request(Map<String, dynamic> payload, String idToken) async {
    if (apiUrl.isEmpty) throw Exception('Не задано APPS_SCRIPT_URL');
    final uri = Uri.parse(apiUrl);
    if (uri.scheme != 'https') throw Exception('Потрібен HTTPS');
    // Apps Script ContentService returns a 302 after POST. Dart does not
    // automatically follow 302 redirects for POST, so fetch the response
    // from Google's one-time content URL using GET (without the ID token).
    final client = http.Client();
    try {
      final postRequest = http.Request('POST', uri)
        ..headers['Content-Type'] = 'text/plain;charset=utf-8'
        ..body = jsonEncode({...payload, 'idToken': idToken})
        ..followRedirects = false;
      var response = await http.Response.fromStream(
        await client.send(postRequest).timeout(const Duration(seconds: 25)),
      ).timeout(const Duration(seconds: 25));

      for (var hop = 0; hop < 3 && response.statusCode == 302; hop++) {
        final location = response.headers['location'];
        if (location == null) throw Exception('HTTP 302 без Location');
        final target = uri.resolve(location);
        if (target.scheme != 'https' ||
            target.host != 'script.googleusercontent.com') {
          throw Exception('Небезпечне перенаправлення API');
        }
        final getRequest = http.Request('GET', target)
          ..followRedirects = false;
        response = await http.Response.fromStream(
          await client.send(getRequest).timeout(const Duration(seconds: 25)),
        ).timeout(const Duration(seconds: 25));
      }
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Некоректна відповідь API');
      }
      if (decoded['ok'] != true) {
        throw Exception('${decoded['error'] ?? 'API_ERROR'}');
      }
      return decoded;
    } finally {
      client.close();
    }
  }

  Future<void> login() async {
    if (googleWebClientId.isEmpty) {
      setState(() => error = 'Не задано GOOGLE_WEB_CLIENT_ID');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final signed = await google.signIn();
      if (signed == null) {
        if (mounted) setState(() => error = null);
        return;
      }
      final auth = await signed.authentication;
      final idToken = auth.idToken;
      if (idToken == null) throw Exception('Google не повернув ID Token. Перевірте OAuth конфігурацію.');
      final result = await request({'action': 'health'}, idToken);
      if (!mounted) return;
      setState(() { account = signed; token = idToken; role = '${result['role']}'; });
      await load();
    } catch (e) {
      await google.signOut();
      if (mounted) setState(() { account = null; token = null; role = null; error = '$e'; });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> load() async {
    final t = token;
    if (t == null) return;
    setState(() { busy = true; error = null; });
    try {
      final selectedBook = book;
      final selectedTab = tab;
      final currentAccount = account;
      if (currentAccount == null) return;
      final currentAuth = await currentAccount.authentication;
      final freshToken = currentAuth.idToken;
      if (freshToken == null) throw Exception('Не вдалося оновити Google ID Token. Увійдіть повторно.');
      final result = await request({'action': 'read', 'book': selectedBook, 'tab': selectedTab, 'start': selectedBook == 'finance' && selectedTab == 'Панель' ? 3 : selectedTab == 'Розрахунок' ? 5 : 4, 'limit': 30}, freshToken);
      final raw = result['rows'];
      if (raw is! List || raw.any((row) => row is! List)) {
        throw const FormatException('Некоректний формат рядків API');
      }
      final parsed = raw.map<List<String>>((row) =>
          (row as List).map<String>((cell) => '$cell').toList()).toList();
      if (mounted && account == currentAccount && book == selectedBook && tab == selectedTab) {
        setState(() { token = freshToken; rows = parsed; });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> logout() async {
    if (mounted) setState(() { account = null; token = null; role = null; rows = []; error = null; });
    await google.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = account != null && token != null;
    final tabs = book == 'hours'
      ? const ['Робочі години', 'Розрахунок', 'Працівники', 'Обʼєкти', 'Історія ставок']
      : const ['Операції', 'Панель', 'Закупівельники', 'Довідники'];
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BUDOWA GROUP',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF17365B)),
      home: showLaunchSplash
          ? const Scaffold(
              backgroundColor: Color(0xFF0756A3),
              body: SizedBox.expand(
                child: Image(
                  image: AssetImage('assets/images/splash_screen.webp'),
                  fit: BoxFit.cover,
                ),
              ),
            )
          : Scaffold(
        appBar: AppBar(title: const Text('BUDOWA GROUP — TEST'), actions: [
          if (loggedIn) IconButton(onPressed: logout, icon: const Icon(Icons.logout), tooltip: 'Вийти')
        ]),
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/background.webp'),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            color: const Color(0xD9FFFFFF),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!loggedIn) ...[
                      const Text('Тестовий режим. Доступ визначає сервер після перевірки Google ID token.'),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: busy ? null : login,
                        icon: const Icon(Icons.login),
                        label: const Text('Увійти через Google'),
                      ),
                    ] else ...[
                      Text(account!.email, maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('Роль: $role', style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        key: ValueKey('book-$book'),
                        initialValue: book,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Розділ',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'hours', child: Text('Облік робочих годин')),
                          DropdownMenuItem(value: 'finance', child: Text('Баланс і закупівлі')),
                        ],
                        onChanged: busy ? null : (v) {
                          if (v == null || v == book) return;
                          setState(() {
                            book = v;
                            tab = v == 'hours' ? 'Робочі години' : 'Операції';
                            rows = [];
                          });
                          load();
                        },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        key: ValueKey('tab-$book-$tab'),
                        initialValue: tab,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Таблиця',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                        ),
                        items: tabs.map((t) =>
                          DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: busy ? null : (v) {
                          if (v == null || v == tab) return;
                          setState(() { tab = v; rows = []; });
                          load();
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: OutlinedButton.icon(
                          onPressed: busy ? null : load,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Оновити'),
                        )),
                        if (book == 'hours') ...[
                          const SizedBox(width: 8),
                          Expanded(child: OutlinedButton.icon(
                            onPressed: busy ? null : () =>
                              Navigator.of(context).push(MaterialPageRoute<void>(
                                builder: (_) => const HoursEntryForm())),
                            icon: const Icon(Icons.edit_note, size: 18),
                            label: const Text('Чернетка'),
                          )),
                        ],
                      ]),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 5),
                        child: Text('TEST • Лише читання. Запис вимкнено.',
                          style: TextStyle(color: Color(0xFF9A4500), fontSize: 12)),
                      ),
                      if (busy) const LinearProgressIndicator(),
                      const SizedBox(height: 4),
                      Expanded(
                        child: rows.isEmpty
                          ? Center(child: Text(busy
                              ? 'Завантаження тестових даних…'
                              : error != null
                                ? 'Не вдалося завантажити дані'
                                : 'Немає рядків для показу'))
                          : book == 'finance' && tab == 'Панель'
                            ? financeDashboard()
                            : book == 'hours' && tab == 'Робочі години'
                            ? workHoursView()
                            : book == 'finance' && tab == 'Довідники'
                            ? directoriesView()
                            : ListView.builder(
                              key: ValueKey('records-$book-$tab'),
                              itemCount: rows.length,
                              itemBuilder: (context, i) =>
                                hasVisibleValues(rows[i])
                                  ? dataCard(rows[i], i)
                                  : const SizedBox.shrink(),
                            ),
                      ),
                    ],
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SelectableText(error!,
                          style: const TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
