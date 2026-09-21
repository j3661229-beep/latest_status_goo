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

  // ─── Google Sign-In ───────────────────────────────────────────────────────

  Future<UserModel?> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null;

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) throw Exception('Failed to get Google ID token');

      return await _signInWithBackend('/auth/google', {'idToken': idToken});
    } on PlatformException catch (e) {
      debugPrint('Google Sign In Error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Google Sign In Error: $e');
      rethrow;
    }
  }

  // ─── Firebase Phone Auth ──────────────────────────────────────────────────

  /// Sign in with a Firebase phone auth ID token (from FirebaseAuth.signInWithCredential)
  Future<Map<String, dynamic>> signInWithFirebaseToken(String idToken) async {
    final dio = Dio(BaseOptions(baseUrl: AppConstants.apiBaseUrl));
    final resp = await dio.post('/auth/firebase-phone', data: {'idToken': idToken});

    final accessToken = resp.data['accessToken'] as String;
    final refreshToken = resp.data['refreshToken'] as String;
    final userData = resp.data['user'] as Map<String, dynamic>;
    final onboardingRequired = resp.data['onboardingRequired'] as bool? ?? false;

    final box = Hive.box(AppConstants.hiveBoxSettings);
    await box.put(AppConstants.keyAccessToken, accessToken);
    await box.put(AppConstants.keyRefreshToken, refreshToken);
    await box.put(AppConstants.keyOnboardingCompleted, !onboardingRequired);

    // Persist user fields
    final user = UserModel.fromJson(userData);
    await _persistUser(user);

    return {'user': user, 'onboardingRequired': onboardingRequired};
  }

  // ─── OTP (legacy backend-driven, kept for backward compat) ───────────────

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
    final onboardingRequired = resp.data['onboardingRequired'] as bool? ?? false;

    final box = Hive.box(AppConstants.hiveBoxSettings);
    await box.put(AppConstants.keyAccessToken, accessToken);
    await box.put(AppConstants.keyRefreshToken, refreshToken);
    await box.put(AppConstants.keyOnboardingCompleted, !onboardingRequired);

    final user = UserModel.fromJson(userData);
    await _persistUser(user);

    return {'user': user, 'onboardingRequired': onboardingRequired};
  }

  // ─── Profile Completion ───────────────────────────────────────────────────

  Future<void> completeProfile({
    required String name,
    String? profilePhoto,
    String? state,
    String? region,
    String? language,
  }) async {
    final box = Hive.box(AppConstants.hiveBoxSettings);
    final token = box.get(AppConstants.keyAccessToken);

    final dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      headers: {'Authorization': 'Bearer $token'},
    ));

    final resp = await dio.post('/auth/complete-profile', data: {
      'name': name,
      if (profilePhoto != null) 'profilePhoto': profilePhoto,
      if (state != null) 'state': state,
      if (region != null) 'region': region,
      if (language != null) 'language': language,
    });

    final userData = resp.data['user'] as Map<String, dynamic>;
    final user = UserModel.fromJson(userData);
    await _persistUser(user);

    // Persist state/region locally for quick access
    if (state != null) await box.put(AppConstants.keyState, state);
    if (region != null) await box.put(AppConstants.keyRegion, region);
    await box.put(AppConstants.keyOnboardingCompleted, true);
  }

  /// Upload a profile photo to GCS via our backend
  Future<String?> uploadProfilePhoto(String filePath) async {
    try {
      final box = Hive.box(AppConstants.hiveBoxSettings);
      final token = box.get(AppConstants.keyAccessToken);

      final dio = Dio(BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        headers: {'Authorization': 'Bearer $token'},
      ));

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: 'profile.jpg'),
      });

      final resp = await dio.post('/upload/profile-photo', data: formData);
      return resp.data['url'] as String?;
    } catch (e) {
      debugPrint('Profile photo upload error: $e');
      return null;
    }
  }

  // ─── Profile Update (legacy) ──────────────────────────────────────────────

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
    await _persistUser(user);
  }

  // ─── Sign Out ─────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    final box = Hive.box(AppConstants.hiveBoxSettings);
    await box.deleteAll([
      AppConstants.keyAccessToken,
      AppConstants.keyRefreshToken,
      AppConstants.keyUser,
      AppConstants.keyOnboardingCompleted,
      AppConstants.keyState,
      AppConstants.keyRegion,
    ]);
  }

  // ─── Getters ──────────────────────────────────────────────────────────────

  UserModel? getCurrentUser() {
    final box = Hive.box(AppConstants.hiveBoxSettings);
    final jsonStr = box.get(AppConstants.keyUser);
    if (jsonStr == null) return null;
    try {
      // Stored as JSON string
      return UserModel.fromJson(
          Map<String, dynamic>.from(Map.castFrom(jsonStr)));
    } catch (_) {
      return null;
    }
  }

  String? getAccessToken() {
    final box = Hive.box(AppConstants.hiveBoxSettings);
    return box.get(AppConstants.keyAccessToken);
  }

  String? getUserState() {
    final box = Hive.box(AppConstants.hiveBoxSettings);
    return box.get(AppConstants.keyState);
  }

  String? getUserRegion() {
    final box = Hive.box(AppConstants.hiveBoxSettings);
    return box.get(AppConstants.keyRegion);
  }

  Future<UserModel?> updateBusinessBranding({
    String? businessName,
    String? businessPhone,
    String? businessAddress,
    String? businessDesignation,
    String? businessLogo,
    String? frameType,
  }) async {
    final box = Hive.box(AppConstants.hiveBoxSettings);
    final token = box.get(AppConstants.keyAccessToken);

    UserModel? updatedUser;

    try {
      if (token != null) {
        final dio = Dio(BaseOptions(
          baseUrl: AppConstants.apiBaseUrl,
          headers: {'Authorization': 'Bearer $token'},
        ));
        final resp = await dio.put('/user/me', data: {
          if (businessName != null) 'businessName': businessName,
          if (businessPhone != null) 'businessPhone': businessPhone,
          if (businessAddress != null) 'businessAddress': businessAddress,
          if (businessDesignation != null) 'businessDesignation': businessDesignation,
          if (businessLogo != null) 'businessLogo': businessLogo,
          if (frameType != null) 'frameType': frameType,
        });
        if (resp.data != null && resp.data['data'] != null) {
          updatedUser = UserModel.fromJson(resp.data['data'] as Map<String, dynamic>);
          await _persistUser(updatedUser);
        }
      }
    } catch (e) {
      debugPrint('Failed to sync business branding to backend: $e');
    }

    if (updatedUser == null) {
      final rawUser = box.get(AppConstants.keyUser);
      if (rawUser != null) {
        UserModel user;
        if (rawUser is Map<String, dynamic>) {
          user = UserModel.fromJson(rawUser);
        } else {
          user = UserModel.fromJson(Map<String, dynamic>.from(rawUser as Map));
        }
        updatedUser = user.copyWith(
          businessName: businessName,
          businessPhone: businessPhone,
          businessAddress: businessAddress,
          businessDesignation: businessDesignation,
          businessLogo: businessLogo,
          frameType: frameType,
        );
        await _persistUser(updatedUser);
      }
    }

    return updatedUser;
  }

  bool get isLoggedIn => getAccessToken() != null;

  bool get onboardingCompleted {
    final box = Hive.box(AppConstants.hiveBoxSettings);
    return box.get(AppConstants.keyOnboardingCompleted, defaultValue: false) == true;
  }

  // ─── Private Helpers ──────────────────────────────────────────────────────

  Future<UserModel> _signInWithBackend(String path, Map<String, dynamic> body) async {
    final dio = Dio(BaseOptions(baseUrl: AppConstants.apiBaseUrl));
    final resp = await dio.post(path, data: body);

    final accessToken = resp.data['accessToken'] as String;
    final refreshToken = resp.data['refreshToken'] as String;
    final userData = resp.data['user'] as Map<String, dynamic>;

    final box = Hive.box(AppConstants.hiveBoxSettings);
    await box.put(AppConstants.keyAccessToken, accessToken);
    await box.put(AppConstants.keyRefreshToken, refreshToken);

    final user = UserModel.fromJson(userData);
    await _persistUser(user);
    return user;
  }

  Future<void> _persistUser(UserModel user) async {
    final box = Hive.box(AppConstants.hiveBoxSettings);
    await box.put(AppConstants.keyUser, user.toJson());
    if (user.state != null) await box.put(AppConstants.keyState, user.state!);
    if (user.region != null) await box.put(AppConstants.keyRegion, user.region!);
  }
}
