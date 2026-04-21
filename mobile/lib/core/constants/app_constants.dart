// lib/core/constants/app_constants.dart

class AppConstants {
  AppConstants._();

  // App info
  static const String appName = 'Status Go';
  static const String appTagline = 'स्टेटस गो';
  static const String appVersion = '1.0.0';

  // API
  static const String apiBaseUrl = String.fromEnvironment(
    'FLUTTER_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1', // Android emulator localhost
  );

  // Razorpay
  static const String razorpayKeyId = String.fromEnvironment(
    'FLUTTER_RAZORPAY_KEY_ID',
    defaultValue: 'rzp_test_placeholder',
  );

  // Hive box names
  static const String hiveBoxUser = 'user_box';
  static const String hiveBoxSettings = 'settings_box';
  static const String hiveBoxSaved = 'saved_box';

  // Hive keys
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUser = 'user';
  static const String keyLanguage = 'language';
  static const String keyHasOnboarded = 'has_onboarded';
  static const String keyDisplayName = 'display_name';
  static const String keyCustomPhoto = 'custom_photo';
  static const String keyStreakCount = 'streak_count';
  static const String keyLastStreakDate = 'last_streak_date';

  // Plan limits (FREE)
  static const int freeImageDownloadsPerDay = 10;
  static const int freeVideoDownloadsPerDay = 3;

  // Pagination
  static const int defaultPageSize = 20;

  // Status frame size (export canvas)
  static const double frameWidth = 1080.0;
  static const double frameHeight = 1920.0;

  // Cache duration (client-side)
  static const Duration homeRefreshInterval = Duration(minutes: 20);
  static const Duration searchCacheDuration = Duration(minutes: 5);
}
