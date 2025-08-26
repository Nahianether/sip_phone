import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sip_ua/sip_ua.dart';
import '../providers/sip_providers.dart';
import '../providers/settings_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _wsUrlController = TextEditingController();
  final _sipUriController = TextEditingController();
  final _authUserController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedCredentials();
    });
  }

  Future<void> _loadSavedCredentials() async {
    final sipService = ref.read(sipServiceProvider);
    final credentials = await sipService.getSavedCredentials();
    
    _wsUrlController.text = credentials['wsUrl'] ?? '';
    _sipUriController.text = credentials['username'] != null && credentials['server'] != null 
        ? '${credentials['username']}@${credentials['server']}' 
        : '';
    _authUserController.text = credentials['username'] ?? '';
    _passwordController.text = credentials['password'] ?? '';
    _displayNameController.text = credentials['displayName'] ?? '';
    
    ref.read(wsUrlProvider.notifier).state = credentials['wsUrl'] ?? '';
    ref.read(authUserProvider.notifier).state = credentials['username'] ?? '';
    ref.read(passwordProvider.notifier).state = credentials['password'] ?? '';
    ref.read(displayNameProvider.notifier).state = credentials['displayName'] ?? '';
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;

    ref.read(isConnectingProvider.notifier).state = true;

    final sipUri = _sipUriController.text;
    final username = _authUserController.text;
    String server = '';
    
    if (sipUri.contains('@')) {
      server = sipUri.split('@')[1];
    }

    try {
      final sipService = ref.read(sipServiceProvider);
      final success = await sipService.connect(
        username: username,
        password: _passwordController.text,
        server: server,
        wsUrl: _wsUrlController.text,
        displayName: _displayNameController.text.isNotEmpty 
            ? _displayNameController.text 
            : null,
      );

      ref.read(isConnectingProvider.notifier).state = false;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Connecting to SIP server...' : 'Connection failed - please check your settings'),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ref.read(isConnectingProvider.notifier).state = false;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _disconnect() async {
    final sipService = ref.read(sipServiceProvider);
    await sipService.disconnect();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Disconnected'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnecting = ref.watch(isConnectingProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            const Text(
              'Account Settings',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // WebSocket URL
            TextFormField(
              controller: _wsUrlController,
              decoration: const InputDecoration(
                labelText: 'WebSocket URL',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
                hintText: 'wss://sip.ibos.io:8089/ws',
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter WebSocket URL';
                }
                if (!value!.startsWith('ws://') && !value.startsWith('wss://')) {
                  return 'URL must start with ws:// or wss://';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // SIP URI
            TextFormField(
              controller: _sipUriController,
              decoration: const InputDecoration(
                labelText: 'SIP URI',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.alternate_email),
                hintText: '564613@sip.ibos.io',
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter SIP URI';
                }
                if (!value!.contains('@')) {
                  return 'Please enter valid SIP URI (user@domain)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Authorization User
            TextFormField(
              controller: _authUserController,
              decoration: const InputDecoration(
                labelText: 'Authorization User',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
                hintText: '564613',
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter authorization user';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Password
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
                hintText: 'Enter your SIP password',
              ),
              obscureText: !_isPasswordVisible,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter password';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Display Name
            TextFormField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
                hintText: '564613',
              ),
            ),
            const SizedBox(height: 30),
            
            // Connection Status and Buttons
            Consumer(
              builder: (context, ref, child) {
                final registrationState = ref.watch(registrationStateProvider);
                final reconnectStatus = ref.watch(reconnectStatusProvider);
                final sipService = ref.watch(sipServiceProvider);
                
                return registrationState.when(
                  data: (state) {
                    final isConnected = state.state == RegistrationStateEnum.REGISTERED;
                    
                    return Column(
                      children: [
                        // Reconnection Status
                        reconnectStatus.when(
                          data: (status) {
                            if (sipService.isReconnecting) {
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange),
                                ),
                                child: Row(
                                  children: [
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(status)),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (error, stack) => const SizedBox.shrink(),
                        ),
                        
                        // Connect/Disconnect Button
                        if (!isConnected)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isConnecting ? null : _connect,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: isConnecting
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text('Register', style: TextStyle(fontSize: 16)),
                            ),
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _disconnect,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text('Disconnect', style: TextStyle(fontSize: 16)),
                            ),
                          ),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(child: Text('Error: $error')),
                );
              },
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Configuration Help:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('• Username: Your SIP account username'),
                  const Text('• Password: Your SIP account password'),
                  const Text('• Server: Your SIP server domain'),
                  const Text('• WebSocket URL: The WSS endpoint for SIP over WebSocket'),
                  const SizedBox(height: 8),
                  Text(
                    'Example: wss://yourserver.com:8089/ws',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _wsUrlController.dispose();
    _sipUriController.dispose();
    _authUserController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }
}