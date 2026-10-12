// lib/core/constants/app_constants.dart
import 'package:flutter/foundation.dart';

class AppConstants {
  AppConstants._();

  // App info
  static const String appName = 'Status Go';
  static const String appTagline = 'स्टेटस गो';
  static const String appVersion = '1.0.0';

  // API
  // Pass --dart-define=FLUTTER_API_BASE_URL=https://api.example.com/api/v1 for
  // profile/release builds. The plain-http LAN default only applies to debug builds.
  static const String _apiBaseUrlDefine = String.fromEnvironment('FLUTTER_API_BASE_URL');
  static const String _debugApiBaseUrl = 'https://statusgo-api-412085285504.asia-south1.run.app/api/v1';
  static const String _releasePlaceholderApiBaseUrl = 'https://statusgo-api-412085285504.asia-south1.run.app/api/v1';

  static String get apiBaseUrl {
    if (_apiBaseUrlDefine.isNotEmpty) return _apiBaseUrlDefine;
    if (kDebugMode) return _debugApiBaseUrl;
    debugPrint(
      'ERROR: FLUTTER_API_BASE_URL was not provided for a non-debug build. '
      'Pass --dart-define=FLUTTER_API_BASE_URL=https://<host>/api/v1',
    );
    return _releasePlaceholderApiBaseUrl;
  }

  // Razorpay (public key id only — provide via --dart-define; the backend also
  // returns keyId from /subscribe/create, which takes precedence)
  static const String razorpayKeyId = String.fromEnvironment(
    'FLUTTER_RAZORPAY_KEY_ID',
    defaultValue: 'rzp_test_TmJlbSe2oDPij0',
  );

  // Google Sign-In: the WEB OAuth client id the backend verifies id tokens against
  static const String googleServerClientId = String.fromEnvironment('FLUTTER_GOOGLE_SERVER_CLIENT_ID');
  // iOS OAuth client id (only used on iOS)
  static const String googleIosClientId = String.fromEnvironment('FLUTTER_GOOGLE_CLIENT_ID_IOS');

  // Store / support
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.statusgo.status_go';

  // ──────────────────────────────────────────────────────────────────────────
  // TODO(owner): fill in ALL values below before publishing to the Play Store.
  // They are rendered in Privacy Policy / Terms / Refund / About / Help pages.
  // ──────────────────────────────────────────────────────────────────────────
  static const String supportEmail = 'support@statusgo.app'; // TODO(owner)
  static const String supportPhone = '+91 00000 00000'; // TODO(owner): support call number
  static const String supportWhatsappNumber = '910000000000'; // TODO(owner): digits only, with country code
  static const String companyName = 'Status Go (TODO: registered company name)'; // TODO(owner)
  static const String companyAddress = 'TODO: registered office address, City, State, PIN, India'; // TODO(owner)
  static const String grievanceOfficerName = 'TODO: Grievance Officer name'; // TODO(owner)
  static const String grievanceOfficerEmail = 'grievance@statusgo.app'; // TODO(owner)
  static const String websiteUrl = 'https://statusgo.app'; // TODO(owner)
  static const String privacyUrl = 'https://statusgo.app/privacy'; // TODO(owner): hosted copy (Play Console needs one)
  static const String termsUrl = 'https://statusgo.app/terms'; // TODO(owner)
  static const String refundUrl = 'https://statusgo.app/refund'; // TODO(owner)
  static const String policyLastUpdated = '1 October 2026'; // update when policy text changes

  // Push Notifications (OneSignal)
  static const String oneSignalAppId = String.fromEnvironment(
    'FLUTTER_ONESIGNAL_APP_ID',
    defaultValue: '',
  );

  // Hive box names
  static const String hiveBoxUser = 'user_box';
  static const String hiveBoxSettings = 'settings_box';
  static const String hiveBoxSaved = 'saved_box';
  static const String hiveBoxNotifications = 'notifications_box';

  // Hive keys
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUser = 'user';
  static const String keyLanguage = 'language';
  static const String keyHasOnboarded = 'has_onboarded';
  static const String keyOnboardingCompleted = 'onboarding_completed';
  static const String keyDisplayName = 'display_name';
  /// Legacy key (migrated by SessionStore.migrateLegacy) — do not write.
  static const String keyCustomPhoto = 'custom_photo';
  static const String keySavedTemplateIds = 'saved_template_ids';
  static const String keyStreakCount = 'streak_count';
  static const String keyLastStreakDate = 'last_streak_date';
  static const String keyState = 'user_state';
  static const String keyRegion = 'user_region';
  static const String keyOneSignalPlayerId = 'onesignal_player_id';
  static const String keyThemeMode = 'theme_mode'; // 'system' | 'light' | 'dark'
  static const String keyIntroSeen = 'intro_seen';
  static const String keyPushEnabled = 'push_enabled';
  static const String keyDailyReminder = 'daily_reminder_enabled';
  static const String keyFestivalAlerts = 'festival_alerts_enabled';

  // Plan limits (FREE) — informational only. NOT enforced client-side on purpose:
  // the server must own download limits (a client check is trivially bypassed).
  static const int freeImageDownloadsPerDay = 10;
  static const int freeVideoDownloadsPerDay = 3;

  // Pagination
  static const int defaultPageSize = 20;

  // Status frame size (export canvas)
  static const double frameWidth = 1080.0;
  static const double frameHeight = 1920.0;
  // Export: rendered composition is captured so its width equals [frameWidth].

  // Cache duration (client-side)
  static const Duration homeRefreshInterval = Duration(minutes: 20);
  static const Duration searchCacheDuration = Duration(minutes: 5);
}
