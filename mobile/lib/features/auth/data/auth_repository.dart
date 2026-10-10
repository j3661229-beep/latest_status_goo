// lib/features/auth/data/auth_repository.dart
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../../../core/auth/session_store.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/notification_service.dart';
import '../domain/models/user_model.dart';

part 'auth_repository.g.dart';

@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) {
  return AuthRepository();
}

/// Result of a successful login.
class AuthResult {
  final UserModel user;
  final bool onboardingRequired;
  const AuthResult({required this.user, required this.onboardingRequired});
}

class AuthRepository {
  AuthRepository({Dio? api, Dio? publicApi})
      : _api = api ?? apiClient,
        _publicApi = publicApi ?? publicApiClient;

  /// Authenticated client (auto token refresh).
  final Dio _api;

  /// Client without auth interceptor — only for login endpoints.
  final Dio _publicApi;

  SessionStore get _session => SessionStore.instance;

  static GoogleSignIn _buildGoogleSignIn() {
    final isIOS = !kIsWeb && Platform.isIOS;
    return GoogleSignIn(
      // Only iOS needs an explicit client id; Android resolves it from the
      // package name + SHA-1 registered in the Google Cloud console.
      clientId: isIOS && AppConstants.googleIosClientId.isNotEmpty ? AppConstants.googleIosClientId : null,
      // The WEB client id: makes Google issue an idToken whose audience the
      // backend verifies against.
      serverClientId: AppConstants.googleServerClientId.isNotEmpty ? AppConstants.googleServerClientId : null,
      scopes: const ['email', 'profile'],
    );
  }

  static final GoogleSignIn _googleSignIn = _buildGoogleSignIn();

  // ─── Google Sign-In ───────────────────────────────────────────────────────

  /// Returns null when the user cancels the Google account picker.
  Future<AuthResult?> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null;

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        await _googleSignIn.signOut();
        throw const ApiException(
          'Google से ID टोकन नहीं मिला। ऐप में FLUTTER_GOOGLE_SERVER_CLIENT_ID (Web client ID) सेट करें।',
        );
      }

      return await _loginWith('/auth/google', {'idToken': idToken});
    } on PlatformException catch (e) {
      debugPrint('Google Sign In Error: ${e.code} - ${e.message}');
      throw ApiException('Google Sign-In विफल रहा (${e.code})।');
    }
  }

  // ─── OTP ──────────────────────────────────────────────────────────────────

  /// Sends an OTP. Throws on failure (callers surface the message).
  /// Returns the OTP only when the backend runs in test-OTP mode and includes it
  /// in the response (development only).
  Future<String?> sendOtp(String phoneNumber) async {
    final resp = await _publicApi.post('/auth/otp/send', data: {'phoneNumber': phoneNumber});
    final data = resp.data;
    if (data is Map && data['otp'] != null) {
      final otp = data['otp'].toString();
      return otp.isEmpty ? null : otp;
    }
    return null;
  }

  /// Verifies the OTP with the backend. Only real backend tokens create a session.
  Future<AuthResult> verifyOtp(String phoneNumber, String otp) {
    return _loginWith('/auth/otp/verify', {'phoneNumber': phoneNumber, 'otp': otp});
  }

  // ─── Profile Completion ───────────────────────────────────────────────────

  /// Completes the profile on the server. Throws if the server call fails —
  /// the UI keeps the entered values and lets the user retry.
  /// [profilePhotoUrl] must be a remote URL (never a local file path).
  Future<UserModel> completeProfile({
    required String name,
    String? profilePhotoUrl,
    String? state,
    String? region,
    String? language,
  }) async {
    assert(profilePhotoUrl == null || SessionStore.isRemoteUrl(profilePhotoUrl));
    final resp = await _api.post('/auth/complete-profile', data: {
      'name': name,
      if (profilePhotoUrl != null && SessionStore.isRemoteUrl(profilePhotoUrl)) 'profilePhoto': profilePhotoUrl,
      if (state != null) 'state': state,
      if (region != null) 'region': region,
      if (language != null) 'language': language,
    });

    final user = await _persistServerUser(_extractUser(resp.data));
    await _session.setDisplayName(name);
    await _session.setOnboardingCompleted(true);
    return user;
  }

  /// Uploads a profile photo. Returns the remote URL. Throws on failure.
  Future<String> uploadProfilePhoto(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: 'profile.jpg'),
    });
    final resp = await _api.post(
      '/upload/profile-photo',
      data: formData,
      options: Options(sendTimeout: const Duration(seconds: 60), receiveTimeout: const Duration(seconds: 60)),
    );
    final url = resp.data is Map ? resp.data['url'] as String? : null;
    if (url == null || !SessionStore.isRemoteUrl(url)) {
      throw const ApiException('फ़ोटो अपलोड नहीं हो सकी।');
    }
    await _session.setLocalPhotoPath(filePath);
    return url;
  }

  // ─── Profile Update ───────────────────────────────────────────────────────

  Future<UserModel> updateProfile({required String name, String? photoUrl}) async {
    final resp = await _api.put('/user/me', data: {
      'name': name,
      if (photoUrl != null && SessionStore.isRemoteUrl(photoUrl)) 'profilePhoto': photoUrl,
    });
    return _persistServerUser(_extractUser(resp.data));
  }

  /// GET /user/me → refreshes the cached user (plan, stats, branding).
  Future<UserModel?> refreshCurrentUser() async {
    if (!_session.isLoggedIn) return null;
    final resp = await _api.get('/user/me');
    final data = resp.data;
    final userJson = _extractUser(data);
    // `plan.status` is authoritative for the plan (handles expiry server-side).
    if (data is Map && data['plan'] is Map && (data['plan'] as Map)['status'] is String) {
      userJson['plan'] = (data['plan'] as Map)['status'];
    }
    return _persistServerUser(userJson);
  }

  // ─── Sign Out ─────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    final refreshToken = _session.refreshToken;
    if (refreshToken != null) {
      // Best-effort server-side revoke; never blocks logout.
      _publicApi
          .post('/auth/logout', data: {'refreshToken': refreshToken})
          .timeout(const Duration(seconds: 4))
          .catchError((Object _) => Response(requestOptions: RequestOptions()));
    }
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await NotificationService.instance.onSignOut();
    await _session.clearSession();
  }

  // ─── Edit profile / language / delete account ──────────────────────────────

  /// Uploads an image (business logo) without touching the locally cached
  /// profile photo. Returns the remote URL. Throws on failure.
  Future<String> uploadImage(String filePath, {String filename = 'image.jpg'}) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: filename),
    });
    final resp = await _api.post(
      '/upload/profile-photo',
      data: formData,
      options: Options(sendTimeout: const Duration(seconds: 60), receiveTimeout: const Duration(seconds: 60)),
    );
    final url = resp.data is Map ? resp.data['url'] as String? : null;
    if (url == null || !SessionStore.isRemoteUrl(url)) {
      throw const ApiException('फ़ोटो अपलोड नहीं हो सकी।');
    }
    return url;
  }

  /// PUT /user/me with any subset of profile fields. Empty strings clear a
  /// text field on the server. Persists the returned user.
  Future<UserModel> updateProfileFields(Map<String, dynamic> fields) async {
    final resp = await _api.put('/user/me', data: fields);
    return _persistServerUser(_extractUser(resp.data));
  }

  /// Persists the preferred language (HINDI / MARATHI / ENGLISH ...) on the server.
  Future<UserModel> updateLanguage(String language) => updateProfileFields({'language': language});

  /// DELETE /user/me — in-app account deletion (Play Store requirement).
  /// On success the session and personal local data are wiped, which makes the
  /// router redirect to /login.
  Future<void> deleteAccount() async {
    await _api.delete('/user/me');
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await NotificationService.instance.onSignOut();
    await _session.clearPersonalData();
    await _session.clearSession();
  }

  // ─── Getters ──────────────────────────────────────────────────────────────

  UserModel? getCurrentUser() => _session.readUser();

  String? getAccessToken() => _session.accessToken;

  bool get isLoggedIn => _session.isLoggedIn;

  bool get onboardingCompleted => _session.onboardingCompleted;

  // ─── Business Branding ────────────────────────────────────────────────────

  /// PUT /user/me returns `{ user }`. Persists the server copy. Throws on failure.
  Future<UserModel> updateBusinessBranding({
    String? businessName,
    String? businessPhone,
    String? businessAddress,
    String? businessDesignation,
    String? businessLogo,
    String? frameType,
  }) async {
    final resp = await _api.put('/user/me', data: {
      if (businessName != null) 'businessName': businessName,
      if (businessPhone != null) 'businessPhone': businessPhone,
      if (businessAddress != null) 'businessAddress': businessAddress,
      if (businessDesignation != null) 'businessDesignation': businessDesignation,
      if (businessLogo != null) 'businessLogo': businessLogo,
      if (frameType != null) 'frameType': frameType,
    });
    return _persistServerUser(_extractUser(resp.data));
  }

  // ─── Private Helpers ──────────────────────────────────────────────────────

  Future<AuthResult> _loginWith(String path, Map<String, dynamic> body) async {
    final resp = await _publicApi.post(path, data: body);
    final data = resp.data;
    if (data is! Map) throw const ApiException('सर्वर से अमान्य जवाब मिला।');

    final accessToken = data['accessToken'] as String?;
    final refreshToken = data['refreshToken'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw const ApiException('लॉगिन विफल रहा। कृपया दोबारा कोशिश करें।');
    }

    final userJson = _extractUser(data);
    final onboardingRequired = data['onboardingRequired'] == true;

    // Onboarding flag first, then tokens (token write notifies the router).
    await _session.setOnboardingCompleted(!onboardingRequired);
    final user = await _persistServerUser(userJson);
    await _session.saveTokens(accessToken: accessToken, refreshToken: refreshToken);

    return AuthResult(user: user, onboardingRequired: onboardingRequired);
  }

  Map<String, dynamic> _extractUser(dynamic data) {
    if (data is Map && data['user'] is Map) {
      return Map<String, dynamic>.from(data['user'] as Map);
    }
    throw const ApiException('सर्वर से उपयोगकर्ता जानकारी नहीं मिली।');
  }

  /// Merges the server user over the cached one (server responses don't always
  /// include every field, e.g. /user/me has no phoneNumber) and persists it.
  Future<UserModel> _persistServerUser(Map<String, dynamic> serverJson) async {
    final cached = _session.readUserJson();
    final sameUser = cached != null && serverJson['id'] != null && cached['id'] == serverJson['id'];
    final merged = <String, dynamic>{if (sameUser) ...cached};
    serverJson.forEach((key, value) {
      if (value != null) merged[key] = value;
    });
    if (_session.onboardingCompleted) merged['onboardingCompleted'] = true;
    // Drop unknown nested objects Hive can't round-trip cleanly.
    merged.removeWhere((_, v) => v is Map || v is List);

    final user = UserModel.fromJson(merged);
    await _session.writeUser(user);
    NotificationService.instance.syncUser(user);
    return user;
  }
}
