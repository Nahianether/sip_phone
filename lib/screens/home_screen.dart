import 'package:flutter/material.dart';
import 'package:sip_ua/sip_ua.dart';
import '../services/sip_service.dart';
import '../services/call_manager.dart';
import 'dialer_screen.dart';
import 'settings_screen.dart';
import 'active_call_screen.dart';
import 'websocket_test_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SipService _sipService = SipService();
  final CallManager _callManager = CallManager();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _sipService.callStream.listen(_handleCall);
    _attemptAutoConnect();
  }

  Future<void> _attemptAutoConnect() async {
    final credentials = await _sipService.getSavedCredentials();
    if (credentials['username'] != null && 
        credentials['password'] != null && 
        credentials['server'] != null &&
        credentials['wsUrl'] != null) {
      
      // Extract server from SIP URI if needed
      String server = credentials['server']!;
      if (credentials['username']!.contains('@')) {
        server = credentials['username']!.split('@')[1];
      }
      
      await _sipService.connect(
        username: credentials['username']!,
        password: credentials['password']!,
        server: server,
        wsUrl: credentials['wsUrl']!,
        displayName: credentials['displayName'],
        saveCredentials: false,
      );
    }
  }

  void _handleCall(Call call) {
    _callManager.addCall(call);
    
    if (call.direction == 'incoming') {
      _showIncomingCallDialog(call);
    }
  }

  void _showIncomingCallDialog(Call call) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Incoming Call'),
        content: Text('Call from: ${call.remote_identity?.toString() ?? 'Unknown'}'),
        actions: [
          TextButton(
            onPressed: () {
              _sipService.hangup(call);
              Navigator.pop(context);
            },
            child: const Text('Decline', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              _sipService.answer(call);
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ActiveCallScreen(call: call),
                ),
              );
            },
            child: const Text('Answer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SIP Phone'),
        actions: [
          StreamBuilder<RegistrationState>(
            stream: _sipService.registrationStream,
            builder: (context, snapshot) {
              final isConnected = snapshot.data?.state == RegistrationStateEnum.REGISTERED;
              final isReconnecting = _sipService.isReconnecting;
              
              Color statusColor;
              String statusText;
              IconData statusIcon;
              
              if (isReconnecting) {
                statusColor = Colors.orange;
                statusText = 'Reconnecting';
                statusIcon = Icons.sync;
              } else if (isConnected) {
                statusColor = Colors.green;
                statusText = 'Connected';
                statusIcon = Icons.circle;
              } else {
                statusColor = Colors.red;
                statusText = 'Disconnected';
                statusIcon = Icons.circle;
              }
              
              return Container(
                margin: const EdgeInsets.only(right: 16),
                child: Row(
                  children: [
                    Icon(
                      statusIcon,
                      color: statusColor,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const DialerScreen(),
          const WebSocketTestScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dialpad),
            label: 'Dialer',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.wifi),
            label: 'WebSocket',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sipService.dispose();
    _callManager.dispose();
    super.dispose();
  }
}