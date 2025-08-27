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
/*
final reconnectStatusProvider = StreamProvider<String>((ref) {
  final sipService = ref.watch(sipServiceProvider);
  return sipService.reconnectStatusStream;
});
*/
final activeCallsProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final callManager = ref.watch(callManagerProvider);
  return callManager.callsStream;
});

final connectionStatusProvider = Provider<bool>((ref) {
  final registrationState = ref.watch(registrationStateProvider);
  return registrationState.when(
    data: (state) => state.state == RegistrationStateEnum.REGISTERED,
    loading: () => false,
    error: (error, stack) => false,
  );
});
/*
final autoConnectProvider = FutureProvider<bool>((ref) async {
  print('🔄 AutoConnect Provider: Starting auto-connect process');
  final sipService = ref.read(sipServiceProvider);

  // Check if already connected
  if (sipService.connected) {
    print('✅ AutoConnect Provider: Already connected');
    return true;
  }

  final credentials = await sipService.getSavedCredentials();
  print(
    '🔍 AutoConnect Provider: Retrieved credentials - username: ${credentials['username']}, server: ${credentials['server']}',
  );

  // Check if all required credentials are available and autoConnect is enabled
  if (credentials['username'] != null &&
      credentials['password'] != null &&
      credentials['server'] != null &&
      credentials['wsUrl'] != null) {
    // Check if autoConnect is enabled in saved settings
    final settings = sipService.getSavedSettings();
    print('⚙️ AutoConnect Provider: Auto-connect enabled: ${settings?.autoConnect}');
    if (settings?.autoConnect != true) {
      print('❌ AutoConnect Provider: Auto-connect disabled in settings');
      return false;
    }

    String server = credentials['server']!;
    if (credentials['username']!.contains('@')) {
      server = credentials['username']!.split('@')[1];
    }

    print('🚀 AutoConnect Provider: Attempting connection for ${credentials['username']}');
    final result = await sipService.connect(
      username: credentials['username']!,
      password: credentials['password']!,
      server: server,
      wsUrl: credentials['wsUrl']!,
      displayName: credentials['displayName'],
      saveCredentials: false,
    );
    print('📞 AutoConnect Provider: Connection result: $result');
    return result;
  } else {
    print('❌ AutoConnect Provider: Missing credentials');
  }

  return false;
});
*/

/*
final keepAliveAutoConnectProvider = FutureProvider<bool>((ref) async {
  ref.keepAlive();
  print('🔄 KeepAlive Provider: Initializing connection');

  final sipService = ref.read(sipServiceProvider);

  // Check if already connected
  if (sipService.connected) {
    print('✅ KeepAlive Provider: Already connected');
    return true;
  }

  final credentials = await sipService.getSavedCredentials();
  print(
    '🔍 KeepAlive Provider: Retrieved credentials - username: ${credentials['username']}, server: ${credentials['server']}',
  );

  // Check if all required credentials are available and autoConnect is enabled
  if (credentials['username'] != null &&
      credentials['password'] != null &&
      credentials['server'] != null &&
      credentials['wsUrl'] != null) {
    // Check if autoConnect is enabled in saved settings
    final settings = sipService.getSavedSettings();
    print('⚙️ KeepAlive Provider: Auto-connect enabled: ${settings?.autoConnect}');
    if (settings?.autoConnect != true) {
      print('❌ KeepAlive Provider: Auto-connect disabled in settings');
      return false;
    }

    String server = credentials['server']!;
    if (credentials['username']!.contains('@')) {
      server = credentials['username']!.split('@')[1];
    }

    print('🚀 KeepAlive Provider: Attempting connection for ${credentials['username']}');
    final result = await sipService.connect(
      username: credentials['username']!,
      password: credentials['password']!,
      server: server,
      wsUrl: credentials['wsUrl']!,
      displayName: credentials['displayName'],
      saveCredentials: false,
    );
    print('📞 KeepAlive Provider: Connection result: $result');
    return result;
  } else {
    print('❌ KeepAlive Provider: Missing credentials');
  }

  return false;
});
*/
