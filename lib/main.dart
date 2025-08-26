import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sip_ua/sip_ua.dart';
import 'screens/home_screen.dart';
import 'screens/active_call_screen.dart';
import 'screens/incoming_call_screen.dart';
import 'services/navigation_service.dart';
import 'services/permission_service.dart';
import 'services/storage_service.dart';
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

class _PermissionWrapperState extends ConsumerState<PermissionWrapper> {
  final PermissionService _permissionService = PermissionService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermissions();
    });
  }

  Future<void> _requestPermissions() async {
    await _permissionService.requestAllPermissions(context);
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}
