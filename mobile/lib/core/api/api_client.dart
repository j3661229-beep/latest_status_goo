// lib/core/api/api_client.dart
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import '../constants/app_constants.dart';

Dio createDio() {
  final dio = Dio(BaseOptions(
    baseUrl: AppConstants.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  // Request interceptor — attach JWT
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final box = await Hive.openBox(AppConstants.hiveBoxSettings);
      final token = box.get(AppConstants.keyAccessToken);
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      return handler.next(options);
    },
    onError: (error, handler) async {
      // 401 — attempt token refresh
      if (error.response?.statusCode == 401) {
        try {
          final box = await Hive.openBox(AppConstants.hiveBoxSettings);
          final refreshToken = box.get(AppConstants.keyRefreshToken);
          if (refreshToken == null) return handler.next(error);

          final refreshDio = Dio(BaseOptions(baseUrl: AppConstants.apiBaseUrl));
          final resp = await refreshDio.post('/auth/refresh', data: {'refreshToken': refreshToken});
          final newAccessToken = resp.data['accessToken'];
          final newRefreshToken = resp.data['refreshToken'];

          await box.put(AppConstants.keyAccessToken, newAccessToken);
          await box.put(AppConstants.keyRefreshToken, newRefreshToken);

          // Retry original request with new token
          final opts = error.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newAccessToken';
          final retryResp = await dio.fetch(opts);
          return handler.resolve(retryResp);
        } catch (_) {
          // Force logout
          final box = await Hive.openBox(AppConstants.hiveBoxSettings);
          await box.deleteAll([AppConstants.keyAccessToken, AppConstants.keyRefreshToken, AppConstants.keyUser]);
        }
      }
      return handler.next(error);
    },
  ));

  return dio;
}
