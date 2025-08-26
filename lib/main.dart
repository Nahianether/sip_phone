import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sip_phone/services/call_kit.dart';
import 'package:sip_ua/sip_ua.dart';
import 'screens/home_screen.dart';
import 'screens/active_call_screen.dart';
import 'screens/incoming_call_screen.dart';
import 'services/navigation_service.dart';
import 'services/websocket_service.dart';
import 'services/permission_service.dart';
import 'services/storage_service.dart';
import 'services/sip_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.initialize();
  runApp(const ProviderScope(child: SipPhoneApp()));
}

class SipPhoneApp extends StatelessWidget {
  const SipPhoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIP Phone',
      navigatorKey: NavigationService.navigatorKey,
      theme: AppTheme.lightTheme,
      home: const PermissionWrapper(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/active_call': (context) {
          final call = ModalRoute.of(context)!.settings.arguments as Call;
          return ActiveCallScreen(call: call);
        },
        '/incoming_call': (context) {
          final call = ModalRoute.of(context)!.settings.arguments as Call;
          return IncomingCallScreen(call: call);
        },
      },
    );
  }
}

class PermissionWrapper extends ConsumerStatefulWidget {
  const PermissionWrapper({super.key});

  @override
  ConsumerState<PermissionWrapper> createState() => _PermissionWrapperState();
}

class _PermissionWrapperState extends ConsumerState<PermissionWrapper> with WidgetsBindingObserver {
  final PermissionService _permissionService = PermissionService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissions();
    checkAndNavigationCallingPage();
    WidgetsBinding.instance.addPostFrameCallback((_) {});
  }

  Future<void> _requestPermissions() async {
    await _permissionService.requestAllPermissions(context);

    WebSocketService.setMessageHandler((String message) {
      print('Received WebSocket message: $message');
    });

    WebSocketService.setConnectionStatusHandler((bool isConnected) {
      print('WebSocket connection status changed: $isConnected');
    });

    // Check for stored SIP credentials before attempting auto-connect
    final storedSettings = StorageService.getSipSettings();
    if (storedSettings != null && 
        storedSettings.autoConnect == true &&
        storedSettings.username?.isNotEmpty == true &&
        storedSettings.password?.isNotEmpty == true &&
        storedSettings.server?.isNotEmpty == true &&
        storedSettings.wsUrl?.isNotEmpty == true) {
      
      print('Auto-connecting with stored credentials...');
      // Use SipService instead of WebSocketService for proper SIP connection
      final sipService = SipService();
      await sipService.connect(
        username: storedSettings.username!,
        password: storedSettings.password!,
        server: storedSettings.server!,
        wsUrl: storedSettings.wsUrl!,
        displayName: storedSettings.displayName,
        saveCredentials: false, // Don't save again
      );
    } else {
      print('Auto-connect skipped: missing credentials');
    }
    
    await init_();
  }

  Future<void> checkAndNavigationCallingPage() async {
    // NavigationService.navigatorKey.instance.pushNamedIfNotCurrent('incoming_call', args: currentCall);
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    print(state);
    if (state == AppLifecycleState.resumed) {
      //Check call when open app from background
      checkAndNavigationCallingPage();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}

 

/*
sip_ws_url =  wss://sip.ibos.io:8089/ws
sip_server = 564612@sip.ibos.io
sip_username = 564612
sip_password = iBOS123
sip_display_name = "Remon"
*/