// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection.p.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sipHelpersHash() => r'b9a4bba6a61fdb6ec4c8ee2b87528e57ee73d325';

/// See also [SipHelpers].
@ProviderFor(SipHelpers)
final sipHelpersProvider = NotifierProvider<SipHelpers, SIPUAHelper?>.internal(
  SipHelpers.new,
  name: r'sipHelpersProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$sipHelpersHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SipHelpers = Notifier<SIPUAHelper?>;
String _$serverConnectionHash() => r'8a7eabccc069249d998af49d0cdbe71883ba8645';

/// See also [ServerConnection].
@ProviderFor(ServerConnection)
final serverConnectionProvider =
    AsyncNotifierProvider<ServerConnection, bool>.internal(
  ServerConnection.new,
  name: r'serverConnectionProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$serverConnectionHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ServerConnection = AsyncNotifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
