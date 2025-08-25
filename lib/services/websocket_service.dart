import 'package:flutter/services.dart';

class SipConfig {
  final String wsUrl;
  final String server;
  final String username;
  final String password;
  final String displayName;
  
  const SipConfig({
    required this.wsUrl,
    required this.server,
    required this.username,
    required this.password,
    required this.displayName,
  });
  
  WebSocketConfig toWebSocketConfig() {
    final uri = Uri.parse(wsUrl);
    return WebSocketConfig(
      host: uri.host,
      port: uri.port,
      path: uri.path.isEmpty ? '/ws' : uri.path,
      useSSL: uri.scheme == 'wss',
      headers: {
        'sip_ws_url': wsUrl,
        'sip_server': server,
        'sip_username': username,
        'sip_password': password,
        'sip_display_name': displayName,
      },
    );
  }
}

class WebSocketConfig {
  final String host;
  final int port;
  final String? path;
  final bool useSSL;
  final Map<String, String> queryParams;
  final Map<String, String> headers;
  
  const WebSocketConfig({
    required this.host,
    required this.port,
    this.path,
    this.useSSL = true,
    this.queryParams = const {},
    this.headers = const {},
  });
  
  Map<String, dynamic> toMap() {
    return {
      'host': host,
      'port': port,
      'path': path ?? '/ws',
      'useSSL': useSSL,
      'queryParams': queryParams,
      'headers': headers,
    };
  }
  
  String get url {
    final protocol = useSSL ? 'wss' : 'ws';
    final portStr = (port != 80 && port != 443) ? ':$port' : '';
    final pathStr = path ?? '/ws';
    
    var url = '$protocol://$host$portStr$pathStr';
    
    if (queryParams.isNotEmpty) {
      final params = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      url += '?$params';
    }
    
    return url;
  }
}

class WebSocketService {
  static const MethodChannel _channel = MethodChannel('websocket_service');
  static Function(String)? _messageHandler;
  static Function(bool)? _connectionStatusHandler;
  
  static Future<bool> connectWithConfig(WebSocketConfig config) async {
    try {
      _setupMethodCallHandler();
      final bool result = await _channel.invokeMethod('connectWebSocketWithConfig', config.toMap());
      return result;
    } on PlatformException catch (e) {
      print('Failed to connect WebSocket: ${e.message}');
      return false;
    }
  }
  
  static Future<bool> connectWithSipConfig(SipConfig sipConfig) async {
    return connectWithConfig(sipConfig.toWebSocketConfig());
  }
  
  static Future<bool> connectWebSocket({
    required String host,
    required int port, 
    required String apiKey,
    required String empId,
    required String empName,
    required String depId,
    required String accId,
    Map<String, String>? additionalParams,
  }) async {
    final queryParams = <String, String>{
      'api_key': apiKey,
      'emp_id': empId,
      'emp_name': empName,
      'dep_id': depId,
      'acc_id': accId,
    };
    
    if (additionalParams != null) {
      queryParams.addAll(additionalParams);
    }
    
    final config = WebSocketConfig(
      host: host,
      port: port,
      queryParams: queryParams,
      useSSL: port == 443 || port == 8089 || port == 8443,
    );
    
    return connectWithConfig(config);
  }
  
  static Future<bool> connectWebSocketWithUrl(String url) async {
    try {
      _setupMethodCallHandler();
      final bool result = await _channel.invokeMethod('connectWebSocketWithUrl', {
        'url': url,
      });
      return result;
    } on PlatformException catch (e) {
      print('Failed to connect WebSocket: ${e.message}');
      return false;
    }
  }
  
  static Future<bool> disconnectWebSocket() async {
    try {
      final bool result = await _channel.invokeMethod('disconnectWebSocket');
      return result;
    } on PlatformException catch (e) {
      print('Failed to disconnect WebSocket: ${e.message}');
      return false;
    }
  }
  
  static Future<bool> sendMessage(String message) async {
    try {
      final bool result = await _channel.invokeMethod('sendMessage', {
        'message': message,
      });
      return result;
    } on PlatformException catch (e) {
      print('Failed to send message: ${e.message}');
      return false;
    }
  }
  
  static void setMessageHandler(Function(String) onMessage) {
    _messageHandler = onMessage;
  }
  
  static void setConnectionStatusHandler(Function(bool) onStatusChanged) {
    _connectionStatusHandler = onStatusChanged;
  }
  
  static void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'onMessageReceived':
          final String message = call.arguments['message'];
          _messageHandler?.call(message);
          break;
        case 'onConnectionStatusChanged':
          final bool isConnected = call.arguments['isConnected'];
          _connectionStatusHandler?.call(isConnected);
          break;
      }
    });
  }
}