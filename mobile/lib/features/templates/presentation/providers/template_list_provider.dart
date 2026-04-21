// lib/features/templates/presentation/providers/template_list_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/template_repository.dart';
import '../../domain/models/template_model.dart';

part 'template_list_provider.g.dart';

class TemplateFilter {
  final String? categoryId;
  final String? type;
  final String? lang;

  TemplateFilter({this.categoryId, this.type, this.lang});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TemplateFilter &&
        other.categoryId == categoryId &&
        other.type == type &&
        other.lang == lang;
  }

  @override
  int get hashCode => categoryId.hashCode ^ type.hashCode ^ lang.hashCode;
}

@riverpod
class TemplateList extends _$TemplateList {
  int _page = 1;
  bool _hasMore = true;

  @override
  FutureOr<List<TemplateModel>> build(TemplateFilter filter) async {
    _page = 1;
    _hasMore = true;
    return _fetchPage(1);
  }

  Future<List<TemplateModel>> _fetchPage(int page) async {
    final repo = ref.read(templateRepositoryProvider);
    final results = await repo.getTemplates(
      categoryId: filter.categoryId,
      type: filter.type,
      lang: filter.lang,
      page: page,
      limit: 20,
    );
    
    if (results.length < 20) {
      _hasMore = false;
    }
    
    return results;
  }

  Future<void> loadMore() async {
    if (state.isLoading || !_hasMore || !state.hasValue) return;

    state = const AsyncValue.loading();
    _page++;
    
    final newItems = await AsyncValue.guard(() => _fetchPage(_page));
    
    state = newItems.when(
      data: (items) => AsyncValue.data([...state.value!, ...items]),
      error: (e, st) {
        _page--; // Revert page
        return AsyncValue.error(e, st);
      },
      loading: () => const AsyncValue.loading(),
    );
  }
}

@riverpod
Future<TemplateModel?> singleTemplate(SingleTemplateRef ref, String id) {
  final repo = ref.read(templateRepositoryProvider);
  return repo.getTemplateById(id);
}
