// lib/core/api/api_client.dart
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../auth/session_store.dart';
import '../constants/app_constants.dart';

/// `options.extra` flag: request was already retried after a token refresh.
const String kExtraRetried = 'auth_retried';

/// `options.extra` flag: never attach a token / never try to refresh.
const String kExtraSkipAuth = 'skip_auth';

BaseOptions _baseOptions() => BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

/// Client WITHOUT the auth interceptor — only for login / refresh endpoints.
final Dio publicApiClient = Dio(_baseOptions());

Dio createDio() {
  final dio = Dio(_baseOptions());
  dio.interceptors.add(_AuthInterceptor(dio, publicApiClient));
  return dio;
}

/// Shared authenticated client. Use this for every authenticated request so
/// that expired access tokens are refreshed transparently.
final Dio apiClient = createDio();

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._dio, this._refreshDio);

  final Dio _dio;
  final Dio _refreshDio;

  /// Single-flight lock: concurrent 401s share one /auth/refresh call.
  Completer<String?>? _refreshCompleter;

  static bool _isRefreshCall(RequestOptions o) => o.path.contains('/auth/refresh');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra[kExtraSkipAuth] != true) {
      final token = SessionStore.instance.accessToken;
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final shouldTryRefresh = err.response?.statusCode == 401 &&
        options.extra[kExtraRetried] != true &&
        options.extra[kExtraSkipAuth] != true &&
        !_isRefreshCall(options) &&
        SessionStore.instance.isLoggedIn;

    if (!shouldTryRefresh) return handler.next(err);

    final newToken = await _refreshAccessToken();
    if (newToken == null) return handler.next(err);

    // Retry the original request exactly once.
    options.extra[kExtraRetried] = true;
    options.headers['Authorization'] = 'Bearer $newToken';
    try {
      final response = await _dio.fetch<dynamic>(options);
      return handler.resolve(response);
    } on DioException catch (e) {
      // The retried request failed for some other reason (timeout / 500 / ...).
      // Do NOT wipe the session here — just surface the error.
      return handler.next(e);
    }
  }

  Future<String?> _refreshAccessToken() {
    final inFlight = _refreshCompleter;
    if (inFlight != null) return inFlight.future;

    final completer = Completer<String?>();
    _refreshCompleter = completer;
    _doRefresh().then(
      (token) {
        _refreshCompleter = null;
        completer.complete(token);
      },
      onError: (Object _) {
        _refreshCompleter = null;
        completer.complete(null);
      },
    );
    return completer.future;
  }

  Future<String?> _doRefresh() async {
    final session = SessionStore.instance;
    final refreshToken = session.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      // Unrecoverable: an access token was rejected and we cannot refresh it.
      await session.clearSession();
      return null;
    }

    try {
      final resp = await _refreshDio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(extra: {kExtraSkipAuth: true}),
      );
      final data = resp.data;
      final newAccess = data is Map ? data['accessToken'] as String? : null;
      final newRefresh = data is Map ? data['refreshToken'] as String? : null;
      if (newAccess == null || newAccess.isEmpty) return null;
      await session.saveTokens(accessToken: newAccess, refreshToken: newRefresh ?? refreshToken);
      return newAccess;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        // Refresh token invalid / revoked / account inactive → force logout.
        // SessionStore notifies the router, which redirects to /login.
        debugPrint('Token refresh rejected ($status) — clearing session');
        await session.clearSession();
      } else {
        debugPrint('Token refresh failed (network/server): ${e.message}');
      }
      return null;
    }
  }
}
