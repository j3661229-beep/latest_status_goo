// lib/core/data/notification_repository.dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../api/api_client.dart';
import '../constants/app_constants.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

final unreadNotificationsCountProvider = StateProvider<int>((ref) {
  return 0;
});

final notificationsListProvider =
    StateNotifierProvider<NotificationsNotifier, AsyncValue<List<NotificationModel>>>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  return NotificationsNotifier(repo, ref);
});

// ─── Repository ───────────────────────────────────────────────────────────────

class NotificationRepository {
  // Shared authenticated client (handles token refresh).
  Dio _getDio() => apiClient;

  /// Fetch notifications from backend or fallback to local Hive cache
  Future<List<NotificationModel>> fetchNotifications({int page = 1, int limit = 30}) async {
    List<NotificationModel> backendList = [];
    try {
      final dio = _getDio();
      final resp = await dio.get('/user/notifications', queryParameters: {
        'page': page,
        'limit': limit,
      });

      if (resp.data != null && resp.data['data'] != null) {
        final raw = resp.data['data'] as List;
        backendList = raw.map((item) => NotificationModel.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Backend notifications fetch failed, using local cache: $e');
    }

    // Read local Hive notifications
    final localList = getLocalNotifications();

    // Merge: backend takes precedence, local items not in backend are appended
    final Map<String, NotificationModel> merged = {};
    for (final item in backendList) {
      merged[item.id] = item;
    }
    for (final item in localList) {
      if (!merged.containsKey(item.id)) {
        merged[item.id] = item;
      }
    }

    final result = merged.values.toList()
      ..sort((a, b) => b.sentAt.compareTo(a.sentAt));

    // Save to Hive for offline availability
    await _cacheAllLocally(result);

    return result;
  }

  List<NotificationModel> getLocalNotifications() {
    try {
      if (!Hive.isBoxOpen(AppConstants.hiveBoxNotifications)) return [];
      final box = Hive.box(AppConstants.hiveBoxNotifications);
      final List<NotificationModel> items = [];
      for (final key in box.keys) {
        final val = box.get(key);
        if (val != null && val is Map) {
          try {
            items.add(NotificationModel.fromJson(Map<String, dynamic>.from(val)));
          } catch (_) {}
        }
      }
      items.sort((a, b) => b.sentAt.compareTo(a.sentAt));
      return items;
    } catch (_) {
      return [];
    }
  }

  Future<void> markAsRead(String id) async {
    // 1. Update local
    try {
      if (Hive.isBoxOpen(AppConstants.hiveBoxNotifications)) {
        final box = Hive.box(AppConstants.hiveBoxNotifications);
        final item = box.get(id);
        if (item != null && item is Map) {
          final updated = Map<String, dynamic>.from(item);
          updated['isRead'] = true;
          await box.put(id, updated);
        }
      }
    } catch (_) {}

    // 2. Update backend
    try {
      final dio = _getDio();
      await dio.put('/user/notifications/$id/read');
    } catch (e) {
      debugPrint('Error marking notification as read on backend: $e');
    }
  }

  Future<void> markAllAsRead() async {
    // 1. Update all local
    try {
      if (Hive.isBoxOpen(AppConstants.hiveBoxNotifications)) {
        final box = Hive.box(AppConstants.hiveBoxNotifications);
        for (final key in box.keys) {
          final item = box.get(key);
          if (item != null && item is Map) {
            final updated = Map<String, dynamic>.from(item);
            updated['isRead'] = true;
            await box.put(key, updated);
          }
        }
      }
    } catch (_) {}

    // 2. Update backend
    try {
      final dio = _getDio();
      await dio.put('/user/notifications/read-all');
    } catch (e) {
      debugPrint('Error marking all notifications as read on backend: $e');
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      if (Hive.isBoxOpen(AppConstants.hiveBoxNotifications)) {
        final box = Hive.box(AppConstants.hiveBoxNotifications);
        await box.delete(id);
      }
    } catch (_) {}

    try {
      final dio = _getDio();
      await dio.delete('/user/notifications/$id');
    } catch (_) {}
  }

  Future<void> _cacheAllLocally(List<NotificationModel> list) async {
    try {
      if (!Hive.isBoxOpen(AppConstants.hiveBoxNotifications)) return;
      final box = Hive.box(AppConstants.hiveBoxNotifications);
      for (final item in list) {
        await box.put(item.id, item.toJson());
      }
    } catch (_) {}
  }
}

// ─── State Notifier ───────────────────────────────────────────────────────────

class NotificationsNotifier extends StateNotifier<AsyncValue<List<NotificationModel>>> {
  final NotificationRepository _repo;
  final Ref _ref;
  StreamSubscription<NotificationModel>? _sub;

  NotificationsNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
    // Deferred: load() updates unreadNotificationsCountProvider, and Riverpod forbids modifying another
    // provider while this one is still initialising (throws in debug builds).
    Future<void>.microtask(() {
      if (mounted) load();
    });
    // Listen for live foreground notifications arriving via OneSignal
    _sub = NotificationService.instance.onNotificationReceived.listen((notif) {
      _onLiveNotificationArrived(notif);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    // Load local immediately for instant UI
    final local = _repo.getLocalNotifications();
    if (local.isNotEmpty) {
      state = AsyncValue.data(local);
      _updateUnreadCount(local);
    }

    try {
      final items = await _repo.fetchNotifications();
      state = AsyncValue.data(items);
      _updateUnreadCount(items);
    } catch (e, st) {
      if (local.isEmpty) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> markAsRead(String id) async {
    final current = state.valueOrNull ?? [];
    final updated = current.map((n) {
      if (n.id == id) return n.copyWith(isRead: true);
      return n;
    }).toList();

    state = AsyncValue.data(updated);
    _updateUnreadCount(updated);
    await _repo.markAsRead(id);
  }

  Future<void> markAllAsRead() async {
    final current = state.valueOrNull ?? [];
    final updated = current.map((n) => n.copyWith(isRead: true)).toList();

    state = AsyncValue.data(updated);
    _updateUnreadCount(updated);
    await _repo.markAllAsRead();
  }

  Future<void> delete(String id) async {
    final current = state.valueOrNull ?? [];
    final updated = current.where((n) => n.id != id).toList();

    state = AsyncValue.data(updated);
    _updateUnreadCount(updated);
    await _repo.deleteNotification(id);
  }

  void _onLiveNotificationArrived(NotificationModel notif) {
    final current = state.valueOrNull ?? [];
    // Prepend new notification to top
    final updated = [notif, ...current.where((n) => n.id != notif.id)];
    state = AsyncValue.data(updated);
    _updateUnreadCount(updated);
  }

  void _updateUnreadCount(List<NotificationModel> items) {
    final unread = items.where((n) => !n.isRead).length;
    _ref.read(unreadNotificationsCountProvider.notifier).state = unread;
  }
}
