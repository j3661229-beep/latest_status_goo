// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$trendingTermsHash() => r'c54692debeaee73892e9192cc3b5280f0ebf515d';

/// See also [trendingTerms].
@ProviderFor(trendingTerms)
final trendingTermsProvider = AutoDisposeFutureProvider<List<String>>.internal(
  trendingTerms,
  name: r'trendingTermsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$trendingTermsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TrendingTermsRef = AutoDisposeFutureProviderRef<List<String>>;
String _$searchTemplatesHash() => r'e0eefc32fb4cd23f5b640e74f5237c038ef406ef';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$SearchTemplates
    extends BuildlessAutoDisposeAsyncNotifier<List<TemplateModel>> {
  late final String query;

  FutureOr<List<TemplateModel>> build(
    String query,
  );
}

/// See also [SearchTemplates].
@ProviderFor(SearchTemplates)
const searchTemplatesProvider = SearchTemplatesFamily();

/// See also [SearchTemplates].
class SearchTemplatesFamily extends Family<AsyncValue<List<TemplateModel>>> {
  /// See also [SearchTemplates].
  const SearchTemplatesFamily();

  /// See also [SearchTemplates].
  SearchTemplatesProvider call(
    String query,
  ) {
    return SearchTemplatesProvider(
      query,
    );
  }

  @override
  SearchTemplatesProvider getProviderOverride(
    covariant SearchTemplatesProvider provider,
  ) {
    return call(
      provider.query,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'searchTemplatesProvider';
}

/// See also [SearchTemplates].
class SearchTemplatesProvider extends AutoDisposeAsyncNotifierProviderImpl<
    SearchTemplates, List<TemplateModel>> {
  /// See also [SearchTemplates].
  SearchTemplatesProvider(
    String query,
  ) : this._internal(
          () => SearchTemplates()..query = query,
          from: searchTemplatesProvider,
          name: r'searchTemplatesProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$searchTemplatesHash,
          dependencies: SearchTemplatesFamily._dependencies,
          allTransitiveDependencies:
              SearchTemplatesFamily._allTransitiveDependencies,
          query: query,
        );

  SearchTemplatesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.query,
  }) : super.internal();

  final String query;

  @override
  FutureOr<List<TemplateModel>> runNotifierBuild(
    covariant SearchTemplates notifier,
  ) {
    return notifier.build(
      query,
    );
  }

  @override
  Override overrideWith(SearchTemplates Function() create) {
    return ProviderOverride(
      origin: this,
      override: SearchTemplatesProvider._internal(
        () => create()..query = query,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        query: query,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<SearchTemplates, List<TemplateModel>>
      createElement() {
    return _SearchTemplatesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SearchTemplatesProvider && other.query == query;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, query.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SearchTemplatesRef
    on AutoDisposeAsyncNotifierProviderRef<List<TemplateModel>> {
  /// The parameter `query` of this provider.
  String get query;
}

class _SearchTemplatesProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<SearchTemplates,
        List<TemplateModel>> with SearchTemplatesRef {
  _SearchTemplatesProviderElement(super.provider);

  @override
  String get query => (origin as SearchTemplatesProvider).query;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
