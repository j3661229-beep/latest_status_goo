// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discover_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$discoverTemplatesHash() => r'6802287869c2c79dd76d2eb761de858a888230df';

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

/// See also [discoverTemplates].
@ProviderFor(discoverTemplates)
const discoverTemplatesProvider = DiscoverTemplatesFamily();

/// See also [discoverTemplates].
class DiscoverTemplatesFamily extends Family<AsyncValue<List<TemplateModel>>> {
  /// See also [discoverTemplates].
  const DiscoverTemplatesFamily();

  /// See also [discoverTemplates].
  DiscoverTemplatesProvider call({
    String? categoryId,
    String? type,
  }) {
    return DiscoverTemplatesProvider(
      categoryId: categoryId,
      type: type,
    );
  }

  @override
  DiscoverTemplatesProvider getProviderOverride(
    covariant DiscoverTemplatesProvider provider,
  ) {
    return call(
      categoryId: provider.categoryId,
      type: provider.type,
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
  String? get name => r'discoverTemplatesProvider';
}

/// See also [discoverTemplates].
class DiscoverTemplatesProvider
    extends AutoDisposeFutureProvider<List<TemplateModel>> {
  /// See also [discoverTemplates].
  DiscoverTemplatesProvider({
    String? categoryId,
    String? type,
  }) : this._internal(
          (ref) => discoverTemplates(
            ref as DiscoverTemplatesRef,
            categoryId: categoryId,
            type: type,
          ),
          from: discoverTemplatesProvider,
          name: r'discoverTemplatesProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$discoverTemplatesHash,
          dependencies: DiscoverTemplatesFamily._dependencies,
          allTransitiveDependencies:
              DiscoverTemplatesFamily._allTransitiveDependencies,
          categoryId: categoryId,
          type: type,
        );

  DiscoverTemplatesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.categoryId,
    required this.type,
  }) : super.internal();

  final String? categoryId;
  final String? type;

  @override
  Override overrideWith(
    FutureOr<List<TemplateModel>> Function(DiscoverTemplatesRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: DiscoverTemplatesProvider._internal(
        (ref) => create(ref as DiscoverTemplatesRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        categoryId: categoryId,
        type: type,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<TemplateModel>> createElement() {
    return _DiscoverTemplatesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is DiscoverTemplatesProvider &&
        other.categoryId == categoryId &&
        other.type == type;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, categoryId.hashCode);
    hash = _SystemHash.combine(hash, type.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin DiscoverTemplatesRef
    on AutoDisposeFutureProviderRef<List<TemplateModel>> {
  /// The parameter `categoryId` of this provider.
  String? get categoryId;

  /// The parameter `type` of this provider.
  String? get type;
}

class _DiscoverTemplatesProviderElement
    extends AutoDisposeFutureProviderElement<List<TemplateModel>>
    with DiscoverTemplatesRef {
  _DiscoverTemplatesProviderElement(super.provider);

  @override
  String? get categoryId => (origin as DiscoverTemplatesProvider).categoryId;
  @override
  String? get type => (origin as DiscoverTemplatesProvider).type;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
