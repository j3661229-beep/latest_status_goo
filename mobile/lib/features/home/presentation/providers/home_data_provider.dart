// lib/features/home/presentation/providers/home_data_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/indian_festivals_calendar.dart';
import '../../data/home_repository.dart';

part 'home_data_provider.g.dart';

/// Single source for GET /templates/home — shared by the Home feed and Discover
/// (kept alive so switching tabs doesn't refetch). Call [refresh] for
/// pull-to-refresh.
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

  /// Re-fetches while keeping the previous data visible.
  Future<void> refresh() async {
    state = const AsyncLoading<HomeFeedData>().copyWithPrevious(state);
    state = await AsyncValue.guard(_fetchData);
  }
}

/// Upcoming festivals from GET /festivals/upcoming, falling back to the bundled
/// static calendar when offline / on error / when the server has none.
@riverpod
Future<List<IndianFestivalItem>> upcomingFestivals(UpcomingFestivalsRef ref) async {
  try {
    final raw = await ref.read(homeRepositoryProvider).getUpcomingFestivals();
    final items = <IndianFestivalItem>[];
    for (var i = 0; i < raw.length; i++) {
      final item = IndianFestivalItem.fromApi(raw[i], i);
      if (item != null) items.add(item);
    }
    if (items.isNotEmpty) return items;
  } catch (_) {
    // Offline fallback below.
  }
  return IndianFestivalsCalendar.getSortedUpcoming();
}
