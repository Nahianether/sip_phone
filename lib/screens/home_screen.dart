import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sip_phone/providers/incoming.p.dart';
import 'package:sip_ua/sip_ua.dart';
import '../providers/sip_providers.dart';
import 'dialer_screen.dart';
import 'active_call_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // No need for manual auto-connect - handled by keepAliveAutoConnectProvider
  }

  Future<void> _showIncomingCallDialog(Call call) async {
    final sipService = ref.read(sipServiceProvider);
    await showDialog(
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
              Navigator.push(context, MaterialPageRoute(builder: (context) => ActiveCallScreen(call: call)));
            },
            child: const Text('Answer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Initialize auto-connect provider to trigger connection
    final autoConnectState = ref.watch(keepAliveAutoConnectProvider);
    print('🏠 HomeScreen: AutoConnect state: $autoConnectState');
    
    // Handle connection state
    autoConnectState.when(
      data: (connected) => print('🏠 HomeScreen: Connection result: $connected'),
      loading: () => print('🏠 HomeScreen: Connection in progress...'),
      error: (error, stack) => print('🏠 HomeScreen: Connection error: $error'),
    );
    
    // Listen for call state changes
    ref.listen<AsyncValue<Call>>(callStateProvider, (previous, next) {
      next.whenData((call) {
        final callManager = ref.read(callManagerProvider);
        callManager.addCall(call);

        if (call.direction == 'incoming') {
          _showIncomingCallDialog(tempCall ?? call);
        }
      });
    });

    // Simply return the DialerScreen with its own tab navigation
    return const DialerScreen();
  }
}
