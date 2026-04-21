// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'template_list_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$singleTemplateHash() => r'2845d2ad3cfed900195edb0277fdec7ad47d10ed';

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

/// See also [singleTemplate].
@ProviderFor(singleTemplate)
const singleTemplateProvider = SingleTemplateFamily();

/// See also [singleTemplate].
class SingleTemplateFamily extends Family<AsyncValue<TemplateModel?>> {
  /// See also [singleTemplate].
  const SingleTemplateFamily();

  /// See also [singleTemplate].
  SingleTemplateProvider call(
    String id,
  ) {
    return SingleTemplateProvider(
      id,
    );
  }

  @override
  SingleTemplateProvider getProviderOverride(
    covariant SingleTemplateProvider provider,
  ) {
    return call(
      provider.id,
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
  String? get name => r'singleTemplateProvider';
}

/// See also [singleTemplate].
class SingleTemplateProvider extends AutoDisposeFutureProvider<TemplateModel?> {
  /// See also [singleTemplate].
  SingleTemplateProvider(
    String id,
  ) : this._internal(
          (ref) => singleTemplate(
            ref as SingleTemplateRef,
            id,
          ),
          from: singleTemplateProvider,
          name: r'singleTemplateProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$singleTemplateHash,
          dependencies: SingleTemplateFamily._dependencies,
          allTransitiveDependencies:
              SingleTemplateFamily._allTransitiveDependencies,
          id: id,
        );

  SingleTemplateProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String id;

  @override
  Override overrideWith(
    FutureOr<TemplateModel?> Function(SingleTemplateRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SingleTemplateProvider._internal(
        (ref) => create(ref as SingleTemplateRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<TemplateModel?> createElement() {
    return _SingleTemplateProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SingleTemplateProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SingleTemplateRef on AutoDisposeFutureProviderRef<TemplateModel?> {
  /// The parameter `id` of this provider.
  String get id;
}

class _SingleTemplateProviderElement
    extends AutoDisposeFutureProviderElement<TemplateModel?>
    with SingleTemplateRef {
  _SingleTemplateProviderElement(super.provider);

  @override
  String get id => (origin as SingleTemplateProvider).id;
}

String _$templateListHash() => r'23ebb407ca67825f30a053133f0e3dbde736a807';

abstract class _$TemplateList
    extends BuildlessAutoDisposeAsyncNotifier<List<TemplateModel>> {
  late final TemplateFilter filter;

  FutureOr<List<TemplateModel>> build(
    TemplateFilter filter,
  );
}

/// See also [TemplateList].
@ProviderFor(TemplateList)
const templateListProvider = TemplateListFamily();

/// See also [TemplateList].
class TemplateListFamily extends Family<AsyncValue<List<TemplateModel>>> {
  /// See also [TemplateList].
  const TemplateListFamily();

  /// See also [TemplateList].
  TemplateListProvider call(
    TemplateFilter filter,
  ) {
    return TemplateListProvider(
      filter,
    );
  }

  @override
  TemplateListProvider getProviderOverride(
    covariant TemplateListProvider provider,
  ) {
    return call(
      provider.filter,
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
  String? get name => r'templateListProvider';
}

/// See also [TemplateList].
class TemplateListProvider extends AutoDisposeAsyncNotifierProviderImpl<
    TemplateList, List<TemplateModel>> {
  /// See also [TemplateList].
  TemplateListProvider(
    TemplateFilter filter,
  ) : this._internal(
          () => TemplateList()..filter = filter,
          from: templateListProvider,
          name: r'templateListProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$templateListHash,
          dependencies: TemplateListFamily._dependencies,
          allTransitiveDependencies:
              TemplateListFamily._allTransitiveDependencies,
          filter: filter,
        );

  TemplateListProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.filter,
  }) : super.internal();

  final TemplateFilter filter;

  @override
  FutureOr<List<TemplateModel>> runNotifierBuild(
    covariant TemplateList notifier,
  ) {
    return notifier.build(
      filter,
    );
  }

  @override
  Override overrideWith(TemplateList Function() create) {
    return ProviderOverride(
      origin: this,
      override: TemplateListProvider._internal(
        () => create()..filter = filter,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        filter: filter,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<TemplateList, List<TemplateModel>>
      createElement() {
    return _TemplateListProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TemplateListProvider && other.filter == filter;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, filter.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TemplateListRef
    on AutoDisposeAsyncNotifierProviderRef<List<TemplateModel>> {
  /// The parameter `filter` of this provider.
  TemplateFilter get filter;
}

class _TemplateListProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<TemplateList,
        List<TemplateModel>> with TemplateListRef {
  _TemplateListProviderElement(super.provider);

  @override
  TemplateFilter get filter => (origin as TemplateListProvider).filter;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
