import 'package:dio/dio.dart';

/// Base sealed class for all API errors.
///
/// Enables exhaustive pattern matching in UI code:
/// ```dart
/// switch (error) {
///   case ValidationException e: ...
///   case UnauthorizedException e: ...
///   case NotFoundException e: ...
///   case NetworkException e: ...
///   case ServerException e: ...
/// }
/// ```
sealed class AppException implements Exception {
  final String message;
  final String code;
  final int? statusCode;

  const AppException({
    required this.message,
    required this.code,
    this.statusCode,
  });

  /// Parses a [DioException] into the appropriate [AppException] subclass.
  ///
  /// Priority:
  /// 1. Backend `error.code` from response body (e.g. `VALIDATION_FAILED`)
  /// 2. HTTP status code (e.g. 401 → UnauthorizedException)
  /// 3. [DioExceptionType] (e.g. connectionTimeout → NetworkException)
  factory AppException.fromDioError(DioException e) {
    final responseData = e.response?.data;
    final backendCode = _extractString(responseData, ['error', 'code']);
    final backendMessage = _extractString(responseData, ['message'])
        ?? _extractString(responseData, ['error', 'message']);
    final statusCode = e.response?.statusCode;

    if (backendCode != null) {
      return _fromBackendCode(
        code: backendCode,
        message: backendMessage ?? _defaultMessageForCode(backendCode),
        statusCode: statusCode,
        responseData: responseData,
      );
    }

    if (statusCode != null) {
      return _fromStatusCode(statusCode, responseData);
    }

    return _fromDioType(e.type);
  }

  // ─── Backend error.code mapping ──────────────────────────

  static AppException _fromBackendCode({
    required String code,
    required String message,
    int? statusCode,
    dynamic responseData,
  }) {
    switch (code) {
      case 'VALIDATION_FAILED':
        return ValidationException(
          message: message,
          code: code,
          statusCode: statusCode,
          errors: _extractErrors(responseData),
        );
      case 'UNAUTHENTICATED':
        return UnauthorizedException(
          message: message,
          code: code,
          statusCode: statusCode,
        );
      case 'NOT_FOUND':
        return NotFoundException(
          message: message,
          code: code,
          statusCode: statusCode,
        );
      default:
        return ServerException(
          message: message,
          code: code,
          statusCode: statusCode,
        );
    }
  }

  // ─── HTTP status code mapping (fallback) ────────────────

  static AppException _fromStatusCode(int statusCode, dynamic responseData) {
    switch (statusCode) {
      case 400:
      case 422:
        return ValidationException(
          message: 'Data yang dikirim tidak valid.',
          code: 'VALIDATION_FAILED',
          statusCode: statusCode,
          errors: _extractErrors(responseData),
        );
      case 401:
        return UnauthorizedException(
          message: 'Sesi Anda telah berakhir. Silakan login kembali.',
          code: 'UNAUTHENTICATED',
          statusCode: statusCode,
        );
      case 403:
        return UnauthorizedException(
          message: 'Anda tidak memiliki akses ke sumber daya ini.',
          code: 'FORBIDDEN',
          statusCode: statusCode,
        );
      case 404:
        return NotFoundException(
          message: 'Data tidak ditemukan.',
          code: 'NOT_FOUND',
          statusCode: statusCode,
        );
      case 429:
        return ServerException(
          message: 'Terlalu banyak permintaan. Silakan coba lagi nanti.',
          code: 'RATE_LIMITED',
          statusCode: statusCode,
        );
      default:
        return ServerException(
          message: 'Terjadi kesalahan pada server.',
          code: 'SERVER_ERROR',
          statusCode: statusCode,
        );
    }
  }

  // ─── DioExceptionType mapping (last resort) ─────────────

  static AppException _fromDioType(DioExceptionType type) {
    switch (type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException(
          message: 'Koneksi timeout. Periksa koneksi internet Anda.',
          code: 'TIMEOUT',
        );
      case DioExceptionType.connectionError:
        return NetworkException(
          message: 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
          code: 'CONNECTION_ERROR',
        );
      case DioExceptionType.cancel:
        return NetworkException(
          message: 'Permintaan dibatalkan.',
          code: 'CANCELED',
        );
      case DioExceptionType.badCertificate:
        return NetworkException(
          message: 'Koneksi tidak aman.',
          code: 'BAD_CERTIFICATE',
        );
      case DioExceptionType.badResponse:
        return ServerException(
          message: 'Terjadi kesalahan pada server.',
          code: 'SERVER_ERROR',
        );
      case DioExceptionType.unknown:
        return NetworkException(
          message: 'Terjadi kesalahan jaringan yang tidak diketahui.',
          code: 'UNKNOWN',
        );
    }
  }

  // ─── Helpers ────────────────────────────────────────────

  static String? _extractString(dynamic data, List<String> keys) {
    if (data is! Map) return null;
    Object? current = data;
    for (final key in keys) {
      if (current is! Map) return null;
      current = current[key];
    }
    if (current is String) return current;
    return null;
  }

  static Map<String, List<String>>? _extractErrors(dynamic data) {
    if (data is! Map) return null;
    final raw = data['errors'];
    if (raw is! Map) return null;
    return raw.map((key, value) {
      if (value is List) {
        return MapEntry(key.toString(), value.map((e) => e.toString()).toList());
      }
      return MapEntry(key.toString(), [value.toString()]);
    });
  }

  static String _defaultMessageForCode(String code) {
    switch (code) {
      case 'VALIDATION_FAILED':
        return 'Data yang dikirim tidak valid.';
      case 'UNAUTHENTICATED':
        return 'Sesi Anda telah berakhir. Silakan login kembali.';
      case 'NOT_FOUND':
        return 'Data tidak ditemukan.';
      case 'FORBIDDEN':
        return 'Anda tidak memiliki akses ke sumber daya ini.';
      case 'RATE_LIMITED':
        return 'Terlalu banyak permintaan. Silakan coba lagi nanti.';
      case 'SERVER_ERROR':
        return 'Terjadi kesalahan pada server.';
      default:
        return 'Terjadi kesalahan. Silakan coba lagi.';
    }
  }
}

/// Network-level error (timeout, connection refused, DNS failure, etc.).
class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    required super.code,
    super.statusCode,
  });
}

/// Server-side error (5xx, unexpected backend code, etc.).
class ServerException extends AppException {
  const ServerException({
    required super.message,
    required super.code,
    super.statusCode,
  });
}

/// Validation error (400, 422) with optional field-level error details.
class ValidationException extends AppException {
  final Map<String, List<String>>? errors;

  const ValidationException({
    required super.message,
    required super.code,
    super.statusCode,
    this.errors,
  });
}

/// Authentication/authorization error (401, 403).
class UnauthorizedException extends AppException {
  const UnauthorizedException({
    required super.message,
    required super.code,
    super.statusCode,
  });
}

/// Resource not found error (404).
class NotFoundException extends AppException {
  const NotFoundException({
    required super.message,
    required super.code,
    super.statusCode,
  });
}
