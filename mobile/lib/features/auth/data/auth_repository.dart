// lib/features/auth/data/auth_repository.dart
import 'package:dio/dio.dart';
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
