// lib/features/auth/presentation/providers/current_user_provider.dart
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/models/user_model.dart';

part 'current_user_provider.g.dart';

@riverpod
UserModel? currentUser(CurrentUserRef ref) {
  try {
    final box = Hive.box(AppConstants.hiveBoxSettings);
    final userStr = box.get(AppConstants.keyUser);
    if (userStr == null) return null;

    // The user is stored as a JSON string representation
    // Try both Map and String formats
    if (userStr is Map<String, dynamic>) {
      return UserModel.fromJson(userStr);
    }
    if (userStr is String) {
      // May be stored as a JSON string
      try {
        final decoded = jsonDecode(userStr);
        if (decoded is Map<String, dynamic>) {
          return UserModel.fromJson(decoded);
        }
      } catch (_) {}
    }
    return null;
  } catch (_) {
    return null;
  }
}
