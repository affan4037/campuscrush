import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';

/// Utility class for handling and categorizing errors throughout the application
class ErrorHandler {
  // Private constructor to prevent instantiation
  ErrorHandler._();

  /// Common network error messages
  static const String _networkErrorMessage =
      'Network error. Please check your connection.';
  static const String _timeoutErrorMessage =
      'Connection timed out. Please try again.';
  static const String _unexpectedErrorMessage = 'An unexpected error occurred.';

  /// HTTP status codes
  static const int _statusUnauthorized = 401;
  static const int _statusForbidden = 403;
  static const int _statusNotFound = 404;
  static const int _statusPayloadTooLarge = 413;
  static const int _statusUnsupportedMedia = 415;
  static const int _statusUnprocessableEntity = 422;
  static const int _statusTooManyRequests = 429;

  /// Extracts a user-friendly error message from different error types
  static String getErrorMessage(dynamic error) {
    if (error is DioException) {
      return _handleDioException(error);
    } else if (error is SocketException) {
      return _networkErrorMessage;
    } else if (error is TimeoutException) {
      return _timeoutErrorMessage;
    }

    return error?.toString() ?? _unexpectedErrorMessage;
  }

  /// Processes DioException errors
  static String _handleDioException(DioException error) {
    // Handle response errors
    if (error.response != null) {
      final statusCode = error.response!.statusCode;
      final data = error.response!.data;

      return _getMessageForStatusCode(statusCode, data);
    }

    // Handle connection errors
    if (error.type == DioExceptionType.connectionTimeout) {
      return _timeoutErrorMessage;
    } else if (error.type == DioExceptionType.connectionError) {
      return _networkErrorMessage;
    }

    return error.message ?? _unexpectedErrorMessage;
  }

  /// Maps HTTP status codes to user-friendly messages
  static String _getMessageForStatusCode(int? statusCode, dynamic data) {
    switch (statusCode) {
      case _statusUnauthorized:
        return 'Authentication failed. Please log in again.';
      case _statusForbidden:
        return 'Access denied. Please check your permissions.';
      case _statusNotFound:
        return 'Resource not found.';
      case _statusPayloadTooLarge:
        return 'File is too large. Please choose a smaller file.';
      case _statusUnsupportedMedia:
        return 'Unsupported file type.';
      case _statusUnprocessableEntity:
        return _getDetailFromResponse(data,
            defaultMessage: 'Invalid data provided.');
      case _statusTooManyRequests:
        return 'Too many requests. Please try again later.';
      default:
        return _getDetailFromResponse(data,
            defaultMessage: _unexpectedErrorMessage);
    }
  }

  /// Extracts detailed error message from response if available
  static String _getDetailFromResponse(dynamic data,
      {required String defaultMessage}) {
    if (data is Map<String, dynamic> && data.containsKey('detail')) {
      final detail = data['detail'];
      return detail?.toString() ?? defaultMessage;
    }
    return defaultMessage;
  }

  /// Determines if an error is related to authentication
  static bool isAuthenticationError(dynamic error) {
    if (error is DioException && error.response != null) {
      final statusCode = error.response!.statusCode;
      return statusCode == _statusUnauthorized ||
          statusCode == _statusForbidden;
    }

    final String errorString = error?.toString().toLowerCase() ?? '';
    return errorString.contains('token') ||
        errorString.contains('auth') ||
        errorString.contains('unauthorized') ||
        errorString.contains('unauthenticated');
  }

  /// Determines if an error is related to network connectivity
  static bool isNetworkError(dynamic error) {
    return error is SocketException ||
        error is TimeoutException ||
        (error is DioException &&
            (error.type == DioExceptionType.connectionTimeout ||
                error.type == DioExceptionType.connectionError));
  }
}
