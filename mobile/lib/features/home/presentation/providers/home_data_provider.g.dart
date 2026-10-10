// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_data_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$upcomingFestivalsHash() => r'1c8dc133853826ef3cdac37fdcbe81d997008df5';

/// Upcoming festivals from GET /festivals/upcoming, falling back to the bundled
/// static calendar when offline / on error / when the server has none.
///
/// Copied from [upcomingFestivals].
@ProviderFor(upcomingFestivals)
final upcomingFestivalsProvider =
    AutoDisposeFutureProvider<List<IndianFestivalItem>>.internal(
  upcomingFestivals,
  name: r'upcomingFestivalsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$upcomingFestivalsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UpcomingFestivalsRef
    = AutoDisposeFutureProviderRef<List<IndianFestivalItem>>;
String _$homeDataHash() => r'54c3b5c4029b9cffc3ccee29f2a8e5180045863d';

/// Single source for GET /templates/home — shared by the Home feed and Discover
/// (kept alive so switching tabs doesn't refetch). Call [refresh] for
/// pull-to-refresh.
///
/// Copied from [HomeData].
@ProviderFor(HomeData)
final homeDataProvider = AsyncNotifierProvider<HomeData, HomeFeedData>.internal(
  HomeData.new,
  name: r'homeDataProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$homeDataHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$HomeData = AsyncNotifier<HomeFeedData>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
