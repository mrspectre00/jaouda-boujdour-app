import 'package:flutter/foundation.dart';

/// Handles errors in a consistent way across the application
/// Logs errors in debug mode and optionally rethrows them
void handleError(String message, dynamic error, {bool shouldRethrow = false}) {
  debugPrint('$message: $error');

  if (shouldRethrow) {
    throw '$message: $error';
  }
}
