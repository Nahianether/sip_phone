import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectionTypeProvider = StateProvider<String>((ref) => 'WebSocket');
final wsUrlProvider = StateProvider<String>((ref) => '');
final sipUriProvider = StateProvider<String>((ref) => '');
final authUserProvider = StateProvider<String>((ref) => '');
final passwordProvider = StateProvider<String>((ref) => '');
final displayNameProvider = StateProvider<String>((ref) => '');
final isConnectingProvider = StateProvider<bool>((ref) => false);
final autoReconnectEnabledProvider = StateProvider<bool>((ref) => true);