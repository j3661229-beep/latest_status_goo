// lib/features/auth/presentation/providers/current_user_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/auth/session_store.dart';
import '../../domain/models/user_model.dart';

part 'current_user_provider.g.dart';

/// Exposes the [SessionStore] so providers/widgets rebuild on session changes.
final sessionStoreProvider = ChangeNotifierProvider<SessionStore>((ref) => SessionStore.instance);

/// The cached current user. Rebuilds whenever the session store changes
/// (login, profile refresh, logout).
@riverpod
UserModel? currentUser(CurrentUserRef ref) {
  return ref.watch(sessionStoreProvider).readUser();
}
