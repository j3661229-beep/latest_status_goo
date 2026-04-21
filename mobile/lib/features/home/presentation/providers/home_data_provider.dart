// lib/features/home/presentation/providers/home_data_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/home_repository.dart';
import '../../../templates/domain/models/template_model.dart';
import '../../../templates/data/template_repository.dart';

part 'home_data_provider.g.dart';

class HomeState {
  final List<CategoryModel> categories;
  final List<TemplateModel> featured;
  final List<TemplateModel> trending;
  final List<dynamic> festivals;
  
  HomeState({
    required this.categories,
    required this.featured,
    required this.trending,
    required this.festivals,
  });
}

@Riverpod(keepAlive: true)
class HomeData extends _$HomeData {
  @override
  Future<HomeState> build() async {
    return _fetchData();
  }

  Future<HomeState> _fetchData() async {
    final homeRepo = ref.read(homeRepositoryProvider);
    
    // Fetch all independently to not block on a single failure
    final results = await Future.wait([
      homeRepo.getCategories(),
      homeRepo.getFeatured(),
      homeRepo.getTrending(),
      homeRepo.getUpcomingFestivals()
    ]);

    return HomeState(
      categories: results[0] as List<CategoryModel>,
      featured: results[1] as List<TemplateModel>,
      trending: results[2] as List<TemplateModel>,
      festivals: results[3] as List<dynamic>,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchData());
  }
}
