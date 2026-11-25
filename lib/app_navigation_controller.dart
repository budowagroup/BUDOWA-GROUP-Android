import 'package:flutter/material.dart';

/// Navigation owned by MaterialApp, not the BuildContext of its parent State.
class AppNavigationController {
  final navigatorKey = GlobalKey<NavigatorState>();
  final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  Future<T?> push<T extends Object?>(Widget page) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      throw StateError('Навігація ще не готова. Повторіть дію.');
    }
    return navigator.push<T>(
      MaterialPageRoute<T>(builder: (_) => page),
    );
  }

  void showMessage(String message) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
