import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fcm_service.dart';
import 'sip_service.dart';

/// This service demonstrates the background call handling approach
/// without complex CallKit integration issues
class BackgroundCallService {
  static final BackgroundCallService _instance = BackgroundCallService._internal();
  factory BackgroundCallService() => _instance;
  BackgroundCallService._internal();

  final FCMService _fcmService = FCMService();
  final SipService _sipService = SipService();

  Future<void> initialize() async {
    await _fcmService.initialize();
    debugPrint('BackgroundCallService initialized');
  }

  /// Get the FCM token and show it to user
  /// User can send this token to their SIP server
  Future<String?> getFCMToken() async {
    return await _fcmService.getFCMToken();
  }

  /// Demo function to simulate what happens when FCM notification arrives
  /// In real implementation, this would be triggered by FCM
  Future<void> simulateIncomingCallNotification({
    required String callerName,
    required String callerId,
  }) async {
    debugPrint('Background: Simulating incoming call from $callerName');
    
    // This would normally be triggered by FCM notification
    // For now, we'll just show a local notification or dialog
    await _showIncomingCallNotification(callerName, callerId);
  }

  Future<void> _showIncomingCallNotification(String callerName, String callerId) async {
    // In a real app, this would:
    // 1. Show native CallKit UI
    // 2. Play ringtone
    // 3. Wake up the device
    // 4. Show full-screen incoming call UI
    
    debugPrint('Background: Would show CallKit UI for $callerName');
    
    // For demo purposes, we'll just log what would happen
    debugPrint('Background: CallKit would show:');
    debugPrint('  - Caller: $callerName');
    debugPrint('  - Number: $callerId');
    debugPrint('  - Accept/Decline buttons');
    debugPrint('  - Ringtone playing');
  }

  /// Handle when user accepts the call via CallKit
  Future<void> handleCallAcceptedViaCallKit(String callerId) async {
    debugPrint('Background: User accepted call from $callerId');
    
    try {
      // 1. Connect to SIP server
      if (!_sipService.connected) {
        debugPrint('Background: Connecting to SIP server...');
        
        final credentials = await _sipService.getSavedCredentials();
        if (credentials['username'] != null) {
          final connected = await _sipService.connect(
            username: credentials['username']!,
            password: credentials['password']!,
            server: credentials['server']!,
            wsUrl: credentials['wsUrl']!,
            displayName: credentials['displayName'],
            saveCredentials: false,
          );
          
          if (!connected) {
            debugPrint('Background: Failed to connect to SIP server');
            return;
          }
        }
      }
      
      // 2. In a real implementation, you would need to coordinate with your SIP server
      //    to answer the specific incoming call that triggered the FCM notification
      debugPrint('Background: SIP connected, ready to answer call');
      
      // 3. The SIP server would then establish the call connection
      debugPrint('Background: Call should now be connected');
      
    } catch (e) {
      debugPrint('Background: Error handling call accept: $e');
    }
  }

  /// Save FCM token for server integration
  Future<void> saveFCMTokenForServer() async {
    final token = await getFCMToken();
    if (token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token_for_server', token);
      debugPrint('Background: FCM token saved: ${token.substring(0, 20)}...');
    }
  }

  /// Get instruction for server integration
  String getServerIntegrationInstructions() {
    return '''
FCM + CallKit Integration Instructions:

1. FIREBASE SETUP (Required):
   - Go to https://console.firebase.google.com
   - Create project or use existing
   - Add Android app: com.example.sip_phone
   - Download google-services.json → android/app/
   - Add iOS app: com.example.sipPhone  
   - Download GoogleService-Info.plist → ios/

2. SERVER INTEGRATION:
   - Get FCM token from app (see getFCMToken())
   - Send token to your SIP server
   - When call comes to user, server sends FCM notification:
     {
       "to": "<user_fcm_token>",
       "data": {
         "type": "incoming_call",
         "caller_id": "01687722962",
         "caller_name": "John Doe",
         "call_uuid": "unique_call_id"
       }
     }

3. CALLKIT SETUP:
   - FCM notification triggers CallKit UI
   - User sees native call screen (even when app closed)
   - When accepted → app connects to SIP → answers call

4. PERMISSIONS NEEDED:
   - Microphone permission
   - Notification permission
   - Background app refresh
   - CallKit permissions (iOS)

This approach allows incoming calls even when app is completely closed!
''';
  }
}