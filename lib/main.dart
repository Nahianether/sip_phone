import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sip_ua/sip_ua.dart';
import 'screens/home_screen.dart';
import 'screens/active_call_screen.dart';
import 'screens/incoming_call_screen.dart';
import 'services/navigation_service.dart';
import 'services/websocket_service.dart';

void main() {
  runApp(const SipPhoneApp());
}

class SipPhoneApp extends StatelessWidget {
  const SipPhoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIP Phone',
      navigatorKey: NavigationService.navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
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

class PermissionWrapper extends StatefulWidget {
  const PermissionWrapper({super.key});

  @override
  State<PermissionWrapper> createState() => _PermissionWrapperState();
}

class _PermissionWrapperState extends State<PermissionWrapper> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.microphone,
      Permission.camera,
    ].request();
    
    WebSocketService.setMessageHandler((String message) {
      print('Received WebSocket message: $message');
    });
    
    WebSocketService.setConnectionStatusHandler((bool isConnected) {
      print('WebSocket connection status changed: $isConnected');
    });
    
    // SIP configuration as your server expects
    final sipConfig = SipConfig(
      wsUrl: 'wss://sip.ibos.io:8089/ws',
      server: '564612@sip.ibos.io',
      username: '564612',
      password: 'iBOS123',
      displayName: 'Remon',
    );
    
    await WebSocketService.connectWithSipConfig(sipConfig);
    
    // Example 2: Or use the legacy method (still supported)
    /*
    await WebSocketService.connectWebSocket(
      host: 'track-api.ibos.io', 
      port: 443,
      apiKey: 'iBOS123',
      empId: '564612',
      empName: 'Remon', 
      depId: 'sip.ibos.io',
      accId: '564612',
      additionalParams: {
        'custom_param': 'value',
      },
    );
    */
    
    // Example 3: Or connect directly with URL
    /*
    await WebSocketService.connectWebSocketWithUrl(
      'wss://track-api.ibos.io/ws?api_key=iBOS123&emp_id=564612&emp_name=Remon'
    );
    */
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