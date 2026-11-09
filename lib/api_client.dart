import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_storage.dart';

/// Thrown for any non-2xx response, carrying the backend's error message
/// when available.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// Thrown specifically when a request got a 401, the automatic refresh
/// attempt ALSO failed (refresh token expired, blacklisted, or missing) —
/// meaning the session is genuinely over and the user must log in again.
/// Screens making authenticated calls should catch this specifically and
/// redirect to WelcomeBackScreen, distinct from a normal ApiException.
class SessionExpiredException implements Exception {
  @override
  String toString() => 'Session expired. Please log in again.';
}

class ApiClient {
  // TODO: point this at your real backend once deployed.
  static const String baseUrl = 'https://api.sabispend.online/api';
  // 'https://doubling-sediment-fragility.ngrok-free.dev/api';

  // Ensures concurrent 401s all await the SAME refresh attempt instead of
  // each independently calling /token/refresh/ with the same refresh
  // token. This matters because the backend rotates + blacklists refresh
  // tokens on use (see SIMPLE_JWT settings) — a second concurrent refresh
  // call using the same now-already-used token would fail, incorrectly
  // triggering a forced logout even though the FIRST refresh succeeded.
  static Future<bool>? _refreshFuture;

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? accessToken,
    bool isRetry = false,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 401 && accessToken != null && !isRetry) {
      final refreshed = await _ensureRefreshed();
      if (refreshed) {
        final newToken = await TokenStorage.getAccessToken();
        return post(path, body, accessToken: newToken, isRetry: true);
      }
      throw SessionExpiredException();
    }

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> get(
    String path, {
    String? accessToken,
    bool isRetry = false,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: {
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 401 && accessToken != null && !isRetry) {
      final refreshed = await _ensureRefreshed();
      if (refreshed) {
        final newToken = await TokenStorage.getAccessToken();
        return get(path, accessToken: newToken, isRetry: true);
      }
      throw SessionExpiredException();
    }

    return _handleResponse(response);
  }

  /// Same as get(), but for endpoints that return a raw JSON array
  /// (e.g. payout plan history) rather than an object.
  static Future<List<dynamic>> getList(
    String path, {
    String? accessToken,
    bool isRetry = false,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: {
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 401 && accessToken != null && !isRetry) {
      final refreshed = await _ensureRefreshed();
      if (refreshed) {
        final newToken = await TokenStorage.getAccessToken();
        return getList(path, accessToken: newToken, isRetry: true);
      }
      throw SessionExpiredException();
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      return decoded is List ? decoded : [];
    }

    throw ApiException(response.statusCode, 'Failed to load data.');
  }

  /// For endpoints returning 204 No Content on success (delete
  /// operations) — no response body to parse, just success or failure.
  static Future<void> delete(
    String path, {
    String? accessToken,
    bool isRetry = false,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: {
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 401 && accessToken != null && !isRetry) {
      final refreshed = await _ensureRefreshed();
      if (refreshed) {
        final newToken = await TokenStorage.getAccessToken();
        return delete(path, accessToken: newToken, isRetry: true);
      }
      throw SessionExpiredException();
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    String message = 'Something went wrong.';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] != null) {
        message = decoded['error'].toString();
      }
    } catch (_) {}

    throw ApiException(response.statusCode, message);
  }

  /// Deduplicates concurrent refresh attempts — see _refreshFuture comment.
  static Future<bool> _ensureRefreshed() {
    _refreshFuture ??= _doRefresh().whenComplete(() => _refreshFuture = null);
    return _refreshFuture!;
  }

  static Future<bool> _doRefresh() async {
    final refreshToken = await TokenStorage.getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      );

      if (response.statusCode != 200) return false;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final newAccess = data['access'] as String;

      // IMPORTANT: the backend has ROTATE_REFRESH_TOKENS=True, meaning
      // it issues a NEW refresh token here too, and blacklists the old
      // one. If this new refresh token isn't saved, the NEXT refresh
      // attempt will fail (using an already-blacklisted token) even
      // though this one succeeded — a subtle bug that only shows up on
      // the *second* refresh, not the first.
      final newRefresh = data['refresh'] as String? ?? refreshToken;

      await TokenStorage.saveTokens(access: newAccess, refresh: newRefresh);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {
      // Non-JSON response — fall through with an empty map.
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    String message =
        data['error']?.toString() ??
        data['message']?.toString() ??
        'Something went wrong.';
    if (data['error'] == null && data['message'] == null && data.isNotEmpty) {
      final firstKey = data.keys.first;
      final firstValue = data[firstKey];
      if (firstValue is List && firstValue.isNotEmpty) {
        message = firstValue.first.toString();
      }
    }

    throw ApiException(response.statusCode, message);
  }
}
