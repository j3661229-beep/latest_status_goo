// lib/core/api/api_error.dart
import 'package:dio/dio.dart';

/// Extracts a user-presentable message from an API error.
/// Prefers the server's `error` / `message` field, falls back to a friendly
/// Hindi message for network failures.
String apiErrorMessage(Object error, {String fallback = 'कुछ गलत हो गया। कृपया दोबारा कोशिश करें।'}) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final msg = data['error'] ?? data['message'];
      if (msg is String && msg.trim().isNotEmpty) return msg;
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'सर्वर से जवाब नहीं मिला। कृपया इंटरनेट जांचें और दोबारा कोशिश करें।';
      case DioExceptionType.connectionError:
        return 'सर्वर से कनेक्ट नहीं हो सका। कृपया इंटरनेट जांचें।';
      default:
        break;
    }
    final status = error.response?.statusCode;
    if (status != null && status >= 500) {
      return 'सर्वर में समस्या है। कृपया थोड़ी देर बाद कोशिश करें।';
    }
    return fallback;
  }
  if (error is ApiException) return error.message;
  return fallback;
}

/// Simple typed exception for app-level API failures.
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}
