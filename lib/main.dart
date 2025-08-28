import 'dart:developer' show log;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sip_phone/providers/connection.p.dart';
import 'package:sip_phone/providers/incoming.p.dart';
import 'package:sip_phone/services/call_kit.dart';
import 'package:sip_ua/sip_ua.dart';
import 'screens/home_screen.dart';
import 'screens/active_call_screen.dart';
import 'screens/incoming_call_screen.dart';
import 'services/navigation_service.dart';
import 'services/websocket_service.dart';
import 'services/permission_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.initialize();
  runApp(const ProviderScope(child: SipPhoneApp()));
}

class SipPhoneApp extends ConsumerWidget {
  const SipPhoneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(isDarkModeProvider);
    ref.watch(serverConnectionProvider);
    ref.watch(sipHelpersProvider);

    // Initialize auto-connect at app level
    // ref.watch(keepAliveAutoConnectProvider);

    return MaterialApp(
      title: 'SIP Phone',
      navigatorKey: NavigationService.navigatorKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false, // Remove debug banner
      home: const PermissionWrapper(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/active_call': (context) {
          final call = ModalRoute.of(context)!.settings.arguments as Call;
          return ActiveCallScreen(call: call);
        },
        '/incoming_call': (context) {
          final call = ModalRoute.of(context)!.settings.arguments as Call;
          return IncomingCallScreen(call: tempCall ?? call);
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
      debugPrint('Received WebSocket message: $message');
    });

    WebSocketService.setConnectionStatusHandler((bool isConnected) {
      debugPrint('WebSocket connection status changed: $isConnected');
      if (!isConnected) {
        print('------ WebSocket server connection disconnected ------');
      }
    });

    // Initialize CallKit listener for iOS call handling
    listenCallkit();
    debugPrint('CallKit listener initialized');
    await Future.delayed(const Duration(seconds: 2));
    // final r_ = await ref.read(serverConnectionProvider.notifier).connect_();
    // ref.read(serverConnectionProvider.notifier).set(r_);

    await init_();
  }

  Future<void> checkAndNavigationCallingPage() async {
    // NavigationService.navigatorKey.instance.pushNamedIfNotCurrent('incoming_call', args: currentCall);
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    log('didChangeAppLifecycleState ---------$state');
    debugPrint(state.toString());
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