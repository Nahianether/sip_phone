import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sip_ua/sip_ua.dart';
import '../providers/sip_providers.dart';
import 'dialer_screen.dart';
import 'active_call_screen.dart';
import 'websocket_test_screen.dart';

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
    });
  }

  Future<void> _attemptAutoConnect() async {
    final sipService = ref.read(sipServiceProvider);
    final credentials = await sipService.getSavedCredentials();

    // Check if all required credentials are available and autoConnect is enabled
    if (credentials['username'] != null &&
        credentials['password'] != null &&
        credentials['server'] != null &&
        credentials['wsUrl'] != null) {
      // Check if autoConnect is enabled in saved settings
      final settings = sipService.getSavedSettings();
      if (settings?.autoConnect != true) {
        debugPrint('Auto-connect disabled in settings');
        return;
      }

      String server = credentials['server']!;
      if (credentials['username']!.contains('@')) {
        server = credentials['username']!.split('@')[1];
      }

      debugPrint('Attempting auto-connect with saved credentials');
      await sipService.connect(
        username: credentials['username']!,
        password: credentials['password']!,
        server: server,
        wsUrl: credentials['wsUrl']!,
        displayName: credentials['displayName'],
        saveCredentials: false,
      );
    } else {
      debugPrint('Auto-connect skipped: missing credentials');
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
    // Listen for call state changes
    ref.listen<AsyncValue<Call>>(callStateProvider, (previous, next) {
      next.whenData((call) {
        final callManager = ref.read(callManagerProvider);
        callManager.addCall(call);

        if (call.direction == 'incoming') {
          _showIncomingCallDialog(call);
        }
      });
    });

    // Simply return the DialerScreen with its own tab navigation
    return const DialerScreen();
  }
}
