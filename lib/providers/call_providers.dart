import 'package:flutter_riverpod/flutter_riverpod.dart';

final isMutedProvider = StateProvider<bool>((ref) => false);
final isSpeakerOnProvider = StateProvider<bool>((ref) => false);
final isHeldProvider = StateProvider<bool>((ref) => false);
final callDurationProvider = StateProvider<String>((ref) => '00:00');
final callStatusProvider = StateProvider<String>((ref) => 'Connecting...');