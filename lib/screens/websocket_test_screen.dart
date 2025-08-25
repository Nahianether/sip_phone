import 'package:flutter/material.dart';
import '../services/websocket_service.dart';

class WebSocketTestScreen extends StatefulWidget {
  const WebSocketTestScreen({super.key});

  @override
  State<WebSocketTestScreen> createState() => _WebSocketTestScreenState();
}

class _WebSocketTestScreenState extends State<WebSocketTestScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<String> _messages = [];
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _setupWebSocketHandlers();
  }

  void _setupWebSocketHandlers() {
    WebSocketService.setMessageHandler((String message) {
      setState(() {
        _messages.add('Received: $message');
      });
    });
    
    WebSocketService.setConnectionStatusHandler((bool isConnected) {
      setState(() {
        _isConnected = isConnected;
        _messages.add('Connection status: ${isConnected ? 'Connected' : 'Disconnected'}');
      });
    });
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      WebSocketService.sendMessage(message);
      setState(() {
        _messages.add('Sent: $message');
      });
      _messageController.clear();
    }
  }

  void _connectWebSocket() async {
    // Example of flexible WebSocket configuration
    final config = WebSocketConfig(
      host: 'track-api.ibos.io',
      port: 443,
      path: '/ws',
      useSSL: true,
      queryParams: {
        'api_key': 'iBOS123',
        'emp_id': '564612',
        'emp_name': 'Remon',
        'dep_id': 'sip.ibos.io',
        'acc_id': '564612',
        'test_mode': 'true',
      },
    );
    
    final success = await WebSocketService.connectWithConfig(config);
    if (!success) {
      setState(() {
        _messages.add('Failed to connect to WebSocket');
      });
    }
  }

  void _disconnectWebSocket() async {
    await WebSocketService.disconnectWebSocket();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    _isConnected ? Icons.circle : Icons.circle_outlined,
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'WebSocket Status: ${_isConnected ? 'Connected' : 'Disconnected'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _isConnected ? _disconnectWebSocket : _connectWebSocket,
                    child: Text(_isConnected ? 'Disconnect' : 'Connect'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message to send',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isConnected ? _sendMessage : null,
                child: const Text('Send'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Messages:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final isReceived = message.startsWith('Received:');
                  final isSent = message.startsWith('Sent:');
                  
                  Color? backgroundColor;
                  if (isReceived) backgroundColor = Colors.blue.shade50;
                  if (isSent) backgroundColor = Colors.green.shade50;
                  
                  return Container(
                    color: backgroundColor,
                    child: ListTile(
                      dense: true,
                      title: Text(
                        message,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: isReceived ? Colors.blue.shade700 : 
                                 isSent ? Colors.green.shade700 : null,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _messages.clear();
              });
            },
            child: const Text('Clear Messages'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}