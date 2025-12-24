import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

/// HTTP client wrapper with consistent timeout handling and error management
class ApiClient {
  /// Make a GET request with timeout handling
  /// Returns null on failure instead of throwing
  static Future<Map<String, dynamic>?> getJson(
    Uri uri, {
    Duration? timeout,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http
          .get(uri, headers: headers)
          .timeout(timeout ?? HttpConfig.defaultTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      debugPrint('⚠️ HTTP ${response.statusCode} for $uri');
      return null;
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        debugPrint('⏱️ Request timed out: $uri');
      } else {
        debugPrint('❌ HTTP error for $uri: $e');
      }
      return null;
    }
  }

  /// Make a GET request and return raw response body as string
  static Future<String?> getString(
    Uri uri, {
    Duration? timeout,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http
          .get(uri, headers: headers)
          .timeout(timeout ?? HttpConfig.defaultTimeout);

      if (response.statusCode == 200) {
        return response.body;
      }

      debugPrint('⚠️ HTTP ${response.statusCode} for $uri');
      return null;
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        debugPrint('⏱️ Request timed out: $uri');
      } else {
        debugPrint('❌ HTTP error for $uri: $e');
      }
      return null;
    }
  }

  /// Download image bytes with timeout
  static Future<Uint8List?> getImageBytes(
    String url, {
    Duration? timeout,
  }) async {
    if (url.isEmpty || !url.startsWith('http')) return null;

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(timeout ?? HttpConfig.imageTimeout);

      if (response.statusCode == 200 &&
          response.bodyBytes.length >= ImageConfig.minImageSizeBytes) {
        return response.bodyBytes;
      }

      return null;
    } catch (e) {
      debugPrint('⚠️ Failed to download image: $e');
      return null;
    }
  }

  /// Make a GET request with retry logic for rate-limited APIs
  static Future<Map<String, dynamic>?> getJsonWithRetry(
    Uri uri, {
    Duration? timeout,
    int maxRetries = HttpConfig.maxRetries,
    Duration? retryDelay,
  }) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final response = await http
            .get(uri)
            .timeout(timeout ?? HttpConfig.defaultTimeout);

        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        }

        // Handle rate limiting (429) or server errors (5xx)
        if (response.statusCode == 429 ||
            (response.statusCode >= 500 && response.statusCode < 600)) {
          if (attempt < maxRetries) {
            debugPrint(
                '⏳ Rate limited/Server error, retrying in ${retryDelay?.inMilliseconds ?? HttpConfig.retryDelay.inMilliseconds}ms...');
            await Future.delayed(retryDelay ?? HttpConfig.retryDelay);
            continue;
          }
        }

        debugPrint('⚠️ HTTP ${response.statusCode} for $uri');
        return null;
      } catch (e) {
        if (attempt < maxRetries) {
          await Future.delayed(retryDelay ?? HttpConfig.retryDelay);
          continue;
        }
        debugPrint('❌ HTTP error for $uri after $maxRetries retries: $e');
        return null;
      }
    }
    return null;
  }
}

/// Response wrapper for API calls that need error information
class ApiResponse<T> {
  final T? data;
  final String? error;
  final int? statusCode;

  const ApiResponse({this.data, this.error, this.statusCode});

  bool get isSuccess => data != null && error == null;
  bool get isError => error != null;

  factory ApiResponse.success(T data) => ApiResponse(data: data);

  factory ApiResponse.error(String message, [int? code]) =>
      ApiResponse(error: message, statusCode: code);
}
