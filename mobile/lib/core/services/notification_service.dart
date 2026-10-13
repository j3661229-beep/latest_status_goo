// lib/core/services/notification_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../api/api_client.dart';
import '../constants/app_constants.dart';
import '../models/notification_model.dart';
import '../widgets/app_ui.dart';
import '../../features/auth/domain/models/user_model.dart';

/// Returns true if the route was handled, false if the app isn't ready yet
/// (the deep link then stays buffered until [flushPendingDeepLink]).
typedef NotificationNavigationHandler = bool Function(String route, Map<String, dynamic>? data);

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  bool _initialized = false;
  NotificationNavigationHandler? _navigationHandler;
  final _onNotificationReceivedController = StreamController<NotificationModel>.broadcast();

  Stream<NotificationModel> get onNotificationReceived => _onNotificationReceivedController.stream;

  // Deep link received before a navigation handler was registered / ready
  // (cold start from a notification tap).
  String? _pendingRoute;
  Map<String, dynamic>? _pendingData;

  void setNavigationHandler(NotificationNavigationHandler handler) {
    _navigationHandler = handler;
    flushPendingDeepLink();
  }

  void clearNavigationHandler() {
    _navigationHandler = null;
  }

  /// Delivers a buffered deep link if the app is ready to navigate.
  void flushPendingDeepLink() {
    final route = _pendingRoute;
    final handler = _navigationHandler;
    if (route == null || handler == null) return;
    final data = _pendingData;
    if (handler(route, data)) {
      _pendingRoute = null;
      _pendingData = null;
    }
  }

  /// Initialize OneSignal with App ID & listeners
  Future<void> init() async {
    if (_initialized) return;

    const appId = AppConstants.oneSignalAppId;
    if (appId.isEmpty) {
      debugPrint('ℹ️ OneSignal App ID is not configured. Skipping OneSignal init.');
      _initialized = true;
      return;
    }

    try {
      // 1. Initialize SDK
      OneSignal.initialize(appId);
      debugPrint('✅ OneSignal initialized successfully with App ID: $appId');

      // 2. Setup Foreground Notification Listener
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        debugPrint('🔔 OneSignal foreground notification received: ${event.notification.title}');
        
        // Extract notification details
        final notif = _mapOneSignalNotification(event.notification);
        
        // Save to local Hive box for in-app inbox
        _saveNotificationLocally(notif);

        // Notify in-app streams
        _onNotificationReceivedController.add(notif);

        // Display the notification banner
        event.notification.display();
      });

      // 3. Setup Notification Click Listener
      OneSignal.Notifications.addClickListener((event) {
        debugPrint('👆 OneSignal notification clicked: ${event.notification.title}');
        final notif = _mapOneSignalNotification(event.notification);
        _saveNotificationLocally(notif.copyWith(isRead: true));

        final data = event.notification.additionalData;
        _handleDeepLink(data);
      });

      // 4. Listen for push subscription / playerId changes
      OneSignal.User.pushSubscription.addObserver((state) {
        final newId = state.current.id;
        if (newId != null && newId.isNotEmpty) {
          debugPrint('📱 OneSignal Player/Subscription ID updated: $newId');
          _persistPlayerIdLocally(newId);
          _syncPlayerIdToBackend(newId);
        }
      });

      // 5. Initial playerId check
      final currentId = OneSignal.User.pushSubscription.id;
      if (currentId != null && currentId.isNotEmpty) {
        _persistPlayerIdLocally(currentId);
      }

      _initialized = true;
    } catch (e) {
      debugPrint('❌ OneSignal initialization failed: $e');
    }
  }

  /// Request push notification permissions with polite senior-friendly check
  Future<bool> requestPermission() async {
    try {
      final accepted = await OneSignal.Notifications.requestPermission(true);
      debugPrint('OneSignal notification permission result: $accepted');
      return accepted;
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      return false;
    }
  }

  /// Senior-friendly dialog explaining benefits before system prompt
  Future<void> promptPermissionDialog(BuildContext context) async {
    final box = Hive.box(AppConstants.hiveBoxSettings);
    final prompted = box.get('notif_permission_prompted', defaultValue: false) as bool;
    if (prompted) return;

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final p = ctx.palette;
        Widget bullet(String text) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: AppText.body(size: 15, weight: FontWeight.w600, color: p.textPrimary, height: 1.35),
                    ),
                  ),
                ],
              ),
            );
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.brandGradient),
                    child: const Icon(Icons.notifications_active_rounded, color: AppColors.white, size: 36),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'स्टेटस सूचना पाएं',
                  textAlign: TextAlign.center,
                  style: AppText.heading(size: 21, color: p.textPrimary),
                ),
                const SizedBox(height: 10),
                Text(
                  'रोज़ सुबह नए भक्ति व सुविचार स्टेटस और त्योहारों की विशेष शुभकामनाएं सबसे पहले पाने के लिए नोटिफिकेशन ऑन करें।',
                  textAlign: TextAlign.center,
                  style: AppText.body(size: 15, color: p.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 8),
                bullet('रोज़ सुबह 7 बजे नया स्टेटस'),
                bullet('सण व उत्सव की याद दिलाना'),
                const SizedBox(height: 24),
                GradientButton(
                  label: 'हाँ, शुरू करें',
                  icon: Icons.notifications_active_rounded,
                  onPressed: () async {
                    box.put('notif_permission_prompted', true);
                    Navigator.pop(ctx);
                    await requestPermission();
                  },
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    box.put('notif_permission_prompted', true);
                    Navigator.pop(ctx);
                  },
                  child: const Text('बाद में'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Sync user details with OneSignal on login/restore
  Future<void> syncUser(UserModel user) async {
    if (AppConstants.oneSignalAppId.isEmpty) {
      debugPrint('ℹ️ OneSignal not configured. Skipping user sync.');
      return;
    }
    try {
      // 1. OneSignal external user id login
      await OneSignal.login(user.id);
      debugPrint('👤 OneSignal logged in user: ${user.id}');

      // 2. Set tags for segment targeting
      final tags = <String, String>{
        'user_id': user.id,
        'language': user.language.toUpperCase(),
        'plan': user.plan.toUpperCase(),
        'app_version': AppConstants.appVersion,
      };

      if (user.state != null && user.state!.isNotEmpty) {
        tags['state'] = user.state!;
      }
      if (user.region != null && user.region!.isNotEmpty) {
        tags['region'] = user.region!;
      }

      await OneSignal.User.addTags(tags);
      debugPrint('🏷️ OneSignal tags set: $tags');

      // 3. Sync player ID with backend
      final playerId = OneSignal.User.pushSubscription.id;
      if (playerId != null && playerId.isNotEmpty) {
        await _syncPlayerIdToBackend(playerId);
      }
    } catch (e) {
      debugPrint('Error syncing user with OneSignal: $e');
    }
  }

  // ─── Preferences (Settings screen) ────────────────────────────────────────

  /// Whether the device is currently opted in to push (false if OneSignal is
  /// not configured or the SDK call fails).
  bool get isPushOptedIn {
    if (AppConstants.oneSignalAppId.isEmpty) return false;
    try {
      return OneSignal.User.pushSubscription.optedIn ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opts the device in/out of push. Opting in asks for the OS permission first.
  /// Returns the resulting state.
  Future<bool> setPushEnabled(bool enabled) async {
    if (AppConstants.oneSignalAppId.isEmpty) return false;
    try {
      if (enabled) {
        final granted = await requestPermission();
        if (!granted) return false;
        await OneSignal.User.pushSubscription.optIn();
      } else {
        await OneSignal.User.pushSubscription.optOut();
      }
      return enabled;
    } catch (e) {
      debugPrint('Error changing push preference: $e');
      return isPushOptedIn;
    }
  }

  /// Syncs a boolean preference as a OneSignal tag ("1" / "0") for segment targeting.
  Future<void> setPreferenceTag(String key, bool enabled) async {
    if (AppConstants.oneSignalAppId.isEmpty) return;
    try {
      await OneSignal.User.addTags({key: enabled ? '1' : '0'});
    } catch (e) {
      debugPrint('Error setting OneSignal tag $key: $e');
    }
  }

  /// Logout from OneSignal on app sign-out
  Future<void> onSignOut() async {
    if (AppConstants.oneSignalAppId.isEmpty) return;
    try {
      await OneSignal.logout();
      debugPrint('👋 OneSignal logged out');
    } catch (e) {
      debugPrint('Error logging out from OneSignal: $e');
    }
  }

  // ─── Private Helpers ──────────────────────────────────────────────────────

  NotificationModel _mapOneSignalNotification(OSNotification notification) {
    final data = notification.additionalData;
    String notifType = 'NEW_CONTENT';
    if (data != null && data['type'] != null) {
      notifType = data['type'].toString();
    } else if (data != null && data['notifType'] != null) {
      notifType = data['notifType'].toString();
    }

    String? imageUrl = notification.bigPicture;
    if (imageUrl == null && data != null && data['imageUrl'] != null) {
      imageUrl = data['imageUrl'].toString();
    }

    return NotificationModel(
      id: notification.notificationId,
      title: notification.title ?? 'Status Go',
      body: notification.body ?? '',
      type: notifType,
      data: data,
      imageUrl: imageUrl,
      isRead: false,
      sentAt: DateTime.now(),
    );
  }

  Future<void> _saveNotificationLocally(NotificationModel notif) async {
    try {
      if (!Hive.isBoxOpen(AppConstants.hiveBoxNotifications)) {
        await Hive.openBox(AppConstants.hiveBoxNotifications);
      }
      final box = Hive.box(AppConstants.hiveBoxNotifications);
      await box.put(notif.id, notif.toJson());
    } catch (e) {
      debugPrint('Failed to save notification locally: $e');
    }
  }

  Future<void> _persistPlayerIdLocally(String playerId) async {
    try {
      final box = Hive.box(AppConstants.hiveBoxSettings);
      await box.put(AppConstants.keyOneSignalPlayerId, playerId);
    } catch (_) {}
  }

  Future<void> _syncPlayerIdToBackend(String playerId) async {
    try {
      final box = Hive.box(AppConstants.hiveBoxSettings);
      final token = box.get(AppConstants.keyAccessToken);
      if (token == null) return;

      await apiClient.put('/user/player-id', data: {
        'playerId': playerId,
        'appVersion': AppConstants.appVersion,
      });
      debugPrint('✅ Synced player ID to backend: $playerId');
    } catch (e) {
      debugPrint('Failed to sync player ID to backend: $e');
    }
  }

  void _handleDeepLink(Map<String, dynamic>? data) {
    if (data == null) return;

    String? destination;
    if (data['deepLink'] != null && data['deepLink'].toString().isNotEmpty) {
      destination = data['deepLink'].toString();
    } else if (data['screen'] != null && data['screen'].toString().isNotEmpty) {
      destination = data['screen'].toString();
    }

    if (destination == null || destination.isEmpty) {
      destination = '/home';
    }

    // Standardize route path
    String route;
    if (destination.startsWith('/')) {
      route = destination;
    } else {
      switch (destination.toLowerCase()) {
        case 'home':
          route = '/home';
          break;
        case 'discover':
        case 'festivals':
          route = '/discover';
          break;
        case 'premium':
          route = '/premium';
          break;
        case 'saved':
          route = '/saved';
          break;
        case 'notifications':
          route = '/notifications';
          break;
        default:
          if (data['templateId'] != null) {
            route = '/template/${data['templateId']}';
          } else {
            route = '/home';
          }
      }
    }

    debugPrint('🚀 Notification deep link: $route with data: $data');
    _pendingRoute = route;
    _pendingData = data;
    flushPendingDeepLink();
  }
}
