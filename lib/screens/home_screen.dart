import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sip_ua/sip_ua.dart';
import '../providers/sip_providers.dart';
import 'dialer_screen.dart';
import 'settings_screen.dart';
import 'active_call_screen.dart';
import 'websocket_test_screen.dart';

final currentIndexProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attemptAutoConnect();
      _listenToCallStream();
    });
  }

  void _listenToCallStream() {
    ref.listen<AsyncValue<Call>>(callStateProvider, (previous, next) {
      next.whenData((call) {
        final callManager = ref.read(callManagerProvider);
        callManager.addCall(call);
        
        if (call.direction == 'incoming') {
          _showIncomingCallDialog(call);
        }
      });
    });
  }

  Future<void> _attemptAutoConnect() async {
    final sipService = ref.read(sipServiceProvider);
    final credentials = await sipService.getSavedCredentials();
    if (credentials['username'] != null && 
        credentials['password'] != null && 
        credentials['server'] != null &&
        credentials['wsUrl'] != null) {
      
      String server = credentials['server']!;
      if (credentials['username']!.contains('@')) {
        server = credentials['username']!.split('@')[1];
      }
      
      await sipService.connect(
        username: credentials['username']!,
        password: credentials['password']!,
        server: server,
        wsUrl: credentials['wsUrl']!,
        displayName: credentials['displayName'],
        saveCredentials: false,
      );
    }
  }

  void _showIncomingCallDialog(Call call) {
    final sipService = ref.read(sipServiceProvider);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Incoming Call'),
        content: Text('Call from: ${call.remote_identity?.toString() ?? 'Unknown'}'),
        actions: [
          TextButton(
            onPressed: () {
              sipService.hangup(call);
              Navigator.pop(context);
            },
            child: const Text('Decline', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              sipService.answer(call);
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
    final currentIndex = ref.watch(currentIndexProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('SIP Phone'),
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final registrationState = ref.watch(registrationStateProvider);
              final isReconnecting = ref.watch(isReconnectingProvider);
              
              return registrationState.when(
                data: (state) {
                  final isConnected = state.state == RegistrationStateEnum.REGISTERED;
                  
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
                loading: () => const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (error, stack) => const Icon(
                  Icons.error,
                  color: Colors.red,
                  size: 16,
                ),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: currentIndex,
        children: [
          const DialerScreen(),
          const WebSocketTestScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => ref.read(currentIndexProvider.notifier).state = index,
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
}