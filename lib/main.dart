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
  String book = 'hours';
  String tab = 'Робочі години';
  List<List<String>> rows = [];

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
      final result = await request({'action': 'read', 'book': selectedBook, 'tab': selectedTab, 'start': 4, 'limit': 30}, freshToken);
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
    final columns = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BUDOWA GROUP',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF17365B)),
      home: Scaffold(
        appBar: AppBar(title: const Text('BUDOWA GROUP — TEST'), actions: [
          if (loggedIn) IconButton(onPressed: logout, icon: const Icon(Icons.logout), tooltip: 'Вийти')
        ]),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (!loggedIn) ...[
              const Text('Тестовий режим. Доступ визначає сервер після перевірки Google ID token.'),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: busy ? null : login,
                icon: const Icon(Icons.login), label: const Text('Увійти через Google')),
            ] else ...[
              Text('${account!.email} • $role', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: book, isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'hours', child: Text('Облік робочих годин')),
                  DropdownMenuItem(value: 'finance', child: Text('Баланс і закупівлі')),
                ],
                onChanged: busy ? null : (v) {
                  if (v == null) return;
                  setState(() { book = v; tab = v == 'hours' ? 'Робочі години' : 'Операції'; rows = []; });
                  load();
                },
              ),
              DropdownButton<String>(
                value: tab, isExpanded: true,
                items: tabs.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: busy ? null : (v) {
                  if (v == null) return;
                  setState(() { tab = v; rows = []; });
                  load();
                },
              ),
              OutlinedButton(onPressed: busy ? null : load, child: const Text('Оновити тестові дані')),
              if (book == 'hours')
                OutlinedButton.icon(onPressed: busy ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HoursEntryForm())), icon: const Icon(Icons.edit_note), label: const Text('Новий запис годин — чернетка')),

              const Text('Лише читання тестових копій. Запис вимкнено.',
                style: TextStyle(color: Colors.deepOrange)),
              const SizedBox(height: 8),
              Expanded(child: rows.isEmpty
                ? Center(child: Text(busy ? 'Завантаження тестових даних…' : error != null ? 'Не вдалося завантажити дані' : 'Немає рядків для показу'))
                : SingleChildScrollView(scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(columns: [
                        for (var i = 0; i < columns; i++) DataColumn(label: Text('${i + 1}'))
                      ], rows: rows.map((r) => DataRow(cells: [
                        for (var i = 0; i < columns; i++)
                          DataCell(Text(i < r.length ? r[i] : ''))
                      ])).toList()),
                    ))),
            ],
            if (busy) const LinearProgressIndicator(),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 8),
              child: SelectableText(error!, style: const TextStyle(color: Colors.red))),
          ]),
        ),
      ),
    );
  }
}
