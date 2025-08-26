import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sip_ua/sip_ua.dart';
import '../services/sip_service.dart';
import '../services/call_manager.dart';

final sipServiceProvider = Provider<SipService>((ref) {
  return SipService();
});

final callManagerProvider = Provider<CallManager>((ref) {
  return CallManager();
});

final registrationStateProvider = StreamProvider<RegistrationState>((ref) {
  final sipService = ref.watch(sipServiceProvider);
  return sipService.registrationStream;
});

final callStateProvider = StreamProvider<Call>((ref) {
  final sipService = ref.watch(sipServiceProvider);
  return sipService.callStream;
});

final reconnectStatusProvider = StreamProvider<String>((ref) {
  final sipService = ref.watch(sipServiceProvider);
  return sipService.reconnectStatusStream;
});

final activeCallsProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final callManager = ref.watch(callManagerProvider);
  return callManager.callsStream;
});

final connectionStatusProvider = Provider<bool>((ref) {
  final sipService = ref.watch(sipServiceProvider);
  return sipService.connected;
});

final isReconnectingProvider = Provider<bool>((ref) {
  final sipService = ref.watch(sipServiceProvider);
  return sipService.isReconnecting;
});