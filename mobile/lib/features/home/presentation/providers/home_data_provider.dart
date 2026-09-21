// lib/features/home/presentation/providers/home_data_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/home_repository.dart';

part 'home_data_provider.g.dart';

@Riverpod(keepAlive: true)
class HomeData extends _$HomeData {
  @override
  Future<HomeFeedData> build() async {
    return _fetchData();
  }

  Future<HomeFeedData> _fetchData() async {
    final homeRepo = ref.read(homeRepositoryProvider);
    return homeRepo.getHomeFeed();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchData());
  }
}
