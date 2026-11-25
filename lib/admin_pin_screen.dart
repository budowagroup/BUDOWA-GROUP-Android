import 'package:flutter/material.dart';

/// Additional password for TEST read-only administrators. Server verifies it.
class AdminPinScreen extends StatefulWidget {
  const AdminPinScreen({super.key, required this.adminEmail, required this.verify});
  final String adminEmail;
  final Future<void> Function(String pin) verify;
  @override
  State<AdminPinScreen> createState() => _AdminPinScreenState();
}
class _AdminPinScreenState extends State<AdminPinScreen> {
  final controller = TextEditingController();
  bool submitting = false;
  String? error;

  @override
  void dispose() { controller.dispose(); super.dispose(); }

  Future<void> submit() async {
    if (submitting) return;
    final pin = controller.text;
    if (pin.length < 7) {
      setState(() => error = 'Введіть повний пароль адміністратора.');
      return;
    }
    setState(() { submitting = true; error = null; });
    try {
      await widget.verify(pin);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() {
        final code = e.toString();
        error = code.contains('ADMIN_PIN_LOCKED')
            ? 'Забагато невдалих спроб. Повторіть через 15 хвилин.'
            : code.contains('ADMIN_PIN_INVALID')
            ? 'Неправильний пароль адміністратора.'
            : code.contains('ADMIN_PIN_NOT_CONFIGURED')
            ? 'Пароль цього адміністратора ще не налаштований.'
            : 'Не вдалося підтвердити пароль. Перевірте підключення.';
      });
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Пароль адміністратора')),
    body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Icon(Icons.admin_panel_settings_outlined, size: 56),
          const SizedBox(height: 16),
          const Text('Додаткова перевірка доступу',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(widget.adminEmail, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          const Text('Після входу через Google введіть персональний пароль. '
              'Адміністратори можуть лише читати TEST-таблиці.'),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            maxLength: 128,
            enabled: !submitting,
            onSubmitted: (_) => submit(),
            decoration: const InputDecoration(
              labelText: 'Пароль адміністратора',
              border: OutlineInputBorder(),
            ),
          ),
          if (error != null) Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
          FilledButton(
            onPressed: submitting ? null : submit,
            child: Text(submitting ? 'Перевіряємо…' : 'Підтвердити'),
          ),
          TextButton(
            onPressed: submitting ? null : () => Navigator.of(context).pop(false),
            child: const Text('Скасувати вхід'),
          ),
        ]),
      ),
    ))),
  );
}
