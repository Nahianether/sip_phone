import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sip_ua/sip_ua.dart';
import '../services/sip_service.dart';
import '../services/background_call_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SipService _sipService = SipService();
  final BackgroundCallService _backgroundService = BackgroundCallService();
  final _formKey = GlobalKey<FormState>();
  String? _fcmToken;
  
  // Connection Type
  String _connectionType = 'WebSocket';
  
  final _wsUrlController = TextEditingController();
  final _sipUriController = TextEditingController();
  final _authUserController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  
  bool _isConnecting = false;
  bool _autoReconnectEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _loadFCMToken();
  }

  Future<void> _loadSavedCredentials() async {
    final credentials = await _sipService.getSavedCredentials();
    setState(() {
      _wsUrlController.text = credentials['wsUrl'] ?? '';
      _sipUriController.text = credentials['username'] != null && credentials['server'] != null 
          ? '${credentials['username']}@${credentials['server']}' 
          : '';
      _authUserController.text = credentials['username'] ?? '';
      _passwordController.text = credentials['password'] ?? '';
      _displayNameController.text = credentials['displayName'] ?? '';
    });
  }

  Future<void> _loadFCMToken() async {
    final token = await _backgroundService.getFCMToken();
    setState(() {
      _fcmToken = token;
    });
  }

  Future<void> _copyFCMToken() async {
    if (_fcmToken != null) {
      await Clipboard.setData(ClipboardData(text: _fcmToken!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('FCM Token copied to clipboard'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _showBackgroundCallInstructions() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Background Call Setup'),
        content: SingleChildScrollView(
          child: Text(_backgroundService.getServerIntegrationInstructions()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showFCMTestInstructions() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🧪 FCM Testing Guide'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Test FCM notifications using Firebase Console:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('1. 🌐 Go to Firebase Console'),
              const Text('   console.firebase.google.com'),
              const SizedBox(height: 8),
              const Text('2. 📱 Select your project'),
              const SizedBox(height: 8),
              const Text('3. 📬 Go to Cloud Messaging'),
              const SizedBox(height: 8),
              const Text('4. ➕ Click "Send your first message"'),
              const SizedBox(height: 16),
              const Text(
                'Test Configuration:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📝 Notification:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text('Title: Incoming Call from John Doe'),
                    const Text('Body: Tap to answer the call'),
                    const SizedBox(height: 8),
                    const Text(
                      '🎯 Target:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text('Token: (Copy from above)'),
                    const SizedBox(height: 8),
                    const Text(
                      '⚙️ Additional Options > Advanced:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text('Custom data:'),
                    Container(
                      margin: const EdgeInsets.only(left: 16, top: 4),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('type: incoming_call'),
                          Text('caller_id: 01687722962'),
                          Text('caller_name: John Doe'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '🧪 Test Scenarios:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 8),
              const Text('• App in foreground → Check debug logs'),
              const Text('• App in background → Should wake app'),
              const Text('• App closed → Should open app'),
              const SizedBox(height: 16),
              const Text(
                '👀 Watch Flutter logs for:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '🔥 FCM Foreground message received!\n🔥 FCM: *** INCOMING CALL SIMULATION ***',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isConnecting = true;
    });

    // Parse SIP URI to extract username and server
    final sipUri = _sipUriController.text;
    final username = _authUserController.text;
    String server = '';
    
    if (sipUri.contains('@')) {
      server = sipUri.split('@')[1];
    }

    try {
      final success = await _sipService.connect(
        username: username,
        password: _passwordController.text,
        server: server,
        wsUrl: _wsUrlController.text,
        displayName: _displayNameController.text.isNotEmpty 
            ? _displayNameController.text 
            : null,
      );

      setState(() {
        _isConnecting = false;
      });

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
      setState(() {
        _isConnecting = false;
      });
      
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
    await _sipService.disconnect();
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
            
            // Connection Type
            const Text(
              'Connection Type',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Radio<String>(
                  value: 'TCP',
                  groupValue: _connectionType,
                  onChanged: (value) {
                    setState(() {
                      _connectionType = value!;
                    });
                  },
                ),
                const Text('TCP'),
                const SizedBox(width: 40),
                Radio<String>(
                  value: 'WebSocket',
                  groupValue: _connectionType,
                  onChanged: (value) {
                    setState(() {
                      _connectionType = value!;
                    });
                  },
                ),
                const Text('WebSocket'),
              ],
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
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  // TODO: Implement test connection
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Test connection feature coming soon')),
                  );
                },
                icon: const Icon(Icons.network_check),
                label: const Text('Test Connection'),
              ),
            ),
            const SizedBox(height: 20),
            
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
                  icon: const Icon(Icons.visibility),
                  onPressed: () {
                    // TODO: Toggle password visibility
                  },
                ),
                hintText: 'iBOS123',
              ),
              obscureText: true,
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
            const SizedBox(height: 20),
            
            // Auto Reconnect Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Auto Reconnect', style: TextStyle(fontSize: 16)),
                Switch(
                  value: _autoReconnectEnabled,
                  onChanged: (value) {
                    setState(() {
                      _autoReconnectEnabled = value;
                    });
                    _sipService.enableAutoReconnect(value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 30),
            
            // Connection Status and Buttons
            StreamBuilder<RegistrationState>(
              stream: _sipService.registrationStream,
              builder: (context, snapshot) {
                final isConnected = snapshot.data?.state == RegistrationStateEnum.REGISTERED;
                
                return Column(
                  children: [
                    // Reconnection Status
                    StreamBuilder<String>(
                      stream: _sipService.reconnectStatusStream,
                      builder: (context, reconnectSnapshot) {
                        if (reconnectSnapshot.hasData && _sipService.isReconnecting) {
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
                                Expanded(child: Text(reconnectSnapshot.data!)),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    
                    // Connect/Disconnect Button
                    if (!isConnected)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isConnecting ? null : _connect,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isConnecting
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
            ),
            const SizedBox(height: 30),
            
            // Background Calls Section
            const Divider(),
            const SizedBox(height: 20),
            const Text(
              'Background Calls (FCM + CallKit)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'FCM Token for Server Integration',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        onPressed: _showBackgroundCallInstructions,
                        child: const Text('Setup Guide'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _fcmToken ?? 'Loading FCM token...',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: _fcmToken != null ? Colors.black87 : Colors.grey,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: _fcmToken != null ? _copyFCMToken : null,
                          icon: const Icon(Icons.copy, size: 20),
                          tooltip: 'Copy token',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Send this token to your SIP server to enable background calls when app is closed.',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => _showFCMTestInstructions(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('📱 Test FCM Notifications'),
                  ),
                ],
              ),
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