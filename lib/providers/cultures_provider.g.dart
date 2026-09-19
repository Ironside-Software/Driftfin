// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cultures_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Cultures)
final culturesProvider = CulturesProvider._();

final class CulturesProvider extends $NotifierProvider<Cultures, List<CultureDto>> {
  CulturesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'culturesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$culturesHash();

  @$internal
  @override
  Cultures create() => Cultures();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<CultureDto> value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<List<CultureDto>>(value));
  }
}

String _$culturesHash() => r'588163e393fff0bc643f10c4be598787a3581170';

abstract class _$Cultures extends $Notifier<List<CultureDto>> {
  List<CultureDto> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<CultureDto>, List<CultureDto>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<CultureDto>, List<CultureDto>>,
              List<CultureDto>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
