// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'board_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$boardNotifierHash() => r'5e79b9816a7eeec53d16c880c0247453d2d60a03';

/// See also [BoardNotifier].
@ProviderFor(BoardNotifier)
final boardNotifierProvider =
    AsyncNotifierProvider<BoardNotifier, List<BoardItem>>.internal(
      BoardNotifier.new,
      name: r'boardNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$boardNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$BoardNotifier = AsyncNotifier<List<BoardItem>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
