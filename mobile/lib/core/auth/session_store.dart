// lib/core/auth/session_store.dart
//
// Single source of truth for the auth session (tokens, onboarding flag) and the
// locally cached user profile. Everything lives in the settings box; legacy keys
// that used to be duplicated in the user box are migrated on startup.
//
// It is a [ChangeNotifier] so GoRouter (refreshListenable) and Riverpod providers
// can react when the session changes — e.g. when a token refresh fails and the
// session is wiped, the router redirects to /login.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../constants/app_constants.dart';
import '../../features/auth/domain/models/user_model.dart';

class SessionStore extends ChangeNotifier {
  SessionStore._();
  static final SessionStore instance = SessionStore._();

  // Local-only keys (not part of the server user object)
  static const String keyLocalPhotoPath = 'photoPath'; // file on this device
  static const String keyProfilePhotoUrl = 'profilePhotoUrl'; // remote http(s) URL

  Box get _box => Hive.box(AppConstants.hiveBoxSettings);

  // ─── Tokens / Session ─────────────────────────────────────────────────────

  String? get accessToken => _box.get(AppConstants.keyAccessToken) as String?;
  String? get refreshToken => _box.get(AppConstants.keyRefreshToken) as String?;

  bool get isLoggedIn {
    final t = accessToken;
    return t != null && t.isNotEmpty;
  }

  bool get onboardingCompleted =>
      _box.get(AppConstants.keyOnboardingCompleted, defaultValue: false) == true;

  Future<void> saveTokens({required String accessToken, String? refreshToken}) async {
    await _box.put(AppConstants.keyAccessToken, accessToken);
    if (refreshToken != null) {
      await _box.put(AppConstants.keyRefreshToken, refreshToken);
    }
    notifyListeners();
  }

  Future<void> setOnboardingCompleted(bool value) async {
    await _box.put(AppConstants.keyOnboardingCompleted, value);
    notifyListeners();
  }

  /// Wipes the session. Local personalisation (language, local photo) is kept so a
  /// re-login on the same device feels seamless.
  Future<void> clearSession() async {
    await _box.deleteAll([
      AppConstants.keyAccessToken,
      AppConstants.keyRefreshToken,
      AppConstants.keyUser,
      AppConstants.keyOnboardingCompleted,
      AppConstants.keyState,
      AppConstants.keyRegion,
      keyProfilePhotoUrl,
    ]);
    // Per-account caches
    try {
      await Hive.box(AppConstants.hiveBoxSaved).delete(AppConstants.keySavedTemplateIds);
    } catch (_) {}
    notifyListeners();
  }

  // ─── User ─────────────────────────────────────────────────────────────────

  /// Reads the cached user. Hive returns `Map<dynamic, dynamic>` after a restart,
  /// and very old builds stored a JSON string — accept both.
  UserModel? readUser() {
    final raw = _box.get(AppConstants.keyUser);
    final map = _asJsonMap(raw);
    if (map == null) return null;
    try {
      return UserModel.fromJson(map);
    } catch (e) {
      debugPrint('SessionStore: failed to parse cached user: $e');
      return null;
    }
  }

  Map<String, dynamic>? readUserJson() => _asJsonMap(_box.get(AppConstants.keyUser));

  /// Persists the user and mirrors frequently used fields into flat keys.
  Future<void> writeUser(UserModel user) async {
    await _box.put(AppConstants.keyUser, user.toJson());
    if (user.name != null && user.name!.trim().isNotEmpty) {
      await _box.put(AppConstants.keyDisplayName, user.name);
    }
    final photo = user.profilePhoto;
    if (photo != null && isRemoteUrl(photo)) {
      await _box.put(keyProfilePhotoUrl, photo);
    }
    if (user.language.isNotEmpty) await _box.put(AppConstants.keyLanguage, user.language);
    if (user.state != null) await _box.put(AppConstants.keyState, user.state);
    if (user.region != null) await _box.put(AppConstants.keyRegion, user.region);
    if (user.onboardingCompleted) {
      await _box.put(AppConstants.keyOnboardingCompleted, true);
    }
    notifyListeners();
  }

  // ─── Local personalisation ────────────────────────────────────────────────

  String? get displayName {
    final local = _box.get(AppConstants.keyDisplayName) as String?;
    if (local != null && local.trim().isNotEmpty) return local;
    return readUser()?.name;
  }

  Future<void> setDisplayName(String name) async {
    await _box.put(AppConstants.keyDisplayName, name);
    notifyListeners();
  }

  /// Local file path of the photo the user picked on this device.
  String? get localPhotoPath => _box.get(keyLocalPhotoPath) as String?;

  Future<void> setLocalPhotoPath(String? path) async {
    if (path == null || path.isEmpty) {
      await _box.delete(keyLocalPhotoPath);
    } else {
      await _box.put(keyLocalPhotoPath, path);
    }
    notifyListeners();
  }

  /// Remote (uploaded) profile photo URL.
  String? get profilePhotoUrl {
    final url = _box.get(keyProfilePhotoUrl) as String?;
    if (url != null && url.isNotEmpty) return url;
    final p = readUser()?.profilePhoto;
    return (p != null && isRemoteUrl(p)) ? p : null;
  }

  /// The best photo to render: the locally picked file (most recent user choice)
  /// if it still exists, otherwise the uploaded URL.
  String? get effectivePhoto => localPhotoPath ?? profilePhotoUrl;

  String? get language => _box.get(AppConstants.keyLanguage) as String?;

  // ─── Migration ────────────────────────────────────────────────────────────

  /// Migrates legacy duplicated keys (user box `name`/`photoPath`, settings
  /// `custom_photo`) into the single settings-box layout. Safe to call repeatedly.
  Future<void> migrateLegacy() async {
    try {
      final userBox = Hive.box(AppConstants.hiveBoxUser);

      final legacyName = userBox.get('name') as String?;
      if (legacyName != null && legacyName.trim().isNotEmpty) {
        final current = _box.get(AppConstants.keyDisplayName) as String?;
        if (current == null || current.trim().isEmpty) {
          await _box.put(AppConstants.keyDisplayName, legacyName);
        }
      }

      for (final legacy in [userBox.get('photoPath'), _box.get(AppConstants.keyCustomPhoto)]) {
        if (legacy is! String || legacy.isEmpty) continue;
        if (isRemoteUrl(legacy)) {
          if (_box.get(keyProfilePhotoUrl) == null) await _box.put(keyProfilePhotoUrl, legacy);
        } else if (_box.get(keyLocalPhotoPath) == null) {
          await _box.put(keyLocalPhotoPath, legacy);
        }
      }

      // A local path that was mistakenly sent/stored as the server profile photo
      final u = readUserJson();
      if (u != null) {
        final p = u['profilePhoto'];
        if (p is String && p.isNotEmpty && !isRemoteUrl(p)) {
          u['profilePhoto'] = null;
          await _box.put(AppConstants.keyUser, u);
        }
      }

      // Old dev builds created fake sessions that the backend never issued.
      final token = accessToken;
      if (token != null && token.startsWith('mock_jwt_token_')) {
        await _box.deleteAll([
          AppConstants.keyAccessToken,
          AppConstants.keyRefreshToken,
          AppConstants.keyUser,
          AppConstants.keyOnboardingCompleted,
        ]);
      }

      await userBox.deleteAll(['name', 'photoPath']);
      await _box.delete(AppConstants.keyCustomPhoto);
    } catch (e) {
      debugPrint('SessionStore migration error: $e');
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static bool isRemoteUrl(String value) =>
      value.startsWith('http://') || value.startsWith('https://');

  static Map<String, dynamic>? _asJsonMap(Object? raw) {
    if (raw == null) return null;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }
}
