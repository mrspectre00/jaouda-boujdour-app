class ApiException implements Exception {
  final String message;
  final dynamic originalError;

  ApiException(this.message, [this.originalError]);

  @override
  String toString() {
    if (originalError != null) {
      return 'ApiException: $message (Original error: $originalError)';
    }
    return 'ApiException: $message';
  }
}
