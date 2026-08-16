class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  AppException(this.message, {this.code, this.originalError});

  @override
  String toString() => 'AppException($code): $message';
}

class AuthException extends AppException {
  AuthException(super.message, {super.code, super.originalError});
}

class NetworkException extends AppException {
  NetworkException(super.message, {super.code, super.originalError});
}

class PaymentException extends AppException {
  PaymentException(super.message, {super.code, super.originalError});
}

class LocationException extends AppException {
  LocationException(super.message, {super.code, super.originalError});
}

class StorageException extends AppException {
  StorageException(super.message, {super.code, super.originalError});
}

class DeliveryException extends AppException {
  DeliveryException(super.message, {super.code, super.originalError});
}

class RefundException extends AppException {
  RefundException(super.message, {super.code, super.originalError});
}

class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  ValidationException(super.message, {this.fieldErrors, super.code, super.originalError});
}
