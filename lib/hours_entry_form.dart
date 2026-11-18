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
          const Text('Чернетка для вкладки «Робочі години». Запис у таблицю ще вимкнено.'),
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
