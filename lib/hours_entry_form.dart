import 'package:flutter/material.dart';

/// TEST-only entry form. It never writes to Google Sheets.
class HoursEntryForm extends StatefulWidget {
  const HoursEntryForm({super.key});
  @override
  State<HoursEntryForm> createState() => _HoursEntryFormState();
}

class _HoursEntryFormState extends State<HoursEntryForm> {
  final key = GlobalKey<FormState>();
  final employee = TextEditingController();
  final object = TextEditingController();
  final advance = TextEditingController(text: '0');
  final note = TextEditingController();
  DateTime date = DateTime.now();
  TimeOfDay? start;
  TimeOfDay? end;
  int breakMinutes = 0;
  bool preview = false;
  final List<Map<String, String>> drafts = [];
  int? editingIndex;


  @override
  void dispose() {
    employee.dispose();
    object.dispose();
    advance.dispose();
    note.dispose();
    super.dispose();
  }

  int minutes(TimeOfDay time) => time.hour * 60 + time.minute;
  String display(TimeOfDay? time) => time == null
      ? 'Оберіть час'
      : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Future<void> chooseTime(bool isStart) async {
    final chosen = await showTimePicker(
      context: context,
      initialTime: isStart ? (start ?? const TimeOfDay(hour: 8, minute: 0))
          : (end ?? const TimeOfDay(hour: 17, minute: 0)),
    );
    if (chosen != null) setState(() { if (isStart) { start = chosen; } else { end = chosen; } preview = false; });
  }

  void saveLocalDraft() {
    final formValid = key.currentState!.validate();
    final validTime = start != null && end != null &&
        minutes(end!) > minutes(start!) + breakMinutes;
    if (!formValid || !validTime) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Перевірте обов’язкові поля, час і перерву')));
      return;
    }
    final data = <String, String>{
      'employee': employee.text.trim(),
      'object': object.text.trim(),
      'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'start': display(start),
      'end': display(end),
      'break': breakMinutes.toString(),
      'hours': ((minutes(end!) - minutes(start!) - breakMinutes) / 60).toStringAsFixed(2),
      'advance': advance.text.trim().replaceAll(',', '.'),
      'note': note.text.trim(),
    };
    setState(() {
      if (editingIndex == null) {
        drafts.add(data);
      } else {
        drafts[editingIndex!] = data;
      }
      editingIndex = null;
      preview = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Чернетку збережено лише в пам’яті застосунку. Google Sheets не змінено.')));
  }

  void editLocalDraft(int index) {
    final data = drafts[index];
    final parts = data['date']!.split('-').map(int.parse).toList();
    final startParts = data['start']!.split(':').map(int.parse).toList();
    final endParts = data['end']!.split(':').map(int.parse).toList();
    setState(() {
      editingIndex = index;
      employee.text = data['employee']!;
      object.text = data['object']!;
      date = DateTime(parts[0], parts[1], parts[2]);
      start = TimeOfDay(hour: startParts[0], minute: startParts[1]);
      end = TimeOfDay(hour: endParts[0], minute: endParts[1]);
      breakMinutes = int.parse(data['break']!);
      advance.text = data['advance']!;
      note.text = data['note']!;
      preview = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final validTime = start != null && end != null &&
        minutes(end!) > minutes(start!) + breakMinutes;
    final totalMinutes = validTime ? minutes(end!) - minutes(start!) - breakMinutes : 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Новий запис — TEST')),
      body: Form(
        key: key,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('TEST: створення та редагування локальних чернеток. Дані зникнуть після закриття екрана. Запис у Google Sheets вимкнено.'),
          const SizedBox(height: 16),
          TextFormField(controller: employee, decoration: const InputDecoration(
            labelText: 'Працівник', border: OutlineInputBorder()),
            validator: (v) => v == null || v.trim().isEmpty ? 'Вкажіть працівника' : null),
          const SizedBox(height: 12),
          TextFormField(controller: object, decoration: const InputDecoration(
            labelText: 'Об’єкт', border: OutlineInputBorder()),
            validator: (v) => v == null || v.trim().isEmpty ? 'Вкажіть об’єкт' : null),
          const SizedBox(height: 12),
          ListTile(
            title: const Text('Дата'),
            subtitle: Text('${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}'),
            trailing: const Icon(Icons.calendar_month),
            onTap: () async {
              final chosen = await showDatePicker(context: context, initialDate: date,
                firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (chosen != null) setState(() { date = chosen; preview = false; });
            },
          ),
          ListTile(title: const Text('Початок роботи'), subtitle: Text(display(start)),
            trailing: const Icon(Icons.schedule), onTap: () => chooseTime(true)),
          ListTile(title: const Text('Кінець роботи'), subtitle: Text(display(end)),
            trailing: const Icon(Icons.schedule), onTap: () => chooseTime(false)),
          DropdownButtonFormField<int>(
            initialValue: breakMinutes,
            decoration: const InputDecoration(labelText: 'Перерва (хвилини)'),
            items: [0, 15, 30, 45, 60, 90, 120].map((v) =>
              DropdownMenuItem(value: v, child: Text('$v'))).toList(),
            onChanged: (v) => setState(() { breakMinutes = v ?? 0; preview = false; }),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: advance, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Аванс (zł)', border: OutlineInputBorder()),
            validator: (v) {
              final value = double.tryParse((v ?? '').replaceAll(',', '.'));
              return value == null || !value.isFinite || value < 0 ? 'Вкажіть суму від 0' : null;
            }),
          const SizedBox(height: 12),
          TextFormField(controller: note, maxLines: 2,
            decoration: const InputDecoration(labelText: 'Примітка', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.fact_check),
            label: const Text('Перевірити запис'),
            onPressed: () {
              final formValid = key.currentState!.validate();
              if (!validTime) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Час завершення має бути пізніше початку з урахуванням перерви')));
              }
              setState(() => preview = formValid && validTime);
            },
          ),
          if (preview) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: const Icon(Icons.save_outlined),
              label: Text(editingIndex == null ? 'Зберегти локальну чернетку' : 'Оновити локальну чернетку'),
              onPressed: saveLocalDraft,
            ),
          ],
          if (drafts.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Локальні чернетки (${drafts.length})',
                style: Theme.of(context).textTheme.titleMedium),
            const Text('Лише поточний екран — у таблицях записів немає.'),
            ...List.generate(drafts.length, (i) {
              final item = drafts[i];
              return Card(child: ListTile(
                title: Text('${item['employee']} — ${item['object']}'),
                subtitle: Text('${item['date']} · ${item['start']}–${item['end']} · ${item['hours']} год'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: 'Редагувати чернетку',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => editLocalDraft(i),
                  ),
                  IconButton(
                    tooltip: 'Видалити чернетку',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() {
                      drafts.removeAt(i);
                      if (editingIndex == i) editingIndex = null;
                      else if (editingIndex != null && editingIndex! > i) editingIndex = editingIndex! - 1;
                    }),
                  ),
                ]),
              ));
            }),
          ],
          if (preview) Card(child: Padding(padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Перевірена чернетка', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Працівник: ${employee.text.trim()}'),
              Text('Об’єкт: ${object.text.trim()}'),
              Text('Час: ${display(start)}–${display(end)}'),
              Text('Перерва: $breakMinutes хв'),
              Text('Робочий час: ${(totalMinutes / 60).toStringAsFixed(2)} год'),
              Text('Аванс: ${advance.text} zł'),
              const SizedBox(height: 8),
              const Text('Не збережено. Серверний запис буде додано після перевірки API.',
                style: TextStyle(color: Colors.deepOrange)),
            ]),
          )),
        ]),
      ),
    );
  }
}

 
/// Local-only forms for reference and rate-history tabs.
/// The calculated payroll tab is derived from source data and remains read-only.
class HoursTabDraftForm extends StatefulWidget {
  final String tab;
  const HoursTabDraftForm({super.key, required this.tab});
  @override
  State<HoursTabDraftForm> createState() => _HoursTabDraftFormState();
}

class _HoursTabDraftFormState extends State<HoursTabDraftForm> {
  final formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> fields = {};
  final List<Map<String, String>> drafts = [];
  int? editingIndex;

  List<String> get labels {
    switch (widget.tab) {
      case 'Працівники':
        return ['Працівник', 'Посада', 'Ставка netto/год', 'Активний (Так/Ні)'];
      case 'Обʼєкти':
      case 'Об’єкти':
        return ['Об’єкт', 'Адреса', 'Активний (Так/Ні)'];
      case 'Історія ставок':
        return ['Працівник', 'Діє від (РРРР-ММ-ДД)', 'Ставка netto/год', 'Примітка'];
      default:
        return [];
    }
  }

  @override
  void initState() {
    super.initState();
    for (final label in labels) {
      fields[label] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? validate(String label, String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty && label != 'Адреса' && label != 'Посада' && label != 'Примітка') {
      return 'Обов’язкове поле';
    }
    if (label.contains('Ставка')) {
      final number = double.tryParse(text.replaceAll(',', '.'));
      if (number == null || !number.isFinite || number < 0) return 'Вкажіть коректну ставку';
    }
    if (label.startsWith('Активний') && !['так', 'ні'].contains(text.toLowerCase())) {
      return 'Вкажіть Так або Ні';
    }
    if (label.startsWith('Діє від')) {
      final match = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text);
      final parsed = DateTime.tryParse(text);
      if (!match || parsed == null || parsed.toIso8601String().substring(0, 10) != text) {
        return 'Формат РРРР-ММ-ДД';
      }
    }
    return null;
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    setState(() {
      final data = {for (final entry in fields.entries) entry.key: entry.value.text.trim()};
      if (editingIndex == null) {
        drafts.add(data);
      } else {
        drafts[editingIndex!] = data;
      }
      editingIndex = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Локальну чернетку збережено. Google Sheets не змінено.')));
  }

  void edit(int index) {
    setState(() {
      editingIndex = index;
      for (final entry in fields.entries) {
        entry.value.text = drafts[index][entry.key] ?? '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tab == 'Розрахунок') {
      return Scaffold(
        appBar: AppBar(title: const Text('Розрахунок — TEST')),
        body: const Padding(
          padding: EdgeInsets.all(20),
          child: Text('Ця вкладка розраховується формулами Google Sheets. '
              'Для безпечного тестування змінюйте чернетки у вкладках '
              '«Робочі години», «Працівники» та «Історія ставок». '
              'Розрахункові формули не редагуються з застосунку.'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('${widget.tab} — TEST')),
      body: Form(
        key: formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Лише локальні чернетки. Запис у Google Sheets вимкнено. '
              'Чернетки зникають після закриття екрана.'),
          const SizedBox(height: 16),
          ...labels.map((label) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              controller: fields[label],
              decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
              keyboardType: label.contains('Ставка')
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              validator: (v) => validate(label, v),
            ),
          )),
          FilledButton.icon(
            onPressed: save,
            icon: const Icon(Icons.save_outlined),
            label: Text(editingIndex == null ? 'Додати локальну чернетку' : 'Зберегти зміни чернетки'),
          ),
          const SizedBox(height: 16),
          Text('Чернетки (${drafts.length})', style: Theme.of(context).textTheme.titleMedium),
          ...List.generate(drafts.length, (index) {
            final item = drafts[index];
            return Card(child: ListTile(
              title: Text(item[labels.first] ?? ''),
              subtitle: Text(item.entries.skip(1).map((e) => '${e.key}: ${e.value}').join(' · ')),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: 'Редагувати',
                  onPressed: () => edit(index),
                  icon: const Icon(Icons.edit_outlined)),
                IconButton(
                  tooltip: 'Видалити',
                  onPressed: () => setState(() {
                    drafts.removeAt(index);
                    if (editingIndex == index) editingIndex = null;
                    else if (editingIndex != null && editingIndex! > index) editingIndex = editingIndex! - 1;
                  }),
                  icon: const Icon(Icons.delete_outline)),
              ]),
            ));
          }),
        ]),
      ),
    );
  }
}
).hasMatch(text);
      final parsed = DateTime.tryParse(text);
      if (!match || parsed == null || parsed.toIso8601String().substring(0, 10) != text) {
        return 'Формат РРРР-ММ-ДД';
      }
    }
    return null;
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    setState(() {
      final data = {for (final entry in fields.entries) entry.key: entry.value.text.trim()};
      if (editingIndex == null) {
        drafts.add(data);
      } else {
        drafts[editingIndex!] = data;
      }
      editingIndex = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Локальну чернетку збережено. Google Sheets не змінено.')));
  }

  void edit(int index) {
    setState(() {
      editingIndex = index;
      for (final entry in fields.entries) {
        entry.value.text = drafts[index][entry.key] ?? '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tab == 'Розрахунок') {
      return Scaffold(
        appBar: AppBar(title: const Text('Розрахунок — TEST')),
        body: const Padding(
          padding: EdgeInsets.all(20),
          child: Text('Ця вкладка розраховується формулами Google Sheets. '
              'Для безпечного тестування змінюйте чернетки у вкладках '
              '«Робочі години», «Працівники» та «Історія ставок». '
              'Розрахункові формули не редагуються з застосунку.'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('${widget.tab} — TEST')),
      body: Form(
        key: formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Лише локальні чернетки. Запис у Google Sheets вимкнено. '
              'Чернетки зникають після закриття екрана.'),
          const SizedBox(height: 16),
          ...labels.map((label) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              controller: fields[label],
              decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
              keyboardType: label.contains('Ставка')
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              validator: (v) => validate(label, v),
            ),
          )),
          FilledButton.icon(
            onPressed: save,
            icon: const Icon(Icons.save_outlined),
            label: Text(editingIndex == null ? 'Додати локальну чернетку' : 'Зберегти зміни чернетки'),
          ),
          const SizedBox(height: 16),
          Text('Чернетки (${drafts.length})', style: Theme.of(context).textTheme.titleMedium),
          ...List.generate(drafts.length, (index) {
            final item = drafts[index];
            return Card(child: ListTile(
              title: Text(item[labels.first] ?? ''),
              subtitle: Text(item.entries.skip(1).map((e) => '${e.key}: ${e.value}').join(' · ')),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: 'Редагувати',
                  onPressed: () => edit(index),
                  icon: const Icon(Icons.edit_outlined)),
                IconButton(
                  tooltip: 'Видалити',
                  onPressed: () => setState(() {
                    drafts.removeAt(index);
                    if (editingIndex == index) editingIndex = null;
                    else if (editingIndex != null && editingIndex! > index) editingIndex = editingIndex! - 1;
                  }),
                  icon: const Icon(Icons.delete_outline)),
              ]),
            ));
          }),
        ]),
      ),
    );
  }
}
