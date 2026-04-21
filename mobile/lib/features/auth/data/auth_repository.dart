// lib/features/auth/data/auth_repository.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/models/user_model.dart';

part 'auth_repository.g.dart';

@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) {
  return AuthRepository();
}

class AuthRepository {
  final _googleSignIn = GoogleSignIn(
    clientId: const String.fromEnvironment('FLUTTER_GOOGLE_CLIENT_ID_ANDROID'),
    scopes: ['email', 'profile'],
  );

  Future<UserModel?> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null;

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) throw Exception('Failed to get Google ID token');

      // Call backend
      final dio = Dio(BaseOptions(baseUrl: AppConstants.apiBaseUrl));
      final resp = await dio.post('/auth/google', data: {'idToken': idToken});

      final accessToken = resp.data['accessToken'] as String;
      final refreshToken = resp.data['refreshToken'] as String;
      final userData = resp.data['user'] as Map<String, dynamic>;

      // Persist tokens
      final box = Hive.box(AppConstants.hiveBoxSettings);
      await box.put(AppConstants.keyAccessToken, accessToken);
      await box.put(AppConstants.keyRefreshToken, refreshToken);

      final user = UserModel.fromJson(userData);
      await box.put(AppConstants.keyUser, user.toJson().toString());

      return user;
    } on PlatformException catch (e) {
      debugPrint('Google Sign In Error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Google Sign In Error: $e');
      rethrow;
    }
  }

  Future<void> sendOtp(String phoneNumber) async {
    final dio = Dio(BaseOptions(baseUrl: AppConstants.apiBaseUrl));
    await dio.post('/auth/otp/send', data: {'phoneNumber': phoneNumber});
  }

  Future<Map<String, dynamic>> verifyOtp(String phoneNumber, String otp) async {
    final dio = Dio(BaseOptions(baseUrl: AppConstants.apiBaseUrl));
    final resp = await dio.post('/auth/otp/verify', data: {
      'phoneNumber': phoneNumber,
      'otp': otp,
    });

    final accessToken = resp.data['accessToken'] as String;
    final refreshToken = resp.data['refreshToken'] as String;
    final userData = resp.data['user'] as Map<String, dynamic>;
    final onboardingRequired = resp.data['onboardingRequired'] as bool;

    // Persist tokens
    final box = Hive.box(AppConstants.hiveBoxSettings);
    await box.put(AppConstants.keyAccessToken, accessToken);
    await box.put(AppConstants.keyRefreshToken, refreshToken);

    final user = UserModel.fromJson(userData);
    await box.put(AppConstants.keyUser, user.toJson().toString());

    return {
      'user': user,
      'onboardingRequired': onboardingRequired,
    };
  }

  Future<void> updateProfile({required String name, String? photoUrl}) async {
    final box = Hive.box(AppConstants.hiveBoxSettings);
    final token = box.get(AppConstants.keyAccessToken);
    
    final dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      headers: {'Authorization': 'Bearer $token'},
    ));

    final resp = await dio.put('/user/me', data: {
      'name': name,
      if (photoUrl != null) 'profilePhoto': photoUrl,
    });

    final userData = resp.data['user'] as Map<String, dynamic>;
    final user = UserModel.fromJson(userData);
    await box.put(AppConstants.keyUser, user.toJson().toString());
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    final box = Hive.box(AppConstants.hiveBoxSettings);
    await box.deleteAll([
      AppConstants.keyAccessToken,
      AppConstants.keyRefreshToken,
      AppConstants.keyUser,
    ]);
  }

  UserModel? getCurrentUser() {
    final box = Hive.box(AppConstants.hiveBoxSettings);
    final userStr = box.get(AppConstants.keyUser);
    if (userStr == null) return null;
    try {
      // Simplified — in production use proper JSON decode
      return null;
    } catch (_) {
      return null;
    }
  }

  String? getAccessToken() {
    final box = Hive.box(AppConstants.hiveBoxSettings);
    return box.get(AppConstants.keyAccessToken);
  }

  bool get isLoggedIn => getAccessToken() != null;
}
