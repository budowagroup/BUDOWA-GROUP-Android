import 'package:flutter/material.dart';
import 'edit_reference_data.dart';

/// Values verified against the reference spreadsheets on 2026-11-25.
/// The current server can replace this snapshot with live TEST metadata.
class SheetPresentation {
  final Map<String, Color> objects, operations, buyers, categories;
  final List<String> advanceMonths, paidMonths;
  final bool live;

  const SheetPresentation({
    required this.objects, required this.operations,
    this.buyers = const {}, this.categories = const {},
    this.advanceMonths = paymentMonths, this.paidMonths = paymentMonths,
    this.live = false,
  });

  static const snapshot = SheetPresentation(
    objects: {
      'Legionowo Michał': Color(0xFFE8F6E8),
      'Lomyanki Grzegorz': Color(0xFF9FC5E8),
      'Rembertow Rafal': Color(0xFFFF9900),
      'Stare Babice Grzegorz': Color(0xFFE8EAED),
      'Адміністрація': Color(0xFF00FF00),
    },
    operations: {'Надходження': Color(0xFFD9EAD3), 'Витрати': Colors.white},
  );

  factory SheetPresentation.fromResponse(Map<String, dynamic> response) {
    final data = response['presentation'];
    if (data is! Map) return snapshot;
    Map<String, Color> colors(String key) {
      final source = data[key];
      if (source is! Map) throw const FormatException('Некоректні кольори Google Sheets');
      final result = <String, Color>{};
      for (final entry in source.entries) {
        final hex = entry.value;
        if (entry.key is! String || hex is! String ||
            !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) {
          throw const FormatException('Некоректний колір Google Sheets');
        }
        result[entry.key as String] = Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
      }
      return Map.unmodifiable(result);
    }
    List<String> months(String key) {
      final source = data[key];
      if (source is! List || source.isEmpty ||
          source.any((v) => v is! String || v.trim().isEmpty)) {
        throw const FormatException('Некоректний список місяців Google Sheets');
      }
      return List.unmodifiable(source.cast<String>().toSet());
    }
    return SheetPresentation(
      objects: colors('objectColors'), operations: colors('operationColors'),
      buyers: colors('buyerColors'), categories: colors('categoryColors'),
      advanceMonths: months('advanceMonths'), paidMonths: months('paymentMonths'),
      live: true,
    );
  }

  Color objectColor(String name) => objects[name.trim()] ?? Colors.white;
  Color operationColor(String name) => operations[name.trim()] ?? Colors.white;
  Color financeColor(int column, String name) {
    switch (column) {
      case 2: return buyers[name.trim()] ?? Colors.white;
      case 4: return operationColor(name);
      case 6: return categories[name.trim()] ?? Colors.white;
      case 7: return objectColor(name);
      default: return Colors.white;
    }
  }
}
