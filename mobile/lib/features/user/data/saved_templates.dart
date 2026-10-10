// lib/features/user/data/saved_templates.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/api/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../templates/data/template_repository.dart';
import '../../templates/domain/models/template_model.dart';

/// GET /user/saved — errors propagate so the Saved screen shows its retry UI.
final savedTemplatesProvider = FutureProvider.autoDispose<List<TemplateModel>>((ref) async {
  final res = await apiClient.get('/user/saved', queryParameters: {'page': 1, 'limit': 50});
  final templates = parseTemplateList(res.data);
  // Keep the cached id set in sync with the server's list.
  ref.read(savedIdsProvider.notifier).replaceAll(templates.map((t) => t.id));
  return templates;
});

/// Set of saved template ids, cached in the saved box so the bookmark icon has
/// the right initial state immediately (even offline).
final savedIdsProvider = StateNotifierProvider<SavedIdsNotifier, Set<String>>((ref) {
  return SavedIdsNotifier(ref);
});

class SavedIdsNotifier extends StateNotifier<Set<String>> {
  SavedIdsNotifier(this._ref) : super(_readCache());

  final Ref _ref;

  static Box get _box => Hive.box(AppConstants.hiveBoxSaved);

  static Set<String> _readCache() {
    try {
      final raw = _box.get(AppConstants.keySavedTemplateIds);
      if (raw is List) return raw.map((e) => e.toString()).toSet();
    } catch (_) {}
    return <String>{};
  }

  void _persist() {
    _box.put(AppConstants.keySavedTemplateIds, state.toList());
  }

  void replaceAll(Iterable<String> ids) {
    state = ids.toSet();
    _persist();
  }

  bool isSaved(String id) => state.contains(id);

  bool _synced = false;

  /// Syncs the id set from GET /user/saved once per app session (errors are
  /// ignored — the cached set is used meanwhile).
  Future<void> ensureSynced() async {
    if (_synced) return;
    _synced = true;
    try {
      final res = await apiClient.get('/user/saved', queryParameters: {'page': 1, 'limit': 50});
      if (!mounted) return;
      replaceAll(parseTemplateList(res.data).map((t) => t.id));
    } catch (_) {
      _synced = false;
    }
  }

  /// Optimistically toggles a bookmark. Rolls back and rethrows on failure.
  /// Returns the new saved state.
  Future<bool> toggle(String templateId) async {
    final wasSaved = state.contains(templateId);
    _set(templateId, !wasSaved);
    try {
      if (wasSaved) {
        await apiClient.delete('/user/saved/$templateId');
      } else {
        await apiClient.post('/user/saved/$templateId');
      }
      _ref.invalidate(savedTemplatesProvider);
      return !wasSaved;
    } catch (_) {
      _set(templateId, wasSaved);
      rethrow;
    }
  }

  void _set(String id, bool saved) {
    final next = {...state};
    if (saved) {
      next.add(id);
    } else {
      next.remove(id);
    }
    state = next;
    _persist();
  }
}
